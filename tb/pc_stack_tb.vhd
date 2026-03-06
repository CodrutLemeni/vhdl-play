library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.r1600_pkg.all;

library std;
use std.env.all;

entity pc_stack_tb is
end entity pc_stack_tb;

architecture sim of pc_stack_tb is
    constant CLK_PERIOD : time := 10 ns;

    signal clk     : std_logic := '0';
    signal rst     : std_logic := '1';
    signal push    : std_logic := '0';
    signal pop     : std_logic := '0';
    signal data_in : std_logic_vector(PM_ADR_W-1 downto 0) := (others => '0');
    signal data_out: std_logic_vector(PM_ADR_W-1 downto 0);
begin
    clk <= not clk after CLK_PERIOD / 2;

    uut : entity work.pc_stack
        port map (
            iCLK  => clk,
            iRST  => rst,
            iPUSH => push,
            iPOP  => pop,
            iDATA => data_in,
            oDATA => data_out
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
        rst <= '0';
        tick;

        assert data_out = (data_out'range => '0')
            report "empty stack should read as zero"
            severity failure;

        data_in <= std_logic_vector(to_unsigned(5, PM_ADR_W));
        push <= '1';
        tick;
        push <= '0';
        assert data_out = std_logic_vector(to_unsigned(5, PM_ADR_W))
            report "first push did not update top of stack"
            severity failure;

        data_in <= std_logic_vector(to_unsigned(9, PM_ADR_W));
        push <= '1';
        tick;
        push <= '0';
        assert data_out = std_logic_vector(to_unsigned(9, PM_ADR_W))
            report "second push did not update top of stack"
            severity failure;

        data_in <= std_logic_vector(to_unsigned(12, PM_ADR_W));
        push <= '1';
        tick;
        push <= '0';
        assert data_out = std_logic_vector(to_unsigned(12, PM_ADR_W))
            report "third push did not update top of stack"
            severity failure;

        pop <= '1';
        tick;
        pop <= '0';
        assert data_out = std_logic_vector(to_unsigned(9, PM_ADR_W))
            report "first pop did not restore previous value"
            severity failure;

        pop <= '1';
        tick;
        pop <= '0';
        assert data_out = std_logic_vector(to_unsigned(5, PM_ADR_W))
            report "second pop did not restore oldest value"
            severity failure;

        pop <= '1';
        tick;
        pop <= '0';
        assert data_out = (data_out'range => '0')
            report "final pop should empty the stack"
            severity failure;

        report "PASS: pc_stack_tb" severity note;
        stop;
        wait;
    end process;
end architecture sim;
