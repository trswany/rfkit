//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// fir_rrc_tb is a testbench to verify an rrc implementation of this fir.
// This is a specific implementation that will be used in a design.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module fir_rrc_tb();
  logic clk = 1'b0;
  logic rst = 1'b0;
  logic [11:0] in = 12'b0000_0000_0000;
  logic [11:0] out;
  fir #(
    .InputLengthBits(12),
    .CoefficientLengthBits(14),
    .AccumulatorLengthBits(27),
    .NumTaps(21),
    .OutputTruncationBits(14),
    .Coefficients({
      -14'd61, +14'd63, +14'd173, +14'd63, -14'd307, -14'd642, -14'd434,
      +14'd642, +14'd2371, +14'd3994, +14'd4658, +14'd3994, +14'd2371, +14'd642,
      -14'd434, -14'd642, -14'd307, +14'd63, +14'd173, +14'd63, -14'd61
    })
  ) dut(
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
      in = 12'b1010_1010_1010;
      repeat (500) begin
        `CHECK_EQUAL(out, 12'b0)
        #10;
      end
    end // end of test case

    `TEST_CASE("produces_zeroes_for_zero_input") begin
      in <= 12'b0;
      repeat (500) begin
        `CHECK_EQUAL(out, 12'b0)
        #10;
      end
    end // end of test case

    `TEST_CASE("produces_correct_impulse_response") begin
      localparam logic signed [11:0] expected_response[21] = {
        -12'd8, 12'd7, 12'd21, 12'd7, -12'd39, -12'd81, -12'd55,
        12'd80, 12'd296, 12'd499, 12'd581, 12'd499, 12'd296, 12'd80,
        -12'd55, -12'd81, -12'd39, 12'd7, 12'd21, 12'd7, -12'd8
      };
      in <= 12'b0111_1111_1111;
      #10;
      in <= 12'b0;
      #10;
      foreach (expected_response[i]) begin
        `CHECK_EQUAL(out, expected_response[i])
        #10;
      end
    end // end of test case

    `TEST_CASE("produces_correct_dc_gain") begin
      in <= 12'b0111_1111_1111;

      // Give the filter more than enough time to fully ramp up.
      repeat (50) begin
        #10;
      end

      repeat (50) begin
        #10;
        `CHECK_EQUAL(out, 12'd2046)
      end
    end // end of test case
  end

  `WATCHDOG(100us);
endmodule
