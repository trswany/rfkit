//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// clock_divider_tb is a testbench to verify the clock_divider.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module clock_divider_tb();
  logic rst = 1'b0;
  logic clk_in = 1'b0;
  logic clk_out_2;
  logic clk_out_16;

  clock_divider #(.DIVISOR(2)) dut_2(
    .clk_out(clk_out_2),
    .rst(rst),
    .clk_in(clk_in)
  );

  clock_divider #(.DIVISOR(16)) dut_16(
    .clk_out(clk_out_16),
    .rst(rst),
    .clk_in(clk_in)
  );

  always begin
    #5;
    clk_in <= !clk_in;
  end

  `TEST_SUITE begin
    `TEST_SUITE_SETUP begin
      rst <= 1'b1;
      #10;
      rst <= 1'b0;
    end

    `TEST_CASE("divides_clock_by_2") begin
      repeat (10) begin
        `CHECK_EQUAL(clk_out_2, 1'b0);
        #10;
        `CHECK_EQUAL(clk_out_2, 1'b1);
        #10;
      end
    end // end of test case

    `TEST_CASE("divides_clock_by_16") begin
      repeat (10) begin
        repeat(8) begin
          `CHECK_EQUAL(clk_out_16, 1'b0);
          #10;
        end
          repeat(8) begin
          `CHECK_EQUAL(clk_out_16, 1'b1);
          #10;
        end
      end
    end // end of test case
  end

  `WATCHDOG(5000ns);
endmodule
