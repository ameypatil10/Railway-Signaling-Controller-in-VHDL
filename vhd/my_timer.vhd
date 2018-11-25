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

entity my_timer is
	Port(	
			    clock : in std_logic;
			    reset : in  std_logic;
			    done : out std_logic;
			    enable : in  std_logic);
end entity my_timer;

architecture Behavioral of my_timer is

signal second_count: integer := 0;
signal ticks : integer := 0;

begin
	process(clock, reset, enable)
	begin
		if( reset = '1' ) then
			second_count <= 0;
			ticks <= 0;
		elsif( rising_edge(clock) ) then
			if( enable = '1' ) then
				if(second_count > 32) then
					done <='1';
				else 
					if( ticks = 100000000 ) then
						second_count <= second_count + 1;
						ticks <= 0; 
					else
						ticks <= ticks + 1;
						second_count <= second_count;
					end if;
					done <= '0';
				end if;	
			else
				done <= '0';
				ticks <= 0;
				second_count <= 0;
			end if;
		end if;
	end process;
end Behavioral;

