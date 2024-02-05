//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2024 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// gardner_ted_qam is a Gardner timing-error detector for QAM signals.
// The QAM timing error estimate is formed by running the PAM Gardner-TED on the
// in-phase and quadrature signals separately and then adding the results.
//
// Because of the extra addition, we have to allocate an additional bit of
// OutputLengthBits to allow for bit growth and avoid overflow. The PAM version
// of Gardner TED requires (1+2*InputLengthBits) bits, but we require
// (2+2*InputLengthBits) bits. See that module for more info about bit growth.
//
// Inputs:
// * clk: clock
// * rst: synchronous reset
// * in_i: in-phase 2's-complement input data
// * in_q: quadrature 2's-complement input data
// * in_valid_i: data will be clocked into the in-phase side when true
// * in_valid_q: data will be clocked into the quadrature side when true
// * out_ready: downstream module is ready to clock in the output word
// * trigger: a new output will only be presented when trigger is asserted
//
// Outputs:
// * out: 2's-complement output data
// * out_valid: a new word is being presented on the output

`timescale 1ns/1ps

module gardner_ted_qam #(
  parameter int SamplesPerSymbol = 4,
  parameter int InputLengthBits = 12,
  parameter int OutputLengthBits = 26  // Warning: avoid overflow, see above.
) (
  input logic clk,
  input logic rst,
  input logic signed [InputLengthBits-1:0] in_i, in_q,
  output logic signed [OutputLengthBits-1:0] out,
  input logic in_valid_i, in_valid_q, out_ready, trigger,
  output logic out_valid
);
  logic signed [OutputLengthBits-1:0] out_i, out_q;

  gardner_ted_pam #(
    .SamplesPerSymbol(SamplesPerSymbol),
    .InputLengthBits(InputLengthBits),
    .OutputLengthBits(OutputLengthBits - 1)
  ) ted_i(
    .clk(clk),
    .rst(rst),
    .in(in_i),
    .in_valid(in_valid_i),
    .trigger(trigger),
    .out(out_i),
    .out_valid(out_valid),
    .out_ready(out_ready)
  );

  gardner_ted_pam #(
    .SamplesPerSymbol(SamplesPerSymbol),
    .InputLengthBits(InputLengthBits),
    .OutputLengthBits(OutputLengthBits - 1)
  ) ted_q(
    .clk(clk),
    .rst(rst),
    .in(in_q),
    .in_valid(in_valid_q),
    .trigger(trigger),
    .out(out_q),
    .out_valid(),  // out_valid is driven by in-phase TED.
    .out_ready(out_ready)
  );

  initial begin
    if (SamplesPerSymbol % 2 != 0) begin
      $error("SamplesPerSymbol must be even.");
    end
    if (OutputLengthBits < (2 + 2*InputLengthBits)) begin
      $error("Output will overflow. See note about bit growth.");
    end
  end

  always_comb begin
    out = out_i + out_q;
  end
endmodule
