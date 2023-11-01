//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// freqeuncy_locked_loop_tb is a testbench to verify freqeuncy_locked_loop.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module freqeuncy_locked_loop_tb();
  logic clk = 1'b0;
  logic rst = 1'b0;
  logic signed [11:0] in_i = 12'b0000_0000_0000;
  logic signed [11:0] in_q = 12'b0000_0000_0000;
  logic in_valid = 1'b1;
  logic out_ready = 1'b1;
  logic signed [11:0] out;
  logic out_valid;

  frequency_locked_loop dut(
    .clk(clk),
    .rst(rst),
    .in_i(in_i),
    .in_q(in_q),
    .out(out),
    .in_valid(in_valid),
    .out_valid(out_valid),
    .out_ready(out_ready)
  );

  always begin
    #5;
    clk <= !clk;
  end

  `TEST_SUITE begin
    `TEST_SUITE_SETUP begin
      rst <= 1'b1;
      @(posedge clk);
      rst <= 1'b0;
      @(posedge clk);
      #5;  // Get into the middle of a clock cycle.
    end

    `TEST_CASE("stays_in_reset") begin
      rst = 1'b1;  // Keep rst asserted.
      #20;
      in_i = 12'b1010_1010_1010;
      in_q = 12'b0000_1111_0000;
      repeat (1000) begin
        `CHECK_EQUAL(out, 12'b0)
        #10;
      end
    end // end of test case

    `TEST_CASE("produces_zeroes_for_zero_input") begin
      in_i = 12'b0;
      in_q = 12'b0;
      repeat (500) begin
        `CHECK_EQUAL(out, 12'b0)
        #10;
      end
    end // end of test case
  end

  `WATCHDOG(100ms);
endmodule
