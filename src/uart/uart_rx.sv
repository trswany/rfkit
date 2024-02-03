//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// uart_rx is a very simple, statically-configured uart receiver.
//
// Inputs:
// * clk: clock that runs much faster than the UART bitrate.
// * rst: synchronous reset for the detector
// * sample_trigger: 1-clk pulse that tells the uart when to sample
// * raw_data: raw and asynchronous RX data; will be sampled
//
// Outputs:
// * data: received byte
// * data_valid: 1-cycle pulse at the time that a byte is made available

`timescale 1ns/1ps

module uart_rx (
  input logic clk,
  input logic rst,
  input logic sample_trigger,
  input logic raw_data,

  output logic [7:0] data,
  output logic data_valid
);
  logic [9:0] buffer;
  logic rst_start_bit_detector;
  logic estimated_bit;
  logic estimated_bit_ready;

  // Use a "1" bit as a signal for when the buffer is full.
  // This signal bit will get shifted through as bits come in.
  localparam logic [9:0] BufferResetValue = 10'b0_0000_0000_1;

  start_bit_detector start_bit_detector (
    .clk(clk),
    .rst(rst_start_bit_detector),
    .sample_trigger(sample_trigger),
    .raw_data(raw_data),
    .start_bit_detected(start_bit_detected)
  );

  bit_sampler bit_sampler (
    .clk(clk),
    .rst(!start_bit_detected),
    .sample_trigger(sample_trigger),
    .raw_data(raw_data),
    .estimated_bit(estimated_bit),
    .estimate_ready(estimated_bit_ready)
  );

  always @(posedge clk) begin
    if (rst) begin
      rst_start_bit_detector <= 1'b1;
      data_valid <= 1'b0;
      buffer <= BufferResetValue;
    end else begin
      if (data_valid) begin
        // If we just delivered data, reset the buffer.
        buffer <= BufferResetValue;
      end else if (estimated_bit_ready) begin
        // Otherwise, shift bits into our buffer as they come in.
        buffer <= {buffer[8:0], estimated_bit};
      end

      if (buffer[9] == 1'b1) begin
        // If we received a full batch of bits, reset the detector.
        rst_start_bit_detector <= 1'b1;
      end else begin
        rst_start_bit_detector <= 1'b0;
      end

      if (data_valid) begin
        // If we just delivered data, reset the data_valid signal.
        data_valid <= 1'b0;
      end else if (buffer[9] == 1'b1 && buffer[0] == 1'b1) begin
        // If the buffer is full and it's a valid stop bit, deliver the data.
        data_valid <= 1'b1;
      end else begin
        data_valid <= 1'b0;
      end
    end
  end

  // When the buffer is full, the MSBit is a 1, and the LSBit is the stop bit.
  // We want to strip both of those bits out of the final result. Use the
  // streaming operator to reverse the order of the data bits.
  always_comb begin
    data = {<<bit{buffer[8:1]}};
  end
endmodule
