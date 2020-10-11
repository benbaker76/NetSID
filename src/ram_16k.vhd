library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;

library unisim;
	use unisim.vcomponents.all;

entity RAM_16K is
	port (
		DOA	: out std_logic_vector ( 7 downto 0);	-- Port A 1-bit Data Output
		ADDRA	: in  std_logic_vector (13 downto 0);	-- Port A 14-bit Address Input
		CLKA	: in  std_logic;								-- Port A Clock

		DIB	: in  std_logic_vector ( 7 downto 0);	-- Port B 1-bit Data Input
		ADDRB	: in  std_logic_vector (13 downto 0);	-- Port B 14-bit Address Input
		CLKB	: in  std_logic								-- Port B Clock
	 );
end;

architecture RTL of RAM_16K is

-- use generate to connect x8 RAMBs in parallel to the 8 bit data bus
begin
	RAM : for i in 7 downto 0 generate
		inst : RAMB16_S1_S1
		generic map (
			WRITE_MODE_A => "READ_FIRST",   -- WRITE_FIRST, READ_FIRST or NO_CHANGE
			WRITE_MODE_B => "READ_FIRST",   -- WRITE_FIRST, READ_FIRST or NO_CHANGE
			SIM_COLLISION_CHECK => "ALL"    -- "NONE", "WARNING", "GENERATE_X_ONLY", "ALL"
		)
		port map (
			DOA	=> DOA(i downto i),
			ADDRA	=> ADDRA,
			CLKA	=> CLKA,
			DIA	=> "0",
			ENA	=> '1',
			SSRA	=> '0',
			WEA	=> '0',

			DOB	=> open,
			ADDRB	=> ADDRB,
			CLKB	=> CLKB,
			DIB	=> DIB(i downto i),
			ENB	=> '1',
			SSRB	=> '0',
			WEB	=> '1'
		);
  end generate;
end RTL;

