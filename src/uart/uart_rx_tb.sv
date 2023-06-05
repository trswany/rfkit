//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// uart_rx_tb is a testbench to verify the uart_rx.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module uart_rx_tb();
  logic clk = 1'b0;
  logic rst = 1'b0;
  logic raw_data = 1'b1;
  logic [7:0] data;
  logic data_valid;
  wire sample_trigger;

  uart_rx dut(
    .data(data),
    .data_valid(data_valid),
    .clk(clk),
    .sample_trigger(sample_trigger),
    .rst(rst),
    .raw_data(raw_data)
  );

  pulse_generator #(.Period(10)) pulse_generator(
    .clk(clk),
    .rst(rst),
    .pulse(sample_trigger)
  );

  logic [255:0] sample_stream = 256'b0;
  logic [7:0] got_byte = 8'b0;

  always begin
    #5;
    clk <= !clk;
  end

  `TEST_SUITE begin
    `TEST_SUITE_SETUP begin
      // Reset the DUT and set the data signal to the idle state.
      raw_data <= 1'b1;
      rst <= 1'b1;
      @(posedge clk);
      rst <= 1'b0;
      @(posedge clk);
    end

    `TEST_CASE("stays_in_reset") begin
      rst <= 1'b1;  // Keep the rst signal asserted.
      repeat (3000) begin
        @(posedge clk);
        `CHECK_EQUAL(data_valid, 1'b0, "expected low data_valid");
      end
      data <= 1'b0;
      repeat (3000) begin
        @(posedge clk);
        `CHECK_EQUAL(data_valid, 1'b0, "expected low data_valid");
      end
    end // end of test case

    `TEST_CASE("waits_for_start_bit") begin
      // Make sure data_valid stays low until we get a real byte.
      repeat (10000) begin
        @(posedge clk);
        `CHECK_EQUAL(data_valid, 1'b0);
      end
    end // end of test case

    `TEST_CASE("receives_perfect_byte") begin
      int sample_index;

      // Run a few samples to let the start-bit detector warm up.
      repeat (10) begin
        @(posedge sample_trigger);
      end
      // Build a stream of a start bit 0'b0, 8'b11010101, and a stop bit 0'b1.
      sample_stream <= {
        16'b0000_0000_0000_0000,  // start bit
        16'b1111_1111_1111_1111,
        16'b1111_1111_1111_1111,
        16'b0000_0000_0000_0000,
        16'b1111_1111_1111_1111,
        16'b0000_0000_0000_0000,
        16'b1111_1111_1111_1111,
        16'b0000_0000_0000_0000,
        16'b1111_1111_1111_1111,
        16'b1111_1111_1111_1111   // stop bit
      };
      sample_index = 159;
      while (sample_index >= 0) begin
        @(posedge clk);
        if (sample_trigger) begin
          raw_data <= sample_stream[sample_index];
          sample_index--;
        end
        // We expect to receive the data halfway through the stop bit.
        if (data_valid == 1'b1) begin
          got_byte <= data;
        end
      end
      raw_data <= 01'b1;
      `CHECK_EQUAL(got_byte, 8'b1101_0101);
    end // end of test case

    `TEST_CASE("receives_two_perfect_bytes") begin
      int sample_index;

      // Run a few cycles to let the start-bit detector warm up.
      repeat (10) begin
        @(posedge sample_trigger);
      end
      // Build a stream of a start bit 0'b0, 8'b11010101, and a stop bit 0'b1.
      sample_stream <= {
        16'b0000_0000_0000_0000,  // start bit
        16'b1111_1111_1111_1111,
        16'b1111_1111_1111_1111,
        16'b0000_0000_0000_0000,
        16'b1111_1111_1111_1111,
        16'b0000_0000_0000_0000,
        16'b1111_1111_1111_1111,
        16'b0000_0000_0000_0000,
        16'b1111_1111_1111_1111,
        16'b1111_1111_1111_1111   // stop bit
      };
      sample_index = 159;
      while (sample_index >= 0) begin
        @(posedge clk);
        if (sample_trigger) begin
          raw_data <= sample_stream[sample_index];
          sample_index--;
        end
        // We expect to receive the data halfway through the stop bit.
        if (data_valid == 1'b1) begin
          got_byte <= data;
        end
      end
      raw_data <= 01'b1;
      `CHECK_EQUAL(got_byte, 8'b1101_0101);

      repeat (10) begin
        #10;
      end

      // Build a stream of a start bit 0'b0, 8'b11000101, and a stop bit 0'b1.
      sample_stream <= {
        16'b0000_0000_0000_0000,  // start bit
        16'b1111_1111_1111_1111,
        16'b1111_1111_1111_1111,
        16'b0000_0000_0000_0000,
        16'b0000_0000_0000_0000,
        16'b0000_0000_0000_0000,
        16'b1111_1111_1111_1111,
        16'b0000_0000_0000_0000,
        16'b1111_1111_1111_1111,
        16'b1111_1111_1111_1111   // stop bit
      };
      sample_index = 159;
      while (sample_index >= 0) begin
        @(posedge clk);
        if (sample_trigger) begin
          raw_data <= sample_stream[sample_index];
          sample_index--;
        end
        // We expect to receive the data halfway through the stop bit.
        if (data_valid == 1'b1) begin
          got_byte <= data;
        end
      end
      raw_data <= 01'b1;
      `CHECK_EQUAL(got_byte, 8'b1100_0101);
    end // end of test case

    `TEST_CASE("rejects_incorrect_stop_bit") begin
      int sample_index;

      // Run a few cycles to let the start-bit detector warm up.
      repeat (10) begin
        @(posedge sample_trigger);
      end
      // Build a stream of a start bit 0'b0, some bits, and a bad stop bit (0'b0).
      sample_stream <= {
        16'b0000_0000_0000_0000,  // start bit
        16'b1111_1111_1111_1111,
        16'b1111_1111_1111_1111,
        16'b0000_0000_0000_0000,
        16'b1111_1111_1111_1111,
        16'b0000_0000_0000_0000,
        16'b1111_1111_1111_1111,
        16'b0000_0000_0000_0000,
        16'b1111_1111_1111_1111,
        16'b0000_0000_0000_0000   // stop bit
      };
      sample_index = 159;
      while (sample_index >= 0) begin
        @(posedge clk);
        if (sample_trigger) begin
          raw_data <= sample_stream[sample_index];
          sample_index--;
        end
        `CHECK_EQUAL(data_valid, 1'b0);
      end
      raw_data <= 01'b1;
      // Make sure that the data_ready never goes high.
      repeat (2000) begin
        @(posedge clk);
        `CHECK_EQUAL(data_valid, 1'b0);
      end
    end // end of test case

    `TEST_CASE("verify_sampling_point") begin
      int sample_index;

      // Run a few cycles to let the start-bit detector warm up.
      repeat (10) begin
        @(posedge sample_trigger);
      end
      // Build a stream of a start bit 0'b0, 8'b11010101, and a stop bit 0'b1.
      // Make these bits malformed so we verify that the detector is sampling
      // in roughly the middle of the bits.
      sample_stream <= {
        16'b0000_0000_0000_0000,  // start bit
        16'b0000_0011_1100_0000,  // 1
        16'b0000_0011_1100_0000,  // 1
        16'b1111_1100_0011_1111,  // 0
        16'b0000_0011_1100_0000,  // 1
        16'b1111_1100_0011_1111,  // 0
        16'b0000_0011_1100_0000,  // 1
        16'b1111_1100_0011_1111,  // 0
        16'b0000_0011_1100_0000,  // 1
        16'b1111_1111_1111_1111   // stop bit
      };
      sample_index = 159;
      while (sample_index >= 0) begin
        @(posedge clk);
        if (sample_trigger) begin
          raw_data <= sample_stream[sample_index];
          sample_index--;
        end
        // We expect to receive the data halfway through the stop bit.
        if (data_valid == 1'b1) begin
          got_byte <= data;
        end
      end
      raw_data <= 01'b1;
      `CHECK_EQUAL(got_byte, 8'b1101_0101);
    end // end of test case
  end

  `WATCHDOG(200000ns);
endmodule

