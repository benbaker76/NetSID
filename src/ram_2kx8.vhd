library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;

library UNISIM;
	use UNISIM.Vcomponents.all;

entity RAM_16K is
	port (
		DOA		: out std_logic_vector ( 7 downto 0);	-- Port A 1-bit Data Output
		ADDRA	: in  std_logic_vector (10 downto 0);	-- Port A 14-bit Address Input
		CLKA	: in  std_logic;											-- Port A Clock

		DIB		: in  std_logic_vector ( 7 downto 0);	-- Port B 1-bit Data Input
		ADDRB	: in  std_logic_vector (10 downto 0);	-- Port B 14-bit Address Input
		CLKB	: in  std_logic												-- Port B Clock
	 );
end;

architecture RTL of RAM_16K is

begin
	RAM : if true generate
		ram_inst : RAMB16_S9_S9
		generic map (
			WRITE_MODE_A				=> "READ_FIRST",	-- WRITE_FIRST, READ_FIRST or NO_CHANGE
			WRITE_MODE_B				=> "READ_FIRST",	-- WRITE_FIRST, READ_FIRST or NO_CHANGE
			SIM_COLLISION_CHECK	=> "NONE" 				-- "NONE", "WARNING", "GENERATE_X_ONLY", "ALL"


			)
--		-- The following INIT_xx declarations specify the initial contents of the RAM
		port map (
			DOA		=> DOA,
			ADDRA	=> ADDRA,
			CLKA	=> CLKA,
			DIA		=> x"00",
			DIPA	=> "0",
			ENA		=> '1',
			SSRA	=> '0',
			WEA		=> '0',

			DOB		=> open,
			ADDRB	=> ADDRB,
			CLKB	=> CLKB,
			DIB		=> DIB,
			DIPB	=> "0",
			ENB		=> '1',
			SSRB	=> '0',
			WEB		=> '1'
		);
  end generate;
end RTL;

