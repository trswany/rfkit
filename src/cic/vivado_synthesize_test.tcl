################################################################################
## SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
## SPDX-License-Identifier: MIT
################################################################################

# Simple script for testing vivado synthesis. Run with:
# `vivado -mode batch -source vivado_synthesize_test.tcl`

read_verilog comb.sv
read_verilog compensator.sv
read_verilog decimator.sv
read_verilog integrator.sv
read_verilog cic_decimator.sv
synth_design -part xc7z010clg225-1 -top cic_decimator
