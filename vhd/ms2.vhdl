library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ms2 is
port (clk_in	: in std_logic;

	  -- List of all the things that macro state 2 
	  -- needs from top level.
	  reset : in std_logic;
	  enable : in std_logic;
	  sw_in : in std_logic_vector(7 downto 0);
	  chanAddr_in : in std_logic_vector(6 downto 0);
	  h2fData_in : in std_logic_vector(7 downto 0);
	  h2fValid_in : in std_logic;
	  data_from_neighbor : in std_logic_vector(7 downto 0);
	  h2fReady_out : out std_logic;

	  f2hData_out : out std_logic_vector(7 downto 0);
	  f2hValid_out : out std_logic;
	  f2hReady_in : in std_logic;

	  done : out std_logic;
	  led_out : out std_logic_vector(7 downto 0));
end ms2;

architecture Behavioral of ms2 is

	signal flags : std_logic_vector(3 downto 0);
	signal input_number : integer range 0 to 9 := 0;
	type INPUT is array (7 downto 0) of std_logic_vector(7 downto 0);
	signal out_buffer : std_logic_vector(7 downto 0) := "00000000";
	signal data_in : INPUT;												-- need to trim this
	signal data_next : INPUT;
	signal grid_info : INPUT;
	signal ticks : integer := 0;
	signal stop_reading : std_logic := '1';
	signal second_count : integer  := 0;

	component decrypter
		port(
			    clock : in std_logic;
			    K : in std_logic_vector(31 downto 0); 
			    C : in  std_logic_vector(31 downto 0);
			    P : out  std_logic_vector(31 downto 0);
			    reset : in  std_logic;
			    done : out std_logic;
			    enable : in  std_logic
		    );
	end component;

	component my_timer
		port(
			    clock : in std_logic;
			    reset : in  std_logic;
			    done : out std_logic;
			    enable : in  std_logic
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

	constant coordinate : std_logic_vector(31 downto 0) := "00010010000000000000000000000000";
	constant ack2 : std_logic_vector (31 downto 0) := "11011110101011110111011001010100";
	constant ack1 : std_logic_vector (31 downto 0) := "10110000000000000000000000001011";
	constant key : std_logic_vector (31 downto 0) := "00010010001101000101011001111000";

	constant reset_dec : std_Ulogic := '0';
	signal reset_timer : std_logic := '0';

	signal chanOut : std_logic_vector (6 downto 0) := "0000100";
	signal chanIn : std_logic_vector (6 downto 0) := "0000101";
	signal send_done : std_logic :='0';

	signal correct_channel : std_logic := '0';

	signal send_enable : std_logic := '0';
	signal timer_enable : std_logic := '0';
	signal dec_enable : std_logic := '0';
	
	signal dec_inp : std_logic_vector (31 downto 0);
	signal send_inp : std_logic_vector (31 downto 0);

	signal output_ready : std_logic := '0';
	signal f2hData_buff : std_logic_vector(7 downto 0) ;
	
	signal dec_out : std_logic_vector (31 downto 0);
	signal dec_done : std_logic := '0';
	signal timer_done : std_logic := '0';

	signal slider_done : std_logic;

	signal signal_display : std_logic_vector (7 downto 0);
	signal state : integer := 0;
	signal direction : integer := 0;

begin 

	time_mod : component my_timer
	 port map(
			 clock => clk_in,
			 reset => reset_timer,
			 done => timer_done,
			 enable => timer_enable
	 ); 

	de_mod : component decrypter
	 port map(
			 clock => clk_in,
			 K => key,
			 P => dec_out,
			 C => dec_inp,
			 reset => reset_dec,
			 done => dec_done,
			 enable => dec_enable
	 ); 


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

	correct_channel <= '1' when chanAddr_in = chanOut else '0';

	process (clk_in)
	begin 
		if( rising_edge(clk_in) ) then
			if ( reset= '1' ) then
				data_in(0) <= (others => '0');
				data_in(1) <= (others => '0');
				data_in(2) <= (others => '0');
				data_in(3) <= (others => '0');
			else 
				data_in(0) <= data_next(0);
				data_in(1) <= data_next(1);
				data_in(2) <= data_next(2);
				data_in(3) <= data_next(3);
			end if;
		end if;
	end process; 

	dec_inp <= data_in(3) & data_in(2) & data_in(1) & data_in(0);

	process (clk_in, reset)
	begin
		if( reset = '1') then
			state <= 0;
			second_count <= 0;
			stop_reading <= '1';
			send_enable <= '0';
			timer_enable <= '1';
			dec_enable <= '1';
			reset_timer <= '0';
			done <= '0';

		elsif( rising_edge(clk_in) ) then
			if(enable = '1') then 
				if (state = 0 ) then
					stop_reading <= '0';
					reset_timer <= '1';
				
					if( send_enable = '1' ) then
						send_inp <= coordinate;
						if( send_done = '1' ) then				-- send complete -> go to State 1
							send_enable <= '0';
							input_number <= 0;
							state <= 10;
							stop_reading <= '0';
							reset_timer <= '1';
						else
							state <= state;
							send_enable <= send_enable;
						end if;
					else
						send_enable <= '1';
						state <= state;
					end if;

				elsif( state = 10 ) then							-- State 1: take input and check against coordinate
					if( timer_done = '1' ) then
						reset_timer <= reset_timer;
						timer_enable <= '0';
						state <= 0;
						dec_enable <= '0';
					elsif( stop_reading = '0' ) then
						if( input_number < 4 ) then
							if( h2fValid_in = '1' ) then
								input_number <= input_number + 1;
							else
								input_number <= input_number;
							end if;
							
							stop_reading <= '0';
							dec_enable <= '0';
						else
							input_number <= 0;
							stop_reading <= '1';
							dec_enable <= '1';
						end if;
						reset_timer <= '0';
						timer_enable <= '1';
						state <= state;

					else	
						send_enable <= '0';
						if( dec_done = '1') then
							if( dec_out = coordinate ) then			-- if sent data is same as coordinate, go to State 3
								timer_enable <= '0';
								state <= 20;
								send_enable <= '0';
							else
								reset_timer <= reset_timer;
								timer_enable <= timer_enable;
								state <= state;							-- wrong input, reread buffer
								stop_reading <= '0';
							end if;
						else
							reset_timer <= '0';
							timer_enable <= '1';
							state <= state;
							stop_reading <= '1';
						end if;

					--send_enable <= '0';
					
					end if;

				elsif( state = 20 ) then							-- State 2: Send ecnrypted ACK1
					if( send_enable = '1' ) then
						if( send_done = '1' ) then				-- send complete -> go to State 1
							send_enable <= '0';
							state <= 30;
							stop_reading <= '0';
							reset_timer <= '1';
						else
							state <= state;
							send_enable <= send_enable;
						end if;
					else
						send_enable <= '1';
						send_inp <= ack1;
						state <= state;
					end if;
				
				elsif( state = 30 ) then							-- State 3: take input and check against ack2
					if( timer_done = '1' ) then
						reset_timer <= reset_timer;
						timer_enable <= '0';
						state <= 0;
						dec_enable <= '0';
					elsif( stop_reading = '0' ) then
						if( input_number < 4 ) then
							if( h2fValid_in = '1' ) then
								input_number <= input_number + 1;
							else
								input_number <= input_number;
							end if;
							
							stop_reading <= '0';
							dec_enable <= '0';
						else
							input_number <= 0;
							stop_reading <= '1';
							dec_enable <= '1';
						end if;

						reset_timer <= '0';
						timer_enable <= '1';
						state <= state;

					else	
						if( dec_done = '1' ) then
							if( dec_out = ack2 ) then			-- if sent data is same as ack2, go to State 4
								state <= 40;
								timer_enable <= '0';	
							else
								reset_timer <= reset_timer;
								timer_enable <= timer_enable;
								state <= state;
							end if;
							stop_reading <= '0';
						else
							reset_timer <= '0';
							timer_enable <= '1';
							state <= state;
							stop_reading <= '1';
						end if;

					end if;
					send_enable <= '0';
					
				elsif( state = 40 ) then							-- State 4: take input of first 4 directions
					if( stop_reading = '0' ) then
						if( input_number < 4 ) then
							if( h2fValid_in = '1' ) then
								input_number <= input_number + 1;
							else
								input_number <= input_number;
							end if;
							
							stop_reading <= '0';
							dec_enable <= '0';
						else
							input_number <= 0;
							stop_reading <= '1';
							dec_enable <= '1';
						end if;

						state <= state;
					else 
						if( dec_done = '1' ) then
							state <= 50;
						else
							state <= state;
							stop_reading <= '1';
						end if;	
					end if;
					send_enable <= '0';
					
				elsif( state = 50 ) then							-- State 5: Send ACK1 after receiving first 4 inputs of grid data
					if( send_enable = '1' ) then
						send_inp <= ack1;
						if( send_done = '1' ) then				-- send complete -> go to State 6
							send_enable <= '0';
							state <= 60;
							stop_reading <= '0';
						else
							state <= state;
							send_enable <= send_enable;
						end if;
					else
						send_enable <= '1';
						state <= state;
					end if;
				

				elsif( state = 60 ) then							-- State 6: take input of last 4 directions
					if( stop_reading = '0' ) then
						if( input_number < 4 ) then
							if( h2fValid_in = '1' ) then
								input_number <= input_number + 1;
							else
								input_number <= input_number;
							end if;
							
							stop_reading <= '0';
							dec_enable <= '0';
						else
							input_number <= 0;
							stop_reading <= '1';
							dec_enable <= '1';
						end if;

						state <= state;
					else 
						send_enable <= '0';
						if( dec_done = '1' ) then
							state <= 70;
						else
							state <= state;
							stop_reading <= '1';
						end if;	
					end if;

				elsif( state = 70 ) then							-- State 7: Send ACK1 after receiving last 4 inputs of grid data
					if( send_enable = '1' ) then
						send_inp <= ack1;
						if( send_done = '1' ) then				-- send complete -> go to State 8
							send_enable <= '0';
							state <= 80;
							second_count <= 0;
							ticks <= 0;
							reset_timer <= '1';
						else
							state <= state;
							send_enable <= send_enable;
						end if;
					else
						send_enable <= '1';
						state <= state;
					end if;
				
				elsif( state =80 ) then							--State 8 :ack2				
					if( timer_done = '1' ) then
						reset_timer <= reset_timer;
						timer_enable <= '0';
						state <= 0;
						dec_enable <= '0';
					elsif( stop_reading = '0' ) then
						if( input_number < 4 ) then
							if( h2fValid_in = '1' ) then
								input_number <= input_number + 1;
							else
								input_number <= input_number;
							end if;
							
							stop_reading <= '0';
							dec_enable <= '0';
						else
							input_number <= 0;
							stop_reading <= '1';
							dec_enable <= '1';
						end if;

						reset_timer <= '0';
						timer_enable <= '1';
						state <= state;

					else	
						if( dec_done = '1' ) then
							if( dec_out = ack2 ) then			-- if sent data is same as ack2, go to State 4
								state <= 90;
								timer_enable <= '0';
								second_count <= 0;
								ticks <= 0;
							else
								reset_timer <= reset_timer;
								timer_enable <= timer_enable;
								state <= state;
							end if;
							stop_reading <= '0';
						else
							reset_timer <= '0';
							timer_enable <= '1';
							state <= state;
							stop_reading <= '1';
						end if;

					end if;
					send_enable <= '0';
				elsif( state =90 ) then							--State 8 :display and wait for 16 seconds				
					if( second_count >= 24 ) then
						state <= 100;
						second_count <= 0;
						ticks <= 0;
					else 
						stop_reading <= stop_reading;
						if( ticks = 50000000 ) then
							second_count <= second_count + 1;
							ticks <= 0; 
						else
							ticks <= ticks + 1;
							second_count <= second_count;
						end if;
						state <= state;
					end if;
					send_enable <= '0';
				elsif( state = 100 ) then
					done <= '1';
					state <= state;
				end if;
			end if;
		end if;
	end process;

	grid_info(0) <=
		dec_out(7 downto 0) when state = 40 and dec_done = '1'
		else grid_info(0);

	grid_info(1) <= 
		dec_out(15 downto 8) when state = 40 and dec_done = '1'
		else grid_info(1);
	
	grid_info(2) <= 
		dec_out(23 downto 16) when state = 40 and dec_done = '1' 
		else grid_info(2);
	
	grid_info(3) <= 
		dec_out(31 downto 24) when state = 40 and dec_done = '1' 
		else grid_info(3);
	
	grid_info(4) <= 
		dec_out(7 downto 0) when state = 60 and dec_done = '1' 
		else grid_info(4);
	
	grid_info(5) <= 
		dec_out(15 downto 8) when state = 60 and dec_done = '1' 
		else grid_info(5);
	
	grid_info(6) <= 
		dec_out(23 downto 16) when state = 60 and dec_done = '1' 
		else grid_info(6);
	
	grid_info(7) <= 
		dec_out(31 downto 24) when state = 60 and dec_done = '1' 
		else grid_info(7);


	data_next(0) <=
       		h2fData_in when chanAddr_in = chanIn and h2fValid_in = '1' and input_number = 0 and stop_reading = '0'
		else data_in(0);

	data_next(1) <=
		h2fData_in when chanAddr_in = chanIn and h2fValid_in = '1' and input_number = 1 and stop_reading = '0'
	        else data_in(1);

	data_next(2) <=
		h2fData_in when chanAddr_in = chanIn and h2fValid_in = '1' and input_number = 2 and stop_reading = '0'
	      	else data_in(2);

    data_next(3) <=
  		h2fData_in when chanAddr_in = chanIn and h2fValid_in = '1' and input_number = 3 and stop_reading = '0'
		else data_in(3);


	out_buffer <= 
		grid_info(second_count / 3) when state = 90			
		else "10000001" when state = 10
		else "10000010" when state = 20
		else "10000011" when state = 30
		else "10000100" when state = 40
		else "10000101" when state = 50
		else "10000110" when state = 60
		else "10000111" when state = 70
		else "10001000" when state = 80
		else "10001010" when state = 100
		else "10000000" when state = 0
		else "00000000";

	direction <= 
		second_count / 3 when state = 90
		else 8;
--	led_out <= reprint;

	process (clk_in)
	begin
		if(rising_edge(clk_in)) then
			if(out_buffer(4) = '0' or out_buffer(3) = '0') then
				signal_display(2 downto 0) <= "001";
			else 
				if((data_from_neighbor(4) = '0' or data_from_neighbor(3) = '0') 
					and out_buffer(7 downto 5) = data_from_neighbor(7 downto 5)) then
					signal_display(2 downto 0) <= "001";
				elsif(sw_in(direction) = '1' and sw_in((direction+4) mod 8) = '1') then
					if(direction > (direction+4) mod 8) then					
						if((second_count mod 3) = 0) then
							signal_display(2 downto 0) <= "100";
						elsif((second_count mod 3) = 1) then 
							signal_display(2 downto 0) <= "010";
						else 
							signal_display(2 downto 0) <= "001";
						end if;
					else 
						signal_display(2 downto 0) <= "001";
					end if;
				elsif(sw_in(direction) = '1' and sw_in((direction+4) mod 8) = '0') then
					if(out_buffer(2 downto 0) = "001") then
						signal_display(2 downto 0) <= "010";
					else 
						signal_display(2 downto 0) <= "100";
					end if;
				else
					signal_display(2 downto 0) <= "001";
				end if;
			end if;
		end if;
	end process;

	signal_display(7 downto 5) <= out_buffer(7 downto 5);
	
	signal_display(4 downto 3) <= "00";	

	led_out <= signal_display when state = 90
			   else out_buffer;

	f2hData_out <=	f2hData_buff when output_ready = '1' and send_enable = '1' and chanAddr_in = chanOut
								else			"00000000";				--if send is enabled, read 				
	
	h2fReady_out <= '1';                                                     --END_SNIPPET(registers)
	flags <= "00" & f2hReady_in & reset;
	f2hValid_out <= '1' when chanAddr_in = chanOut else '0';
end architecture;
