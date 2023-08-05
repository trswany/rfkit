################################################################################
## SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
## SPDX-License-Identifier: MIT
################################################################################

# Simple script for testing vivado synthesis. Run with:
# `vivado -mode batch -source vivado_synthesize_test.tcl`

read_verilog ad396x_data_interface.sv

# Generate errors for inferred latches.
set_msg_config -id "Synth 8-327" -new_severity "ERROR"

synth_design -part xc7z010clg225-1 -top ad396x_data_interface
