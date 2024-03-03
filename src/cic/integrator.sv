//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// integrator is a integrator stage for use in a CIC filter.
// This block simply adds every new sample to a running sum. Overflows are
// intentionally allowed to occur because that is required for the CIC filter to
// operate correctly. In a CIC, the integrator stages are allowed to have signed
// overflows, and those overflows are corrected in the comb stages. The
// WordLength of this module must match the WordLength of the comb stages. This
// module doesn't have an in_ready output because it's always ready.
//
// in -> (+) -----> out
//        |     |
//       z-1 <---
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

module integrator #(
  parameter int WordLengthBits = 29
) (
  input logic clk,
  input logic rst,
  input logic signed [WordLengthBits-1:0] in,
  output logic signed [WordLengthBits-1:0] out,
  input logic in_valid, out_ready,
  output logic out_valid
);
  logic signed [WordLengthBits-1:0] accumulator;

  always @(posedge clk) begin
    if (rst) begin
      accumulator <= '0;
      out <= '0;
      out_valid <= '0;
    end else begin
      if (in_valid) begin
        accumulator <= accumulator + in;
        out <= accumulator + in;
        out_valid <= 1'b1;
      end else if (out_ready) begin
        out_valid <= 1'b0;
      end
    end
  end
endmodule
