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
// * clk: clock at 16x the nominal data bitrate
// * rst: synchronous reset for the detector
// * raw_data: raw and asynchronous RX data; will be sampled
//
// Outputs:
// * estimated_data: estimated value of the received data bit
// * sample_clk: short, 1-cycle pulse with rising edge at each decision time
//
// The bit sampler is designed to be held in reset until a start bit is
// detected. When the start bit is detected, the reset should be released
// at which point the bit sampler will start collecting and counting samples.
//
// When the sample count reaches 18, samples 14 through 18 (5 total) are
// checked, and majority voting is used to determine the value of the estimated
// bit. The sample clock is then asserted for exactly one clock period.

`timescale 1ns/1ps

module bit_sampler (
  output logic estimated_data,
  output logic sample_clk,
  input clk,
  input rst,
  input raw_data
);
  logic [4:0] buffer;
  logic [3:0] divider_counter;
  logic [1:0] delay_line;

  always @(posedge clk) begin
    if (rst) begin
      estimated_data <= 1'b0;
      sample_clk <= 1'b0;
      buffer <= 5'b0;
      divider_counter <= 4'b0;
      delay_line <= 2'b0;
    end else begin
      // Store the last 5 samples.
      buffer <= {buffer[3:0], raw_data};

      // Generate a pulse every 16 clk pulses. This counter is exactly 4 bits
      // wide, so it will roll over every 16 pulses.
      divider_counter <= divider_counter + 1;

      // Run the divided pulse through a 2-cycle delay. We want the sampler to
      // look at 5 samples centered around the optimal sampling point, so we
      // need to way for 2 extra samples to come in.
      delay_line <= {delay_line[0], (divider_counter == 15)};

      // Take the estimate and pulse the sample_clk.
      if (delay_line[1]) begin
        estimated_data <= ($countbits(buffer, '1) >= 3);
        sample_clk <= 1'b1;
      end else begin
        sample_clk <= 1'b0;
      end
    end
  end
endmodule
