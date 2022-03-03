library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Serializator is
   generic(
      C_NR_OF_BITS : integer := 16;
      C_SYS_CLK_FREQ_MHZ : integer := 100;
      C_PDM_FREQ_HZ : integer := 2000000
   );
   port(
      clk_i : in std_logic;
      rst_i : in std_logic;
      en_i : in std_logic;      --enable serializarea in timpul redarii audio
      
      done_o : out std_logic;    --semnalizeaza ca data este trimisa
      data_i : in std_logic_vector(C_NR_OF_BITS - 1 downto 0);       --input data
      
      -- PWM
      pwm_audio_o : out std_logic;       --audio output
      pwm_sdaudio_o : out std_logic      --audio output enable
   );
end Serializator;

architecture Behavioral of Serializator is
-- pentru a crea semnalul de clk_int
signal cnt_clk : integer range 0 to 127 := 0;
-- semnalul intern pdm_clk
signal clk_int : std_logic := '0';

-- semnal clk_int pentru a crea pdm_clk_rising
signal clk_intt : std_logic := '0';
signal pdm_clk_rising : std_logic;

-- registru de shiftare pentru a stoca temporar datele
signal pdm_s_tmp : std_logic_vector((C_NR_OF_BITS-1) downto 0);
-- counter pentru numarul de biti
signal cnt_bits : integer range 0 to C_NR_OF_BITS -1 := 0;

signal pwm_int : std_logic;
signal done_int : std_logic;

begin

   -- enable audio
   pwm_sdaudio_o <= '1';
    
-- numara bitii
   CNT: process(clk_i) begin
      if rising_edge(clk_i) then
         if pdm_clk_rising = '1' then
            if cnt_bits = (C_NR_OF_BITS-1) then
               cnt_bits <= 0;
            else
               cnt_bits <= cnt_bits + 1;
            end if;
         end if;
      end if;
   end process CNT;
   
-- genereaza semnalul de done_o cand toti bitii sunt serializati
   process(clk_i)
   begin
      if rising_edge(clk_i) then
         if pdm_clk_rising = '1' then
            if cnt_bits = (C_NR_OF_BITS-1) then
               done_o <= '1';
            end if;
         else
            done_o <= '0';
         end if;
      end if;
   end process;
   
-- registrul de shiftare
   SHIFT_OUT: process(clk_i)
   begin
      if rising_edge(clk_i) then
         if pdm_clk_rising = '1' then
            if cnt_bits = (C_NR_OF_BITS-1) then
               pdm_s_tmp <= data_i;
            else
               pdm_s_tmp <= pdm_s_tmp(C_NR_OF_BITS-2 downto 0) & '0';
            end if;
         end if;
      end if;
   end process SHIFT_OUT;
   
   -- semnalul de output serializat
   pwm_audio_o <= pdm_s_tmp(C_NR_OF_BITS-1) when en_i = '1' else clk_int;


-- generarea semnalului intern de pdm clock
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
   
   pdm_clk_rising <= '1' when clk_int = '1' and clk_intt = '0' else '0';
      
end Behavioral;