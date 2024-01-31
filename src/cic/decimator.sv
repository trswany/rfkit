//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// decimator produces 1 output sample for every DecimationFactor input samples.
// This module discards unused samples. It doesn't have an in_ready output
// because it's always ready.
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

module decimator #(
  parameter int WordLengthBits = 29,
  parameter int DecimationFactor = 50
) (
  input logic clk,
  input logic rst,
  input logic signed [WordLengthBits-1:0] in,
  output logic signed [WordLengthBits-1:0] out,
  input logic in_valid, out_ready,
  output logic out_valid
);
  localparam int CounterLengthBits = 16;
  logic [CounterLengthBits-1:0] count;

  initial begin
    if ($clog2(DecimationFactor) > CounterLengthBits) begin
      $error("DecimationFactor too high for internal counter.");
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      count <= '0;
      out <= '0;
      out_valid <= '0;
    end else begin
      if (in_valid) begin
        if (count == DecimationFactor - 1) begin
          count <= '0;
          out <= in;
        end else begin
          count <= count + 1;
        end
      end
      if (in_valid && (count == DecimationFactor - 1)) begin
        out_valid <= 1'b1;
      end else if (out_ready) begin
        out_valid <= 1'b0;
      end
    end
  end
endmodule
