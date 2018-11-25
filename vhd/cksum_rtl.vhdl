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
architecture rtl of swled is
	constant key : std_logic_vector (31 downto 0) := "00010010001101000101011001111000";
	
	signal data_from_neighbor : std_logic_vector (7 downto 0) := x"ff";
	component ms2
		port(
			clk_in	: in std_logic;

	  		-- List of all the things that macro state 2 
	  		-- needs from top level.
	  		reset : in std_logic;
	  		enable : in std_logic;
	  		sw_in : in std_logic_vector(7 downto 0);
			chanAddr_in : in std_logic_vector (6 downto 0);
	  		h2fData_in : in std_logic_vector(7 downto 0);
	  		h2fValid_in : in std_logic;
	  		h2fReady_out : out std_logic;

	  		data_from_neighbor : in std_logic_vector (7 downto 0);
	  		f2hData_out : out std_logic_vector(7 downto 0);
	  		f2hValid_out : out std_logic;
			f2hReady_in : in std_logic;

			done : out std_logic;
			led_out : out std_logic_vector(7 downto 0)
			);
	end component;

	component sender
		port(
			    output_ready : out std_logic;	
			    ready_to_send : in std_logic;
			    clock : in std_logic;
			    K : in std_logic_vector(31 downto 0); 
			    f2hData_buff: out std_logic_vector (7 downto 0);
			    enable: in std_logic;
				payload: in std_logic_vector(31 downto 0);
				done : out std_logic;
				correct_channel : in std_logic
	);
	end component;

	signal signal_display : std_logic := '1';
	signal state : integer := 10;

	signal reset_ms2 : std_logic := '0';
	signal enable_ms2 : std_logic := '0';
	signal done_ms2 : std_logic := '0';
	signal led_out_ms2 : std_logic_vector(7 downto 0);

	signal ticks : integer := 0;
	signal second_count : integer := 0;

------signals added
	signal correct_channel : std_logic := '0';
	signal output_ready : std_logic := '0';
	signal send_inp : std_logic_vector (31 downto 0);
	signal send_done : std_logic :='0';

	signal control_led : std_logic_vector(7 downto 0) := x"FF";
	signal f2hData_buff : std_logic_vector(7 downto 0);
	signal f2hData_out_buffer : std_logic_vector(7 downto 0);
	signal up_pushed : std_logic := '0';
	signal left_pushed : std_logic:='0';
	signal down_pushed : std_logic:='0';
	signal send_enable : std_logic:='0';
	signal f2hValid_out_ms2 : std_logic;
	signal flags : std_logic_vector(3 downto 0);
	signal check_h2fValid : std_logic := '0';

	signal chanOut : std_logic_vector (6 downto 0) := "0000100";

	signal prep_for_tx : std_logic := '0';
	signal received : std_logic := '0';
begin

	correct_channel <= '1' when chanAddr_in = chanOut else '0';

	send_mod : component sender
	 port map(
			clock => clk_in,
			K => key,
			enable => send_enable,
			f2hData_buff =>f2hData_buff,
			payload => send_inp,
			done => send_done,
			ready_to_send => f2hReady_in,
			output_ready => output_ready,
			correct_channel => correct_channel
			);

	process (clk_in)
	begin
		if(reset = '1') then
				send_enable <= '0';
				second_count <= 0;
				enable_ms2 <= '0';
				reset_ms2 <= '0';
				state <= 10;
				ticks <= 0;
				data_from_neighbor <= x"ff";
				up_pushed <= '0';
				left_pushed <= '0';
				prep_for_tx <= '0';
				down_pushed <= '0';
		elsif( rising_edge( clk_in ) ) then
			if(state = 10) then
				prep_for_tx <= '0';
				control_led <= "11111111";
				if(second_count >= 3) then
					state <= 20;
					second_count <= 0;
					reset_ms2 <= '1';
					enable_ms2 <= '0';
					ticks <= 0;
				else 
					if( ticks = 50000000 ) then
						second_count <= second_count + 1;
						ticks <= 0;
					else
						ticks <= ticks + 1;
						second_count <= second_count;
					end if;
					state <= state;
				end if;
			elsif(state = 20) then
				if (enable_ms2 = '1') then
					if(done_ms2 = '0') then
						control_led <= led_out_ms2;
						reset_ms2 <= '0';
					else 
						tx_enable <= '0';
						reset_uart_tx <= '0';
						enable_ms2 <= '0';
						state <= 30;
						down_pushed <= '0';
						send_enable <= '0';
						reset_ms2 <= '1';
					end if;
				else
					enable_ms2 <= '1';
				end if;
				if (up = '1') then 
					up_pushed <= '1';
				else 
					up_pushed <= up_pushed;
				end if;
				if (left = '1') then
					left_pushed <= '1';
				else 
					left_pushed <= left_pushed;
				end if;
			elsif (state = 30) then		
				if (up_pushed = '1') then
					control_led <= "00000011";
					if(down_pushed = '1') then 
						if(send_done = '1') then
							state <= 40;
							up_pushed <= '0';
							send_enable <= '0';
							prep_for_tx <= '0';
						else
							send_inp <= x"000000" & sw_in;
							send_enable <= '1';
							state <=state;
						end if;
					elsif (down = '1') then
						down_pushed <= '1';
					else
						send_enable <= '0';
						state <= state;
					end if;
				else
					prep_for_tx <= '0';
					state <= 40;
				end if;
			elsif (state = 40) then	
				if (left_pushed = '1') then
					if(prep_for_tx = '1') then
						data_send <= sw_in;

						--		ticks = 8 * 100 MHz / baud rate
						if (ticks = 0) then
							reset_uart_tx <= '1';
							ticks <= ticks +1;
						elsif (ticks < 8*41700) then
							control_led <= "00000100";
							ticks <= ticks + 1;
							reset_uart_tx <= '0';
							tx_enable <= '1';
						elsif(ticks = 8*41700) then
							ticks <= 0;
							received <= '0';
							state <= 50;
							ticks <= 0;
							prep_for_tx <= '0';
							left_pushed <= '0';
							tx_enable <= '0';
							reset_uart_tx <= '0';
							control_led <= "00000101";
						else 
							control_led <= "00000100";
							ticks <= ticks + 1;
							tx_enable <= '0';
							reset_uart_tx <= '1';
						end if;
					elsif (right = '1') then
						prep_for_tx <= '1';
						ticks <= 0;
					end if;
				else
					received <= '0';
					state <= 50;
					ticks  <= 0;
					control_led <= "00000101";
				end if;

			elsif(state = 50) then
				if (rx_enable = '1') then
					received <= '1';
					data_from_neighbor <= data_recv;
					control_led <= data_recv;
				else
					control_led <= control_led;
					data_from_neighbor <= data_from_neighbor;
				end if;
				if(second_count >= 10) then
					state <= 60;
					ticks <= 0;
					second_count <= 0;
				else 
					if( ticks = 50000000 ) then
						second_count <= second_count + 1;
						ticks <= 0;
					else
						ticks <= ticks + 1;
						second_count <= second_count;
					end if;
					state <= state;
				end if;
			elsif (state = 60) then
				if(second_count >= 20) then
					state <= 20;
					second_count <= 0;
					reset_ms2 <= '1';
					ticks <= 0;
				else 
					control_led <= "00000110";
					if( ticks = 50000000 ) then
						second_count <= second_count + 1;
						ticks <= 0;
					else
						ticks <= ticks + 1;
						second_count <= second_count;
					end if;
					state <= state;
				end if;
			end if;
		end if;
	end process; 
   
	macro_state_2 : component ms2
 	port map(
 		clk_in => clk_in,
 		reset => reset_ms2,
 		enable => enable_ms2,
		chanAddr_in => chanAddr_in,
 		sw_in => sw_in,
 		data_from_neighbor => data_from_neighbor,
 		h2fData_in => h2fData_in,
 		h2fValid_in => h2fValid_in,
 		h2fReady_out => h2fReady_out,
 		f2hData_out => f2hData_out_buffer,
 		f2hValid_out => f2hValid_out_ms2,
 		f2hReady_in => f2hReady_in,
 		done => done_ms2,
 		led_out => led_out_ms2
 	);					

--	

 	led_out <= control_led; --"000001"&tx_ready&txstarted when state = 40 else control_led;

 	f2hValid_out <= '1' when state = 30
					else f2hValid_out_ms2 when state = 20
					else '0';
 	f2hData_out <= f2hData_out_buffer when state = 20 
 					else f2hData_buff when state = 30 and output_ready = '1' and send_enable = '1' and chanAddr_in = chanOut
 					else "00000000";

	seven_seg : entity work.seven_seg
	port map(
			 clk_in     => clk_in,
			 data_in    => "0010001100100011",
			 dots_in    => flags,
			 segs_out   => sseg_out,
			 anodes_out => anode_out
	 );
end architecture;
