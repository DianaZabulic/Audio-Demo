library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Demo is
   port(
      clk_i          : in    std_logic;
      rstn_i         : in    std_logic;
      
      --periferice
      btn_u          : in    std_logic;
      
      --microfon(semnale PDM)
      pdm_m_clk_o    : out   std_logic; --semnal output M_CLK catre microfon 
      pdm_m_data_i   : in    std_logic; --input PDM data de la microfon
      pdm_lrsel_o    : out   std_logic; --setat la '0', data e citita pe frontul pozitiv
      
      --semnale audio output
      pwm_audio_o    : out   std_logic; --audio output data
      pwm_sdaudio_o  : out   std_logic; --enable audio output
      
      --semnale RAM
      Mem_A          : out   std_logic_vector(22 downto 0);
      Mem_DQ         : inout std_logic_vector(15 downto 0);
      Mem_CEN        : out   std_logic;
      Mem_OEN        : out   std_logic;
      Mem_WEN        : out   std_logic;
      Mem_UB         : out   std_logic;
      Mem_LB         : out   std_logic;
      Mem_ADV        : out   std_logic;
      Mem_CLK        : out   std_logic;
      Mem_CRE        : out   std_logic);
end Demo;

architecture Behavioral of Demo is
--Deserializator
component Deserializator is
generic(
   C_NR_OF_BITS         : integer := 16;
   C_SYS_CLK_FREQ_MHZ   : integer := 100;
   C_PDM_FREQ_HZ       : integer := 2000000);
port(
   clk_i          : in  std_logic;
   rst_i          : in  std_logic;
   en_i           : in  std_logic; 
   done_o         : out std_logic; 
   data_o         : out std_logic_vector(C_NR_OF_BITS - 1 downto 0); 
   pdm_m_clk_o    : out std_logic; 
   pdm_m_data_i   : in  std_logic; 
   pdm_lrsel_o    : out std_logic);
end component;

--Controler memorie
component ControlerMemorie is
   generic (
      -- ciclu citire/scriere(ns)
      C_RW_CYCLE_NS : integer := 100
   );
   port (
      -- interfata controlerului
      clk_i    : in  std_logic; -- 100 MHz clock sistem
      rst_i    : in  std_logic; --activ pe high
      rnw_i    : in  std_logic; -- citeste/scrie
      be_i     : in  std_logic_vector(3 downto 0); -- byte enable
      addr_i   : in  std_logic_vector(31 downto 0); -- adresa de input
      data_i   : in  std_logic_vector(31 downto 0); -- data input
      cs_i     : in  std_logic; --chip select activ pe high
	  data_o   : out std_logic_vector(31 downto 0); -- data output
	  rd_ack_o : out std_logic; -- flag citire
	  wr_ack_o : out std_logic; -- flag scriere
      
      -- semnalele memoriei PSRAM
      Mem_A    : out std_logic_vector(22 downto 0);
      Mem_DQ_O : out std_logic_vector(15 downto 0);
      Mem_DQ_I : in  std_logic_vector(15 downto 0);
      Mem_DQ_T : out std_logic_vector(15 downto 0);
      Mem_CEN  : out std_logic;
      Mem_OEN  : out std_logic;
      Mem_WEN  : out std_logic;
      Mem_UB   : out std_logic;
      Mem_LB   : out std_logic;
      Mem_ADV  : out std_logic;
      Mem_CLK  : out std_logic;
      Mem_CRE  : out std_logic;
      Mem_Wait : in  std_logic);
end component;

--Serializator
component Serializator is
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
end component;

constant SECONDS_TO_RECORD    : integer := 5;
constant PDM_FREQ_HZ          : integer := 2000000; 
constant SYS_CLK_FREQ_MHZ     : integer := 100;
constant NR_OF_BITS           : integer := 16;
constant NR_SAMPLES_TO_REC    : integer := (((SECONDS_TO_RECORD*PDM_FREQ_HZ)/NR_OF_BITS) - 1);

--folosit pentru a concatena cei 32 biti de date din memorie
constant DATA_CONCAT : std_logic_vector (32 - NR_OF_BITS - 1 downto 0) := (others =>'0');
type state_type is (stIdle, stRecord, stInter, stPlayback);
signal state, next_state : state_type;

--semnale comune
signal rst_i : std_logic;
signal rnw_int : std_logic;
signal addr_int : std_logic_vector(31 downto 0);
signal done_int : std_logic;
signal Mem_DQ_O, Mem_DQ_I, Mem_DQ_T : std_logic_vector(15 downto 0);

signal mem_data_i : std_logic_vector (31 downto 0) := (others => '0');
signal mem_data_o : std_logic_vector (31 downto 0) := (others => '0');

--record
signal en_des : std_logic;
signal done_des : std_logic;
signal data_des : std_logic_vector(NR_OF_BITS - 1 downto 0);
signal addr_rec : std_logic_vector(31 downto 0) := (others => '0');
signal cntRecSamples : integer := 0;
signal done_des_dly : std_logic;

--playback
signal en_ser : std_logic;
signal done_ser : std_logic;
signal rd_ack_int : std_logic;
signal data_ser : std_logic_vector(NR_OF_BITS - 1 downto 0);
signal data_ser0 : std_logic_vector(NR_OF_BITS - 1 downto 0);
signal addr_play : std_logic_vector(31 downto 0) := (others => '0');
signal cntPlaySamples : integer := 0;
signal done_ser_dly : std_logic;

begin
   
   rst_i <= not rstn_i;
   
   --bus bidirectional
   Mem_DQ <= Mem_DQ_O when Mem_DQ_T = x"0000" else (others => 'Z');
   Mem_DQ_I <= Mem_DQ;

--Deserializator
Deserializer: Deserializator
   generic map(
      C_NR_OF_BITS        => NR_OF_BITS,
      C_SYS_CLK_FREQ_MHZ  => SYS_CLK_FREQ_MHZ,
      C_PDM_FREQ_HZ       => PDM_FREQ_HZ)
   port map(
      clk_i          => clk_i,
      rst_i          => rst_i,
      en_i           => en_des,
      done_o         => done_des,
      data_o         => data_des,
      pdm_m_clk_o    => pdm_m_clk_o,
      pdm_m_data_i   => pdm_m_data_i,
      pdm_lrsel_o    => pdm_lrsel_o);
   
--Memorie
mem_data_i <= DATA_CONCAT & data_des;
data_ser <= mem_data_o (NR_OF_BITS -1 downto 0);

MemCtrl: ControlerMemorie
   generic map(
      C_RW_CYCLE_NS => 100)
   port map(
      clk_i          => clk_i,
      rst_i          => rst_i,
      rnw_i          => rnw_int,
      be_i           => "0011", -- 16 biti
      addr_i         => addr_int,
      data_i         => mem_data_i,
      cs_i           => done_int,
      data_o         => mem_data_o,
      rd_ack_o       => rd_ack_int,
      wr_ack_o       => open,
      Mem_A          => Mem_A,
      Mem_DQ_O       => Mem_DQ_O,
      Mem_DQ_I       => Mem_DQ_I,
      Mem_DQ_T       => Mem_DQ_T,
      Mem_CEN        => Mem_CEN,
      Mem_OEN        => Mem_OEN,
      Mem_WEN        => Mem_WEN,
      Mem_UB         => Mem_UB,
      Mem_LB         => Mem_LB,
      Mem_ADV        => Mem_ADV,
      Mem_CLK        => Mem_CLK,
      Mem_CRE        => Mem_CRE,
      Mem_Wait       => '0');
   
   done_int <= done_des or done_ser;
      
--Serializator

   --salveaza data_ser cand s-a terminat de citi din memorie
   process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rd_ack_int = '1' then
            data_ser0 <= data_ser;
         end if;
      end if;
   end process;
   
Serializer: Serializator
   generic map(
      C_NR_OF_BITS        => NR_OF_BITS,
      C_SYS_CLK_FREQ_MHZ  => SYS_CLK_FREQ_MHZ,
      C_PDM_FREQ_HZ       => PDM_FREQ_HZ)
   port map(
      clk_i          => clk_i,
      rst_i          => rst_i,
      en_i           => en_ser,
      done_o         => done_ser,
      data_i         => data_ser0,
      pwm_audio_o    => pwm_audio_o,
      pwm_sdaudio_o  => pwm_sdaudio_o
      );
   
--numara cat s-a inregistrat
   process(clk_i)
   begin
      if rising_edge(clk_i) then
         if state = stRecord then
            if done_des = '1' then
               cntRecSamples <= cntRecSamples + 1;
            end if;
            if done_des_dly = '1' then
               addr_rec <= addr_rec + "10";
            end if;
         else
            cntRecSamples <= 0;
            addr_rec <= (others => '0');
         end if;
         done_des_dly <= done_des;
      end if;
   end process;

--numara cat s-a dat play
   process(clk_i)
   begin
      if rising_edge(clk_i) then
         if state = stPlayback then
            if done_ser = '1' then
               cntPlaySamples <= cntPlaySamples + 1;
            end if;
            if done_ser_dly = '1' then
               addr_play <= addr_play + "10";
            end if;
         else
            cntPlaySamples <= 0;
            addr_play <= (others => '0');
         end if;
         done_ser_dly <= done_ser;
      end if;
   end process;

--FSM pentru determinarea starii urmatoare
SYNC_PROC: process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i = '1' then
            state <= stIdle;
         else
            state <= next_state;
         end if;        
      end if;
   end process;
 
--proces pentru determinarea semnalelor
OUTPUT_DECODE: process(clk_i)
   begin
      if rising_edge(clk_i) then
         case (state) is
            when stIdle =>
               rnw_int  <= '0';
               en_ser   <= '0';
               en_des   <= '0';
               addr_int <= (others => '0');
            when stRecord =>
               rnw_int  <= '0';
               en_ser   <= '0';
               en_des   <= '1';
               addr_int <= addr_rec;
            when stInter =>
               rnw_int  <= '0';
               en_ser   <= '0';
               en_des   <= '0';
               addr_int <= (others => '0');
            when stPlayback =>
               rnw_int  <= '1';
               en_ser   <= '1';
               en_des   <= '0';
               addr_int <= addr_play;
            when others =>
               rnw_int  <= '0';
               en_ser   <= '0';
               en_des   <= '0';
               addr_int <= (others => '0');
         end case;
      end if;
   end process;
 
--proces pentru stare
NEXT_STATE_DECODE: process(state, btn_u, cntRecSamples, cntPlaySamples)
   begin
      next_state <= state;
      case (state) is
         when stIdle =>
            if btn_u = '1' then
               next_state <= stRecord;
            end if;
         when stRecord =>
            if cntRecSamples = NR_SAMPLES_TO_REC then
               next_state <= stInter;
            end if;
         when stInter =>
            next_state <= stPlayback;
         when stPlayback =>
            if cntPlaySamples = NR_SAMPLES_TO_REC then
               next_state <= stIdle;
            end if;
         when others =>
            next_state <= stIdle;
      end case;      
   end process;
   
end Behavioral;