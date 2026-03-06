library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.r1600_pkg.all;

library std;
use std.env.all;

entity mem_ctrl_tb is
end entity mem_ctrl_tb;

architecture sim of mem_ctrl_tb is
    constant CLK_PERIOD : time := 10 ns;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal mem_read    : std_logic := '0';
    signal mem_write   : std_logic := '0';
    signal addr        : std_logic_vector(DM_ADR_W-1 downto 0) := (others => '0');
    signal wr_data     : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
    signal rd_data     : std_logic_vector(DATA_W-1 downto 0);
    signal rd_valid    : std_logic;
    signal stall       : std_logic;
    signal busy        : std_logic;
    signal dm_adr      : std_logic_vector(DM_ADR_W-1 downto 0);
    signal dm_we_a     : std_logic;
    signal dm_re_a     : std_logic;
    signal dm_we_b     : std_logic;
    signal dm_re_b     : std_logic;
    signal dm_wr_dat   : std_logic_vector(DATA_W-1 downto 0);
    signal dm_rd_dat_a : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
    signal dm_rd_dat_b : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
    signal dm_rdy      : std_logic := '0';
begin
    clk <= not clk after CLK_PERIOD / 2;

    uut : entity work.mem_ctrl
        port map (
            iCLK         => clk,
            iRST         => rst,
            iMEM_READ    => mem_read,
            iMEM_WRITE   => mem_write,
            iADDR        => addr,
            iWR_DATA     => wr_data,
            oRD_DATA     => rd_data,
            oRD_VALID    => rd_valid,
            oSTALL       => stall,
            oBUSY        => busy,
            oDM_ADR      => dm_adr,
            oDM_WE_A     => dm_we_a,
            oDM_RE_A     => dm_re_a,
            oDM_WE_B     => dm_we_b,
            oDM_RE_B     => dm_re_b,
            oDM_WR_DAT   => dm_wr_dat,
            iDM_RD_DAT_A => dm_rd_dat_a,
            iDM_RD_DAT_B => dm_rd_dat_b,
            iDM_RDY      => dm_rdy
        );

    process
        procedure tick is
        begin
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;
    begin
        rst <= '1';
        tick;
        tick;
        rst <= '0';
        tick;

        assert stall = '0' and busy = '0' and rd_valid = '0'
            report "reset: controller did not return to idle"
            severity failure;

        addr <= x"00000010";
        mem_read <= '1';
        dm_rd_dat_a <= x"CAFE";
        dm_rdy <= '0';
        tick;

        assert dm_re_a = '1' and dm_re_b = '0'
            report "read bank A: wrong read enable"
            severity failure;
        assert stall = '1' and busy = '1'
            report "read bank A: controller should stall while waiting"
            severity failure;
        assert dm_adr = x"00000010"
            report "read bank A: address was not latched"
            severity failure;

        mem_read <= '0';
        tick;
        assert dm_re_a = '1' and stall = '1'
            report "read bank A: request did not stay active while waiting"
            severity failure;

        dm_rdy <= '1';
        tick;
        assert dm_re_a = '0' and stall = '1' and busy = '1'
            report "read bank A: controller did not advance to capture"
            severity failure;
        assert rd_valid = '0'
            report "read bank A: data should not be valid before capture"
            severity failure;

        dm_rdy <= '0';
        tick;
        assert stall = '0' and busy = '0'
            report "read bank A: controller did not return to idle after capture"
            severity failure;
        assert rd_valid = '1' and rd_data = x"CAFE"
            report "read bank A: wrong captured data"
            severity failure;

        tick;
        assert rd_valid = '0'
            report "read bank A: valid pulse should be one cycle"
            severity failure;

        addr <= x"80000004";
        mem_read <= '1';
        dm_rd_dat_b <= x"BEEF";
        tick;

        assert dm_re_b = '1' and dm_re_a = '0'
            report "read bank B: wrong read enable"
            severity failure;
        assert dm_adr = x"80000004"
            report "read bank B: address was not latched"
            severity failure;

        mem_read <= '0';
        dm_rdy <= '1';
        tick;
        assert stall = '1' and busy = '1' and rd_valid = '0'
            report "read bank B: capture stage not entered correctly"
            severity failure;

        dm_rdy <= '0';
        tick;
        assert rd_valid = '1' and rd_data = x"BEEF"
            report "read bank B: wrong captured data"
            severity failure;

        tick;
        assert rd_valid = '0'
            report "read bank B: valid pulse should clear"
            severity failure;

        addr <= x"00000020";
        wr_data <= x"1234";
        mem_write <= '1';
        tick;

        assert dm_we_a = '1' and dm_we_b = '0'
            report "write bank A: wrong write enable"
            severity failure;
        assert dm_wr_dat = x"1234" and dm_adr = x"00000020"
            report "write bank A: address or data not driven"
            severity failure;
        assert stall = '1' and busy = '1'
            report "write bank A: controller should stall while waiting"
            severity failure;

        mem_write <= '0';
        tick;
        assert dm_we_a = '1'
            report "write bank A: write enable did not stay asserted while waiting"
            severity failure;

        dm_rdy <= '1';
        tick;
        assert dm_we_a = '0' and stall = '1' and busy = '1'
            report "write bank A: hold state not entered correctly"
            severity failure;
        assert dm_wr_dat = x"1234" and dm_adr = x"00000020"
            report "write bank A: latched write data was not preserved"
            severity failure;

        dm_rdy <= '0';
        addr <= x"FFFFFFFF";
        wr_data <= x"EEEE";
        tick;
        assert stall = '0' and busy = '0'
            report "write bank A: controller did not return to idle"
            severity failure;

        addr <= x"80000024";
        wr_data <= x"5678";
        mem_write <= '1';
        tick;

        assert dm_we_b = '1' and dm_we_a = '0'
            report "write bank B: wrong write enable"
            severity failure;
        assert dm_wr_dat = x"5678" and dm_adr = x"80000024"
            report "write bank B: address or data not driven"
            severity failure;

        mem_write <= '0';
        dm_rdy <= '1';
        tick;
        assert dm_we_b = '0' and stall = '1' and busy = '1'
            report "write bank B: hold state not entered correctly"
            severity failure;

        dm_rdy <= '0';
        tick;
        assert stall = '0' and busy = '0' and rd_valid = '0'
            report "write bank B: controller did not finish cleanly"
            severity failure;

        report "PASS: mem_ctrl_tb" severity note;
        stop;
        wait;
    end process;
end architecture sim;
