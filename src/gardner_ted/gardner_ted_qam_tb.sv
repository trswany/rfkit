//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// gardner_ted_qam_tb is a testbench to verify gardner_ted_qam.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module gardner_ted_qam_tb();
  logic clk = 1'b0;
  logic rst = 1'b0;
  logic signed [11:0] in_i = 12'b0000_0000_0000;
  logic signed [11:0] in_q = 12'b0000_0000_0000;
  logic in_valid_i = 1'b0;
  logic in_valid_q = 1'b0;
  logic trigger = 1'b0;
  logic signed [25:0] out;
  logic out_ready = 1'b0;
  logic out_valid;

  gardner_ted_qam #(
    .SamplesPerSymbol(4),
    .InputLengthBits(12),
    .OutputLengthBits(26)
  ) dut(
    .clk(clk),
    .rst(rst),
    .in_i(in_i),
    .in_q(in_q),
    .in_valid_i(in_valid_i),
    .in_valid_q(in_valid_q),
    .trigger(trigger),
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
      in_i = 12'b1010_1010_1010;
      in_valid_i = 1'b1;
      out_ready = 1'b0;
      repeat (1000) begin
        `CHECK_EQUAL(out, '0)
        `CHECK_EQUAL(out_valid, 1'b0)
        #10;
      end
    end // end of test case

    `TEST_CASE("produces_zeroes_for_zero_input") begin
      in_i = 12'b0;
      in_valid_i = 1'b1;
      repeat (1000) begin
        `CHECK_EQUAL(out, '0)
        #10;
      end
    end // end of test case

    `TEST_CASE("respects_in_valid") begin
      in_i = 12'b1010_1010_1010;
      in_valid_i = 1'b0;
      out_ready = 1'b1;
      repeat (1000) begin
        `CHECK_EQUAL(out, '0)
        `CHECK_EQUAL(out_valid, 1'b0)
        #10;
      end
      in_i = 12'b0;
      in_valid_i = 1'b1;
      #10;
      repeat (1000) begin
        `CHECK_EQUAL(out, '0)
        `CHECK_EQUAL(out_valid, 1'b1)
        #10;
      end
      in_i = 12'b1010_1010_1010;
      in_valid_i = 1'b0;
      #10;
      repeat (1000) begin
        `CHECK_EQUAL(out, '0)
        `CHECK_EQUAL(out_valid, 1'b0)
        #10;
      end
    end // end of test case

    `TEST_CASE("out_valid_does_handshake") begin
      in_valid_i = 1'b0;
      out_ready = 1'b0;
      repeat (100) begin
        `CHECK_EQUAL(out_valid, 1'b0)
        #10;
      end
      in_valid_i = 1'b1;
      #10;
      in_valid_i = 1'b0;
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

    `TEST_CASE("paths_are_independent") begin
      in_i = 12'd0;
      in_q = 12'd200;
      in_valid_i = 1'b1;
      in_valid_q = 1'b1;
      out_ready = 1'b1;
      trigger = 1'b1;
      repeat (10) begin
        // Warm up the pipelines.
        in_i = in_i + 1;
        in_q = in_q + 1;
        #10;
      end
      repeat (1000) begin
        `CHECK_EQUAL(out, ((in_i-4)-(in_i))*(in_i-2) + ((in_q-4)-(in_q))*(in_q-2))
        in_i = in_i + 1;
        in_q = in_q + 1;
        #10;
      end
    end // end of test case

    `TEST_CASE("only_updates_when_triggered") begin
      in_i = 12'd0;
      in_q = 12'd0;
      in_valid_i = 1'b1;
      in_valid_q = 1'b1;
      out_ready = 1'b1;
      trigger = 1'b0;
      #10;
      repeat (50) begin
        in_i = in_i + 1;
        in_q = in_i;
        `CHECK_EQUAL(out, '0)
        `CHECK_EQUAL(out_valid, 1'b1)
        #10;
      end
      trigger = 1'b1;
      in_i = in_i + 1;
      in_q = in_i;
      #10;
      repeat (1000) begin
        `CHECK_EQUAL(out, 2*((in_i-4)-(in_i))*(in_i-2))
        `CHECK_EQUAL(out_valid, 1'b1)
        in_i = in_i + 1;
        in_q = in_i;
        #10;
      end
      trigger = 1'b0;
      #10;
      repeat (1000) begin
        `CHECK_EQUAL(out, 2*((in_i-4)-(in_i))*(in_i-2))
        `CHECK_EQUAL(out_valid, 1'b1)
        #10;
      end
    end // end of test case

    `TEST_CASE("never_overflows") begin
      // Check the worst-case input pattern to make sure we don't overflow.
      in_valid_i = 1'b1;
      in_valid_q = 1'b1;
      out_ready = 1'b1;
      trigger = 1'b1;
      in_i = -12'd2048;  // Maximum negative 12-bit signed integer
      in_q = in_i;
      #10;
      `CHECK_EQUAL(out, 26'd0)
      #10;
      `CHECK_EQUAL(out, 26'd0)
      #10;
      `CHECK_EQUAL(out, -26'd8388608)
      #10;
      `CHECK_EQUAL(out, -26'd8388608)
      #10;
      `CHECK_EQUAL(out, -26'd0)
      in_i = 12'd2047;  // Maximum positive 12-bit signed integer
      in_q = in_i;
      #10;
      `CHECK_EQUAL(out, 26'd16773120)
    end // end of test case
  end

  `WATCHDOG(100ms);
endmodule
