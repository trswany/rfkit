################################################################################
## SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
## SPDX-License-Identifier: MIT
################################################################################

# Simple script for testing vivado synthesis. Run with:
# `vivado -mode batch -source vivado_synthesize_test.tcl`

read_verilog bit_sampler.sv
read_verilog start_bit_detector.sv
read_verilog uart_rx.sv
synth_design -part xc7z010clg225-1 -top uart_rx
