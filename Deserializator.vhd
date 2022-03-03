library IEEE;
use IEEE.std_logic_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Deserializator is
   generic(
      C_NR_OF_BITS : integer := 16;
      C_SYS_CLK_FREQ_MHZ : integer := 100;
      C_PDM_FREQ_HZ : integer := 2000000
   );
   port(
      clk_i : in std_logic;
      rst_i : in std_logic;
      en_i : in std_logic;                                        --enable deserializare(in timp ce  e recording)
      
      done_o : out std_logic;                                     --semnaleaza ca cei 16 biti sunt deserializati
      data_o : out std_logic_vector(C_NR_OF_BITS - 1 downto 0);   --output data deserializat
      
      -- PDM
      pdm_m_clk_o : out std_logic;                                --genereaza clockul la microfon
      pdm_m_data_i : in std_logic;                                --input data de la microfon
      pdm_lrsel_o : out std_logic                                 --setat la '0', data e citata pe front crescator
   );
end Deserializator;

architecture Behavioral of Deserializator is
-- pentru a crea semnalul pdm_m_clk_o
signal cnt_clk : integer range 0 to 127 := 0;
-- semnal pdm_m_clk_o intern
signal clk_int : std_logic := '0';

-- semnal clk_int pentru a crea pdm_clk_rising
signal clk_intt : std_logic := '0';
signal pdm_clk_rising : std_logic;

-- registru de shiftare pentru a deserializa data
signal pdm_tmp : std_logic_vector((C_NR_OF_BITS - 1) downto 0);
-- counter pentru numarul de biti
signal cnt_bits : integer range 0 to C_NR_OF_BITS - 1 := 0;

begin

-- semnalul lrsel este la '0' pentru a citi pe front crescator
   pdm_lrsel_o <= '0';

-- shiftarea bitilor intr-un registru temporar
SHFT_IN: process(clk_i) 
       begin 
          if rising_edge(clk_i) then
             if en_i = '1' and pdm_clk_rising = '1' then 
                pdm_tmp <= pdm_tmp(C_NR_OF_BITS-2 downto 0) & pdm_m_data_i;
             end if; 
          end if;
end process SHFT_IN;
   

-- counter pentru numarul de biti, vedem daca sunt shiftati toi
CNT: process(clk_i) begin
      if rising_edge(clk_i) then
         if en_i = '1' and pdm_clk_rising = '1' then
            if cnt_bits = (C_NR_OF_BITS-1) then
               cnt_bits <= 0;
            else
               cnt_bits <= cnt_bits + 1;
            end if;
         end if;
      end if;
end process CNT;

-- genereaza semnalul de finish, pe data_out va fi pus ce e in acel registru temporar
Finish:process(clk_i) 
       begin
          if rising_edge(clk_i) then
             if en_i = '1' and pdm_clk_rising = '1' then
                if cnt_bits = (C_NR_OF_BITS-1) then
                   done_o <= '1';
                   data_o <= pdm_tmp;
                end if;
             else
                done_o <= '0';
             end if;
          end if;
end process;

-- genereaza clockul PDM
CLK_CNT: process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i = '1' or cnt_clk = ((C_SYS_CLK_FREQ_MHZ*1000000/(C_PDM_FREQ_HZ*2))-1) then
            cnt_clk <= 0;
            clk_int <= not clk_int;
         else
            cnt_clk <= cnt_clk + 1;
         end if;
         clk_intt <= clk_int;
      end if;
end process CLK_CNT;

pdm_m_clk_o <= clk_int;
pdm_clk_rising <= '1' when (clk_int = '1' and clk_intt = '0') else '0';

end Behavioral;
