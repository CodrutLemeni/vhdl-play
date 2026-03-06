-- R1600 Data Memory Controller
-- Handles read/write protocol with wait states for banked data memory
-- Bank A: DM_ADR(31)=0, Bank B: DM_ADR(31)=1

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.r1600_pkg.all;

entity mem_ctrl is
    port (
        iCLK        : in  std_logic;
        iRST        : in  std_logic;
        -- Pipeline interface
        iMEM_READ   : in  std_logic;   -- read request from EX1
        iMEM_WRITE  : in  std_logic;   -- write request from EX1
        iADDR       : in  std_logic_vector(DM_ADR_W-1 downto 0);
        iWR_DATA    : in  std_logic_vector(DATA_W-1 downto 0);
        oRD_DATA    : out std_logic_vector(DATA_W-1 downto 0);
        oRD_VALID   : out std_logic;   -- read data captured and valid
        oSTALL      : out std_logic;   -- stall pipeline (wait state)
        oBUSY       : out std_logic;   -- memory operation in progress
        -- External memory interface
        oDM_ADR     : out std_logic_vector(DM_ADR_W-1 downto 0);
        oDM_WE_A    : out std_logic;
        oDM_RE_A    : out std_logic;
        oDM_WE_B    : out std_logic;
        oDM_RE_B    : out std_logic;
        oDM_WR_DAT  : out std_logic_vector(DATA_W-1 downto 0);
        iDM_RD_DAT_A: in  std_logic_vector(DATA_W-1 downto 0);
        iDM_RD_DAT_B: in  std_logic_vector(DATA_W-1 downto 0);
        iDM_RDY     : in  std_logic
    );
end entity mem_ctrl;

architecture rtl of mem_ctrl is

    type state_t is (
        ST_IDLE,
        ST_READ_WAIT,     -- RE asserted, waiting for RDY
        ST_READ_CAPTURE,  -- RDY received, deassert RE, hold addr, capture next cycle
        ST_WRITE_WAIT,    -- WE asserted, waiting for RDY
        ST_WRITE_HOLD     -- RDY received, deassert WE, hold addr/data one more cycle
    );

    signal state      : state_t := ST_IDLE;
    signal addr_reg   : std_logic_vector(DM_ADR_W-1 downto 0) := (others => '0');
    signal wdata_reg  : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
    signal bank_sel   : std_logic := '0';  -- 0=A, 1=B
    signal rd_data_r  : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
    signal rd_valid_r : std_logic := '0';

begin

    process(iCLK)
    begin
        if rising_edge(iCLK) then
            if iRST = '1' then
                state      <= ST_IDLE;
                addr_reg   <= (others => '0');
                wdata_reg  <= (others => '0');
                bank_sel   <= '0';
                rd_data_r  <= (others => '0');
                rd_valid_r <= '0';
            else
                rd_valid_r <= '0';

                case state is
                    when ST_IDLE =>
                        if iMEM_READ = '1' then
                            addr_reg <= iADDR;
                            bank_sel <= iADDR(31);
                            state    <= ST_READ_WAIT;
                        elsif iMEM_WRITE = '1' then
                            addr_reg  <= iADDR;
                            wdata_reg <= iWR_DATA;
                            bank_sel  <= iADDR(31);
                            state     <= ST_WRITE_WAIT;
                        end if;

                    when ST_READ_WAIT =>
                        if iDM_RDY = '1' then
                            state <= ST_READ_CAPTURE;
                        end if;

                    when ST_READ_CAPTURE =>
                        -- Capture read data
                        if bank_sel = '0' then
                            rd_data_r <= iDM_RD_DAT_A;
                        else
                            rd_data_r <= iDM_RD_DAT_B;
                        end if;
                        rd_valid_r <= '1';
                        state <= ST_IDLE;

                    when ST_WRITE_WAIT =>
                        if iDM_RDY = '1' then
                            state <= ST_WRITE_HOLD;
                        end if;

                    when ST_WRITE_HOLD =>
                        state <= ST_IDLE;

                end case;
            end if;
        end if;
    end process;

    -- Output address and data
    oDM_ADR    <= addr_reg when state /= ST_IDLE else iADDR;
    oDM_WR_DAT <= wdata_reg when state /= ST_IDLE else iWR_DATA;

    -- Read enables: assert in READ_WAIT state
    oDM_RE_A <= '1' when (state = ST_READ_WAIT and bank_sel = '0') else '0';
    oDM_RE_B <= '1' when (state = ST_READ_WAIT and bank_sel = '1') else '0';

    -- Write enables: assert in WRITE_WAIT state
    oDM_WE_A <= '1' when (state = ST_WRITE_WAIT and bank_sel = '0') else '0';
    oDM_WE_B <= '1' when (state = ST_WRITE_WAIT and bank_sel = '1') else '0';

    -- Stall while any memory operation is in progress
    oSTALL <= '1' when state /= ST_IDLE else '0';

    -- Busy when any memory operation is active
    oBUSY <= '1' when state /= ST_IDLE else '0';

    -- Read data output
    oRD_DATA  <= rd_data_r;
    oRD_VALID <= rd_valid_r;

end architecture rtl;
