-- EB Mar 2013
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity t_serial is
port(
  sys_clk: in std_logic; -- 100 MHz system clock
  
  uart_rx: in std_logic;
  uart_tx: out std_logic;

  rx_data: out std_logic_vector(7 downto 0);
  rx_enable: in std_logic;
  tx_data: in std_logic_vector(7 downto 0);
  tx_enable: in std_logic;
  
  reset_btn: in std_logic;
  led: out std_logic_vector(7 downto 0)
);
end t_serial;

architecture Behavioral of t_serial is

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

type fsm_state_t is (idle, received, emitting);
type state_t is
record
  fsm_state: fsm_state_t; -- FSM state
  tx_data: std_logic_vector(7 downto 0);
  tx_enable: std_logic;
end record;
signal reset: std_logic;
signal uart_rx_data: std_logic_vector(7 downto 0);
signal uart_rx_enable: std_logic;
signal uart_tx_data: std_logic_vector(7 downto 0);
signal uart_tx_enable: std_logic;
signal uart_tx_ready: std_logic;
signal ticks : integer:= 0;
signal tx_ready_on : std_logic := '0';
signal pmod_1 : std_logic;
signal pmod_2 : std_logic;
begin

  basic_uart_inst: basic_uart
  generic map (DIVISOR => 1250) -- 2400
  port map (
    clk => sys_clk, reset => reset,
    rx_data => uart_rx_data, rx_enable => uart_rx_enable,
    tx_data => uart_tx_data, tx_enable => uart_tx_enable, tx_ready => uart_tx_ready,
    rx => uart_rx,
    tx => uart_tx
  );

  --reset_control: process (reset_btn) is
  --begin
  --  if reset_btn = '1' then
  --    reset <= '0';
  --  else
  --    reset <= '1';
  --  end if;
  --end process;
  
  pmod_1 <= uart_tx_enable;
  pmod_2 <= uart_tx_ready;
  
  process (sys_clk) is
  begin
    if (rising_edge(sys_clk)) then
        if(ticks = 99999998) then
          reset <= '1';
          ticks <= ticks + 1;
          uart_tx_enable <= '0';
        elsif (ticks = 99999999) then
          reset <= '0';
          ticks <= ticks + 1;
          uart_tx_enable <= '0';
        elsif(ticks = 100000000) then 
          ticks <= 0;
          uart_tx_enable <= '1';
          if(uart_tx_ready = '1') then
            tx_ready_on <= not tx_ready_on;
          end if;
        else 
          ticks <= ticks + 1;
          uart_tx_enable <= '0';
        end if;
    end if;
  end process;

  uart_tx_data <= x"AB";
  led <= "1000000" & tx_ready_on;
  
end Behavioral;

