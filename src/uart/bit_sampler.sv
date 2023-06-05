//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// bit_sampler samples and estimates the values of received bits.
//
// Inputs:
// * clk: clock that runs much faster than the UART bitrate.
// * sample_trigger: 1-clk pulse that tells the sampler when to sample.
// * rst: synchronous reset for the detector
// * raw_data: raw and asynchronous RX data; will be sampled
//
// Outputs:
// * estimated_data: estimated value of the received data bit
// * estimate_ready: 1-cycle pulse at the time that the estimate is taken.
//
// The bit sampler is designed to be held in reset until a start bit is
// detected. When the start bit is detected, the reset should be released
// at which point the bit sampler will start collecting and counting samples.
//
// Every 16 samples, the bit_sampler samples the last 5 bits and uses majority
// voting to determine the value of the estimated bit. The estimate_ready
// signal is asserted for one clock period as the estimated bit is presented.
//
// For the first bit (the first bit coming out of reset), an extra 2-sample
// delay is inserted so that we take the 5 samples centered around the optimal
// bit sampling time (halfway through the bit as referenced to the start time
// given to us by the start_bit_detector). This constant 2-sample offset
// applies to every bit, meaning that every bit is "sampled" at the optimum
// half-bit sample point but that estimated bit is "ready" two samples later.

`timescale 1ns/1ps

module bit_sampler (
  output logic estimated_bit,
  output logic estimate_ready,
  input logic clk,
  input logic sample_trigger,
  input logic rst,
  input logic raw_data
);
  logic [4:0] buffer;
  logic [4:0] samples_needed;

  localparam logic [4:0] SamplesPerBit = 5'd16;
  localparam logic [1:0] TwoSampleDelay = 2'd2;

  always @(posedge clk) begin
    if (rst) begin
      estimated_bit <= 1'b0;
      estimate_ready <= 1'b0;
      buffer <= 5'b0;
      samples_needed <= (SamplesPerBit + TwoSampleDelay);
    end else begin
      if (sample_trigger) begin
        // Store the last 5 samples.
        buffer <= {buffer[3:0], raw_data};
        if (samples_needed == 1) begin
          // If this was the last sample we needed, generate the estimate.
          estimated_bit <= ($countbits(buffer, '1) >= 3);
          estimate_ready <= 1'b1;
          samples_needed <= SamplesPerBit;
        end else begin
          // Otherwise, decrement the counter and keep going.
          samples_needed <= samples_needed - 1;
        end
      end else begin
        // Only assert the estimate_ready signal for a single clock cycle.
        estimate_ready <= 1'b0;
      end
    end
  end
endmodule
