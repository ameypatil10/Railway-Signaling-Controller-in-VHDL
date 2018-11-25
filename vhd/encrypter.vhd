library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity encrypter is
    Port ( clock : in  std_logic;
           K : in  std_logic_vector (31 downto 0);
           P : in  std_logic_vector(31 downto 0);
           C : out  std_logic_vector (31 downto 0);
           reset : in  std_logic;
           done : out std_logic;
           enable : in std_logic);
       end encrypter;
       
architecture Behavioral of encrypter is
    
    signal T : std_logic_vector (3 downto 0);
    signal i : INTEGER range 0 to 31:= 0; -- Counter in the for loop
    signal N : std_logic_vector(5 downto 0); -- Stores the number of times 1 appears in the key K
    signal C_temp : std_logic_vector(31 downto 0);
    
begin
    N <= (("00000"&K(0))+("00000"&K(1))+("00000"&K(2))+("00000"&K(3))
         +("00000"&K(4))+("00000"&K(5))+("00000"&K(6))+("00000"&K(7))
         +("00000"&K(8))+("00000"&K(9))+("00000"&K(10))+("00000"&K(11))
         +("00000"&K(12))+("00000"&K(13))+("00000"&K(14))+("00000"&K(15))
         +("00000"&K(16))+("00000"&K(17))+("00000"&K(18))+("00000"&K(19))
         +("00000"&K(20))+("00000"&K(21))+("00000"&K(22))+("00000"&K(23))
         +("00000"&K(24))+("00000"&K(25))+("00000"&K(26))+("00000"&K(27))
         +("00000"&K(28))+("00000"&K(29))+("00000"&K(30))+("00000"&K(31)));

    process(clock, reset, enable, P)
    begin
        if(reset = '1') then
                C_temp <= "00000000000000000000000000000000";
			    i <= 0;
                done <= '0';
    	elsif(rising_edge(clock)) then
            if (enable = '1') then
                if (i = 0) then
                    T(0)<= K(0) xor K(4) xor K(8) xor K(12) xor K(16) xor K(20) xor K(24) xor K(28);
                     T(1)<= K(1) xor K(5) xor K(9) xor K(13) xor K(17) xor K(21) xor K(25) xor K(29);
                     T(2)<= K(2) xor K(6) xor K(10) xor K(14) xor K(18) xor K(22) xor K(26) xor K(30);
                     T(3)<= K(3) xor K(7) xor K(11) xor K(15) xor K(19) xor K(23) xor K(27) xor K(31);
                    C_temp <= P;
				    i <= i+1;
                    done <= '0';
                elsif(i > 0 and i <= unsigned(N)) then
                    done <= '0';
                    C_temp <= C_temp xor (T & T & T & T & T & T & T& T);
                    T <= T + 1;
                    i <= i + 1; 
                else
                    done <= '1';
                    C <= C_temp;
                end if;

            else
                i <= 0;
                C <= C_temp;
            end if;
        end if;
    end process;
        
end Behavioral;
