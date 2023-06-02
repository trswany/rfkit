//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// uart_tx is a very simple, hard-coded uart transmitter.
//
// Inputs:
// * clk: clock that runs much faster than the UART bitrate
// * sample_trigger: 1-clk pulse that tells the UART when to update samples.
// * rst: synchronous reset for the detector
// * data: byte to be transmitted
// * start: start transmitting the data byte
//
// Outputs:
// * serial_data: transmitted bits
// * ready: the transmitter is idle and ready to transmit another byte
//
// When the start signal is asserted, the data byte is copied to an internal
// buffer and is clocked out of the serial_data port. The data is transmitted
// in 8N1 format (8 data bits, no parity, 1 stop bit) with 16 samples per bit.
// A start bit and a stop bit are appended to the byte being transferred. The
// idle state of the serial_data output is logic 1 (mark).

`timescale 1ns/1ps

module uart_tx (
  output logic serial_data,
  output logic ready,
  input clk,
  input sample_trigger,
  input rst,
  input [7:0] data,
  input start
);
  logic [9:0] buffer;
  logic [7:0] num_samples_remaining;

  always @(posedge clk) begin
    if (rst) begin
      serial_data <= 1'b1;
      ready <= 1'b0;
      buffer <= {1'b0, data[7:0], 1'b0};
      num_samples_remaining <= 8'b0;
    end else begin
      // Only accept a new byte to transmit if we're not busy.
      if (start && ready) begin
        buffer <= {1'b0, data[7:0], 1'b0};
        num_samples_remaining <= 8'd160;
      end

      if (sample_trigger && num_samples_remaining > 0) begin
        serial_data <= buffer[((num_samples_remaining - 1) >> 4)];
        num_samples_remaining <= num_samples_remaining - 1;
      end

      if (start || num_samples_remaining > 0) begin
        ready <= 1'b0;
      end else begin
        ready <= 1'b1;
      end

      if (num_samples_remaining == 0) begin
        serial_data <= 1'b1;
      end
    end
  end
endmodule
