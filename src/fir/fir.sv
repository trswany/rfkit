//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// fir is a parameterized FIR filter with real, fixed-point coefficients.
// The number of taps, tap values, data widths, and truncation bits are all
// adjustable via parameters. This filter allows for bit growth in the internal
// accumulator registers, but assumes that the input and output data widths
// are the same. To facilitate this, there is a bit-shifting "truncator" stage
// that effectively truncates the final accumulator register to get back down
// to the original input bit width before presenting the output word.
//
// Inputs:
// * clk: clock that runs much faster than the UART bitrate
// * rst: synchronous reset for the detector
// * in: 2's-complement input data
// * in_valid: data will be clocked into the filter when in_valid is true
// * out_ready: downstream module is ready to clock in the output word
//
// Outputs:
// * out: 2's-complement output data
// * out_valid: a new word is being presented on the output
//
// To design a low-pass filter for use in this FIR implementation:
// 1) Choose input/output bit widths
// 2) Choose the bit width of the filter weights; this is usually 2 more bits
//    than the input data width to avoid adding excessive quantization noise.
// 3) Design a filter using floating-point taps
// 4) Scale the floating-point taps to use the full range of the filter weight
//    word length. In other words, the largest filter value (in absolute value)
//    should be -2^(N-1) if it's negative or 2^(N-1)-1 if it's positive.
// 5) Determine the DC gain of the taps. If it's not an even power of 2,
//    scale the taps down until the DC gain is a power of 2. This allows the
//    truncator (divisor) stage to be a simple bit shift operation.
// 6) Round the coefficients and conver them to fixed-point.
// 7) Determine the maximum bit growth:
//    max_growth_bits = ceil(log2(sum(abs(fixed_point_coefficients))))
// 8) Set the accumulator bit length to input_length_bits + max_growth_bits
// 9) Set the truncator bit-shift parameter based on the DC gain of the filter.
//
// The process for designing other types of filters is similar, but determining
// maximum filter gain and therefore the maximum bit growth is more complex.
//
// Example structure of a direct-form 4-tap FIR filter. In this configuration,
// the sampleN blocks are registers that get clocked by the sample clock.
//
// in --> sample0 --> sample1 --> sample2 --
//     |           |           |           |
//   coeff0      coeff1      coeff2      coeff3
//     |           |           |           |
//     --------> accum0 ---> accum1 ---> accum2 --> truncator -> out
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
//   accum3 --> accum2 --> accum1 --> accum0 --> truncator -> out

`timescale 1ns/1ps

module fir #(
  parameter int InputLengthBits = 8,
  parameter int CoefficientLengthBits = 10,
  parameter int AccumulatorLengthBits = 20,
  parameter int NumTaps = 3,
  parameter int OutputTruncationBits = 10,
  parameter logic signed [CoefficientLengthBits-1:0] Coefficients [NumTaps] = {
    -10'd300, +10'd511, 10'd300
  }
) (
  input logic clk,
  input logic rst,
  input logic signed [InputLengthBits-1:0] in,
  output logic signed [InputLengthBits-1:0] out,
  input logic in_valid, out_ready,
  output logic out_valid
);
  localparam logic signed [InputLengthBits-1:0] OutMax = 2**(InputLengthBits-1)-1;
  localparam logic signed [InputLengthBits-1:0] OutMin = -(2**(InputLengthBits-1));
  localparam int TopBitsToDrop = AccumulatorLengthBits - InputLengthBits - OutputTruncationBits;

  logic signed [AccumulatorLengthBits-1:0] accumulators[NumTaps];
  logic [TopBitsToDrop:0] overflow_detect_bits;
  logic in_valid_d;

  initial begin
    if (NumTaps < 1) begin
      $error("NumTaps must be at least 1.");
    end
    if (AccumulatorLengthBits - OutputTruncationBits < InputLengthBits) begin
      $error("Not enough accumulator and truncate bits to generate output.");
    end
  end

  // When we drop bits, we'll check for overflow by examining these tops bits.
  assign overflow_detect_bits = accumulators[0][(AccumulatorLengthBits - 1) -: (TopBitsToDrop + 1)];

  always @(posedge clk) begin
    if (rst) begin
      foreach(accumulators[i]) begin
        accumulators[i] <= 0;
      end
      out <= '0;
      out_valid <= '0;
      in_valid_d <= '0;
    end else begin
      in_valid_d <= in_valid;
      if (in_valid) begin
        for (int i = 0; i < (NumTaps - 1); i++) begin
          accumulators[i] <= in * Coefficients[i] + accumulators[i+1];
        end
        accumulators[NumTaps-1] <= in * Coefficients[NumTaps-1];
      end

      // The filter output is just a subset of the bits from the last
      // accumulator. We will drop the bottom OutputTruncationBits and the
      // TopBitsToDrop. Dropping the top bits is dangerous, so force the filter
      // to saturate. To detect saturation, see if the top bits match.
      if ($countones(overflow_detect_bits) == 0 ||
          $countones(overflow_detect_bits) == TopBitsToDrop + 1) begin
        out <= accumulators[0][AccumulatorLengthBits - 1 - TopBitsToDrop : OutputTruncationBits];
      end else if (accumulators[0][AccumulatorLengthBits-1 -: 1] == 1'b1) begin
        out <= OutMin;
      end else begin
        out <= OutMax;
      end

      if (in_valid_d) begin
        // If we accepted a new sample, then the output changed and is valid.
        out_valid = 1'b1;
      end else if (out_ready) begin
        // Otherwise, if the receiver is ready we ack by clearing valid.
        out_valid = 1'b0;
      end else begin
        out_valid = out_valid;
      end
    end
  end
endmodule
