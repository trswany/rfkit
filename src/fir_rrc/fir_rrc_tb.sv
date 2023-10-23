//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// fir_rrc_tb is a testbench to verify the fir_rrc.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module fir_rrc_tb();
  logic clk = 1'b0;
  logic rst = 1'b0;
  logic [11:0] in = 12'b0000_0000_0000;
  logic [11:0] out;

  fir_rrc dut(
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
        -12'd11, 12'd11, 12'd30, 12'd11, -12'd55, -12'd114, -12'd77,
        12'd113, -12'd2, 12'd703, 12'd820, 12'd703, -12'd2, 12'd113,
        -12'd77, -12'd114, -12'd55, 12'd11, 12'd30, 12'd11, -12'd11
      };
      in <= 12'b0111_1111_1111;
      #10;
      in <= 12'b0;
      foreach (expected_response[i]) begin
        `CHECK_EQUAL(out, expected_response[i])
        #10;
      end
      `CHECK_EQUAL(out, 1'd1)
    end // end of test case

    `TEST_CASE("produces_correct_dc_gain") begin
      in <= 12'b0111_1111_1111;

      // Give the filter more than enough time to fully ramp up.
      repeat (50) begin
        #10;
      end

      repeat (50) begin
        #10;
        `CHECK_EQUAL(out, 12'd2047)
      end
    end // end of test case
  end

  `WATCHDOG(100us);
endmodule

