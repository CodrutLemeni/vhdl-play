NVC ?= nvc
STD ?= 2008

RTL_SRCS := \
	rtl/r1600_pkg.vhd \
	rtl/alu.vhd \
	rtl/cond_eval.vhd \
	rtl/dbg_ctrl.vhd \
	rtl/decode.vhd \
	rtl/flag_stack.vhd \
	rtl/mem_ctrl.vhd \
	rtl/pc_stack.vhd \
	rtl/reg_file.vhd \
	rtl/r1600.vhd

TB_SRCS := \
	tb/cond_eval_tb.vhd \
	tb/alu_tb.vhd \
	tb/mem_ctrl_tb.vhd \
	tb/pc_stack_tb.vhd \
	tb/flag_stack_tb.vhd \
	tb/prog_mem_model.vhd \
	tb/data_mem_model.vhd \
	tb/r1600_tb.vhd

.PHONY: clean test

clean:
	rm -rf work

test: clean
	$(NVC) --std=$(STD) -a $(RTL_SRCS) $(TB_SRCS)
	$(NVC) --std=$(STD) -e cond_eval_tb
	$(NVC) --std=$(STD) -r cond_eval_tb
	$(NVC) --std=$(STD) -e alu_tb
	$(NVC) --std=$(STD) -r alu_tb
	$(NVC) --std=$(STD) -e mem_ctrl_tb
	$(NVC) --std=$(STD) -r mem_ctrl_tb
	$(NVC) --std=$(STD) -e pc_stack_tb
	$(NVC) --std=$(STD) -r pc_stack_tb
	$(NVC) --std=$(STD) -e flag_stack_tb
	$(NVC) --std=$(STD) -r flag_stack_tb
	$(NVC) --std=$(STD) -e r1600_tb
	$(NVC) --std=$(STD) -r r1600_tb --stop-time=2us
