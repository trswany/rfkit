//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// uart_tx_tb is a testbench to verify the uart_rx.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module uart_tx_tb();
  logic clk = 1'b0;
  logic rst = 1'b0;
  logic [7:0] data = 8'b0;
  logic start = 1'b0;
  logic serial_data;
  logic ready;
  wire sample_trigger;

  uart_tx dut(
    .serial_data(serial_data),
    .ready(ready),
    .clk(clk),
    .sample_trigger(sample_trigger),
    .rst(rst),
    .data(data),
    .start(start)
  );

  pulse_generator #(.INTERVAL(10)) pulse_generator(
    .out(sample_trigger),
    .rst(rst),
    .clk(clk)
  );

  logic [255:0] want_stream = 256'b0;
  logic [255:0] got_stream = 256'b0;

  always begin
    #5;
    clk <= !clk;
  end

  `TEST_SUITE begin
    `TEST_SUITE_SETUP begin
      data = 8'b0;
      start = 1'b0;
      rst <= 1'b1;
      @(posedge clk);
      rst <= 1'b0;
      @(posedge clk);
    end

    `TEST_CASE("stays_in_reset") begin
      rst <= 1'b1;  // Keep the rst signal asserted.
      @(posedge clk);
      repeat (3000) begin
        @(posedge clk);
        `CHECK_EQUAL(serial_data, 1'b1);
        `CHECK_EQUAL(ready, 1'b0);
      end
      data <= 8'b1101_0101;
      start <= 1'b1;
      repeat (300) begin
        @(posedge clk);
        `CHECK_EQUAL(serial_data, 1'b1);
        `CHECK_EQUAL(ready, 1'b0);
      end
    end // end of test case

    `TEST_CASE("send_a_byte") begin
      int sample_index;

      // Run a few samples to let things warm up.
      repeat (10) begin
        @(posedge sample_trigger);
      end

      // Build a stream of a start bit 0'b0, some bits, and a bad stop bit (0'b0).
      want_stream <= {
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

      // Kick off transmission
      @(posedge sample_trigger);
      @(posedge clk);
      data <= 8'b1101_0101;
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;
      @(posedge clk);

      // Verify the output sample stream.
      sample_index = 159;
      @(posedge sample_trigger);
      @(posedge clk);
      while (sample_index > 0) begin
        @(posedge clk);
        `CHECK_EQUAL(ready, 0'b0);
        `CHECK_EQUAL(serial_data, want_stream[sample_index]);
        if (sample_trigger) begin
          sample_index--;
        end
      end
      @(posedge clk);
      repeat (3000) begin
        @(posedge clk);
        `CHECK_EQUAL(ready, 0'b1);
        `CHECK_EQUAL(serial_data, 0'b1);
      end
    end // end of test case

    `TEST_CASE("send_two_bytes") begin
      int sample_index;

      // Run a few samples to let things warm up.
      repeat (10) begin
        @(posedge sample_trigger);
      end

      // Build a stream of a start bit 0'b0, some bits, and a stop bit (0'b0).
      want_stream <= {
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

      // Kick off transmission
      @(posedge sample_trigger);
      @(posedge clk);
      data <= 8'b1101_0101;
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;
      @(posedge clk);

      // Verify the output sample stream.
      sample_index = 159;
      @(posedge sample_trigger);
      @(posedge clk);
      while (sample_index > 0) begin
        @(posedge clk);
        `CHECK_EQUAL(ready, 0'b0);
        `CHECK_EQUAL(serial_data, want_stream[sample_index]);
        if (sample_trigger) begin
          sample_index--;
        end
      end
      @(posedge clk);
      repeat (3000) begin
        @(posedge clk);
        `CHECK_EQUAL(ready, 0'b1);
        `CHECK_EQUAL(serial_data, 0'b1);
      end

      // Build a stream of a start bit 0'b0, some bits, and a stop bit (0'b0).
      want_stream <= {
        16'b0000_0000_0000_0000,  // start bit
        16'b1111_1111_1111_1111,
        16'b0000_0000_0000_0000,
        16'b1111_1111_1111_1111,
        16'b1111_1111_1111_1111,
        16'b1111_1111_1111_1111,
        16'b1111_1111_1111_1111,
        16'b0000_0000_0000_0000,
        16'b1111_1111_1111_1111,
        16'b0000_0000_0000_0000   // stop bit
      };

      // Kick off transmission
      @(posedge sample_trigger);
      @(posedge clk);
      data <= 8'b1011_1101;
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;
      @(posedge clk);

      // Verify the output sample stream.
      sample_index = 159;
      @(posedge sample_trigger);
      @(posedge clk);
      while (sample_index > 0) begin
        @(posedge clk);
        `CHECK_EQUAL(ready, 0'b0);
        `CHECK_EQUAL(serial_data, want_stream[sample_index]);
        if (sample_trigger) begin
          sample_index--;
        end
      end
      @(posedge clk);
      repeat (3000) begin
        @(posedge clk);
        `CHECK_EQUAL(ready, 0'b1);
        `CHECK_EQUAL(serial_data, 0'b1);
      end
    end // end of test case

    `TEST_CASE("ignore_repeated_start") begin
      int sample_index;
      int bits_remaining;

      // Run a few samples to let things warm up.
      repeat (10) begin
        @(posedge sample_trigger);
      end

      // Run a few cycles to let things warm up.
      repeat (10) begin
        #10;
      end
      // Build a stream of a start bit 0'b0, some bits, and a stop bit (0'b0).
      want_stream <= {
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

      // Kick off transmission
      @(posedge sample_trigger);
      @(posedge clk);
      data <= 8'b1101_0101;
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;
      @(posedge clk);

      // Verify the first half-ish of the sample stream.
      bits_remaining = 159;
      while (bits_remaining >= 80) begin
        @(posedge sample_trigger);
        @(posedge clk);
        @(posedge clk);
        `CHECK_EQUAL(ready, 0'b0);
        `CHECK_EQUAL(serial_data, want_stream[bits_remaining]);
        bits_remaining--;
      end

      // Try to send a second byte while the first is in progress.
      data <= 8'b1111_1111;
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;
      @(posedge clk);

      // Verify the second half-ish of the sample stream. The extra byte
      // and start pulse should be ignored.
      while (bits_remaining >= 0) begin
        @(posedge sample_trigger);
        @(posedge clk);
        @(posedge clk);
        `CHECK_EQUAL(ready, 0'b0);
        `CHECK_EQUAL(serial_data, want_stream[bits_remaining]);
        bits_remaining--;
      end

      repeat (1000) begin
        @(posedge clk);
        `CHECK_EQUAL(ready, 0'b1);
        `CHECK_EQUAL(serial_data, 0'b1);
      end
    end // end of test case
  end

  `WATCHDOG(200000ns);
endmodule

