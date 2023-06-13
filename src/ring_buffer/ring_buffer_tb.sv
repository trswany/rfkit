//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// ring_buffer_tb is a testbench to verify ring_buffer.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module ring_buffer_tb();
  logic clk = 1'b0;
  logic rst = 1'b0;
  logic put = 1'b0;
  logic [7:0] data_in = 8'b0000_0000;
  logic get = 1'b0;
  logic [7:0] data_out;
  logic data_out_valid;
  logic buffer_empty;
  logic buffer_100p_full;

  ring_buffer #(
    .WordLengthBits(8),
    .NumWords(128)
  ) dut(
    .clk(clk),
    .rst(rst),
    .put(put),
    .get(get),
    .data_in(data_in),
    .data_out(data_out),
    .data_out_valid(data_out_valid),
    .buffer_empty(buffer_empty),
    .buffer_100p_full(buffer_100p_full)
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
      data_in = 8'b1010_1010;
      put = 1'b1;
      repeat (10) begin
        `CHECK_EQUAL(buffer_empty, 1'b1);
        `CHECK_EQUAL(data_out_valid, 1'b0)
        #10;
      end
    end // end of test case

    `TEST_CASE("one_cycle_read_latency") begin
      data_in = 8'b1010_1010;
      put = 1'b1;
      get = 1'b1;
      #10;  //  Clock data into the buffer.
      #10;  //  Wait exactly one clock cycle.
      `CHECK_EQUAL(data_out, 8'b1010_1010);
      `CHECK_EQUAL(data_out_valid, 1'b1);
    end // end of test case

    `TEST_CASE("fill_then_empty") begin
      data_in = 8'b1010_1010;
      put = 1'b1;
      `CHECK_EQUAL(buffer_empty, 1'b1);
      `CHECK_EQUAL(buffer_100p_full, 1'b0);
      #10;  // Clock the first byte in.

      // Clock 126 more bytes in.
      repeat (126) begin
        #10;
        `CHECK_EQUAL(buffer_empty, 1'b0);
        `CHECK_EQUAL(buffer_100p_full, 1'b0);
      end

      // Add the last byte into the buffer (now full).
      #10;
      `CHECK_EQUAL(buffer_empty, 1'b0);
      `CHECK_EQUAL(buffer_100p_full, 1'b1);

      // Now start reading bytes.
      put = 1'b0;
      get = 1'b1;
      #10;
      `CHECK_EQUAL(buffer_empty, 1'b0);
      `CHECK_EQUAL(buffer_100p_full, 1'b0);

      // Clock 126 more bytes out.
      repeat (126) begin
        #10;
        `CHECK_EQUAL(buffer_empty, 1'b0);
        `CHECK_EQUAL(buffer_100p_full, 1'b0);
      end

      // Pull the last byte out (now empty).
      #10;
      `CHECK_EQUAL(buffer_empty, 1'b1);
      `CHECK_EQUAL(buffer_100p_full, 1'b0);
    end // end of test case

    `TEST_CASE("continuous_puts_and_gets") begin
      `CHECK_EQUAL(buffer_empty, 1'b1);
      put = 1'b1;
      data_in = 8'd0;
      #10  // Load a byte before we start getting.
      `CHECK_EQUAL(buffer_empty, 1'b0);
      `CHECK_EQUAL(data_out_valid, 1'b0);

      get = 1'b1;  // We should be able to start getting after one clk.
      repeat (250) begin
        data_in = data_in + 1;
        #10;
        // Reads are delayed by one clock cycle.
        `CHECK_EQUAL(data_out, data_in - 1);
        `CHECK_EQUAL(data_out_valid, 1'b1);
        `CHECK_EQUAL(buffer_empty, 1'b0);
        `CHECK_EQUAL(buffer_100p_full, 1'b0);
      end
    end // end of test case

    `TEST_CASE("delayed_get") begin
      data_in = 8'd1;
      put = 1'b1;
      #10  // Clock a 1 into the first slot.
      data_in = 8'd2;  // Clock 2 into rest of the slots.
      `CHECK_EQUAL(data_out_valid, 1'b0);

      // data_out should present 8'd1 until we use "get" to advance.
      // Note that this is undefined behavior but we test it anyway.
      repeat (10) begin
        #10;
        `CHECK_EQUAL(data_out, 8'd1);
        `CHECK_EQUAL(data_out_valid, 1'b0);
      end

      // data_out should present the 8'd1 on the first "get."
      get = 1'b1;
      #10;
      `CHECK_EQUAL(data_out, 8'd1);
      `CHECK_EQUAL(data_out_valid, 1'b1);

      // data_out should present the 8'd2 after the next "get."
      #10;
      `CHECK_EQUAL(data_out, 8'd2);
      `CHECK_EQUAL(data_out_valid, 1'b1);
    end // end of test case

    `TEST_CASE("ignore_gets_while_empty") begin
      // Do some gets even though there's nothing in the buffer.
      get = 1'b1;
      repeat (10) begin
        #10;
        `CHECK_EQUAL(buffer_empty, 1'b1);
        `CHECK_EQUAL(data_out_valid, 1'b0);
      end

      // Clock a 1 into the first slot.
      data_in = 8'b1010_0101;
      put = 1'b1;
      #10;
      put = 1'b0;
      `CHECK_EQUAL(buffer_empty, 1'b0);

      // After the next clock, we should see the data.
      #10;
      `CHECK_EQUAL(buffer_empty, 1'b1);
      `CHECK_EQUAL(data_out, 8'b1010_0101);
      `CHECK_EQUAL(data_out_valid, 1'b1);
    end // end of test case

    `TEST_CASE("buffer_empty_signal_works") begin
      `CHECK_EQUAL(buffer_empty, 1'b1);
      repeat (10) begin
        #10;
        `CHECK_EQUAL(buffer_empty, 1'b1);
      end

      put = 1'b1;
      #10;
      `CHECK_EQUAL(buffer_empty, 1'b0);
      put = 1'b0;
      `CHECK_EQUAL(buffer_empty, 1'b0);

      get = 1'b1;
      #10;
      `CHECK_EQUAL(buffer_empty, 1'b1);
      get = 1'b1;
      `CHECK_EQUAL(buffer_empty, 1'b1);
    end // end of test case

    `TEST_CASE("ignore_puts_on_full_buffer") begin
      // Fill the buffer.
      put = 1'b1;
      data_in = 8'b0000_1111;
      repeat (150) begin
        #10;
      end

      `CHECK_EQUAL(buffer_empty, 1'b0);
      `CHECK_EQUAL(buffer_100p_full, 1'b1);
      `CHECK_EQUAL(data_out_valid, 1'b0);

      // Try to load some more data.
      data_in = 8'b0011_1100;
      repeat (10) begin
        #10;
      end

      `CHECK_EQUAL(buffer_empty, 1'b0);
      `CHECK_EQUAL(buffer_100p_full, 1'b1);
      `CHECK_EQUAL(data_out_valid, 1'b0);

      // Verify that all 128 bytes are the original data.
      put = 1'b0;
      get = 1'b1;
      #10;  // Clock out the first byte.
      repeat (126) begin
        #10;
        `CHECK_EQUAL(buffer_empty, 1'b0);
        `CHECK_EQUAL(buffer_100p_full, 1'b0);
        `CHECK_EQUAL(data_out, 8'b0000_1111);
        `CHECK_EQUAL(data_out_valid, 1'b1);
      end
      #10;  // Clock out the 128th (last) byte.
      `CHECK_EQUAL(buffer_empty, 1'b1);
      `CHECK_EQUAL(buffer_100p_full, 1'b0);
      `CHECK_EQUAL(data_out, 8'b0000_1111);
      `CHECK_EQUAL(data_out_valid, 1'b1);
    end // end of test case
  end

  `WATCHDOG(50000ns);
endmodule

