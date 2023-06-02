//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// bit_sampler samples and estimates the values of received bits.
//
// Goals:
// * Reject spurious pulses
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
// When the sample count reaches 18, samples 14 through 18 (5 total) are
// checked, and majority voting is used to determine the value of the estimated
// bit. estimate_ready is then asserted for exactly one clock period.

`timescale 1ns/1ps

module bit_sampler (
  output logic estimated_data,
  output logic estimate_ready,
  input clk,
  input sample_trigger,
  input rst,
  input raw_data
);
  logic [4:0] buffer;
  logic [3:0] sample_count;
  logic [1:0] delay_line;

  always @(posedge clk) begin
    if (rst) begin
      estimated_data <= 1'b0;
      estimate_ready <= 1'b0;
      buffer <= 5'b0;
      sample_count <= 4'b0;
      delay_line <= 2'b0;
    end else begin
      if (sample_trigger) begin
        // Store the last 5 samples.
        buffer <= {buffer[3:0], raw_data};

        // Count out every batch of 16 samples. This counter is exactly 4 bits
        // wide, so it will roll over every 16 pulses.
        sample_count <= sample_count + 1;

        // Run the top bit of the counter through a 2-cycle delay. We want the
        // sampler to look at 5 samples centered around the optimal sampling
        // point, so we need to way for 2 extra samples to come in.
        delay_line <= {delay_line[0], (sample_count == 15)};
      end

      // Take the estimate and pulse estimate_ready.
      if (sample_trigger && delay_line[1]) begin
        estimated_data <= ($countbits(buffer, '1) >= 3);
        estimate_ready <= 1'b1;
      end else begin
        estimate_ready <= 1'b0;
      end
    end
  end
endmodule
