//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// bram_dual_port_tb is a testbench to verify bram_dual_port.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module bram_dual_port_tb();
  logic clk = 1'b0;
  logic [6:0] address_in = 7'b0000_0000;
  logic [6:0] address_out = 7'b0000_0000;
  logic write_enable = 1'b0;
  logic [7:0] data_in = 8'b0000_0000;
  logic [7:0] data_out;

  bram_dual_port #(
    .WordLengthBits(8),
    .NumWords(128)
  ) dut(
    .clk(clk),
    .address_in(address_in),
    .address_out(address_out),
    .write_enable(write_enable),
    .data_in(data_in),
    .data_out(data_out)
  );

  always begin
    #5;
    clk <= !clk;
  end

  `TEST_SUITE begin
    `TEST_CASE("data_is_available_after_one_clock_cycle") begin
      #10
      address_in = 7'b000_0000;
      address_out = 7'b000_0000;
      write_enable = 0'b1;
      data_in = 8'b1010_1010;
      #10  // wait one clk for the data to be clocked in.
      write_enable = 0'b0;
      #10  // wait one more clk for data to show up on output.
      `CHECK_EQUAL(data_out, 8'b1010_1010);
    end // end of test case

    `TEST_CASE("read_first_during_collisions") begin
      // Read and write to the same address to generate a read-write collision.
      address_in = 7'b000_0000;
      address_out = 7'b000_0000;
      data_in = 8'b1010_1010;
      write_enable = 0'b1;
      #10  // wait one clk for the data to be clocked in.

      // Change the data.
      data_in = 8'b1111_1111;
      #10  // wait one clk for data to be clocked in.

      // Verify that the old byte is still presented on the output.
      `CHECK_EQUAL(data_out, 8'b1010_1010);

      // After one more clock we should get the latest data.
      #10
      `CHECK_EQUAL(data_out, 8'b1111_1111);
    end // end of test case

    `TEST_CASE("data_is_stored") begin
      address_in = 7'h1;
      write_enable = 0'b1;
      data_in = 8'b0000_0001;
      #10  // address 1 gets loaded during this clk.
      address_in = 7'h2;
      data_in = 8'b0000_0010;
      #10  // address 2 gets loaded during this clk.

      data_in = 8'b1111_1111;
      write_enable = 0'b0;

      address_out = 7'h1;
      #10
      `CHECK_EQUAL(data_out, 8'b0000_0001);

      address_out = 7'h2;
      #10
      `CHECK_EQUAL(data_out, 8'b0000_0010);
    end // end of test case

    `TEST_CASE("top_address_works") begin
      address_in = 7'd0;
      write_enable = 0'b1;
      data_in = 8'b0000_0001;
      #10  // address 0 gets loaded during this clk.
      address_in = 7'd127;
      data_in = 8'b0000_0010;
      #10  // address 127 gets loaded during this clk.

      data_in = 8'b1111_1111;
      write_enable = 0'b0;

      address_out = 7'd0;
      #10
      `CHECK_EQUAL(data_out, 8'b0000_0001);

      address_out = 7'd127;
      #10
      `CHECK_EQUAL(data_out, 8'b0000_0010);
    end // end of test case

    `TEST_CASE("read_while_writing_different_addresses") begin
      address_in = 7'd0;
      write_enable = 0'b1;
      data_in = 8'b0000_0001;
      #10  // address 0 gets loaded during this clk.

      address_out = 7'd0;
      address_in = 7'd1;
      data_in = 8'b0000_0010;
      #10
      write_enable = 0'b0;

      `CHECK_EQUAL(data_out, 8'b0000_0001);
      address_out = 7'd1;
      #10
      `CHECK_EQUAL(data_out, 8'b0000_0010);
    end // end of test case
  end

  `WATCHDOG(5000ns);
endmodule

