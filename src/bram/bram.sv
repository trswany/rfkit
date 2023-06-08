//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// bram is single-port, synchronous, write-first (transparent) block ram.
//
// Xilinx UG-627 ("XST User Guide for Virtex-4, Virtex-5, Spartan-3, and Newer
// CPLD Devices") contains information about implementing block rams (see
// section 3). This particular design is single-port with synchronous reads.
//
// Write-firt (or transparent) means that data is made available at the output
// on the same clock cycle that it is clocked into the memory. This is
// recommended by Xilinx to improve performance.
//
// There are also some helpful notes in WP231 "White Paper: Virtex-4,
// Spartan-3/3L, and Spartan-3E FPGAs."
//
// Note that this module intentionally leaves out any kind of reset. There is
// no guarantees about the state of the block ram before it is written.

`timescale 1ns/1ps

module bram #(parameter int WordLengthBits = 8, parameter int NumWords = 128) (
  input logic clk,
  input logic [$clog2(NumWords)-1:0] address,
  input logic write_enable,
  input logic [WordLengthBits-1:0] data_in,
  output logic [WordLengthBits-1:0] data_out
);
  logic [WordLengthBits-1:0] ram [NumWords];
  always @(posedge clk) begin
    if (write_enable) begin
      data_out <= data_in;
      ram[address] <= data_in;
    end else begin
      data_out <= ram[address];
    end
  end
endmodule
