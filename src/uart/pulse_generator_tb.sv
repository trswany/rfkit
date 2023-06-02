//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// pulse_generator_tb is a testbench to verify the pulse_generator.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module pulse_generator_tb();
  logic rst = 1'b0;
  logic clk = 1'b0;
  logic out_3;
  logic out_16;

  pulse_generator #(.INTERVAL(3)) dut_3(
    .out(out_3),
    .rst(rst),
    .clk(clk)
  );

  pulse_generator #(.INTERVAL(16)) dut_16(
    .out(out_16),
    .rst(rst),
    .clk(clk)
  );

  always begin
    #5;
    clk <= !clk;
  end

  `TEST_SUITE begin
    `TEST_SUITE_SETUP begin
      rst <= 1'b1;
      #10;
      rst <= 1'b0;
      #10;
    end

    `TEST_CASE("stays_in_reset") begin
      rst <= 1'b1;  // Keep the rst signal asserted.
      repeat (100) begin
        #10
        `CHECK_EQUAL(out_3, 1'b0);
        `CHECK_EQUAL(out_16, 1'b0);
      end
    end // end of test case

    `TEST_CASE("generates_pulse_every_3") begin
      repeat (10) begin
        repeat(2) begin
          `CHECK_EQUAL(out_3, 1'b0);
          #10;
        end
        `CHECK_EQUAL(out_3, 1'b1);
        #10;
      end
    end // end of test case

    `TEST_CASE("generates_pulse_every_16") begin
      repeat (10) begin
        repeat(15) begin
          `CHECK_EQUAL(out_16, 1'b0);
          #10;
        end
        `CHECK_EQUAL(out_16, 1'b1);
        #10;
      end
    end // end of test case
  end

  `WATCHDOG(5000ns);
endmodule

