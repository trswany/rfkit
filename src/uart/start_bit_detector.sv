//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// start_bit_detector is a simple start-bit detector for UART implementations.
//
// Inputs:
// * clk: clock that runs much faster than the UART bitrate.
// * rst: synchronous reset for the detector
// * sample_trigger: 1-clk pulses at the moment when samples should be taken.
// * raw_data: raw and asynchronous RX data; will be sampled
//
// Outputs:
// * start_bit_detected: high if a start bit has been detected
//
// The start-bit detector waits until it detects a falling edge (mark -> space)
// transition. It then collects 8 samples (including this first space sample)
// and verifies that at least 4 of them are space (logic 0). If less than four
// samples are space, the detector resets and starts looking for the next
// falling edge.
//
// If 4 or more samples were space (logic 0), the detector permanently asserts
// the start_bit_detected output and waits to be reset.
//
// The detector has three critical behaviors: 1) reject spurious pulses,
// 2) debounce the leading edge of the start bit, and 3) treat start
// bits as valid as long as they are over 1/2 of a bit time.

`timescale 1ns/1ps

module start_bit_detector (
  input logic clk,
  input logic rst,
  input logic sample_trigger,
  input logic raw_data,
  output logic start_bit_detected
);
  logic [7:0] buffer;

  localparam logic [2:0] MinGoodSamples = 3'd4;

  always @(posedge clk) begin
    if (rst) begin
      start_bit_detected <= 1'b0;
      buffer <= 8'b0;
    end else begin
      if (start_bit_detected ||
          (buffer[7] && $countbits(buffer, '1) >= MinGoodSamples)) begin
        start_bit_detected <= 1'b1;
      end
      if (sample_trigger) begin
        // Notice that the samples get inverted as they go into the buffer.
        // Through experimentation this was shown to reduce utilization.
        buffer <= {buffer[6:0], !raw_data};
      end
    end
  end
endmodule
