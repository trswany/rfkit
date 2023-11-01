//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// frequency_locked_loop corrects for carrier-frequency offset.
//
// This FLL uses a band-edge FIR filter to develop a freqeuncy offset error
// signal, filters that error signal, and then uses it to drive a numerically-
// controlled oscillator that mixes the incoming signal up or down.
//
// s(t) -> [mixer] ---------------------------------------->
//           / \                                     |
//            |                                      |
//           NCO <- Loop Filter <- Band-Edge Filter <-
//
//
// To keep the band-edge filter implementation in the FPGA easy and cheap, we
// want to use FIR filters with purely real coefficients. This can be done by
// splitting the filter into real and complex weights and then applying both
// those independently to both the I and Q data and re-assembling the parts.
// We can simplify things, though, if we look at the math we're about to do
// in the next stage.
//
//        | i(t) -> Positive Band-Edge Filter -> Magnitude^2 ->
//        |                                                   |
// s(t) - |                                                  [-] ->
//        |                                                   |
//        | q(t) -> Negative Band-Edge Filter -> Magnitude^2 ->
//
// If we do the math, we can simplify things down to this. We'll drop the
// factor of four and worry about that later.
// 4[i(t)*h_imag(t)][q(t)*h_real(t)] - 4[i(t)*h_real(t)][q(t)*h_imag(t)]
//
// Due to strong doppler effects in LEO, the CFO can be relatively high and can
// change quickly. CCSDS 401.0-B-32 recommends to plan for +/- 80kHz and
// +/- 3kHz/sec at 2GHz and altitudes less than 2e6 km.

`timescale 1ns/1ps

module frequency_locked_loop (
  input logic clk,
  input logic rst,
  input logic signed [11:0] in_i, in_q,
  input logic in_valid,
  input logic out_ready,

  output logic signed [11:0] out,
  output logic out_valid
);
  logic [11:0] out_i_real, out_i_imag, out_q_real, out_q_imag;
  logic be_out_valid, product_valid, difference_valid;
  logic [22:0] product1, product2;
  logic [23:0] difference;

  // Band-edge FIR, in-phase data, real side of filter.
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
  ) band_edge_i_real(
    .clk(clk),
    .rst(rst),
    .in(in_i),
    .out(out_i_real),
    .in_valid(in_valid),
    .out_valid(be_out_valid),
    .out_ready('1)
  );

  // Band-edge FIR, quadrature data, real side of filter.
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
  ) band_edge_q_real(
    .clk(clk),
    .rst(rst),
    .in(in_q),
    .out(out_q_real),
    .in_valid(in_valid),
    .out_valid(),
    .out_ready('1)
  );

  // Band-edge FIR, in-phase data, imaginary side of filter.
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
  ) band_edge_i_imag(
    .clk(clk),
    .rst(rst),
    .in(in_i),
    .out(out_i_imag),
    .in_valid(in_valid),
    .out_valid(),
    .out_ready('1)
  );

  // Band-edge FIR, quadrature data, imaginary side of filter.
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
  ) band_edge_q_imag(
    .clk(clk),
    .rst(rst),
    .in(in_q),
    .out(out_q_imag),
    .in_valid(in_valid),
    .out_valid(),
    .out_ready('1)
  );

  // Low-pass loop filter for the FLL error signal. Designed with:
  // generate_low_pass_filter.py --sample_rate=2e6 --num_taps=101 --cutoff=50e3
  fir #(
    .InputLengthBits(12),
    .CoefficientLengthBits(14),
    .AccumulatorLengthBits(30),
    .NumTaps(101),
    .OutputTruncationBits(18),
    .Coefficients({
      14'd83, 14'd85, 14'd86, 14'd87, 14'd87, 14'd84, 14'd78, 14'd68, 14'd53,
      14'd30, 14'd0, -14'd39, -14'd87, -14'd144, -14'd210, -14'd284, -14'd364,
      -14'd448, -14'd533, -14'd616, -14'd692, -14'd756, -14'd804, -14'd830,
      -14'd829, -14'd796, -14'd727, -14'd615, -14'd459, -14'd254, 14'd0,
      14'd305, 14'd659, 14'd1061, 14'd1507, 14'd1992, 14'd2511, 14'd3055,
      14'd3618, 14'd4188, 14'd4756, 14'd5313, 14'd5846, 14'd6347, 14'd6804,
      14'd7208, 14'd7552, 14'd7827, 14'd8028, 14'd8150, 14'd8191, 14'd8150,
      14'd8028, 14'd7827, 14'd7552, 14'd7208, 14'd6804, 14'd6347, 14'd5846,
      14'd5313, 14'd4756, 14'd4188, 14'd3618, 14'd3055, 14'd2511, 14'd1992,
      14'd1507, 14'd1061, 14'd659, 14'd305, 14'd0, -14'd254, -14'd459,
      -14'd615, -14'd727, -14'd796, -14'd829, -14'd830, -14'd804, -14'd756,
      -14'd692, -14'd616, -14'd533, -14'd448, -14'd364, -14'd284, -14'd210,
      -14'd144, -14'd87, -14'd39, 14'd0, 14'd30, 14'd53, 14'd68, 14'd78,
      14'd84, 14'd87, 14'd87, 14'd86, 14'd85, 14'd83
    })
  ) loop_filter(
    .clk(clk),
    .rst(rst),
    .in(difference[($bits(difference) - 1) -: 12]),
    .out(out),
    .in_valid(difference_valid),
    .out_valid(out_valid),
    .out_ready('1)
  );

  always @(posedge clk) begin
    if (rst) begin
      product1 <= '0;
      product2 <= '0;
      product_valid <= '0;
      difference <= '0;
      difference_valid <= '0;
    end else begin
      product1 <= out_i_imag * out_q_real;
      product2 <= out_i_real * out_q_imag;
      product_valid <= be_out_valid;

      difference = product1 - product2;
      difference_valid <= product_valid;
    end
  end

endmodule
