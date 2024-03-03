//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2024 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// gain_bit_shift_tb is a testbench to verify gain_bit_shift.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module gain_bit_shift_tb();
  logic clk = 1'b0;
  logic rst = 1'b0;
  logic signed [11:0] in = 12'b0000_0000_0000;
  logic in_valid = 1'b0;
  logic signed [11:0] out;
  logic out_ready = 1'b0;
  logic out_valid;

  gain_bit_shift #(
    .WordLengthBits(12),
    .GainBits(2)
  ) dut(
    .clk(clk),
    .rst(rst),
    .in(in),
    .in_valid(in_valid),
    .out(out),
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
      in = 12'b1010_1010_1010;
      in_valid = 1'b1;
      out_ready = 1'b0;
      repeat (1000) begin
        `CHECK_EQUAL(out, 12'b0)
        `CHECK_EQUAL(out_valid, 1'b0)
        #10;
      end
    end // end of test case

    `TEST_CASE("produces_zeroes_for_zero_input") begin
      in = 12'b0;
      in_valid = 1'b1;
      repeat (1000) begin
        `CHECK_EQUAL(out, 12'b0)
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

    `TEST_CASE("multiplies_zero") begin
      in_valid = 1'b1;
      out_ready = 1'b1;
      in = 12'd0;
      repeat (100) begin
        `CHECK_EQUAL(out, 12'd0)
        #10;
      end
    end // end of test case

    `TEST_CASE("multiplies_positive_numbers") begin
      in_valid = 1'b1;
      out_ready = 1'b1;
      `CHECK_EQUAL(out, 12'd0)
      in = 12'd15;
      #10;
      `CHECK_EQUAL(out, 12'd60)
      in = 12'd511;
      #10;
      repeat (100) begin
        `CHECK_EQUAL(out, 12'd2044)
        #10;
      end
    end // end of test case

    `TEST_CASE("multiplies_negative_numbers") begin
      in_valid = 1'b1;
      out_ready = 1'b1;
      `CHECK_EQUAL(out, 12'd0)
      in = -12'd12;
      #10;
      `CHECK_EQUAL(out, -12'd48)
      in = -12'd511;
      #10;
      repeat (100) begin
        `CHECK_EQUAL(out, -12'd2044)
        #10;
      end
    end // end of test case

    `TEST_CASE("saturates_on_positive_overflow") begin
      in_valid = 1'b1;
      out_ready = 1'b1;
      in = 12'd512;
      `CHECK_EQUAL(out, 12'd0)
      #10;
      repeat (100) begin
        `CHECK_EQUAL(out, 12'd2047)
        #10;
      end
    end // end of test case

    `TEST_CASE("saturates_on_negative_overflow") begin
      in_valid = 1'b1;
      out_ready = 1'b1;
      in = -12'd513;
      `CHECK_EQUAL(out, 12'd0)
      #10;
      repeat (100) begin
        `CHECK_EQUAL(out, -12'd2048)
        #10;
      end
    end // end of test case
  end

  `WATCHDOG(100ms);
endmodule
