//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// fir_rrc is a hard-coded implementation of a root-raised cosine FIR filter.
// The number of taps, filter coefficients, and structure are all fixed. The
// filter gain is 0, so the input and output widths are the same.
//
// Coefficients were generated with the following tool:
// python3 generate_rrc_filter.py --alpha=0.5 --symbol_rate=500e3 \
//                                --sample_rate=2e6 --num_taps=20
//
// TODO: do decimation in this filter to improve efficiency.
// TODO: round the output samples instead of truncating.
//
// Example structure of a direct-form 4-tap FIR filter. In this configuration,
// the sampleN blocks are registers that get clocked by the sample clock.
//
// in --> sample0 --> sample1 --> sample2 --
//     |           |           |           |
//   coeff0      coeff1      coeff2      coeff3
//     |           |           |           |
//     --------> accum0 ---> accum1 ---> accum2 --> out
//
// Transposing the filter effectively pipelines the additions and eliminates
// the large adder tree that results from the direct form. The main downside
// of the transposed-form is the large fanout of the input sample.
//
// Example structure of a transposed-form 4-tap FIR filter. In this form,
// the accumulator blocks are registers that get clocked by the sample clock.
//
//    in         in         in         in
//     |          |          |          |
//   coeff3     coeff2     coeff1     coeff0
//     |          |          |          |
//   accum3 --> accum2 --> accum1 --> accum0 --> out

`timescale 1ns/1ps

module fir_rrc (
  input logic clk,
  input logic rst,
  input logic signed [11:0] in,
  output logic signed [11:0] out
);
  localparam int NumTaps = 21;
  localparam logic signed [13:0] Coefficients[NumTaps] = {
    -14'd86, 14'd89, 14'd245, 14'd89, -14'd433, -14'd906, -14'd613,
    14'd906, -14'd16, 14'd5632, 14'd6570, 14'd5632, -14'd16, 14'd906,
    -14'd613, -14'd906, -14'd433, 14'd89, 14'd245, 14'd89, -14'd86
  };

  logic signed [26:0] accumulators[NumTaps];

  initial begin
    if (NumTaps < 1) begin
      $error("NumTaps must be at least 1.");
    end
  end

  // The filter output is just the value from the last accumulator. Drop the
  // last 14 bits because this filter was designed for exactly 2^14 of gain.
  assign out = accumulators[0] >> 14;

  always @(posedge clk) begin
    if (rst) begin
      foreach(accumulators[i]) begin
        accumulators[i] <= 0;
      end
    end else begin
      for (int i = 0; i < (NumTaps - 1); i++) begin
        accumulators[i] <= in * Coefficients[i] + accumulators[i+1];
      end
      accumulators[NumTaps-1] <= in * Coefficients[NumTaps-1];
    end
  end
endmodule

