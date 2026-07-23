.PHONY: test compile

export LIBPYTHON_LOC=$(shell cocotb-config --libpython)
# [cocotb 2.0 fix] cocotb 2.0 requires PYGPI_PYTHON_BIN to locate the Python interpreter.
# Without this, the GPI embed layer segfaults with "PYGPI_PYTHON_BIN variable not set".
export PYGPI_PYTHON_BIN=$(shell cocotb-config --python-bin)

test_%:
	make compile
	# [cocotb 2.0 fix] Added -DCOCOTB_SIM to compile the initial block that dumps sim.vcd
	iverilog -o build/sim.vvp -s gpu -g2012 -DCOCOTB_SIM build/gpu.v
	# [cocotb 2.0 fix] Two changes here:
	#   1. MODULE → COCOTB_TEST_MODULES: cocotb 2.0 renamed the env var for specifying test modules.
	#   2. --prefix → --lib-dir: cocotb 2.0 removed the --prefix flag from cocotb-config.
	#      Old: $$(cocotb-config --prefix)/cocotb/libs
	#      New: $$(cocotb-config --lib-dir)  (directly returns the libs directory path)
	COCOTB_TEST_MODULES=test.test_$* vvp -M $$(cocotb-config --lib-dir) -m libcocotbvpi_icarus build/sim.vvp

compile:
	make compile_alu
	# [cocotb 2.0 fix] Added -DCOCOTB_SIM so sv2v includes the initial block in build/gpu.v
	sv2v -DCOCOTB_SIM -I src/* -w build/gpu.v
	echo "" >> build/gpu.v
	cat build/alu.v >> build/gpu.v
	echo '`timescale 1ns/1ns' > build/temp.v
	cat build/gpu.v >> build/temp.v
	mv build/temp.v build/gpu.v

compile_%:
	sv2v -w build/$*.v src/$*.sv

# [cocotb 2.0 fix] Launch GTKWave to view the generated simulation waveform
waves:
	gtkwave build/sim.vcd
