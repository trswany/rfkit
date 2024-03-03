//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// comb is a comb stage for use in a CIC filter.
// A comb simply subtracts a delayed copy of itself from. The delay length
// ("m" in the figure below) is configured by the DelayLength parameter. This
// module's WordLength must match the WordLength of the integrator stages.
//
// in ----> (-) --> out
//     |     |
//   z^-m --->
//
// Inputs:
// * clk: clock
// * rst: synchronous reset
// * in: 2's-complement input data
// * in_valid: data will be clocked into the filter when in_valid is true
// * out_ready: downstream module is ready to clock in the output word
//
// Outputs:
// * out: 2's-complement output data
// * out_valid: a new word is being presented on the output

`timescale 1ns/1ps

module comb #(
  parameter int WordLengthBits = 29,
  parameter int DelayLength = 2
) (
  input logic clk,
  input logic rst,
  input logic signed [WordLengthBits-1:0] in,
  output logic signed [WordLengthBits-1:0] out,
  input logic in_valid, out_ready,
  output logic out_valid
);
  logic signed [WordLengthBits-1:0] delay[DelayLength];

  always @(posedge clk) begin
    if (rst) begin
      foreach(delay[i]) begin
        delay[i] <= '0;
      end
      out <= '0;
      out_valid <= '0;
    end else begin
      if (in_valid) begin
        for (int i = 1; i < DelayLength; i++) begin
          delay[i] <= delay[i-1];
        end
        delay[0] <= in;
        out <= in - delay[DelayLength-1];
        out_valid <= 1'b1;
      end else if (out_ready) begin
        out_valid <= 1'b0;
      end
    end
  end
endmodule
