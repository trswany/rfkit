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
  logic estimated_data;
  logic sample_clk;
  bit_sampler dut(
    .estimated_data(estimated_data),
    .sample_clk(sample_clk),
    .clk(clk),
    .rst(rst),
    .raw_data(raw_data)
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
      #10;
    end

    `TEST_CASE("stays_in_reset") begin
      rst <= 1'b1;  // Keep the rst signal asserted.
      repeat (20) begin
        #10;
        `CHECK_EQUAL(estimated_data, 1'b0, "expected low estimated_data");
        `CHECK_EQUAL(sample_clk, 1'b0, "expected low sample_clk");
      end
      raw_data <= 1'b1;
      repeat (20) begin
        #10;
        `CHECK_EQUAL(estimated_data, 1'b0, "expected low estimated_data");
        `CHECK_EQUAL(sample_clk, 1'b0, "expected low sample_clk");
      end
    end // end of test case

    `TEST_CASE("generates_sample_clk") begin
      rst <= 1'b0;
      // Nothing should happen for the first 17 pulses.
      repeat (17) begin
        #10;
        `CHECK_EQUAL(sample_clk, 1'b0, "expected low sample_clk");
      end

      // After the 18th pulse, we should get a brief blip of the sample_clk.
      #10;
      `CHECK_EQUAL(sample_clk, 1'b1, "expected high sample_clk");

      // The sample_clk should go back to 0 after the 19th clk pulse and stay 
      // low for a total of 15 pulses.
      repeat (15) begin
        #10;
        `CHECK_EQUAL(sample_clk, 1'b0, "expected low sample_clk");
      end

      // It should go high again for the 16th clock pulse.
      #10;
      `CHECK_EQUAL(sample_clk, 1'b1, "expected high sample_clk");

      // And then stay low for 15 more pulses.
      repeat (15) begin
        #10;
        `CHECK_EQUAL(sample_clk, 1'b0, "expected low sample_clk");
      end

      // Check for one more short pulse.
      #10;
      `CHECK_EQUAL(sample_clk, 1'b1, "expected high sample_clk");
      #10;
      `CHECK_EQUAL(sample_clk, 1'b0, "expected low sample_clk");
    end // end of test case

    `TEST_CASE("estimates_zeros") begin
      rst <= 1'b0;
      estimated_data <= 1'b0;
      repeat (150) begin
        #10;
        `CHECK_EQUAL(estimated_data, 1'b0, "expected low estimated_data");
      end
    end // end of test case

    `TEST_CASE("estimates_ones") begin
      rst <= 1'b0;
      estimated_data <= 1'b1;
      repeat (150) begin
        #10;
        `CHECK_EQUAL(estimated_data, 1'b1, "expected high estimated_data");
      end
    end // end of test case

    `TEST_CASE("estimates_one_with_noise") begin
      rst <= 1'b0;
      raw_data <= 1'b1;
      #140;  // Wait for 14 clock pulses.
      raw_data <= 1'b0;  // Set raw_data to 0 to simulate noise.
      #20;  // Wait for 2 clock pulses.
      raw_data <= 1'b1;
      #20;  // Wait for 2 clock pulses.
      `CHECK_EQUAL(estimated_data, 1'b1, "expected high estimated_data");
      `CHECK_EQUAL(sample_clk, 1'b1, "expected high sample_clk");
    end // end of test case

    `TEST_CASE("estimates_multiple_bits") begin
      rst <= 1'b0;
      raw_data <= 1'b0;

      // Wait 17 clock pulses and verify the estimated bit doesn't change.
      repeat (17) begin
        #10;
        `CHECK_EQUAL(estimated_data, 1'b0, "expected low estimated_data");
      end

      // After the 18th pulse, the bit-sampler will make its decision and
      // generate the sample clk pulse. Change the raw_data.
      #10;
      `CHECK_EQUAL(sample_clk, 1'b1, "expected high sample_clk");
      `CHECK_EQUAL(estimated_data, 1'b0, "expected low estimated_data");
      raw_data <= 1'b1;

      // Wait 15 clock pulses and verify the estimated bit doesn't change.
      repeat (15) begin
        #10;
        `CHECK_EQUAL(estimated_data, 1'b0, "expected low estimated_data");
      end

      // After the next pulse, the bit-sampler will make its decision and
      // generate the sample clk pulse. Change the raw_data.
      #10;
      `CHECK_EQUAL(sample_clk, 1'b1, "expected high sample_clk");
      `CHECK_EQUAL(estimated_data, 1'b1, "expected high estimated_data");
      raw_data <= 1'b0;

      // Wait 15 clock pulses and verify the estimated bit doesn't change.
      repeat (15) begin
        #10;
        `CHECK_EQUAL(estimated_data, 1'b1, "expected high estimated_data");
      end
    end // end of test case
  end

  `WATCHDOG(2000ns);
endmodule

