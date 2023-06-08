################################################################################
## SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
## SPDX-License-Identifier: MIT
################################################################################

# Simple script for testing vivado synthesis. Run with:
# `vivado -mode batch -source vivado_synthesize_test.tcl`

read_verilog bram.sv
synth_design -part xc7z010clg225-1 -top bram
