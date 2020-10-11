library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity NetSID_CLOCKS is
	port (
	I_CLK			: in  std_logic;
	I_RESET		: in  std_logic;
	--
	O_CLK_1M		: out std_logic;
	O_CLK_4M		: out std_logic;
	O_CLK_32M	: out std_logic;
	O_RESET		: out std_logic
	);
end;

architecture RTL of NetSID_CLOCKS is
	signal clk_in_ibuf				: std_logic := '0';
	signal clkfb						: std_logic := '0';
	signal clk0_dcm_bufg				: std_logic := '0';
	signal dcm_locked					: std_logic := '0';
	signal delay_count				: std_logic_vector(7 downto 0) := (others => '0');
	signal div_cnt						: std_logic_vector(4 downto 0) := (others => '0');
begin
	IBUFG0 : IBUFG port map (I=> I_CLK, O => clk_in_ibuf);
	O_CLK_1M   <= div_cnt(4); 		-- 50 duty, input clk / 32 = 1Mhz
	O_CLK_4M   <= div_cnt(2); 		-- 50 duty, input clk / 32 = 1Mhz
	O_CLK_32M  <= clk0_dcm_bufg;	-- buffered copy of input 32Mhz clock

	-- generate 32M to match the Papilio clock
	dcm_inst : DCM_SP
	generic map (
		CLKFX_MULTIPLY => 16,
		CLKFX_DIVIDE   => 25,
		CLKIN_PERIOD   => 20.0
	)
	port map (
		CLKIN    => clk_in_ibuf,
		CLKFB    => clkfb,
		RST      => I_RESET,
		CLK0     => clkfb,
		CLKFX    => clk0_dcm_bufg,
		LOCKED   => dcm_locked
	);

	reset_delay : process(I_RESET, clk0_dcm_bufg)
	begin
		if (I_RESET = '1') then
			delay_count <= x"00"; -- longer delay for cpu
			O_RESET <= '1';
		elsif rising_edge(clk0_dcm_bufg) then
			if (delay_count(7 downto 0) = (x"FF")) then
				O_RESET <= '0';
			else
				delay_count <= delay_count + "1";
				O_RESET <= '1';
			end if;
		end if;
	end process;

	p_clk_div : process(I_RESET, clk0_dcm_bufg)
	begin
		if (I_RESET = '1') then
			div_cnt <= (others => '0');
		elsif rising_edge(clk0_dcm_bufg) then
			div_cnt <= div_cnt - 1;
		end if;
	end process;

end RTL;
