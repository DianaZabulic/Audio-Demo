library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity modulPrincipal is
   port(
      clk_i          : in  std_logic;
      rstn_i         : in  std_logic;
      --butoane
      btnu_i         : in  std_logic;
      --microfon PDM
      pdm_clk_o      : out std_logic;
      pdm_data_i     : in  std_logic;
      pdm_lrsel_o    : out std_logic;
      --audio PWM
      pwm_audio_o    : out std_logic;
      pwm_sdaudio_o  : out std_logic);
end modulPrincipal;

architecture Behavioral of modulPrincipal is

component Demo is
   port(
      clk_i          : in    std_logic;
      rstn_i         : in    std_logic;
      btn_u          : in    std_logic;
      pdm_m_clk_o    : out   std_logic; --semnal output M_CLK catre microfon 
      pdm_m_data_i   : in    std_logic; --input PDM data de la microfon
      pdm_lrsel_o    : out   std_logic; --setat la '0', data e citita pe frontul pozitiv
      pwm_audio_o    : out   std_logic; --audio output data
      pwm_sdaudio_o  : out   std_logic; --enable audio output
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
end component;

signal pdm_clk : std_logic;
signal Mem_A: std_logic_vector(22 downto 0);
signal Mem_DQ:  std_logic_vector(15 downto 0); 
signal Mem_CEN, MEM_OEN, MEM_WEN, MEM_UB, Mem_LB, Mem_ADV, Mem_CLK, Mem_CRE: std_logic;

begin
pdm_clk_o <= pdm_clk;
Inst_AudioDemo:Demo
   port map(
      clk_i          => clk_i,
      rstn_i         => rstn_i,
      btn_u          => btnu_i,
      pdm_m_clk_o    => pdm_clk,
      pdm_m_data_i   => pdm_data_i,
      pdm_lrsel_o    => pdm_lrsel_o,
      pwm_audio_o    => pwm_audio_o,
      pwm_sdaudio_o  => pwm_sdaudio_o,
      Mem_A          => Mem_A,
      Mem_DQ         => Mem_DQ,
      Mem_CEN        => Mem_CEN,
      Mem_OEN        => Mem_OEN,
      Mem_WEN        => Mem_WEN,
      Mem_UB         => Mem_UB,
      Mem_LB         => Mem_LB,
      Mem_ADV        => Mem_ADV,
      Mem_CLK        => Mem_CLK,
      Mem_CRE        => Mem_CRE);	  
end Behavioral;