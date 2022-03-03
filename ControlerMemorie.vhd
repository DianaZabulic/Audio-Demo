library ieee;
use ieee.std_logic_1164.all;

entity ControlerMemorie is
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
      Mem_Wait : in  std_logic
   );
end ControlerMemorie;

architecture Behavioral of ControlerMemorie is
-- State machine state names
type States is(Idle, AssertCen, AssertOenWen, Waitt, Deassert, SendData,
               Ack, Done);
signal State, NState: States := Idle;
-- pentru scrierea pe 32 de biti sunt nevoie 2 cicluri
signal TwoCycle: std_logic := '0';	
-- memoria LSB
signal AddrLsb: std_logic;
-- RnW registered signal
signal RnwInt: std_logic;
-- intern byte enable
signal BeInt: std_logic_vector(3 downto 0);
-- busul de adresa interna Bus2IP_Addr 
signal AddrInt: std_logic_vector(31 downto 0);
-- busul de date intern Bus2IP_Data 
signal Data2WrInt: std_logic_vector(31 downto 0);
-- busul intern pentru read IP2_Bus
signal DataRdInt: std_logic_vector(31 downto 0);
-- counter pentru ciclurile de citire/scriere
signal CntCycleTime: integer range 0 to 32;

begin

   -- semnale ale memoriei nefolosite
   Mem_ADV <= '0';
   Mem_CLK <= '0';
   Mem_CRE <= '0';

--semnalele interne ale registrelor
REGISTER_INT: process(clk_i)
   begin
      if rising_edge(clk_i) then
         if State = Idle and cs_i = '1' then
            RnwInt <= rnw_i;
            BeInt <= be_i;
            AddrInt <= addr_i;
            Data2WrInt <= data_i;
         end if;
      end if;
   end process REGISTER_INT;

--initializare FSM
FSM_REGISTER_STATES: process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i = '1' then
            State <= Idle;
         else
            State <= NState;
         end if;
      end if;
   end process FSM_REGISTER_STATES;
   
--tranzitii FSM
FSM_TRANSITIONS: process(cs_i, TwoCycle, CntCycleTime, State)
   begin
      case State is
         when Idle =>
            if cs_i = '1' then
               NState <= AssertCen;
            else
               NState <= Idle;
            end if;
         when AssertCen => NState <= AssertOenWen;
         when AssertOenWen => NState <= Waitt;
         when Waitt =>
            if CntCycleTime = ((C_RW_CYCLE_NS/10) - 2) then
               NState <= Deassert;
            else
               NState <= Waitt;
            end if;
         when Deassert => NState <= SendData;
         when SendData =>
            if TwoCycle = '1' then
               NState <= AssertCen;
            else
               NState <= Ack;
            end if;
         when Ack =>	NState <= Done;
         when Done => NState <= Idle;
         when others => Nstate <= Idle;
      end case;
   end process FSM_TRANSITIONS;
 
--counter pentru ciclurile de read/write
CYCLE_COUNTER: process(clk_i)
   begin
      if rising_edge(clk_i) then
         if State = Waitt then
            CntCycleTime <= CntCycleTime + 1;
         else
            CntCycleTime <= 0;
         end if;
      end if;
   end process CYCLE_COUNTER;

-- Assert CEN
ASSERT_CEN: process(clk_i)
   begin
      if rising_edge(clk_i) then
         if State = AssertOenWen or 
            State = Waitt or 
            State = Deassert then
            Mem_CEN <= '0';
         else
            Mem_CEN <= '1';
         end if;
      end if;
   end process ASSERT_CEN;

-- Assert WEN/OEN
ASSERT_WENOEN: process(clk_i)
   begin
      if rising_edge(clk_i) then
         if State = Waitt or State = Deassert then
            if RnwInt = '1' then
               Mem_OEN <= '0';
               Mem_WEN <= '1';
            else
               Mem_OEN <= '1';
               Mem_WEN <= '0';
            end if;
         else
            Mem_OEN <= '1';
            Mem_WEN <= '1';
         end if;
      end if;
   end process ASSERT_WENOEN;

-- cand se acceseaza un semnal pe 32 de biti se va lua TwoCycle
ASSIGN_TWOCYCLE: process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i = '1' then
            TwoCycle <= '0';
         elsif State = AssertCen and be_i = "1111" then
				TwoCycle <= not TwoCycle;
         end if;
      end if;
   end process ASSIGN_TWOCYCLE;

-- asignarea LSB 
ASSIGN_ADDR_LSB: process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i = '1' then
            AddrLsb <= '0';
         elsif State = AssertCen then
            case BeInt is    --pe 32 biti adresa mai mica e scrisa prima, dupa care aia mai mare
               when "1111" => AddrLsb <= not TwoCycle;
               --adresa mai mare
               when "1100"|"0100"|"1000" => AddrLsb <= '1';
               --adresa mai mica
               when "0011"|"0010"|"0001" => AddrLsb <= '0';
               when others => null;
            end case;
         end if;
      end if;
   end process ASSIGN_ADDR_LSB;

-- Assign Mem_A
ASSIGN_ADDRESS: process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i = '1' then
            Mem_A <= (others => '0');
         elsif State = AssertOenWen or 
               State = Waitt or 
               State = Deassert then
            Mem_A <= AddrInt(22 downto 1) & AddrLsb;
         end if;
      end if;
   end process ASSIGN_ADDRESS;

-- Assign Mem_DQ_O and Mem_DQ_T
ASSIGN_DATA: process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i = '1' then
            Mem_DQ_O <= (others => '0');
         elsif ((State = AssertOenWen or State = Waitt or State = Deassert) and RnwInt = '0') then
            case BeInt is
               when "1111" => 
                  if TwoCycle = '1' then
                     --scrie la adresa mai mica MSdata
                     Mem_DQ_O <= Data2WrInt(15 downto 0);
                  else
                     --scrie la adresa mai mare LSdata
                     Mem_DQ_O <= Data2WrInt(31 downto 16);
                  end if;
               when "0011"|"0010"|"0001" => Mem_DQ_O <= Data2WrInt(15 downto 0);
               when "1100"|"1000"|"0100" => Mem_DQ_O <= Data2WrInt(31 downto 16);
               when others => null;
            end case;
         else
            Mem_DQ_O <= (others => '0');
         end if;
      end if;
   end process ASSIGN_DATA;

   Mem_DQ_T <= (others => '1') when RnwInt = '1' else (others => '0');

--citeste din memorie
READ_DATA: process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i = '1' then
            DataRdInt <= (others => '0');
         elsif State = Deassert then
            case BeInt is
               when "1111" => 
                  if TwoCycle = '1' then
                     --citeste adresa mai mica MSdata
                     DataRdInt(15 downto 0) <= Mem_DQ_I;
                  else
                     --citeste adresa mai mare LSdata
                     DataRdInt(31 downto 16) <= Mem_DQ_I;
                  end if;
               when "0011"|"1100" => 
                  DataRdInt(15 downto 0)  <= Mem_DQ_I;
                  DataRdInt(31 downto 16) <= Mem_DQ_I;
               when "0100"|"0001" => 
                  DataRdInt(7 downto 0)   <= Mem_DQ_I(7 downto 0);
                  DataRdInt(15 downto 8)  <= Mem_DQ_I(7 downto 0);
                  DataRdInt(23 downto 16) <= Mem_DQ_I(7 downto 0);
                  DataRdInt(31 downto 24) <= Mem_DQ_I(7 downto 0);
               when "1000"|"0010" => 
                  DataRdInt(7 downto 0)   <= Mem_DQ_I(15 downto 8);
                  DataRdInt(15 downto 8)  <= Mem_DQ_I(15 downto 8);
                  DataRdInt(23 downto 16) <= Mem_DQ_I(15 downto 8);
                  DataRdInt(31 downto 24) <= Mem_DQ_I(15 downto 8);
               when others => null;
            end case;
         end if;
      end if;
   end process READ_DATA;

--trimite data pe busul AXI
REGISTER_DREAD: process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i = '1' then
            data_o <= (others => '0');
         elsif ((State = SendData or State = Ack or State = Done) and RnwInt = '1') then
            --trimite data pe bus numai daca s-a efectuat un ciclu de citire
            data_o <= DataRdInt;
         else
            data_o <= (others => '0');
         end if;
      end if;
   end process REGISTER_DREAD;

-- asignare semnale
REGISTER_ACK: process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i = '1' then
            rd_ack_o <= '0';
            wr_ack_o <= '0';
         elsif State = Ack and TwoCycle = '0' then
            if RnwInt = '1' then -- read
               rd_ack_o <= '1';
               wr_ack_o <= '0';
            else -- write
               rd_ack_o <= '0';
               wr_ack_o <= '1';
            end if;
         else
            rd_ack_o <= '0';
            wr_ack_o <= '0';
         end if;
      end if;
   end process REGISTER_ACK;

-- asignare UB, LB (folosit la scriere pe 8 biti)
ASSIGN_UB_LB: process(clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i = '1' then
            Mem_UB <= '0'; 
            Mem_LB <= '0';
         elsif RnwInt = '0' then
            if State = AssertOenWen or 
               State = Waitt or 
               State = Deassert then
               case BeInt is
                  --disable byte mai mic cand MSByte este scris
                  when "1000"|"0010" => 
                     Mem_UB <= '0'; 
                     Mem_LB <= '1';
                  --disable byte mai mare cand LSByte este scris
                  when "0100"|"0001" => 
                     Mem_UB <= '1'; 
                     Mem_LB <= '0'; 
                  --enable ambii bytes in alte moduri
                  when others => 
                     Mem_UB <= '0'; 
                     Mem_LB <= '0';
               end case;
            end if;
         else --enable ambii cand se citeste
            Mem_UB <= '0'; 
            Mem_LB <= '0';
         end if;
      end if;
   end process ASSIGN_UB_LB;

end Behavioral;