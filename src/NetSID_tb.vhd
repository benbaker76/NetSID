--------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:   00:09:05 07/25/2011
-- Design Name:
-- Module Name:   C:/Users/alex/workspace/NetSID/build/NetSID_tb.vhd
-- Project Name:  NetSID
-- Target Device:
-- Tool versions:
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
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation
-- simulation model.
--------------------------------------------------------------------------------
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
	use IEEE.std_logic_textio.all;

library std;
	use std.textio.all;

entity netsid_tb is
	generic(stim_file: string :="stim.txt");
end netsid_tb;

architecture behavior of netsid_tb is
	-- Inputs
	file stimulus: text open read_mode is stim_file;
	signal nreset    : std_logic := '1';
	signal clk_in    : std_logic := '0';
	signal I_USB_RXD : std_logic := '1';
	signal button    : std_logic := '1';

	-- Outputs
	signal audio_l   : std_logic := '0';
	signal audio_r   : std_logic := '0';
	signal O_USB_TXD : std_logic := '1';
	signal LEDS      : std_logic_vector(5 downto 1);

	signal clock     : std_logic := '1';
	signal baud_run  : std_logic := '0';
	constant clock_period : time := 20.0 ns; -- 50MHz
	constant baud_period  : time := 500 ns; -- 512000 baud
begin
	uut: entity work.netsid port map (
		I_RESET   => nreset,
		CLK_IN    => clock,
		O_AUDIO_L => audio_l,
		O_AUDIO_R => audio_r,
		LEDS      => LEDS,
		I_USB_RXD => I_USB_RXD,
		O_USB_TXD => O_USB_TXD
	);

	-- Clock process definitions
	clock_process :process
	begin
		clock <= not clock;
		wait for clock_period/2;
	end process;

  serial_in : process
		variable inline : line;
		variable bv : std_logic_vector(7 downto 0);
	begin
		if baud_run = '1' then
			if not endfile(stimulus) then
				readline(stimulus, inline);		-- read a line
				for byte in 0 to 3 loop				-- 4 bytes per line
					hread(inline, bv);				-- convert hex byte to vector
					I_USB_RXD <= '0';					-- start bit
					wait for baud_period;
					for i in 0 to 7 loop				-- bits 0 to 7
						I_USB_RXD <= bv(i);
						wait for baud_period;
					end loop;
					I_USB_RXD <= '1';					-- stop bit
					wait for baud_period;
				end loop;
			else
				wait;
			end if;
		else
			wait for baud_period;
		end if;
	end process;

	-- Stimulus process
	stim_proc: process
	begin
		nreset   <= '1';
		baud_run <= '0';
		wait for clock_period*2000;
		nreset   <= '0';
		wait for clock_period*2000;
		baud_run <= '1';
		wait;
	end process;

end;
