//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// compensator is a compensating FIR filter for a CIC decimator.
// This is a 3-tap filter that two FilterOrder-length delay lines, one multiply,
// and one sum. In the diagram below, m is the FilterOrder and A is the filter
// coefficient for the single non-unity tap. The filter coefficient is
// automatically calculated based on the recommended values in the reference:
// https://www.dsprelated.com/showarticle/1337.php
//
// Because there are 2 additions and one multiply-by-A, the maximum bit growth
// of this filter is 2+ceil(log2(abs(A))). The largest absolute value in the
// coefficient table is currently -18, so the maximum bit growth is 7.
//
// TODO: add a test to make sure we aren't overflowing due to bit growth.
//
// in ----> z^-m ----> z^-m ----
//     |           |           |
//       \   A --> X         /
//         \       |       /
//           \ -> sum <- /
//                 | --------> out
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

// Determines the appropriate filter coefficient based on FilterOrder.
function automatic signed [4:0] ChooseFilterCoefficient(int filter_order);
  if (filter_order == 1) begin
    return -5'd18;
  end else if (filter_order <= 3) begin
    return -5'd10;
  end else if (filter_order <= 5) begin
    return -5'd6;
  end else if (filter_order <= 7) begin
    return -5'd4;
  end
endfunction

module compensator #(
  parameter int InputLengthBits = 29,
  parameter int OutputLengthBits = 36,
  parameter int FilterOrder = 3
) (
  input logic clk,
  input logic rst,
  input logic signed [InputLengthBits-1:0] in,
  output logic signed [OutputLengthBits-1:0] out,
  input logic in_valid, out_ready,
  output logic out_valid
);
  localparam logic signed [4:0] Coefficient = ChooseFilterCoefficient(FilterOrder);
  logic signed [InputLengthBits-1:0] delay[2*FilterOrder];

  initial begin
    if (FilterOrder > 7) begin
      $error("Coefficient calculator only supports FilterOrder <= 7.");
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      foreach(delay[i]) begin
        delay[i] <= '0;
      end
      out <= '0;
      out_valid <= '0;
    end else begin
      if (in_valid) begin
        for (int i = 1; i < 2*FilterOrder; i++) begin
          delay[i] <= delay[i-1];
        end
        delay[0] <= in;
        out <= in + (Coefficient * delay[FilterOrder-1]) + delay[(2*FilterOrder)-1];
        out_valid <= 1'b1;
      end else if (out_ready) begin
        out_valid <= 1'b0;
      end
    end
  end
endmodule
