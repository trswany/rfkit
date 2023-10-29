//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// fir_band_edge is a testbench to verify a band-edge usage of this fir.
// This is a specific implementation that will be used in a design.

// Note: VUnit automatically adds the include path for vunit_defines.svh.
`include "vunit_defines.svh"

`timescale 1ns/1ps

module fir_band_edge_tb();
  logic clk = 1'b0;
  logic rst = 1'b0;
  logic signed [11:0] in = 12'b0000_0000_0000;
  logic signed [11:0] out_real, out_imag;
  logic in_valid = 1'b1;
  logic out_ready = 1'b1;
  logic out_valid_real, out_valid_imag;

  // These filters were generated with:
  // python3 generate_band_edge_filter.py --alpha=0.5 --symbol_rate=500e3
  //                                      --sample_rate=2e6 --num_taps=19
  // With the configured "truncation bits" setting, they have a maximum gain
  // of just under unity (35515/2^16 and 34726/2^16 for the real and imaginary
  // filters, respectively).

  fir #(
    .InputLengthBits(12),
    .CoefficientLengthBits(14),
    .AccumulatorLengthBits(28),
    .NumTaps(19),
    .OutputTruncationBits(16),
    .Coefficients({
      14'd115, 14'd546, 14'd197, 14'd0, 14'd1019, 14'd0, -14'd4281,
      -14'd4549, 14'd2955, 14'd8191, 14'd2955, -14'd4549, -14'd4281,
      14'd0, 14'd1019, 14'd0, 14'd197, 14'd546, 14'd115
    })
  ) dut_real(
    .clk(clk),
    .rst(rst),
    .in(in),
    .out(out_real),
    .in_valid(in_valid),
    .out_valid(out_valid_real),
    .out_ready(out_ready)
  );

  fir #(
    .InputLengthBits(12),
    .CoefficientLengthBits(14),
    .AccumulatorLengthBits(28),
    .NumTaps(19),
    .OutputTruncationBits(16),
    .Coefficients({
      -14'd278, 14'd0, 14'd476, 14'd0, 14'd422, 14'd2730, 14'd1773,
      -14'd4549, -14'd7135, 14'd0, 14'd7135, 14'd4549, -14'd1773,
      -14'd2730, -14'd422, 14'd0, -14'd476, 14'd0, 14'd278
    })
  ) dut_imag(
    .clk(clk),
    .rst(rst),
    .in(in),
    .out(out_imag),
    .in_valid(in_valid),
    .out_valid(out_valid_imag),
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
      repeat (500) begin
        `CHECK_EQUAL(out_real, 12'b0)
        `CHECK_EQUAL(out_imag, 12'b0)
        #10;
      end
    end // end of test case

    `TEST_CASE("produces_zeroes_for_zero_input") begin
      in <= 12'b0;
      repeat (500) begin
        `CHECK_EQUAL(out_real, 12'b0)
        `CHECK_EQUAL(out_imag, 12'b0)
        #10;
      end
    end // end of test case

    `TEST_CASE("produces_correct_impulse_responses") begin
      localparam logic signed [11:0] expected_response_real[19] = {
        12'd3, 12'd17, 12'd6, 12'd0, 12'd31, 12'd0, -12'd134,
        -12'd143, 12'd92, 12'd255, 12'd92, -12'd143, -12'd134, 12'd0,
        12'd31, 12'd0, 12'd6, 12'd17, 12'd3
      };
      localparam logic signed [11:0] expected_response_imag[19] = {
        -12'd9, 12'd0, 12'd14, 12'd0, 12'd13, 12'd85, 12'd55,
        -12'd143, -12'd223, 12'd0, 12'd222, 12'd142, -12'd56, -12'd86,
        -12'd14, 12'd0, -12'd15, 12'd0, 12'd8
      };
      in <= 12'b0111_1111_1111;
      #10;
      in <= 12'b0;
      #10;
      foreach (expected_response_real[i]) begin
        `CHECK_EQUAL(out_real, expected_response_real[i])
        `CHECK_EQUAL(out_imag, expected_response_imag[i])
        #10;
      end
      `CHECK_EQUAL(out_real, 12'd0);
      `CHECK_EQUAL(out_imag, 12'd0);
    end // end of test case

    `TEST_CASE("produces_correct_dc_gain") begin
      in <= 12'b0111_1111_1111;

      // Give the filter more than enough time to fully ramp up.
      repeat (50) begin
        #10;
      end

      repeat (50) begin
        #10;
        `CHECK_EQUAL(out_real, 12'd6);
        `CHECK_EQUAL(out_imag, 12'd0);
      end
    end // end of test case
  end // end of test suite

  `WATCHDOG(100us);
endmodule
