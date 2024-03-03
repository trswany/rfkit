//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2024 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// gain_bit_shift multiplies by bit-shifting and saturates on overflow.
// This module introduces one cycle of latency. It doesn't have an in_ready
// output because it's always ready.
//
// Inputs:
// * clk: clock
// * rst: synchronous reset
// * in: 2's-complement input data
// * in_valid: data will be clocked in when in_valid is true
// * out_ready: downstream module is ready to clock in the output word
//
// Outputs:
// * out: 2's-complement output data
// * out_valid: a new word is being presented on the output

`timescale 1ns/1ps

module gain_bit_shift #(
  parameter int WordLengthBits = 12,
  parameter int GainBits = 2
) (
  input logic clk,
  input logic rst,
  input logic signed [WordLengthBits-1:0] in,
  output logic signed [WordLengthBits-1:0] out,
  input logic in_valid, out_ready,
  output logic out_valid
);
  // Generate the max and min values to use when the output saturates.
  localparam logic signed [WordLengthBits-1:0] OutMax = 2**(WordLengthBits-1)-1;
  localparam logic signed [WordLengthBits-1:0] OutMin = -(2**(WordLengthBits-1));

  // Overflow will occur if and only if the top (GainBits+1) bits don't match.
  // For convenience, create a placeholder of bits that we will check below.
  logic [GainBits+1:0] overflow_detect_bits;
  assign overflow_detect_bits = in[(WordLengthBits - 1) -: (GainBits + 1)];

  always @(posedge clk) begin
    if (rst) begin
      out <= '0;
      out_valid <= '0;
    end else begin
      if (in_valid) begin
        out_valid <= 1'b1;
        if ($countones(overflow_detect_bits) == 0 ||
            $countones(overflow_detect_bits) == GainBits + 1) begin
          out <= {in[WordLengthBits - 1 - GainBits : 0], {GainBits{1'b0}}};
        end else if (in[WordLengthBits-1] == 1'b1) begin
          out <= OutMin;
        end else begin
          out <= OutMax;
        end
      end else if (out_ready) begin
        out_valid <= 1'b0;
      end
    end
  end
endmodule
