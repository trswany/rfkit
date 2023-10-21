//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// fir_rrc is a hard-coded implementation of a root-raised cosine FIR filter.
// The number of taps, filter coefficients, and structure are all fixed.
// TODO: do decimation in this filter to improve efficiency.
// TODO: round the output samples instead of truncating.

// Example structure of a 4-tap FIR filter:
//
// in --> sample0 --> sample1 --> sample2 --
//     |           |           |           |
//   coeff0      coeff1      coeff2      coeff3
//     |           |           |           |
//     --------> accum0 ---> accum1 ---> accum2 --> out
//
// Coefficients were generated with the following tool:
// python3 generate_rrc_filter.py --alpha=0.5 --symbol_rate=500e3 \
//                                --sample_rate=2e6 --num_taps=20

`timescale 1ns/1ps

module fir_rrc (
  input logic clk,
  input logic rst,
  input logic [11:0] in,
  output logic [11:0] out
);
  localparam int NumTaps = 20;
  localparam logic [13:0] Coefficients[NumTaps] = {
    -14'd17, 14'd245, 14'd284, -14'd182, -14'd931,
    -14'd1162, -14'd11, 14'd2673, 14'd5942, 14'd8192,
    14'd8192, 14'd5942, 14'd2673, -14'd11, -14'd1162,
    -14'd931, -14'd182, 14'd284, 14'd245, -14'd17
  };

  // We need one fewer sample buffer and one fewer accumulator than the number
  // of filter taps.
  logic [11:0] samples[NumTaps-1];
  logic [27:0] accumulators[NumTaps-1];

  initial begin
    if (NumTaps < 2) begin
      $error("NumTaps must be at least 2.");
    end
  end

  // The filter output is just the value from the last accumulator. Drop the
  // last 16 bits because they were growth due to filter gain.
  assign out = accumulators[NumTaps-2][27:16];

  always @(posedge clk) begin
    if (rst) begin
      foreach(samples[i]) begin
        samples[i] <= 0;
      end
      foreach(accumulators[i]) begin
        accumulators[i] <= 0;
      end
    end else begin
      // Start the for loop at (NumTaps - 2) because "samples" and
      // "accumulators" both have a size of (NumTaps - 1)
      for (int i = (NumTaps - 2); i > 0; i--) begin
        accumulators[i] <= accumulators[i-1] + (samples[i] * Coefficients[i+1]);
        samples[i] <= samples[i-1];
      end
      accumulators[0] <= in * Coefficients[0];
      samples[0] <= in;
    end
  end
endmodule

