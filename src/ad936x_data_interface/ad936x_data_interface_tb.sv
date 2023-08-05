//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// ad936x_data_interface_tb is a testbench to verify ad936x_data_interface.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module ad936x_data_interface_tb();
  logic clk = 1'b0;
  logic rst = 1'b0;

  // Baseband Processor (BBP) Side
  logic [11:0] bbp_rx_data_i;
  logic [11:0] bbp_rx_data_q;
  logic bbp_rx_data_ready = 1'b0;
  logic bbp_rx_data_valid;
  logic [11:0] bbp_tx_data_i = 12'b0;
  logic [11:0] bbp_tx_data_q = 12'b0;
  logic bbp_tx_data_ready;
  logic bbp_tx_data_valid = 1'b0;

  // AD936x Side
  logic [11:0] ad936x_rx_data = 12'b0;
  logic ad936x_rx_frame = 1'b0;
  logic ad936x_data_clk = 1'b0;
  logic ad936x_data_clk_fb;
  logic [11:0] ad936x_tx_data;
  logic ad936x_tx_frame;

  ad936x_data_interface dut(
    .clk,
    .rst,
    .bbp_rx_data_i,
    .bbp_rx_data_q,
    .bbp_rx_data_ready,
    .bbp_rx_data_valid,
    .bbp_tx_data_i,
    .bbp_tx_data_q,
    .bbp_tx_data_ready,
    .bbp_tx_data_valid,
    .ad936x_rx_data,
    .ad936x_rx_frame,
    .ad936x_data_clk,
    .ad936x_data_clk_fb,
    .ad936x_tx_data,
    .ad936x_tx_frame
  );

  always begin
    #5;
    clk <= ~clk;
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
      bbp_tx_data_i = 12'b1010_1010_1010;
      bbp_tx_data_q = 12'b1010_1010_1010;
      ad936x_rx_data = 12'b1010_1010_1010;
      repeat (1000) begin
        `CHECK_EQUAL(bbp_rx_data_i, 12'b0);
        `CHECK_EQUAL(bbp_rx_data_q, 12'b0);
        `CHECK_EQUAL(bbp_rx_data_valid, 1'b0);
        `CHECK_EQUAL(bbp_tx_data_ready, 1'b0);
        `CHECK_EQUAL(ad936x_data_clk_fb, 1'b0);
        `CHECK_EQUAL(ad936x_tx_data, 12'b0);
        `CHECK_EQUAL(ad936x_tx_frame, 1'b0);
        bbp_rx_data_ready = ~bbp_rx_data_ready;
        bbp_tx_data_valid = ~bbp_tx_data_valid;
        ad936x_rx_frame = ~ad936x_rx_frame;
        ad936x_data_clk = ~ad936x_data_clk;
        #10;
      end
    end // end of test case

    `TEST_CASE("feeds_back_clk") begin
      `CHECK_EQUAL(ad936x_data_clk_fb, 1'b0);
      repeat (100) begin
        ad936x_data_clk = ~ad936x_data_clk;
        `CHECK_EQUAL(ad936x_data_clk_fb, ~ad936x_data_clk);
        #10;
        `CHECK_EQUAL(ad936x_data_clk_fb, ~ad936x_data_clk);
        #10;
        `CHECK_EQUAL(ad936x_data_clk_fb, ad936x_data_clk);
        #10;
        `CHECK_EQUAL(ad936x_data_clk_fb, ad936x_data_clk);
        #10;
        `CHECK_EQUAL(ad936x_data_clk_fb, ad936x_data_clk);
        #10
        `CHECK_EQUAL(ad936x_data_clk_fb, ad936x_data_clk);
        #10;
        `CHECK_EQUAL(ad936x_data_clk_fb, ad936x_data_clk);
        #10;
      end
    end // end of test case

    `TEST_CASE("sends_tx_frames") begin
      bbp_tx_data_i = 12'b0000_1111_0000;
      bbp_tx_data_q = 12'b0011_0000_1100;
      `CHECK_EQUAL(ad936x_tx_frame, 1'b0);
      `CHECK_EQUAL(ad936x_data_clk_fb, 1'b0);
      repeat(100) begin
        #100;
        ad936x_data_clk = 1'b1;
        `CHECK_EQUAL(ad936x_data_clk_fb, 1'b0);
        `CHECK_EQUAL(ad936x_tx_frame, 1'b0);
        #10;
        `CHECK_EQUAL(ad936x_data_clk_fb, 1'b0);
        `CHECK_EQUAL(ad936x_tx_frame, 1'b0);
        #10;
        `CHECK_EQUAL(ad936x_data_clk_fb, 1'b1);
        `CHECK_EQUAL(ad936x_tx_frame, 1'b0);
        #10;
        // One clk cycle after data_clk_fb goes high, the I data is presented.
        `CHECK_EQUAL(ad936x_data_clk_fb, 1'b1);
        `CHECK_EQUAL(ad936x_tx_frame, 1'b1);
        `CHECK_EQUAL(ad936x_tx_data, bbp_tx_data_i);
        #100;
        `CHECK_EQUAL(ad936x_data_clk_fb, 1'b1);
        `CHECK_EQUAL(ad936x_tx_frame, 1'b1);
        `CHECK_EQUAL(ad936x_tx_data, bbp_tx_data_i);
        ad936x_data_clk = 1'b0;
        #10;
        `CHECK_EQUAL(ad936x_data_clk_fb, 1'b1);
        `CHECK_EQUAL(ad936x_tx_frame, 1'b1);
        `CHECK_EQUAL(ad936x_tx_data, bbp_tx_data_i);
        #10;
        `CHECK_EQUAL(ad936x_data_clk_fb, 1'b0);
        `CHECK_EQUAL(ad936x_tx_frame, 1'b1);
        `CHECK_EQUAL(ad936x_tx_data, bbp_tx_data_i);
        #100;
        `CHECK_EQUAL(ad936x_data_clk_fb, 1'b0);
        `CHECK_EQUAL(ad936x_tx_frame, 1'b1);
        `CHECK_EQUAL(ad936x_tx_data, bbp_tx_data_i);
        ad936x_data_clk = 1'b1;
        #10;
        `CHECK_EQUAL(ad936x_data_clk_fb, 1'b0);
        `CHECK_EQUAL(ad936x_tx_frame, 1'b1);
        `CHECK_EQUAL(ad936x_tx_data, bbp_tx_data_i);
        #10;
        `CHECK_EQUAL(ad936x_data_clk_fb, 1'b1);
        `CHECK_EQUAL(ad936x_tx_frame, 1'b1);
        `CHECK_EQUAL(ad936x_tx_data, bbp_tx_data_i);
        #10;
        // One clk cycle after data_clk_fb goes high, the Q data is presented.
        `CHECK_EQUAL(ad936x_data_clk_fb, 1'b1);
        `CHECK_EQUAL(ad936x_tx_frame, 1'b0);
        `CHECK_EQUAL(ad936x_tx_data, bbp_tx_data_q);
        #100;
        `CHECK_EQUAL(ad936x_data_clk_fb, 1'b1);
        `CHECK_EQUAL(ad936x_tx_frame, 1'b0);
        `CHECK_EQUAL(ad936x_tx_data, bbp_tx_data_q);
        ad936x_data_clk = 1'b0;
        #10;
        `CHECK_EQUAL(ad936x_data_clk_fb, 1'b1);
        `CHECK_EQUAL(ad936x_tx_frame, 1'b0);
        `CHECK_EQUAL(ad936x_tx_data, bbp_tx_data_q);
        #10;
        `CHECK_EQUAL(ad936x_data_clk_fb, 1'b0);
        `CHECK_EQUAL(ad936x_tx_frame, 1'b0);
        `CHECK_EQUAL(ad936x_tx_data, bbp_tx_data_q);
      end
    end // end of test case

    `TEST_CASE("buffers_tx_frame") begin
      bbp_tx_data_i = 12'b0000_1111_0000;
      bbp_tx_data_q = 12'b0011_0000_1100;
      `CHECK_EQUAL(ad936x_tx_frame, 1'b0);
      `CHECK_EQUAL(ad936x_data_clk_fb, 1'b0);
      #100;
      ad936x_data_clk = 1'b1;
      #100;
      `CHECK_EQUAL(ad936x_tx_frame, 1'b1);
      `CHECK_EQUAL(ad936x_data_clk_fb, 1'b1);
      `CHECK_EQUAL(ad936x_tx_data, 12'b0000_1111_0000);

      // Change the data on the BBP side but make sure it doesn't affect the
      // ad936x side because the transfer has already started.
      bbp_tx_data_i = 12'b1111_1111_1111;
      bbp_tx_data_q = 12'b0000_0000_0000;

      #100;
      `CHECK_EQUAL(ad936x_tx_frame, 1'b1);
      `CHECK_EQUAL(ad936x_data_clk_fb, 1'b1);
      `CHECK_EQUAL(ad936x_tx_data, 12'b0000_1111_0000);
      ad936x_data_clk = 1'b0;
      #100;
      ad936x_data_clk = 1'b1;
      #100;
      `CHECK_EQUAL(ad936x_tx_frame, 1'b0);
      `CHECK_EQUAL(ad936x_data_clk_fb, 1'b1);
      `CHECK_EQUAL(ad936x_tx_data, 12'b0011_0000_1100);
    end // end of test case

    `TEST_CASE("pulses_tx_ready_once_per_transfer") begin
      repeat(10) begin
        ad936x_data_clk = 1'b1;
        `CHECK_EQUAL(bbp_tx_data_ready, 1'b0);
        #10;
        `CHECK_EQUAL(bbp_tx_data_ready, 1'b0);
        #10;
        `CHECK_EQUAL(bbp_tx_data_ready, 1'b0);
        #10;
        `CHECK_EQUAL(bbp_tx_data_ready, 1'b1);
        #10;
        repeat(10) begin
          `CHECK_EQUAL(bbp_tx_data_ready, 1'b0);
          #10;
        end
        ad936x_data_clk = 1'b0;
        repeat(10) begin
          `CHECK_EQUAL(bbp_tx_data_ready, 1'b0);
          #10;
        end
        ad936x_data_clk = 1'b1;
        repeat(10) begin
          `CHECK_EQUAL(bbp_tx_data_ready, 1'b0);
          #10;
        end
        ad936x_data_clk = 1'b0;
        repeat(10) begin
          `CHECK_EQUAL(bbp_tx_data_ready, 1'b0);
          #10;
        end
      end
    end

    `TEST_CASE("receives_one_rx_frame") begin
      bbp_rx_data_ready = 1'b1;
      ad936x_data_clk = 1'b0;
      `CHECK_EQUAL(bbp_rx_data_valid, 1'b0);
      #100;
      ad936x_rx_data = 12'b0000_1111_0000;
      ad936x_rx_frame = 1'b1;
      `CHECK_EQUAL(bbp_rx_data_valid, 1'b0);
      #10;
      ad936x_data_clk = 1'b1;
      `CHECK_EQUAL(bbp_rx_data_valid, 1'b0);
      #100;
      ad936x_data_clk = 1'b0;
      `CHECK_EQUAL(bbp_rx_data_valid, 1'b0);
      #100
      ad936x_rx_data = 12'b0011_0000_1100;
      ad936x_rx_frame = 1'b0;
      `CHECK_EQUAL(bbp_rx_data_valid, 1'b0);
      #10;
      ad936x_data_clk = 1'b1;
      `CHECK_EQUAL(bbp_rx_data_valid, 1'b0);
      #10;
      `CHECK_EQUAL(bbp_rx_data_valid, 1'b0);
      #10;
      `CHECK_EQUAL(bbp_rx_data_valid, 1'b0);
      #10;
      `CHECK_EQUAL(bbp_rx_data_valid, 1'b1);
      `CHECK_EQUAL(bbp_rx_data_i, 12'b0000_1111_0000);
      `CHECK_EQUAL(bbp_rx_data_q, 12'b0011_0000_1100);
      #10;
      `CHECK_EQUAL(bbp_rx_data_valid, 1'b0);
    end // end of test case

    `TEST_CASE("buffers_rx_frame") begin
      bbp_rx_data_ready = 1'b1;
      ad936x_data_clk = 1'b0;
      #100;
      ad936x_rx_data = 12'b0000_1111_0000;
      ad936x_rx_frame = 1'b1;
      #100;
      ad936x_data_clk = 1'b1;
      #100;
      ad936x_data_clk = 1'b0;
      ad936x_rx_data = 12'b0011_0000_1100;
      ad936x_rx_frame = 1'b0;
      #100;
      ad936x_data_clk = 1'b1;
      #100;
      repeat(20) begin
        `CHECK_EQUAL(bbp_rx_data_i, 12'b0000_1111_0000);
        `CHECK_EQUAL(bbp_rx_data_q, 12'b0011_0000_1100);
        #10;
      end
      ad936x_data_clk = 1'b0;
      repeat(20) begin
        `CHECK_EQUAL(bbp_rx_data_i, 12'b0000_1111_0000);
        `CHECK_EQUAL(bbp_rx_data_q, 12'b0011_0000_1100);
        #10;
      end
      ad936x_rx_data = 12'b0000_0000_0000;
      ad936x_rx_frame = 1'b1;
      #100;
      ad936x_data_clk = 1'b1;
      repeat(20) begin
        `CHECK_EQUAL(bbp_rx_data_i, 12'b0000_1111_0000);
        `CHECK_EQUAL(bbp_rx_data_q, 12'b0011_0000_1100);
        #10;
      end
    end // end of test case

    `TEST_CASE("valid_responds_to_ready") begin
      bbp_rx_data_ready = 1'b0;
      ad936x_rx_frame = 1'b1;
      #10;
      ad936x_data_clk = 1'b1;
      #100;
      ad936x_rx_frame = 1'b0;
      ad936x_data_clk = 1'b0;
      #100;
      ad936x_data_clk = 1'b1;
      #100;
      repeat(50) begin
        #10;
        `CHECK_EQUAL(bbp_rx_data_valid, 1'b1);
      end
      bbp_rx_data_ready = 1'b1;
      repeat(50) begin
        #10;
        `CHECK_EQUAL(bbp_rx_data_valid, 1'b0);
      end
    end // end of test case
  end

  `WATCHDOG(90000ns);
endmodule
