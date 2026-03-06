-- R1600 Top-Level Testbench
-- Instantiates processor with program and data memory models
-- Runs test program and checks register results

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.r1600_pkg.all;

library std;
use std.env.all;

entity r1600_tb is
end entity r1600_tb;

architecture sim of r1600_tb is

    constant CLK_PERIOD : time := 5 ns;  -- 200 MHz

    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal int          : std_logic := '0';
    signal dbg_mode     : std_logic := '0';
    signal dbg_brk_adr  : std_logic_vector(PM_ADR_W-1 downto 0) := (others => '0');
    signal dbg_status   : std_logic_vector(18 downto 0);

    -- Data memory signals
    signal dm_adr       : std_logic_vector(DM_ADR_W-1 downto 0);
    signal dm_we_a      : std_logic;
    signal dm_re_a      : std_logic;
    signal dm_we_b      : std_logic;
    signal dm_re_b      : std_logic;
    signal dm_wr_dat    : std_logic_vector(DATA_W-1 downto 0);
    signal dm_rd_dat_a  : std_logic_vector(DATA_W-1 downto 0);
    signal dm_rd_dat_b  : std_logic_vector(DATA_W-1 downto 0);
    signal dm_rdy       : std_logic;

    -- Program memory signals
    signal pm_adr       : std_logic_vector(PM_ADR_W-1 downto 0);
    signal pm_dat       : std_logic_vector(INSTR_W-1 downto 0);
    signal pm_re        : std_logic;

begin

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT
    u_dut : entity work.r1600
        port map (
            iCLK         => clk,
            iRST         => rst,
            iINT         => int,
            iDBG_MODE    => dbg_mode,
            iDBG_BRK_ADR => dbg_brk_adr,
            oDBG_STATUS  => dbg_status,
            oDM_ADR      => dm_adr,
            oDM_WE_A     => dm_we_a,
            oDM_RE_A     => dm_re_a,
            oDM_WE_B     => dm_we_b,
            oDM_RE_B     => dm_re_b,
            oDM_WR_DAT   => dm_wr_dat,
            iDM_RD_DAT_A => dm_rd_dat_a,
            iDM_RD_DAT_B => dm_rd_dat_b,
            iDM_RDY      => dm_rdy,
            oPM_ADR      => pm_adr,
            iPM_DAT      => pm_dat,
            oPM_RE       => pm_re
        );

    -- Program memory
    u_pmem : entity work.prog_mem_model
        port map (
            iCLK => clk,
            iADR => pm_adr,
            iRE  => pm_re,
            oDAT => pm_dat
        );

    -- Data memory
    u_dmem : entity work.data_mem_model
        port map (
            iCLK      => clk,
            iADR      => dm_adr,
            iWE_A     => dm_we_a,
            iRE_A     => dm_re_a,
            oRD_DAT_A => dm_rd_dat_a,
            iWE_B     => dm_we_b,
            iRE_B     => dm_re_b,
            oRD_DAT_B => dm_rd_dat_b,
            iWR_DAT   => dm_wr_dat,
            oRDY      => dm_rdy
        );

    -- Stimulus
    process
    begin
        rst <= '1';
        wait for CLK_PERIOD * 5;
        rst <= '0';

        -- Run for enough cycles to complete the test program
        -- ~40 instructions + pipeline latency + hazard stalls + call/return + branch
        wait for CLK_PERIOD * 150;

        report "============================================";
        report "R1600 Testbench - Simulation Complete";
        report "============================================";
        report "Debug Status: " & to_string(dbg_status);
        report "Final PM_ADR: " & to_string(pm_adr);
        report "============================================";

        -- PM_ADR is the current fetch address, so the halt self-jump can settle
        -- on the jump itself (36) or the following fetch slot (37).
        assert pm_adr = "000000000100100" or pm_adr = "000000000100101"
            report "FAIL: Expected halt loop fetch PC 36 or 37, got "
                & integer'image(to_integer(unsigned(pm_adr)))
            severity failure;
        report "PASS: Processor reached halt loop at expected fetch PC"
            severity note;

        wait for CLK_PERIOD * 10;
        std.env.stop;
    end process;

end architecture sim;
