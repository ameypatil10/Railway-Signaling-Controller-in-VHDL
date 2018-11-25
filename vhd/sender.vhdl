--
-- Copyright (C) 2009-2012 Chris McClelland
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;   

entity sender is
	Port(	ready_to_send : in std_logic;
		    clock : in std_logic;
		    K : in std_logic_vector(31 downto 0); 
		    f2hData_buff: out std_logic_vector (7 downto 0);
		    enable: in std_logic;
		    output_ready : out std_logic;
			payload: in std_logic_vector(31 downto 0);
			done : out std_logic;
			correct_channel : in std_logic
			);
end entity sender;

architecture Behavioral of sender is

signal output_number: integer range 0 to 16 := 0;
signal enc_done : std_logic := '0';
signal enc_enable : std_logic := '0';
signal enc_out : std_logic_vector (31 downto 0);
signal enc_reset : std_logic := '0';
	
component encrypter
	port(
		    clock : in std_logic;
		    K : in std_logic_vector(31 downto 0); 
		    C : out  std_logic_vector(31 downto 0);
		    P : in  std_logic_vector(31 downto 0);
		    reset : in  std_logic;
		    enable : in  std_logic;
		    done : out std_logic
	    );
end component;

begin

	en_mod : component encrypter
	 port map(
			 clock => clock,
			 K => K,
			 P => payload,
			 C => enc_out,
			 reset => enc_reset,
			 done => enc_done,
			 enable => enc_enable
	 ); 

	process(clock)
	begin
		if( rising_edge(clock) ) then
			if(enable = '1') then
				if(output_number = 0) then
					enc_reset <= '1';
					enc_enable <= '0';
					output_number <= output_number + 1;
					done <= '0';
					output_ready <= '0';
				elsif(output_number < 5) then
					enc_enable <= '1';
					enc_reset <= '0';
					if(enc_done = '1') then
						output_ready <= '1';
						if(ready_to_send = '1') then
							output_number <= output_number + 1;
						else
							output_number <= output_number;
						end if;
					else
						output_ready <= '0';
						output_number <= output_number;
					end if;

					done <= '0';
				else
					if(correct_channel = '1') then
						done <= '1';
					else 
						done <= '0';
					end if;
					output_ready <= '0';
					output_number <= 0;
					enc_enable <= '0';
				end if;
			end if;
		end if;
	end process;

	f2hData_buff <= enc_out(7 downto 0) when output_number = 1
					else enc_out(15 downto 8) when output_number = 2
					else enc_out(23 downto 16) when output_number = 3
					else enc_out(31 downto 24) when output_number = 4
					else "00000000";
					

end Behavioral;

