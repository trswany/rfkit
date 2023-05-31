//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// start_bit_detector is a simple start-bit detector for UART implementations.
//
// Goals:
// * Reject spurious pulses
// * Debounce the leading edge of the start bit
// * Treat start bits as valid as long as they are over 1/2 of a bit time
//
// Inputs:
// * clk: clock at 16x the nominal data bitrate
// * rst: synchronous reset for the detector
// * data: raw and asynchronous RX data; will be sampled
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

`timescale 1ns/1ps

module start_bit_detector (
  output logic start_bit_detected,
  input clk,
  input rst,
  input data
);
  logic [7:0] buffer;
  always @(posedge clk) begin
    if (rst) begin
      start_bit_detected <= 1'b0;
      buffer <= 8'b0;
    end else begin
      // Notice that the samples get inverted as they go into the buffer.
      // Through experimentation this was shown to reduce utilization.
      buffer <= {buffer[6:0], !data};
      if (start_bit_detected ||
          (buffer[7] && $countbits(buffer, '1) >= 4)) begin
        start_bit_detected <= 1'b1;
      end
    end
  end
endmodule
