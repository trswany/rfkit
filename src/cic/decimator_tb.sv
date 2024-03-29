//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// decimator_tb is a testbench to verify decimator.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module decimator_tb();
  logic clk = 1'b0;
  logic rst = 1'b0;
  logic signed [11:0] in = 12'b0000_0000_0000;
  logic in_valid = 1'b0;
  logic signed [11:0] out;
  logic out_ready = 1'b0;
  logic out_valid;

  decimator #(
    .WordLengthBits(12),
    .DecimationFactor(5)
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
        `CHECK_EQUAL(out, 36'b0)
        `CHECK_EQUAL(out_valid, 1'b0)
        #10;
      end
    end // end of test case

    `TEST_CASE("produces_zeroes_for_zero_input") begin
      in = 12'b0;
      in_valid = 1'b1;
      repeat (1000) begin
        `CHECK_EQUAL(out, 36'b0)
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
      repeat (4) begin
        `CHECK_EQUAL(out, '0)
        `CHECK_EQUAL(out_valid, 1'b0)
        #10;
      end
      `CHECK_EQUAL(out_valid, 1'b1)
      #10;
      repeat (4) begin
        `CHECK_EQUAL(out, '0)
        `CHECK_EQUAL(out_valid, 1'b0)
        #10;
      end
      `CHECK_EQUAL(out_valid, 1'b1)
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
      repeat (100) begin
        #10;
      end
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

    `TEST_CASE("copies_from_input_to_output") begin
      in = 12'b1010_1010_1010;
      in_valid = 1'b1;
      out_ready = 1'b1;
      #10
      repeat (4) begin
        `CHECK_EQUAL(out, 12'b0)
        #10;
      end
      repeat (100) begin
        `CHECK_EQUAL(out, 12'b1010_1010_1010)
        #10;
      end
    end // end of test case

    `TEST_CASE("decimates") begin
      in_valid = 1'b0;
      out_ready = 1'b1;
      repeat (10) begin
        repeat (5) begin
          repeat (100) begin
            #10;
            `CHECK_EQUAL(out_valid, 1'b0)
          end
          in_valid = 1'b1;
          #10;
          in_valid = 1'b0;
        end
        `CHECK_EQUAL(out_valid, 1'b1)
      end
    end // end of test case
  end

  `WATCHDOG(100ms);
endmodule
