//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// compensator_tb is a testbench to verify compensator.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module compensator_tb();
  logic clk = 1'b0;
  logic rst = 1'b0;
  logic signed [11:0] in = 12'b0000_0000_0000;
  logic in_valid = 1'b0;
  logic signed [16:0] out, out_order1;
  logic out_ready = 1'b0;
  logic out_valid, out_valid_order1;

  compensator #(
    .InputLengthBits(12),
    .OutputLengthBits(17),
    .FilterOrder(3)
  ) dut(
    .clk(clk),
    .rst(rst),
    .in(in),
    .in_valid(in_valid),
    .out(out),
    .out_valid(out_valid),
    .out_ready(out_ready)
  );

  compensator #(
    .InputLengthBits(12),
    .OutputLengthBits(17),
    .FilterOrder(1)
  ) dut_order1(
    .clk(clk),
    .rst(rst),
    .in(in),
    .in_valid(in_valid),
    .out(out_order1),
    .out_valid(out_valid_order1),
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
      in = 12'b1010_1010_1010;
      in_valid = 1'b1;
      out_ready = 1'b0;
      repeat (1000) begin
        `CHECK_EQUAL(out, 17'b0)
        `CHECK_EQUAL(out_valid, 1'b0)
        #10;
      end
    end // end of test case

    `TEST_CASE("produces_zeroes_for_zero_input") begin
      in = 12'b0;
      in_valid = 1'b1;
      repeat (1000) begin
        `CHECK_EQUAL(out, 17'b0)
        #10;
      end
    end // end of test case

    `TEST_CASE("respects_in_valid") begin
      in = 12'b1010_1010_1010;
      in_valid = 1'b0;
      out_ready = 1'b1;
      repeat (1000) begin
        `CHECK_EQUAL(out, '0)
        `CHECK_EQUAL(out_valid, 1'b0)
        #10;
      end
      in = 12'b0;
      in_valid = 1'b1;
      #10;
      repeat (1000) begin
        `CHECK_EQUAL(out, '0)
        `CHECK_EQUAL(out_valid, 1'b1)
        #10;
      end
      in = 12'b1010_1010_1010;
      in_valid = 1'b0;
      #10;
      repeat (1000) begin
        `CHECK_EQUAL(out, '0)
        `CHECK_EQUAL(out_valid, 1'b0)
        #10;
      end
    end // end of test case

    `TEST_CASE("out_valid_does_handshake") begin
      in_valid = 1'b0;
      out_ready = 1'b0;
      repeat (100) begin
        `CHECK_EQUAL(out_valid, 1'b0)
        #10;
      end
      in_valid = 1'b1;
      #10;
      in_valid = 1'b0;
      #10;
      repeat (100) begin
        `CHECK_EQUAL(out_valid, 1'b1)
        #10;
      end
      out_ready = 1'b1;
      #10;
      out_ready = 1'b0;
      repeat (100) begin
        `CHECK_EQUAL(out_valid, 1'b0)
        #10;
      end
    end // end of test case

    `TEST_CASE("produces_correct_impulse_response") begin
      in_valid = 1'b1;
      out_ready = 1'b1;
      in = 12'd2047;  // Maximum positive 12-bit signed integer
      #10;
      in = 12'd0;
      `CHECK_EQUAL(out, 17'd2047)
      #10;
      `CHECK_EQUAL(out, 17'd0)
      #10;
      `CHECK_EQUAL(out, 17'd0)
      #10;
      `CHECK_EQUAL(out, -17'd20470)
      #10;
      `CHECK_EQUAL(out, 17'd0)
      #10;
      `CHECK_EQUAL(out, 17'd0)
      #10;
      `CHECK_EQUAL(out, 17'd2047)
      #10;
      repeat (100) begin
        `CHECK_EQUAL(out, 17'd0)
        #10;
      end
    end // end of test case

    `TEST_CASE("produces_correct_step_response") begin
      in_valid = 1'b1;
      out_ready = 1'b1;
      in = 12'd2047;  // Maximum positive 12-bit signed integer
      #10;
      `CHECK_EQUAL(out, 17'd2047)
      #10;
      `CHECK_EQUAL(out, 17'd2047)
      #10;
      `CHECK_EQUAL(out, 17'd2047)
      #10;
      `CHECK_EQUAL(out, -17'd18423)
      #10;
      `CHECK_EQUAL(out, -17'd18423)
      #10;
      `CHECK_EQUAL(out, -17'd18423)
      #10;
      repeat (100) begin
        `CHECK_EQUAL(out, -17'd16376)
        #10;
      end
    end // end of test case

    `TEST_CASE("never_overflows") begin
      // repeat the test with maximum gain (lowest filter order) and check
      // the worst-case situation to make sure we don't overflow.
      in_valid = 1'b1;
      out_ready = 1'b1;
      in = 12'd2047;  // Maximum positive 12-bit signed integer
      #10;
      `CHECK_EQUAL(out_order1, 17'd2047)
      in = -12'd2048;  // Maximum negative 12-bit signed integer
      #10;
      `CHECK_EQUAL(out_order1, -17'd38894)  // -2048 + 2047*-18
      in = 12'd2047;  // Maximum positive 12-bit signed integer
      #10;
      `CHECK_EQUAL(out_order1, 17'd40958)  // 2047 + -2048*-18 + 2047
      in = 12'd0;
      #10;
      `CHECK_EQUAL(out_order1, -17'd38894)  // 2047*-18 + -2048
      #10;
      `CHECK_EQUAL(out_order1, 17'd2047)
      #10;
      `CHECK_EQUAL(out_order1, 17'd0)
      #10;
      repeat (100) begin
        `CHECK_EQUAL(out_order1, 17'd0)
        #10;
      end
    end // end of test case
  end

  `WATCHDOG(100ms);
endmodule
