library ieee;
use ieee.std_logic_1164.all;
use work.r1600_pkg.all;

library std;
use std.env.all;

entity flag_stack_tb is
end entity flag_stack_tb;

architecture sim of flag_stack_tb is
    constant CLK_PERIOD : time := 10 ns;

    signal clk    : std_logic := '0';
    signal rst    : std_logic := '1';
    signal push   : std_logic := '0';
    signal pop    : std_logic := '0';
    signal cf_in  : std_logic := '0';
    signal zf_in  : std_logic := '0';
    signal if_in  : std_logic := '0';
    signal cf_out : std_logic;
    signal zf_out : std_logic;
    signal if_out : std_logic;
begin
    clk <= not clk after CLK_PERIOD / 2;

    uut : entity work.flag_stack
        port map (
            iCLK  => clk,
            iRST  => rst,
            iPUSH => push,
            iPOP  => pop,
            iCF   => cf_in,
            iZF   => zf_in,
            iIF   => if_in,
            oCF   => cf_out,
            oZF   => zf_out,
            oIF   => if_out
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

        assert cf_out = '0' and zf_out = '0' and if_out = '0'
            report "empty flag stack should read as zeros"
            severity failure;

        cf_in <= '1';
        zf_in <= '0';
        if_in <= '1';
        push <= '1';
        tick;
        push <= '0';
        assert cf_out = '1' and zf_out = '0' and if_out = '1'
            report "first flag push did not update top of stack"
            severity failure;

        cf_in <= '0';
        zf_in <= '1';
        if_in <= '0';
        push <= '1';
        tick;
        push <= '0';
        assert cf_out = '0' and zf_out = '1' and if_out = '0'
            report "second flag push did not update top of stack"
            severity failure;

        pop <= '1';
        tick;
        pop <= '0';
        assert cf_out = '1' and zf_out = '0' and if_out = '1'
            report "first flag pop did not restore previous flags"
            severity failure;

        pop <= '1';
        tick;
        pop <= '0';
        assert cf_out = '0' and zf_out = '0' and if_out = '0'
            report "second flag pop should empty the stack"
            severity failure;

        report "PASS: flag_stack_tb" severity note;
        stop;
        wait;
    end process;
end architecture sim;
