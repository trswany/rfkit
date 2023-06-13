//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// ring_buffer is an efficient FIFO memory manager for block-RAM storage.
//
// Inputs:
// * clk: clock
// * rst: synchronous reset for the detector
// * put: request for data to be written into buffer on next clk edge
// * get: request for data to be pulled and presented on next clk edge
// * data_in: word to be written to buffer
//
// Outputs:
// * buffer_empty: buffer is empty
// * buffer_100p_full: buffer is 100-percent full
// * data_out_valid: get was requested and data_out now has a valid word
// * data_out: word that was pulled from buffer on the last clk edge
//
// To write (put) data:
// Apply data to data_in and assert "put." If buffer_100p_full is low, data
// will be clocked into the buffer on the next clk cycle. If buffer_100p_full
// is high, no write is performed.
//
// To read (get) data:
// Assert the get signal. If buffer_empty is low, the next available word will
// be removed from the buffer on the next clk cycle and presented on data_out.
// If buffer_empty is high, the data presented on the next clk cycle is
// undefined and should be ignored.
//
// Some notes about internal signals in this implementation:
// head: points to the next bram address to write to.
// tail: points to the next bram address to read from.
// tail_d: the address that was read from during the last clk edge.
// buffer_empty: will the buffer be empty as of the next clk edge?
// put: user wants data to be written on the next clk edge.
// get: user wants data to be pulled and presented on next clk edge.
// data_out_valid: we actually pulled and presented a word on the last edge.
// bram is written only if the buffer will have room on the next edge.
// tail is only advanced if we did a get on the last edge.

`timescale 1ns/1ps

module ring_buffer #(
  parameter int WordLengthBits = 8,
  parameter int NumWords = 128
) (
  input logic clk,
  input logic rst,
  input logic put,
  input logic [WordLengthBits-1:0] data_in,
  input logic get,
  output logic [WordLengthBits-1:0] data_out,
  output logic data_out_valid,
  output logic buffer_empty,
  output logic buffer_100p_full
);
  localparam int AddressWidthBits = $clog2(NumWords);
  logic [AddressWidthBits-1:0] head, tail, tail_d;

  logic bram_write_enable;
  logic last_action_included_put;

  bram_dual_port #(
    .WordLengthBits(WordLengthBits),
    .NumWords(NumWords),
    .AddressWidthBits(AddressWidthBits)
  ) bram_dual_port(
    .clk(clk),
    .address_in(head),
    .address_out(tail),
    .write_enable(bram_write_enable),
    .data_in(data_in),
    .data_out(data_out)
  );

  always @(posedge clk) begin
    if (rst) begin
      head <= '0;
      tail_d <= '0;
      last_action_included_put <= 1'b0;
      data_out_valid <= 1'b0;
    end else begin
      tail_d <= tail;

      if (get && !buffer_empty) begin
        data_out_valid <= 1'b1;
      end else begin
        data_out_valid <= 1'b0;
      end

      // head: increment after bram writes.
      if (bram_write_enable) begin
        if (head == NumWords) begin
          head <= '0;
        end else begin
          head <= head + 1;
        end
      end

      // last_action_included_put: in order to remember if the buffer has data
      // in it, we are going to remmeber if the last "action" included a put.
      if (bram_write_enable) begin
        last_action_included_put <= 1'b1;
      end else if (get && !buffer_empty) begin
        last_action_included_put <= 1'b0;
      end
    end
  end

  always_comb begin
    // tail: we are implementing the tail signal in combinatorial logic in
    // order avoid a one-cycle latency in reads. If we did this in the
    // sequential block, we would need one cycle to update tail and then one
    // cycle for the bram to execute the read. Only advance the tail pointer if
    // we actually did a get on the last clk edge.
    tail = tail_d;
    if (data_out_valid) begin
      if (tail_d == NumWords) begin
        tail = '0;
      end else begin
        tail = tail_d + 1;
      end
    end

    // buffer_empty, buffer_100p_full
    buffer_empty = 1'b0;
    buffer_100p_full = 1'b0;
    if (head == tail) begin
      if (last_action_included_put) begin
        buffer_100p_full = 1'b1;
      end else begin
        buffer_empty = 1'b1;
      end
    end

    // bram_write_enable
    if (put && !buffer_100p_full) begin
      bram_write_enable = 1'b1;
    end else begin
      bram_write_enable = 1'b0;
    end
  end
endmodule
