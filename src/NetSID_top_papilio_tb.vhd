--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   04/23/2020
-- Design Name:   
-- Module Name:   NetSID_top_papilio_tb.vhd
-- Project Name:  NetSID
-- Target Device: xc6slx9-tqg144-2
-- Tool versions: ISE 14.7
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: NetSID
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- unsigned for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
	use ieee.std_logic_unsigned.all;
	use IEEE.std_logic_textio.all;

library std;
	use std.textio.all;

entity netsid_tb is
	generic(stim_file: string :="stim.txt");
end netsid_tb;

architecture behavior of netsid_tb is 

	-- component declaration for the unit under test (uut)

	component netsid
	port(
		JOY_SELECT		: in  std_logic;
		CLK				: in  std_logic;
		AUDIO1_LEFT		: out std_logic;
		AUDIO1_RIGHT	: out std_logic;
		LED1				: out std_logic;
		RX					: in  std_logic;
		TX					: out std_logic
	);
	end component;

	-- Inputs
	file stimulus: text open read_mode is stim_file;
	signal nreset  : std_logic := '1';
	signal osc_in  : std_logic := '0';
	signal usb_txd : std_logic := '1';
	signal button  : std_logic := '1';

	-- Outputs
	signal audio_l  : std_logic := '0';
	signal audio_r  : std_logic := '0';
	signal usb_rxd  : std_logic := '1';
	signal led      : std_logic := '0';

	signal clock    : std_logic := '1';
	signal baud_run : std_logic := '0';
	constant clock_period : time := 31.25 ns;
	constant baud_period  : time := 500 ns; -- 2Mbps
begin

	-- Instantiate the Unit Under Test (UUT)
	uut: netsid port map (
		JOY_SELECT		=> nreset,
		CLK				=> clock,
		AUDIO1_LEFT		=> audio_l,
		AUDIO1_RIGHT	=> audio_r,
		LED1				=> led,
		TX					=> usb_txd,
		RX					=> usb_rxd
	);

	-- Clock process definitions
	clock_process: process
	begin
		clock <= not clock;
		wait for clock_period/2;
	end process;

  serial_in: process
		variable inline : line;
		variable bv : std_logic_vector(7 downto 0);
	begin
		if baud_run = '1' then
			while not endfile(stimulus) loop
				readline(stimulus, inline);		-- read a line
				for byte in 0 to 3 loop				-- 4 bytes per line
					hread(inline, bv);				-- convert hex byte to vector
					usb_txd <= '0';					-- start bit
					wait for baud_period;
					for i in 0 to 7 loop				-- bits 0 to 7
						usb_txd <= bv(i);
						wait for baud_period;
					end loop;
					usb_txd <= '1';					-- stop bit
					wait for baud_period;
				end loop;
			end loop;
		else
			wait for baud_period;
		end if;
	end process;

	-- Stimulus process
	stim_proc: process
	begin		
		nreset <= '0';
		baud_run <= '0';
		wait for clock_period*5;
		nreset <= '1';
		wait for clock_period*10;
		baud_run <= '1';
		wait;
	end process;

end;
