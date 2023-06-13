//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// bram_dual_port is dual-port, synchronous block ram.
//
// This implementation has read-first behavior in the case of a read-write
// collision. This means that if address_in == address_out, data_out will get
// the previously-stored value from that memory location instead of the
// value of data_in.
//
// Note that this module intentionally leaves out any kind of reset. There is
// no guarantees about the state of the block ram before it is written.

`timescale 1ns/1ps

module bram_dual_port #(
  parameter int WordLengthBits = 8,
  parameter int NumWords = 128,
  parameter int AddressWidthBits = 7
) (
  input logic clk,
  input logic [AddressWidthBits-1:0] address_in,
  input logic [AddressWidthBits-1:0] address_out,
  input logic write_enable,
  input logic [WordLengthBits-1:0] data_in,
  output logic [WordLengthBits-1:0] data_out
);
  logic [WordLengthBits-1:0] ram [NumWords];

  initial begin
    if (AddressWidthBits < $clog2(NumWords)) begin
      $error("AddressWidthBits is not big enough to address the full bram.");
    end
  end

  always @(posedge clk) begin
    if (write_enable) begin
      ram[address_in] <= data_in;
    end
    data_out <= ram[address_out];
  end
endmodule
