################################################################################
## SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
## SPDX-License-Identifier: MIT
################################################################################

# Simple script for testing vivado synthesis. Run with:
# `vivado -mode batch -source vivado_synthesize_test.tcl`

# Generate errors for inferred latches.
set_msg_config -id "Synth 8-327" -new_severity "ERROR"

read_verilog ../fir/fir.sv
read_verilog frequency_locked_loop.sv
synth_design -part xc7z010clg225-1 -top frequency_locked_loop
