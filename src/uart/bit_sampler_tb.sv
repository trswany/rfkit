//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// bit_sampler_tb is a testbench to verify the bit_sampler.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module bit_sampler_tb();
  logic clk = 1'b0;
  logic rst = 1'b0;
  logic raw_data = 1'b0;
  logic estimated_bit;
  logic estimate_ready;
  wire sample_trigger;

  bit_sampler dut(
    .clk(clk),
    .rst(rst),
    .sample_trigger(sample_trigger),
    .raw_data(raw_data),
    .estimated_bit(estimated_bit),
    .estimate_ready(estimate_ready)
  );

  pulse_generator #(.Period(10)) pulse_generator(
    .clk(clk),
    .rst(rst),
    .pulse(sample_trigger)
  );

  always begin
    #5;
    clk <= !clk;
  end

  `TEST_SUITE begin
    `TEST_SUITE_SETUP begin
      // Reset the DUT and set the incoming data signal to 0.
      rst <= 1'b1;
      raw_data <= 1'b0;
      @(posedge clk);
      rst <= 1'b0;
      @(posedge clk);
    end

    `TEST_CASE("stays_in_reset") begin
      rst <= 1'b1;  // Keep the rst signal asserted.
      repeat (200) begin
        @(posedge clk)
        `CHECK_EQUAL(estimated_bit, 1'b0);
        `CHECK_EQUAL(estimate_ready, 1'b0);
      end
      raw_data <= 1'b1;
      repeat (200) begin
        @(posedge clk)
        `CHECK_EQUAL(estimated_bit, 1'b0);
        `CHECK_EQUAL(estimate_ready, 1'b0);
      end
    end // end of test case

    `TEST_CASE("generates_estimate_ready") begin
      int num_samples;

      // Nothing should happen until we get 18 samples.
      num_samples = 0;
      while (num_samples < 18) begin
        @(posedge clk)
        if (sample_trigger) begin
          num_samples++;
        end
        `CHECK_EQUAL(estimate_ready, 1'b0);
      end

      // After the 18th pulse, we should get a brief blip of the estimate_ready.
      @(posedge clk);
      `CHECK_EQUAL(estimate_ready, 1'b1);

      // estimate_ready should go back to 0 for a total of 16 samples.
      num_samples = 0;
      while (num_samples < 16) begin
        @(posedge clk)
        if (sample_trigger) begin
          num_samples++;
        end
        `CHECK_EQUAL(estimate_ready, 1'b0);
      end

      // After the 16th pulse, we should get a brief blip of the estimate_ready.
      @(posedge clk)
      `CHECK_EQUAL(estimate_ready, 1'b1);

      // And then stay low for 16 more samples.
      num_samples = 0;
      while (num_samples < 16) begin
        @(posedge clk)
        if (sample_trigger) begin
          num_samples++;
        end
        `CHECK_EQUAL(estimate_ready, 1'b0);
      end

      // Check for one more short pulse.
      // After the 16th pulse, we should get a brief blip of the estimate_ready.
      @(posedge clk)
      `CHECK_EQUAL(estimate_ready, 1'b1);
      @(posedge clk)
      `CHECK_EQUAL(estimate_ready, 1'b0);
    end // end of test case

    `TEST_CASE("estimates_zeros") begin
      raw_data <= 1'b0;
      repeat (1500) begin
        @(posedge clk)
        `CHECK_EQUAL(estimated_bit, 1'b0);
      end
    end // end of test case

    `TEST_CASE("estimates_ones") begin
      int num_samples;
      raw_data <= 1'b1;

      // Nothing should happen until we get 18 samples.
      num_samples = 0;
      while (num_samples < 18) begin
        @(posedge clk)
        if (sample_trigger) begin
          num_samples++;
        end
        `CHECK_EQUAL(estimate_ready, 1'b0);
      end

      // After the 18th pulse, estimated_bit should go to 1.
      @(posedge clk);
      `CHECK_EQUAL(estimated_bit, 1'b1);
      repeat (1500) begin
        @(posedge clk)
        `CHECK_EQUAL(estimated_bit, 1'b1);
      end
    end // end of test case

    `TEST_CASE("estimates_one_with_noise") begin
      // Apply 14 pulses of 1.
      raw_data <= 1'b1;
      for (int i = 0; i < 14; i++) begin
        @(posedge sample_trigger);
      end

      // Set raw_data to 0 to simulate noise for 2 samples.
      raw_data <= 1'b0;
      for (int i = 0; i < 2; i++) begin
        @(posedge sample_trigger);
      end

      // Apply 2 pulses of 1.
      raw_data <= 1'b1;
      for (int i = 0; i < 2; i++) begin
        @(posedge sample_trigger);
      end

      // After two more clocks, the data should be available.
      @(posedge clk);
      @(posedge clk);
      `CHECK_EQUAL(estimated_bit, 1'b1);
      `CHECK_EQUAL(estimate_ready, 1'b1);
    end // end of test case

    `TEST_CASE("estimates_multiple_bits") begin
      // Apply 18 bits of 0, verify the result.
      raw_data <= 1'b0;
      for (int i = 0; i < 18; i++) begin
        @(posedge sample_trigger);
      end
      @(posedge clk);
      @(posedge clk);
      `CHECK_EQUAL(estimate_ready, 1'b1);
      `CHECK_EQUAL(estimated_bit, 1'b0);

      // Apply 16 bits of 1, verify the result.
      raw_data <= 1'b1;
      for (int i = 0; i < 16; i++) begin
        @(posedge sample_trigger);
      end
      @(posedge clk);
      @(posedge clk);
      `CHECK_EQUAL(estimate_ready, 1'b1);
      `CHECK_EQUAL(estimated_bit, 1'b1);
    end // end of test case

    `TEST_CASE("estimate_holds_after_ready_pulse") begin
      int num_samples;

      // Apply 18 bits of 0, verify the result.
      raw_data <= 1'b1;
      for (int i = 0; i < 18; i++) begin
        @(posedge sample_trigger);
      end
      @(posedge clk);
      @(posedge clk);
      `CHECK_EQUAL(estimate_ready, 1'b1);
      `CHECK_EQUAL(estimated_bit, 1'b1);

      // Change the input data and let things run for a few more samples. The
      // estimate shouldn't change (because we haven't collected 16 samples)
      raw_data <= 1'b0;
      num_samples = 0;
      while (num_samples < 10) begin
        @(posedge clk)
        if (sample_trigger) begin
          num_samples++;
        end
        `CHECK_EQUAL(estimated_bit, 1'b1);
      end
    end // end of test case
  end

  `WATCHDOG(50000ns);
endmodule

