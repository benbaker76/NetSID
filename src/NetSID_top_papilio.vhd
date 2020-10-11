-------------------------------------------------------------------------------
--
-- This is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License,
-- or any later version, see <http://www.gnu.org/licenses/>
--
-- This is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- Company:  N/A
-- Engineer: Alex
--
-- Create Date:   04/23/2020
-- Design Name:   
-- Module Name:   NetSID_top_papilio.vhd
-- Project Name:  NetSID
-- Target Device: xc6slx9-tqg144-2
-- Tool versions: ISE 14.7
-- Description:   
-- 
-- NetSID top module
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- 
-------------------------------------------------------------------------------
library ieee;
	use ieee.std_logic_1164.all;
--	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;

library UNISIM;
	use UNISIM.Vcomponents.all;

entity NetSID is
	port (
		JOY_SELECT		: in  std_logic;	-- active low reset
		CLK				: in  std_logic;	-- main clock 32Mhz
		AUDIO1_LEFT		: out std_logic;	-- PWM audio out
		AUDIO1_RIGHT	: out std_logic;	-- PWM audio out
		LED1				: out std_logic;	-- output LED
		RX					: in  std_logic;	-- RS232 data to FPGA
		TX					: out std_logic	-- RS232 data from FPGA
		);
	end;

architecture RTL of NetSID is

	type uartsm is (
		st00,
		st01,
		st02,
		st03,
		st04
	);

	type RAMtoSIDState is (
		stInit,
		stDelay1,
		stDelay2,
		stSync,
		stWait1,
		stWait2,
		stAddr,
		stData,
		stWrite,
		stIdle
	);

	signal clk_div					: unsigned(4 downto 0) := (others => '0');
	signal clk01					: std_logic := '0';	--  1 Mhz
	signal clk04					: std_logic := '0';	--  4 Mhz
	signal clk32					: std_logic := '0';	-- 32 Mhz

	signal stUARTnow				: uartsm := st01;
	signal stUARTnext				: uartsm := st01;
	signal tx_data					: unsigned(7 downto 0) := (others => '1');
	signal rx_data					: unsigned(7 downto 0) := (others => '1');
	signal TxD_busy				: std_logic := '0';
	signal write_to_uart			: std_logic := '0';
	signal rx_data_present		: std_logic := '0';

	signal stSIDnow				: RAMtoSIDState := stInit;
	signal stSIDnext				: RAMtoSIDState := stInit;
	
	signal sid_num					: unsigned(1 downto 0) := (others => '0');
	signal sid_addr				: unsigned(4 downto 0) := (others => '0');
	signal sid_din					: unsigned(7 downto 0) := (others => '0');

	signal sid1_addr				: unsigned(4 downto 0) := (others => '0');
	signal sid1_audio				: std_logic_vector(17 downto 0) := (others => '0');
	signal sid1_dout				: unsigned(7 downto 0) := (others => '0');
	signal sid1_din				: unsigned(7 downto 0) := (others => '0');
	signal sid1_we					: std_logic := '0';
	signal sid1_px					: unsigned(7 downto 0) := (others => '0');
	signal sid1_py					: unsigned(7 downto 0) := (others => '0');

	signal sid2_addr				: unsigned(4 downto 0) := (others => '0');
	signal sid2_audio				: std_logic_vector(17 downto 0) := (others => '0');
	signal sid2_dout				: unsigned(7 downto 0) := (others => '0');
	signal sid2_din				: unsigned(7 downto 0) := (others => '0');
	signal sid2_we					: std_logic := '0';
	signal sid2_px					: unsigned(7 downto 0) := (others => '0');
	signal sid2_py					: unsigned(7 downto 0) := (others => '0');
	
	signal sid3_addr				: unsigned(4 downto 0) := (others => '0');
	signal sid3_audio				: std_logic_vector(17 downto 0) := (others => '0');
	signal sid3_dout				: unsigned(7 downto 0) := (others => '0');
	signal sid3_din				: unsigned(7 downto 0) := (others => '0');
	signal sid3_we					: std_logic := '0';
	signal sid3_px					: unsigned(7 downto 0) := (others => '0');
	signal sid3_py					: unsigned(7 downto 0) := (others => '0');

	signal ram_ai					: unsigned(13 downto 0) := (others => '0');
	signal ram_ao					: unsigned(13 downto 0) := (others => '1');
	signal ram_do					: std_logic_vector( 7 downto 0) := (others => '0');

	signal cycle_cnt				: unsigned(20 downto 0) := (others => '0');
	signal rst						: std_logic := '0';
	signal audio_pwm				: std_logic := '0';
	signal nrxdp					: std_logic := '0';
	signal fifo_empty				: std_logic := '1';
	signal fifo_stop				: std_logic := '1';
	signal buf_full				: std_logic := '0';
	signal buf_full_last			: std_logic := '0';
	signal buf_full_fe			: std_logic := '0';
	signal buf_full_re			: std_logic := '0';

begin
	AUDIO1_LEFT		<= audio_pwm;
	AUDIO1_RIGHT	<= audio_pwm;
	nrxdp				<= not rx_data_present;

  -----------------------------------------------------------------------------
  -- Clocks
  -----------------------------------------------------------------------------
	--
	-- provides a selection of synchronous clocks 1, 4 and 32 Mhz
	-- could provide the baud clock for serial comms
	-- provides a timed reset signal
	--
	u_clocks: entity work.NetSID_CLOCKS
	port map (
		I_CLK			=> CLK,
		I_RESET		=> not JOY_SELECT,
		--
		O_CLK_1M		=> clk01,
		O_CLK_4M		=> clk04,
		O_CLK_32M	=> clk32,
		O_RESET		=> rst					-- timed active high reset
	);

  -----------------------------------------------------------------------------
  -- UART RS232 rx and tx
  -----------------------------------------------------------------------------
  --
  -- 8-bit, 1 stop-bit, no parity transmit and receive macros.
  -- Each contains an embedded 16-byte FIFO buffer.
  --
	
	des: entity work.async_receiver
	port map (
		clk				=> clk32,
		RxD				=> RX,

		RxD_data			=> rx_data,				-- received byte
		RxD_data_ready	=> rx_data_present	-- one clock pulse when RxD_data is valid
	);

	ser: entity work.async_transmitter
	port map (
		clk				=> clk32,
		TxD				=> TX,

		TxD_start		=> write_to_uart,		--	start send when set
		TxD_data			=> tx_data,				-- data byte to send
		TxD_busy			=> TxD_busy				-- busy when set
	);

  -----------------------------------------------------------------------------
  -- FIFO buffer
  -----------------------------------------------------------------------------
	--
	-- dual ported async read / write access
	--
	u_ram: entity work.RAM_16K
	port map (
		DOA			=> ram_do,
		ADDRA			=> std_logic_vector(ram_ao),
		CLKA			=> clk32,
		--
		DIB			=> std_logic_vector(rx_data),
		ADDRB			=> std_logic_vector(ram_ai),
		CLKB			=> nrxdp
	);
	
	u_audiomixer: entity work.audiomixer
	port map(
		clk				=> clk32,
		rst				=> rst,
		ena				=> '1',
		data_in1			=> sid1_audio,
		data_in2			=> sid2_audio,
		data_in3			=> sid3_audio,
		audio_out		=> audio_pwm
	);

	-----------------------------------------------------------------------------
	-- SID 6581
	-----------------------------------------------------------------------------
	--
	-- Implementation of SID sound chip
	--
	u_sid1: entity work.sid6581
	port map (
		clk_1mhz		=> clk01,		-- main SID clock
		clk32			=> clk32,		-- main clock signal
--		clk_DAC		=> clk32,		-- DAC clock signal, must be as high as possible for the best results
		reset			=> rst,			-- high active reset signal (reset when reset = '1')
		cs				=> '1',			-- "chip select", when this signal is '1' this model can be accessed
		we				=> sid1_we,		-- when '1' this model can be written to, otherwise access is considered as read
		addr			=> sid1_addr,	-- address lines (5 bits)
		di				=> sid1_din,	-- data in (to chip, 8 bits)
		do				=> sid1_dout,	-- data out	(from chip, 8 bits)
		pot_x			=> sid1_px,		-- paddle input-X
		pot_y			=> sid1_py,		-- paddle input-Y
--		audio_out	=> audio_pwm,	-- this line outputs the PWM audio-signal
		std_logic_vector(audio_data)	=> sid1_audio	-- audio out 18 bits
	);
		
	--
	u_sid2: entity work.sid6581
	port map (
		clk_1mhz		=> clk01,		-- main SID clock
		clk32			=> clk32,		-- main clock signal
--		clk_DAC		=> clk32,		-- DAC clock signal, must be as high as possible for the best results
		reset			=> rst,			-- high active reset signal (reset when reset = '1')
		cs				=> '1',			-- "chip select", when this signal is '1' this model can be accessed
		we				=> sid2_we,		-- when '1' this model can be written to, otherwise access is considered as read
		addr			=> sid2_addr,	-- address lines (5 bits)
		di				=> sid2_din,	-- data in (to chip, 8 bits)
		do				=> sid2_dout,	-- data out	(from chip, 8 bits)
		pot_x			=> sid2_px,		-- paddle input-X
		pot_y			=> sid2_py,		-- paddle input-Y
--		audio_out	=> audio_pwm,	-- this line outputs the PWM audio-signal
		std_logic_vector(audio_data)	=> sid2_audio	-- audio out 18 bits
	);
		
	--
	u_sid3: entity work.sid6581
	port map (
		clk_1mhz		=> clk01,		-- main SID clock
		clk32			=> clk32,		-- main clock signal
--		clk_DAC		=> clk32,		-- DAC clock signal, must be as high as possible for the best results
		reset			=> rst,			-- high active reset signal (reset when reset = '1')
		cs				=> '1',			-- "chip select", when this signal is '1' this model can be accessed
		we				=> sid3_we,		-- when '1' this model can be written to, otherwise access is considered as read
		addr			=> sid3_addr,	-- address lines (5 bits)
		di				=> sid3_din,	-- data in (to chip, 8 bits)
		do				=> sid3_dout,	-- data out	(from chip, 8 bits)
		pot_x			=> sid3_px,		-- paddle input-X
		pot_y			=> sid3_py,		-- paddle input-Y
--		audio_out	=> audio_pwm,	-- this line outputs the PWM audio-signal
		std_logic_vector(audio_data)	=> sid3_audio	-- audio out 18 bits
	);

	-----------------------------------------------------------------------------
	-- state machine control for ram_to_sid process
	sm_control: process (clk32, rst)
	begin
		if falling_edge(clk32) then
			if rst = '1' then
				stSIDnow <= stInit;
			else
				stSIDnow <= stSIDnext;
			end if;
		end if;
	end process;

	-- detect FIFO empty state
	fifo_control: process(clk32)
	begin
		if falling_edge(clk32) then
			if (ram_ai = ram_ao) then
					fifo_empty <= '1';
				else
					fifo_empty <= '0';
			end if;
		end if;
	end process;

	-- copy data from FIFO to SID at cycle accurate rate
	-- read pointer cannot overtake write pointer and will block (wait)
	ram_to_sid: process (clk04, stSIDnow, rst)
	begin
		if rst = '1' then
			ram_ao <= (others => '1');
			stSIDnext	<= stInit;
		elsif rising_edge(clk04) then
			if fifo_empty = '0' then
				case stSIDnow is
					when stInit		=>
						sid1_we			<= '0';
						sid2_we			<= '0';
						sid3_we			<= '0';
						ram_ao			<= (others => '0');
						cycle_cnt		<= (others => '0');
						stSIDnext		<= stDelay1;
					when stDelay1	=>
						sid1_we			<= '0';
						sid2_we			<= '0';
						sid3_we			<= '0';
						cycle_cnt(17 downto 10) <= unsigned(ram_do);		-- delay high
						ram_ao			<= ram_ao + 1;
						stSIDnext		<= stDelay2;
					when stDelay2	=>
						cycle_cnt(9 downto 2)  <= unsigned(ram_do);		-- delay low
						ram_ao			<= ram_ao + 1;
						stSIDnext		<= stAddr;
					when stAddr		=>
						sid_num			<= unsigned(ram_do(6 downto 5));
						sid_addr			<= unsigned(ram_do(4 downto 0));	-- address
						ram_ao			<= ram_ao + 1;
						stSIDnext		<= stData;
					when stData		=>
						sid_din			<= unsigned(ram_do);					-- value
						ram_ao			<= ram_ao + 1;
						stSIDnext		<= stSync;
					when stSync		=>
						if cycle_cnt = x"0000" then
							stSIDnext 	<= stWrite;
						else
							cycle_cnt 	<= cycle_cnt - 1;						-- wait cycles x4 (since this runs at clk04)
							stSIDnext 	<= stSync;
						end if;	
					when stWrite	=>
						case sid_num is
							when "00"	=>
								sid1_addr	<= sid_addr;
								sid1_din		<= sid_din;
								sid1_we		<= '1';
							when "01"	=>
								sid2_addr	<= sid_addr;
								sid2_din		<= sid_din;
								sid2_we		<= '1';
							when "10"	=>
								sid3_addr	<= sid_addr;
								sid3_din		<= sid_din;
								sid3_we		<= '1';
							when others	=> null;
						end case;
						stSIDnext		<= stDelay1;
					when others		=> null;
				end case;
			end if;
		end if;
	end process;

	-----------------------------------------------------------------------------
	-- data is streaming in from serial at 2000000-8N1 as a byte quad "DD DD RR VV"
	-- DDDD is a big-endian delay in SID clock cycles (985248 Hz PAL or 1022727 Hz NTSC)
	-- RR is a SID register
	-- VV is the value to be written to that register
	--
	-- example: 00 08 04 ff 
	--					means: delay 0008 cycles then write ff to register 04

	-- this receives data from the serial port and buffers
	-- it into 16K of RAMB FIFO
	--
	uart_to_ram: process(clk32, rx_data_present, rst)
	begin
		if rst = '1' then
			ram_ai <= (others => '1');
		elsif rising_edge(rx_data_present) then
			ram_ai <= ram_ai + 1;
		end if;
	end process;

	-- debug test points
	LED1 <= buf_full;

	-----------------------------------------------------------------------------

	-- detect rising and falling edges of buf_full
	buf_full_fe <=     buf_full_last and not buf_full;
	buf_full_re <= not buf_full_last and     buf_full;

	detect_edges: process(clk32)
	begin
		if falling_edge(clk32) then
			buf_full_last <= buf_full;
		end if;
	end process;

	-- transmit a serial byte to stop or start incoming data flow
	uart_fifo_tx: process(clk32)
	begin
		if falling_edge(clk32) then
			if buf_full_re = '1' or buf_full_fe = '1' then
				stUARTnow <= st00;
			else
				stUARTnow <= stUARTnext;
			end if;
		end if;
	end process;

	-- strobe uart we line for exactly one clock cycle
	uart_fifo_we: process(clk32)
	begin
		if rising_edge(clk32) then
			case stUARTnow is
				when st00		=>
					write_to_uart <= '1';
					stUARTnext <= st01;
				when st01		=>
					write_to_uart <= '0';
					stUARTnext <= st01;
				when others		=> null;
			end case;
		end if;		
	end process;

	-- detect a buffer almost full condition
	fifo_handshake: process(clk32)
	begin
		if falling_edge(clk32) then
			if (ram_ai - ram_ao) > 12288 then
				tx_data <= x"45"; -- End TX
				buf_full <= '1';
			elsif (ram_ai - ram_ao) < 4096 then
				tx_data <= x"53"; -- Start TX
				buf_full <= '0';
			end if;
		end if;
	end process;

end RTL;