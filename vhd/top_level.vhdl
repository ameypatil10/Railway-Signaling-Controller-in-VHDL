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

entity top_level is
	port(
	   -- UART I/O ----------------------------------------------------------------------------------
		uart_rx	: in std_logic;
		uart_tx	: out std_logic;
		--Signals pulled on Atlys LEDs for debugging
		wr_en  : out std_logic; --20102016
		rd_en  : out std_logic; --20102016
		full   : out std_logic; --20102016
		empty  : out std_logic; --20102016
		-- FX2LP interface ---------------------------------------------------------------------------
		fx2Clk_in      : in    std_logic;                    -- 48MHz clock from FX2LP
		fx2Addr_out    : out   std_logic_vector(1 downto 0); -- select FIFO: "00" for EP2OUT, "10" for EP6IN
		fx2Data_io     : inout std_logic_vector(7 downto 0); -- 8-bit data to/from FX2LP

		-- When EP2OUT selected:
		fx2Read_out    : out   std_logic;                    -- asserted (active-low) when reading from FX2LP
		fx2OE_out      : out   std_logic;                    -- asserted (active-low) to tell FX2LP to drive bus
		fx2GotData_in  : in    std_logic;                    -- asserted (active-high) when FX2LP has data for us

		-- When EP6IN selected:
		fx2Write_out   : out   std_logic;                    -- asserted (active-low) when writing to FX2LP
		fx2GotRoom_in  : in    std_logic;                    -- asserted (active-high) when FX2LP has room for more data from us
		fx2PktEnd_out  : out   std_logic;                    -- asserted (active-low) when a host read needs to be committed early

		-- Onboard peripherals -----------------------------------------------------------------------
		sseg_out       : out   std_logic_vector(7 downto 0); -- seven-segment display cathodes (one for each segment)
		anode_out      : out   std_logic_vector(3 downto 0); -- seven-segment display anodes (one for each digit)
		led_out        : out   std_logic_vector(7 downto 0); -- eight LEDs
		sw_in          : in    std_logic_vector(7 downto 0);  -- eight switches
		reset_button	: in std_logic;
		left_button 	: in std_logic;
		right_button	: in std_logic;
		up_button		: in std_logic;
		down_button		: in std_logic
	);
end entity;

architecture structural of top_level is
	
	
	component debouncer
		port(clk: in std_logic;
			  button: in std_logic;
			  button_deb: out std_logic);
	end component;

	component basic_uart is
	generic (
		DIVISOR: natural
	);
	port (
	  clk: in std_logic;   -- system clock
	  reset: in std_logic;
	  
	  -- Client interface
	  rx_data: out std_logic_vector(7 downto 0);  -- received byte
	  rx_enable: out std_logic;  -- validates received byte (1 system clock spike)
	  tx_data: in std_logic_vector(7 downto 0);  -- byte to send
	  tx_enable: in std_logic;  -- validates byte to send if tx_ready is '1'
	  tx_ready: out std_logic;  -- if '1', we can send a new byte, otherwise we won't take it
	  
	  -- Physical interface
	  rx: in std_logic;
	  tx: out std_logic
	);
	end component;

	-- Button Inputs --------------------------------------------------------------------------------
	signal left_button_out : std_logic;
	signal right_button_out : std_logic;
	signal up_button_out : std_logic;
	signal down_button_out : std_logic;
	signal reset_button_out : std_logic;
			
	
	-- Channel read/write interface -----------------------------------------------------------------
	signal chanAddr  : std_logic_vector(6 downto 0);  -- the selected channel (0-127)

	-- Host >> FPGA pipe:
	signal h2fData   : std_logic_vector(7 downto 0);  -- data lines used when the host writes to a channel
	signal h2fValid  : std_logic;                     -- '1' means "on the next clock rising edge, please accept the data on h2fData"
	signal h2fReady  : std_logic;                     -- channel logic can drive this low to say "I'm not ready for more data yet"

	-- Host << FPGA pipe:
	signal f2hData   : std_logic_vector(7 downto 0);  -- data lines used when the host reads from a channel
	signal f2hValid  : std_logic;                     -- channel logic can drive this low to say "I don't have data ready for you"
	signal f2hReady  : std_logic;                     -- '1' means "on the next clock rising edge, put your next byte of data on f2hData"
	-- ----------------------------------------------------------------------------------------------

	-- Needed so that the comm_fpga_fx2 module can drive both fx2Read_out and fx2OE_out
	signal fx2Read   : std_logic;

	-- Reset signal so host can delay startup
	signal fx2Reset  : std_logic;
	signal swled_to_uart : std_logic_vector(7 downto 0);
	signal uart_to_swled : std_logic_vector(7 downto 0);
	signal rutx : std_logic;
	signal tx_enable : std_logic;
	signal tx_ready : std_logic;
	signal rx_enable : std_logic;
begin
	
	basic_uart_inst: basic_uart
  	generic map (DIVISOR => 1250) -- 2400
  	port map (
    	clk => fx2Clk_in,
    	reset => rutx,
    	rx_data => uart_to_swled, 
    	rx_enable => rx_enable,
    	tx_data => swled_to_uart, 
    	tx_enable => tx_enable, 
    	tx_ready => tx_ready,
    	rx => uart_rx,
    	tx => uart_tx
	);


	left_button_debouncer: entity work.debouncer
		port map	(clk => fx2Clk_in,
					 button => left_button,
					 button_deb => left_button_out);
	right_button_debouncer: debouncer
		port map	(clk => fx2Clk_in,
					 button => right_button,
					 button_deb => right_button_out);
	up_button_debouncer: debouncer
		port map	(clk => fx2Clk_in,
					 button => up_button,
					 button_deb => up_button_out);
	down_button_debouncer: debouncer
		port map	(clk => fx2Clk_in,
					 button => down_button,
					 button_deb => down_button_out);
	reset_button_debouncer: debouncer
		port map	(clk => fx2Clk_in,
					 button => reset_button,
					 button_deb => reset_button_out);
	-- CommFPGA module
	fx2Read_out <= fx2Read;
	fx2OE_out <= fx2Read;

	fx2Addr_out(0) <=  -- So fx2Addr_out(1)='0' selects EP2OUT, fx2Addr_out(1)='1' selects EP6IN
		'0' when fx2Reset = '0'
		else 'Z';
	comm_fpga_fx2 : entity work.comm_fpga_fx2
		port map(
			clk_in         => fx2Clk_in,
			reset_in       => '0',
			reset_out      => fx2Reset,
			
			-- FX2LP interface
			fx2FifoSel_out => fx2Addr_out(1),
			fx2Data_io     => fx2Data_io,
			fx2Read_out    => fx2Read,
			fx2GotData_in  => fx2GotData_in,
			fx2Write_out   => fx2Write_out,
			fx2GotRoom_in  => fx2GotRoom_in,
			fx2PktEnd_out  => fx2PktEnd_out,

			-- DVR interface -> Connects to application module
			chanAddr_out   => chanAddr,
			h2fData_out    => h2fData,
			h2fValid_out   => h2fValid,
			h2fReady_in    => h2fReady,
			f2hData_in     => f2hData,
			f2hValid_in    => f2hValid,
			f2hReady_out   => f2hReady
		);

	-- Switches & LEDs application
	swled_app : entity work.swled
		port map(
			clk_in       => fx2Clk_in,
			reset_in     => '0',
			
			-- DVR interface -> Connects to comm_fpga module
			chanAddr_in  => chanAddr,
			h2fData_in   => h2fData,
			h2fValid_in  => h2fValid,
			h2fReady_out => h2fReady,
			f2hData_out  => f2hData,
			f2hValid_out => f2hValid,
			f2hReady_in  => f2hReady,
			
			-- External interface

			--Debounced Buttons--------------<SUMIT>
			reset 		 => reset_button_out,
			left         => left_button_out,
			right 		 => right_button_out,
			up 			 => up_button_out,
			down 		 => down_button_out,
			
			data_recv    => uart_to_swled,
        	rx_enable 	 => rx_enable,
			
			data_send    => swled_to_uart,
        	tx_enable 	 => tx_enable,
			reset_uart_tx => rutx,
			---------------------------------</SUMIT>

			sseg_out     => sseg_out,
			anode_out    => anode_out,
			led_out      => led_out,
			sw_in        => sw_in
		);
end architecture;
