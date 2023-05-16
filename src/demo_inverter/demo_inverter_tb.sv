//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// demo_inverter_tb is a testbench to verify the demo_inverter.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module demo_inverter_tb();
  logic in, out;
  demo_inverter dut(.in(in), .out(out));

  `TEST_SUITE begin
    `TEST_CASE("inverts") begin
      begin
        in <= 1'b0;
        #10;
        `CHECK_EQUAL(out, 1'b1, "diagnostic message");
        #10;
        in <= 1'b1;
        #10;
        `CHECK_EQUAL(out, 1'b0, "diagnostic message");
      end
    end // end of test case
  end

  `WATCHDOG(100ns);
endmodule

