//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// start_bit_detector_tb is a testbench to verify the start_bit_detector.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module start_bit_detector_tb();
  logic clk = 1'b0;
  logic rst = 1'b0;
  logic data = 1'b1;
  logic start_bit_detected;
  start_bit_detector dut(
    .start_bit_detected(start_bit_detected),
    .clk(clk),
    .rst(rst),
    .data(data)
  );

  always begin
    #5;
    clk <= !clk;
  end

  `TEST_SUITE begin
    `TEST_SUITE_SETUP begin
      // Reset the DUT and set the data signal to the idle state.
      data <= 1'b1;
      rst <= 1'b1;
      #10;
      rst <= 1'b0;
      #10;
    end

    `TEST_CASE("stays_in_reset") begin
      rst <= 1'b1;  // Keep the rst signal asserted.
      repeat (20) begin
        #10
        `CHECK_EQUAL(start_bit_detected, 1'b0, "expected low start_bit_detected");
      end
      data <= 1'b0;
      repeat (20) begin
        #10
        `CHECK_EQUAL(start_bit_detected, 1'b0, "expected low start_bit_detected");
      end
    end // end of test case

    `TEST_CASE("detects_short_start_bit") begin
      data <= 1'b0;  // begin applying the start bit
      repeat (4) begin
        #10
        `CHECK_EQUAL(start_bit_detected, 1'b0, "expected low start_bit_detected");
      end
      data <= 1'b1;  // stop applying the start bit
      repeat (4) begin
        #10
        `CHECK_EQUAL(start_bit_detected, 1'b0, "expected low start_bit_detected");
      end
      // start_bit_detected should go high 9 clks after the starting edge.
      repeat (20) begin
        #10
        `CHECK_EQUAL(start_bit_detected, 1'b1, "expected high start_bit_detected");
      end
    end

    `TEST_CASE("detects_long_start_bit") begin
      `CHECK_EQUAL(start_bit_detected, 1'b0, "expected low start_bit_detected");
      data <= 1'b0;  // begin applying the start bit
      `CHECK_EQUAL(start_bit_detected, 1'b0, "expected low start_bit_detected");
      repeat (8) begin
        #10
        `CHECK_EQUAL(start_bit_detected, 1'b0, "expected low start_bit_detected");
      end
      repeat (50) begin
        #10
        `CHECK_EQUAL(start_bit_detected, 1'b1, "expected high start_bit_detected");
      end
      data <= 1'b1;  // stop applying the start bit
      repeat (50) begin
        #10
        `CHECK_EQUAL(start_bit_detected, 1'b1, "expected high start_bit_detected");
      end
    end

    `TEST_CASE("rejects_spurious_pulse") begin
      data <= 1'b0;
      `CHECK_EQUAL(start_bit_detected, 1'b0, "expected low start_bit_detected");
      // the DUT should reject spurious blips up to 4 clk periods long.
      repeat (3) begin
        #10
        `CHECK_EQUAL(start_bit_detected, 1'b0, "expected low start_bit_detected");
      end
      data <= 1'b1;
      repeat (20) begin
        #10
        `CHECK_EQUAL(start_bit_detected, 1'b0, "expected low start_bit_detected");
      end
    end // end of test case

    `TEST_CASE("detects_start_after_spurious_pulse") begin
      // Apply a spurious pulse.
      data <= 1'b0;
      #30;
      data <= 1'b1;
      repeat (10) begin
        #10
        `CHECK_EQUAL(start_bit_detected, 1'b0, "expected low start_bit_detected");
      end

      // Apply a real start pulse.
      data <= 1'b0;
      #40;
      data <= 1'b1;
      repeat (4) begin
        #10
        `CHECK_EQUAL(start_bit_detected, 1'b0, "expected low start_bit_detected");
      end
      repeat (20) begin
        #10
        `CHECK_EQUAL(start_bit_detected, 1'b1, "expected high start_bit_detected");
      end
    end // end of test case
  end

  `WATCHDOG(2000ns);
endmodule

