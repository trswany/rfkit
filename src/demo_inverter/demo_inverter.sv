//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// demo_inverter is an unnecessary implementation of a not gate that is being
// used as an initial bringup module for the build and test tooling. This module
// is not intended to be used in any designs.

`timescale 1ns/1ps

module demo_inverter (output logic out, input in);
  always_comb begin
    out <= in ? 1'b0 : 1'b1;
  end
endmodule

