//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// pulse_generator creates a one-clk pulse on a configurable interval.
//
// Warning: this should not be used to generate clock signals.

module pulse_generator #(parameter INTERVAL = 16)(
  output logic out,
  input clk,
  input rst
);
  logic [$clog2(INTERVAL)-1:0] count;
  always @(posedge clk) begin
    if (rst) begin
      out <= 1'b0;
      count <= 0;
    end else begin
      if(count == INTERVAL - 1) begin
        out <= 1'b1;
        count <= 0;
      end else begin
        out <= 1'b0;
        count <= count + 1;
      end
    end
  end
endmodule