-- R1600 Debug and Interrupt Controller
-- Handles maskable interrupt (CALLI 0008) and debug features
-- (breakpoint, step mode → CALLI 0010)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.r1600_pkg.all;

entity dbg_ctrl is
    port (
        iCLK        : in  std_logic;
        iRST        : in  std_logic;
        -- Interrupt input
        iINT        : in  std_logic;
        iIF_FLAG    : in  std_logic;   -- current interrupt enable flag
        -- Debug inputs
        iDBG_MODE   : in  std_logic;   -- step-by-step mode
        iDBG_BRK_ADR: in  std_logic_vector(PM_ADR_W-1 downto 0);
        iCURR_PC    : in  std_logic_vector(PM_ADR_W-1 downto 0);
        -- Pipeline state
        iPIPE_VALID : in  std_logic;   -- instruction completing in WB
        iRETI_EXEC  : in  std_logic;   -- RETI/DRETI being executed
        -- Outputs
        oINT_REQ    : out std_logic;   -- request to insert interrupt CALLI
        oDBG_REQ    : out std_logic;   -- request to insert debug CALLI
        oINT_VEC    : out std_logic_vector(PM_ADR_W-1 downto 0);
        oDBG_VEC    : out std_logic_vector(PM_ADR_W-1 downto 0);
        oMASK_INT   : out std_logic;   -- mask interrupts until RETI
        -- Status output
        iCF         : in  std_logic;
        iZF         : in  std_logic;
        oDBG_STATUS : out std_logic_vector(18 downto 0)
    );
end entity dbg_ctrl;

architecture rtl of dbg_ctrl is
    signal int_sync1    : std_logic := '0';
    signal int_sync2    : std_logic := '0';
    signal int_servicing: std_logic := '0';
    signal dbg_servicing: std_logic := '0';
    signal last_pc      : std_logic_vector(PM_ADR_W-1 downto 0) := (others => '0');
    signal brk_match    : std_logic;
    signal step_req     : std_logic := '0';
    signal dbg_mask_int : std_logic := '0';
begin

    -- Synchronize interrupt input (double-FF)
    process(iCLK)
    begin
        if rising_edge(iCLK) then
            if iRST = '1' then
                int_sync1 <= '0';
                int_sync2 <= '0';
            else
                int_sync1 <= iINT;
                int_sync2 <= int_sync1;
            end if;
        end if;
    end process;

    -- Breakpoint match
    brk_match <= '1' when iCURR_PC = iDBG_BRK_ADR else '0';

    -- Main control process
    process(iCLK)
    begin
        if rising_edge(iCLK) then
            if iRST = '1' then
                int_servicing <= '0';
                dbg_servicing <= '0';
                last_pc       <= (others => '0');
                step_req      <= '0';
                dbg_mask_int  <= '0';
            else
                -- Clear debug mask on RETI/DRETI
                if iRETI_EXEC = '1' and dbg_mask_int = '1' then
                    dbg_mask_int  <= '0';
                    dbg_servicing <= '0';
                end if;

                -- Clear interrupt servicing on RETI
                if iRETI_EXEC = '1' and int_servicing = '1' and dbg_servicing = '0' then
                    int_servicing <= '0';
                end if;

                -- Step mode: request break after each instruction completes
                if iDBG_MODE = '1' and iPIPE_VALID = '1' and dbg_servicing = '0' then
                    step_req <= '1';
                end if;

                -- Breakpoint or step-triggered break
                if (brk_match = '1' or step_req = '1') and dbg_servicing = '0' then
                    step_req      <= '0';
                    dbg_servicing <= '1';
                    dbg_mask_int  <= '1';
                    last_pc       <= iCURR_PC;
                end if;

                -- Accept interrupt
                if int_sync2 = '1' and iIF_FLAG = '1' and int_servicing = '0'
                   and dbg_servicing = '0' and dbg_mask_int = '0' then
                    int_servicing <= '1';
                end if;
            end if;
        end if;
    end process;

    -- Interrupt request: rising edge detected, IF enabled, not already servicing
    oINT_REQ <= '1' when int_sync2 = '1' and iIF_FLAG = '1'
                         and int_servicing = '0' and dbg_servicing = '0'
                         and dbg_mask_int = '0' else '0';
    oINT_VEC <= INT_VECTOR;

    -- Debug request: breakpoint or step mode triggered
    oDBG_REQ <= '1' when (brk_match = '1' or step_req = '1')
                         and dbg_servicing = '0' else '0';
    oDBG_VEC <= DBG_VECTOR;

    -- Mask interrupts during debug
    oMASK_INT <= dbg_mask_int;

    -- Status output: IF, CF, ZF, last PC (15 bits, padded to 16)
    oDBG_STATUS <= iIF_FLAG & iCF & iZF & '0' & last_pc;

end architecture rtl;
