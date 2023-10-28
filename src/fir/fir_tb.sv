//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// fir_tb is a testbench to verify the fir.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module fir_tb();
  logic clk = 1'b0;
  logic rst = 1'b0;
  logic signed [7:0] in = 8'b0000_0000;
  logic signed [7:0] out;

  fir dut(
    .clk(clk),
    .rst(rst),
    .in(in),
    .out(out)
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
      in = 8'b1010_1010;
      repeat (500) begin
        `CHECK_EQUAL(out, 8'b0)
        #10;
      end
    end // end of test case

    `TEST_CASE("produces_zeroes_for_zero_input") begin
      in <= 8'b0;
      repeat (500) begin
        `CHECK_EQUAL(out, 8'b0)
        #10;
      end
    end // end of test case

    `TEST_CASE("produces_correct_impulse_response") begin
      localparam logic signed [7:0] expected_response[3] = {
        -8'd38, 8'd63, 8'd37
      };
      in <= 8'b0111_1111;
      #10;
      in <= 8'b0;
      #10;
      foreach (expected_response[i]) begin
        `CHECK_EQUAL(out, expected_response[i])
        #10;
      end
    end // end of test case

    `TEST_CASE("produces_correct_dc_gain") begin
      in <= 8'b0111_1111;

      // Give the filter more than enough time to fully ramp up.
      repeat (50) begin
        #10;
      end

      repeat (50) begin
        #10;
        `CHECK_EQUAL(out, 8'd63)
      end
    end // end of test case

    `TEST_CASE("saturates_output_on_positive_overflow") begin
      `CHECK_EQUAL(out, 8'd0)
      in <= 8'd127;
      #10;
      `CHECK_EQUAL(out, 8'd0)
      in <= 8'd127;
      #10;
      `CHECK_EQUAL(out, -8'd38)
      in <= -8'd128;
      #10;
      `CHECK_EQUAL(out, 8'd26)
      in <= 8'd0;
      #10;
      // The output should be 138, but that saturates.
      `CHECK_EQUAL(out, 8'd127)
      #10
      `CHECK_EQUAL(out, -8'd27)
    end // end of test case

    `TEST_CASE("saturates_output_on_negative_overflow") begin
      `CHECK_EQUAL(out, 8'd0)
      in <= -8'd128;
      #10;
      `CHECK_EQUAL(out, 8'd0)
      in <= -8'd128;
      #10;
      `CHECK_EQUAL(out, 8'd37)
      in <= 8'd127;
      #10;
      `CHECK_EQUAL(out, -8'd27)
      in <= 8'd0;
      #10;
      // The output should be -139, but that saturates.
      `CHECK_EQUAL(out, -8'd128)
      #10
      `CHECK_EQUAL(out, 8'd25)
    end // end of test case
  end

  `WATCHDOG(100us);
endmodule
