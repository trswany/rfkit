//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// uart_tx is a very simple, hard-coded uart transmitter.
//
// Inputs:
// * clk: clock that runs much faster than the UART bitrate
// * rst: synchronous reset for the detector
// * sample_trigger: 1-clk pulse that tells the UART when to update samples.
// * data: byte to be transmitted
// * start: start transmitting the data byte
//
// Outputs:
// * serial_data: transmitted bits
// * ready: the transmitter is idle and ready to transmit another byte
//
// When the start signal is asserted, the data byte is copied to an internal
// buffer and is then gradually clocked out of the serial_data port. The data
// is transmitted in 8N1 format (8 data bits, no parity, 1 stop bit) with 16
// samples per bit. A start bit and a stop bit are appended to the byte being
// transferred. The idle state of the serial_data output is logic 1 (mark).
// The bits are sent starting with the least-significant bit.

`timescale 1ns/1ps

module uart_tx (
  input logic clk,
  input logic rst,
  input logic sample_trigger,
  input logic [7:0] data,
  input logic start,

  output logic serial_data,
  output logic ready
);
  logic [9:0] buffer;
  logic [7:0] num_samples_remaining;
  logic [7:0] data_reversed;

  localparam logic StartBit = 1'b0;
  localparam logic StopBit = 1'b1;
  localparam logic [4:0] SamplesPerBit = 5'd16;

  // Use the streaming operator to reverse the order of the data bits.
  assign data_reversed = {<<bit{data[7:0]}};

  always @(posedge clk) begin
    if (rst) begin
      serial_data <= 1'b1;
      ready <= 1'b0;
      buffer <= {StartBit, data_reversed, StopBit};
      num_samples_remaining <= 8'b0;
    end else begin
      // Only accept a new byte to transmit if we're not busy.
      if (start && ready) begin
        buffer <= {StartBit, data_reversed, StopBit};
        num_samples_remaining <= SamplesPerBit * $size(buffer);
        ready <= 1'b0;
      end else if (num_samples_remaining > 0) begin
        ready <= 1'b0;
      end else begin
        ready <= 1'b1;
      end

      if (sample_trigger && num_samples_remaining > 0) begin
        serial_data <= buffer[((num_samples_remaining - 1) / SamplesPerBit)];
        num_samples_remaining <= num_samples_remaining - 1;
      end

      if (num_samples_remaining == 0) begin
        serial_data <= 1'b1;
      end
    end
  end
endmodule
