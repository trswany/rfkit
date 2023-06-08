//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// pulse_generator creates a one-clk pulse on a configurable period.
//
// Inputs:
// * clk: clock signal.
// * rst: synchronous reset for the generator.
//
// Outputs:
// * pulse: 1-cycle pulse that occurs every Period.
//
// Parameters:
// * Period: the period, in clk's, of the output pulse.
//
// The pulse_generator counts up to Period clock pulses and then pulses the
// pulse output for exactly one clock cycle.
//
// Warning: this should not be used to generate clock signals.

module pulse_generator #(parameter int Period = 16) (
  input logic clk,
  input logic rst,
  output logic pulse
);
  logic [$clog2(Period)-1:0] count;

  always @(posedge clk) begin
    if (rst) begin
      pulse <= 1'b0;
      count <= 0;
    end else begin
      if(count == Period - 1) begin
        pulse <= 1'b1;
        count <= 0;
      end else begin
        pulse <= 1'b0;
        count <= count + 1;
      end
    end
  end
endmodule
