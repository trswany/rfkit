//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// clock_divider divides a clock by an even integer factor.
//
// Warning: this should not be used to generate general clock signals. Instead,
// please use the clocking peripherals provided by the part you're using and
// make sure you add the appropriate timing constraints and checks. This
// divider is being used to generate a sample clock in a UART peripheral.

module clock_divider #(parameter DIVISOR = 16)(
  output logic clk_out,
  input rst,
  input clk_in
);
  initial begin
    assert (DIVISOR % 2 == 0) else $fatal("Error: DIVISOR must be even");
  end
  logic [$clog2(DIVISOR/2)-1:0] count;
  always @(posedge clk_in) begin
    if (rst) begin
      clk_out <= 1'b0;
      count <= 0;
    end else begin
      if(count == DIVISOR/2 - 1) begin
        clk_out <= ~clk_out;
        count <= 0;
      end else begin
        count <= count + 1;
      end
    end
  end
endmodule