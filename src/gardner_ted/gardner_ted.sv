//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2024 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// gardner_ted is a Gardner timing-error detector.
// This module takes baseband rx samples from the output of the RRC matched
// filter and generates an output that is proportional to the "error" between
// the current and desired symbol sample points. This timing error signal will
// be used as an input to an interpolator that re-samples in the input stream.
//
// Gardner TED uses 3 samples that are spaced by 1/2 of a symbol time (resulting
// in a total spread of one symbol time). This implementation allows for sample
// rates other than 2 samples/symbol by simply ignoring the extra samples.
//
// To avoid overflow, the output word length must be (1+2*InputLengthBits) bits.
//
// The output of this block needs to run at the system sampling rate, but we
// only want to generate a new error estimate once per symbol. The interpolator
// will provide us with a "trigger" signal that tells us when to update our
// estimate.
//
//                  ------------------>
//               -  |                 |
//     |---------> (+) <---------|    |
//     |                         |    |
// in --> [delay] ---> [delay] -->    |
//                 |                  |
//                 ----------------> (x)
//                                    |
//                                    -----> out
//
// Inputs:
// * clk: clock
// * rst: synchronous reset
// * in: 2's-complement input data
// * in_valid: data will be clocked into the filter when in_valid is true
// * out_ready: downstream module is ready to clock in the output word
// * trigger: a new output will only be presented when trigger is asserted
//
// Outputs:
// * out: 2's-complement output data
// * out_valid: a new word is being presented on the output

`timescale 1ns/1ps

module gardner_ted #(
  parameter int SamplesPerSymbol = 4,
  parameter int InputLengthBits = 12,
  parameter int OutputLengthBits = 25  // Warning: avoid overflow, see above.
) (
  input logic clk,
  input logic rst,
  input logic signed [InputLengthBits-1:0] in,
  output logic signed [OutputLengthBits-1:0] out,
  input logic in_valid, out_ready, trigger,
  output logic out_valid
);
  logic signed [InputLengthBits-1:0] samples [SamplesPerSymbol];

  initial begin
    if (SamplesPerSymbol % 2 != 0) begin
      $error("SamplesPerSymbol must be even.");
    end
    if (OutputLengthBits < (1 + 2*InputLengthBits)) begin
      $error("Output will overflow. See note about bit growth.");
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      foreach(samples[i]) begin
        samples[i] <= '0;
      end
      out <= '0;
      out_valid <= '0;
    end else begin
      if (in_valid) begin
        for (int i = 1; i < SamplesPerSymbol; i++) begin
          samples[i] <= samples[i-1];
        end
        samples[0] <= in;
        out_valid <= 1'b1;
      end else if (out_ready) begin
        out_valid <= 1'b0;
      end
      if (trigger) begin
        // Only update the error estimate when we're told by the interpolator.
        out <= (samples[SamplesPerSymbol-1] - in) * samples[(SamplesPerSymbol/2)-1];
      end
    end
  end
endmodule
