//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// cic_decimator_tb is a testbench to verify cic_decimator.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module cic_decimator_tb();
  logic clk = 1'b0;
  logic rst = 1'b0;
  logic signed [11:0] in = 12'b0000_0000_0000;
  logic in_valid = 1'b0;
  logic signed [35:0] out;
  logic out_ready = 1'b1;
  logic out_valid;

  cic_decimator #(
    .InputLengthBits(12),
    .DecimationFactor(8),
    .DelayLength(1),
    .FilterOrder(3),
    .InternalLengthBits(21),  // Warning: avoid overflow
    .OutputLengthBits(26)  // Warning: avoid overflow
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

      // Make sure out_valid doesn't go high until we assert in_valid.
      repeat (1000) begin
        `CHECK_EQUAL(out, '0)
        `CHECK_EQUAL(out_valid, 1'b0)
        #10;
      end

      // Let the chain run for a while with valid data.
      in = 12'b0;
      in_valid = 1'b1;
      repeat (1000) begin
        `CHECK_EQUAL(out, '0)
        #10;
      end

      // Put garbage on the input and de-assert in_valid.
      // Make sure the garbage doesn't come through on the output.
      in = 12'b1010_1010_1010;
      in_valid = 1'b0;
      repeat (1000) begin
        `CHECK_EQUAL(out, '0)
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

    `TEST_CASE("decimates") begin
      in_valid = 1'b0;
      out_ready = 1'b1;
      repeat (10) begin
        repeat (8) begin
          repeat (100) begin
            #10;
            `CHECK_EQUAL(out_valid, 1'b0)
          end
          in_valid = 1'b1;
          #10;
          in_valid = 1'b0;
        end
        // Each of the integrator, and comb stages add a one-sample delay. The
        // decimator also adds one sample of delay. Since this is FilterOrder 3,
        // there are 7 samples of delay (#70 of simulation time).
        #70;
        `CHECK_EQUAL(out_valid, 1'b1)
      end
    end // end of test case

    `TEST_CASE("handles_overflow") begin
      // Integrator overflow should be corrected for in the comb stages. We will
      // apply a step and verify that the output is stable and matches the
      // expected value. The DC gain of the integrator + comb stages is
      // the comb filter delay (DelayLength * DecimationFactor)^FilterOrder. The
      // compensator's DC gain is (2+A) where A is the value of the single
      // non-unity coefficient (A = -10 for a FilterOrder of 3). The total DC
      // gain we expect is therefore ((1 * 8)^3) * (2-10) = -4096.
      in = 12'd987;
      in_valid = 1'b1;
      out_ready = 1'b1;
      repeat (1000) begin
        #10;
      end
      repeat (100) begin
        `CHECK_EQUAL(out, -36'd4042752)
        #10;
      end
    end // end of test case

    `TEST_CASE("extends_sign") begin
      in = -12'd5;
      in_valid = 1'b1;
      out_ready = 1'b1;
      repeat (1000) begin
        #10;
      end
      repeat (100) begin
        `CHECK_EQUAL(out, 36'd20480)
        #10;
      end
    end // end of test case
  end

  `WATCHDOG(100ms);
endmodule
