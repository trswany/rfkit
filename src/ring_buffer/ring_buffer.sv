//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// ring_buffer is an efficient FIFO memory manager for block-RAM storage.
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
// Some notes about signals in this implementation:
// head: points to the next bram address to write to.
// tail: points to the next bram address to read from.
// tail_d: the address that was read from during the last clk edge.
// buffer_empty: will the buffer be empty as of the next clk edge?
// buffer_empty_d: was the buffer empty as of the last clk edge?
// put: user wants data to be written on the next clk edge.
// get: user wants data to be pulled and presented on next clk edge.
// get_d: user requested a get on the last clk edge.
// bram is written only if the buffer will have room on the next edge.
// tail is only advanced if the bram was not empty on the last edge.

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
  output logic buffer_empty,
  output logic buffer_100p_full
);
  localparam int AddressWidthBits = $clog2(NumWords);
  logic [AddressWidthBits-1:0] head, tail, tail_d;

  logic bram_write_enable;
  logic last_action_included_put;
  logic buffer_empty_d;
  logic get_d;

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
      buffer_empty_d <= 1'b1;
      get_d <= 1'b0;
    end else begin
      tail_d <= tail;
      buffer_empty_d <= buffer_empty;
      get_d <= get;

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
    if (get_d && !buffer_empty_d) begin
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
