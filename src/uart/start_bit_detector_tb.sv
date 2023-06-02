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
  wire sample_trigger;

  start_bit_detector dut(
    .start_bit_detected(start_bit_detected),
    .clk(clk),
    .rst(rst),
    .sample_trigger(sample_trigger),
    .data(data)
  );

  always begin
    #5;
    clk <= !clk;
  end

  pulse_generator #(.INTERVAL(10)) pulse_generator(
    .out(sample_trigger),
    .rst(rst),
    .clk(clk)
  );

  `TEST_SUITE begin
    `TEST_SUITE_SETUP begin
      // Reset the DUT and set the data signal to the idle state.
      data <= 1'b1;
      rst <= 1'b1;
      @(posedge clk);
      rst <= 1'b0;
      @(posedge clk);
    end

    `TEST_CASE("stays_in_reset") begin
      rst <= 1'b1;  // Keep the rst signal asserted.
      repeat (200) begin
        @(posedge clk)
        `CHECK_EQUAL(start_bit_detected, 1'b0);
      end
      data <= 1'b0;
      repeat (200) begin
        @(posedge clk)
        `CHECK_EQUAL(start_bit_detected, 1'b0);
      end
    end // end of test case

    `TEST_CASE("detects_short_start_bit") begin
      int num_samples;
      @(posedge sample_trigger);

      // Apply the stop bit for 4 sample clocks.
      data <= 1'b0;
      num_samples = 0;
      while (num_samples < 4) begin
        @(posedge clk)
        if (sample_trigger) begin
          num_samples++;
        end
        `CHECK_EQUAL(start_bit_detected, 1'b0);
      end

      // Stop applying the stop bit and wait another 4 sample clocks.
      @(posedge clk)
      data <= 1'b1;
      num_samples = 0;
      while (num_samples < 4) begin
        @(posedge clk)
        if (sample_trigger) begin
          num_samples++;
        end
        `CHECK_EQUAL(start_bit_detected, 1'b0);
      end

      // After one more clock cycle, start_bit_detected should be asserted.
      @(posedge clk)
      repeat (500) begin
        @(posedge clk)
        `CHECK_EQUAL(start_bit_detected, 1'b1);
      end
    end

    `TEST_CASE("detects_long_start_bit") begin
      int num_samples;
      @(posedge sample_trigger);

      // Apply the stop bit for 8 sample clocks.
      data <= 1'b0;
      num_samples = 0;
      while (num_samples < 8) begin
        @(posedge clk)
        if (sample_trigger) begin
          num_samples++;
        end
        `CHECK_EQUAL(start_bit_detected, 1'b0);
      end

      // After one more clock cycle, start_bit_detected should be asserted.
      @(posedge clk)
      repeat (500) begin
        @(posedge clk)
        `CHECK_EQUAL(start_bit_detected, 1'b1);
      end
    end

    `TEST_CASE("rejects_spurious_pulse") begin
      int num_samples;
      @(posedge sample_trigger);

      // the DUT should reject spurious blips <= 3 clk periods long.
      data <= 1'b0;
      num_samples = 0;
      while (num_samples < 3) begin
        @(posedge clk)
        if (sample_trigger) begin
          num_samples++;
        end
        `CHECK_EQUAL(start_bit_detected, 1'b0);
      end
      data <= 1'b1;
      repeat (500) begin
        @(posedge clk)
        `CHECK_EQUAL(start_bit_detected, 1'b0);
      end
    end // end of test case

    `TEST_CASE("detects_start_after_spurious_pulse") begin
      int num_samples;
      @(posedge sample_trigger);

      // Apply a spurious pulse.
      data <= 1'b0;
      num_samples = 0;
      while (num_samples < 3) begin
        @(posedge clk)
        if (sample_trigger) begin
          num_samples++;
        end
        `CHECK_EQUAL(start_bit_detected, 1'b0);
      end
      data <= 1'b1;
      num_samples = 0;
      while (num_samples < 10) begin
        @(posedge clk)
        if (sample_trigger) begin
          num_samples++;
        end
        `CHECK_EQUAL(start_bit_detected, 1'b0);
      end

      // Apply a real start pulse for 8 sample times.
      @(posedge clk)
      data <= 1'b0;
      num_samples = 0;
      while (num_samples < 8) begin
        @(posedge clk)
        if (sample_trigger) begin
          num_samples++;
        end
        `CHECK_EQUAL(start_bit_detected, 1'b0);
      end

      // After one more clock cycle, start_bit_detected should be asserted.
      @(posedge clk)
      repeat (500) begin
        @(posedge clk)
        `CHECK_EQUAL(start_bit_detected, 1'b1);
      end
    end // end of test case
  end

  `WATCHDOG(20000ns);
endmodule

