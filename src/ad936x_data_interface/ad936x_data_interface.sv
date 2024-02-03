//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// ad936x_data_interface is an adapter for the ad936x IC's I/Q data interface.
// This module is designed to be compatible with both the ad9361 and the ad9363.
// This module currently only supports dual-port, full-duplex, single-data rate,
// CMOS configuration but could be adapted to support more modes in the future.
// Its main purpose is to synchronize the external data bus to the FPGA clock
// and provide a standard valid/ready handshake for the rest of the modules.
//
// Dual-port: use both 12-bit chip interfaces (12-bits of TX, 12-bits of RX).
// Full-duplex: both TX and RX channels are running concurrently.
// Single data rate: RX data captured on the rising edge of ad936x_data_clk.
// CMOS: the data lines are single-ended; this shouldn't affect the HDL.
// Frame pulse mode: the frame signals pulse with a 50% duty cycle.
//
// clk must run substantially faster than ad936x_data_clk. This interface drops
// samples in the case of RX overruns and sends garbage data in the case of TX
// underruns.
//
// * Baseband Processor (BBP) Side Inputs+Outputs
// * clk: clock. The ad936x's asynchronous inputs will be sync'ed to this clk.
// * rst: synchronous reset for the interface
// * bbp_rx_data_i: 12-bit output, RX in-phase sample.
// * bbp_rx_data_q: 12-bit output, RX quadrature sample.
// * bbp_rx_data_ready: input, indicates rx data is ready to be clocked in.
// * bbp_rx_data_valid: output, indicates rx data has been clocked in.
// * bbp_tx_data_i: 12-bit input, TX in-phase sample.
// * bbp_tx_data_q: 12-bit input, TX quadrature sample.
// * bbp_tx_data_ready: output, indicates tx data is ready to be clocked in.
// * bbp_tx_data_valid: input, indicates tx data has been clocked in.
//
// * AD936x Side Inputs+Outputs
// * ad936x_rx_data: 12-bit input, RX in-phase and quadrature samples.
// * ad936x_rx_frame: framing pulse to disambiguate I and Q RX samples.
// * ad936x_data_clk: input, clk for reading rx_data.
// * ad936x_data_clk_fb: output, sync'ed copy of ad936x_data_clk for tx data.
// * ad936x_tx_data: 12-bit output, TX in-phase and quadrature samples.
// * ad936x_tx_frame: framing pulse to disambiguate I and Q TX samples.

`timescale 1ns/1ps

module ad936x_data_interface (
  input logic clk,
  input logic rst,

  // Baseband Processor (BBP) Side
  output logic [11:0] bbp_rx_data_i,
  output logic [11:0] bbp_rx_data_q,
  input logic bbp_rx_data_ready,
  output logic bbp_rx_data_valid,
  input logic [11:0] bbp_tx_data_i,
  input logic [11:0] bbp_tx_data_q,
  output logic bbp_tx_data_ready,
  input logic bbp_tx_data_valid,

  // AD936x Side
  input logic [11:0] ad936x_rx_data,
  input logic ad936x_rx_frame,
  input logic ad936x_data_clk,
  output logic ad936x_data_clk_fb,
  output logic [11:0] ad936x_tx_data,
  output logic ad936x_tx_frame
);
  logic [11:0] ad936x_rx_data_d, ad936x_rx_data_d2, ad936x_rx_data_d3;
  logic [11:0] bbp_rx_data_i_buf, bbp_tx_data_q_buf;
  logic ad936x_rx_frame_d, ad936x_rx_frame_d2, ad936x_rx_frame_d3;
  logic ad936x_data_clk_d, ad936x_data_clk_d2, ad936x_data_clk_d3;

  // clk_fb is just the synchronized version of data_clk.
  assign ad936x_data_clk_fb = ad936x_data_clk_d2;

  always @(posedge clk) begin
    if (rst) begin
      bbp_rx_data_i <= '0;
      bbp_rx_data_q <= '0;
      bbp_rx_data_valid <= '0;
      bbp_tx_data_ready <= '0;
      ad936x_tx_data <= '0;
      ad936x_tx_frame <= '0;
      ad936x_rx_data_d <= '0;
      ad936x_rx_data_d2 <= '0;
      ad936x_rx_data_d3 <= '0;
      ad936x_rx_frame_d <= '0;
      ad936x_rx_frame_d2 <= '0;
      ad936x_rx_frame_d3 <= '0;
      ad936x_data_clk_d <= '0;
      ad936x_data_clk_d2 <= '0;
      ad936x_data_clk_d3 <= '0;
      bbp_rx_data_i_buf <= '0;
      bbp_tx_data_q_buf <= '0;
    end else begin
      // Synchronize the ad936x inputs because they're from a different domain.
      // Every external signal should go through 2 flip flops before access.
      ad936x_rx_data_d3 <= ad936x_rx_data_d2;
      ad936x_rx_data_d2 <= ad936x_rx_data_d;
      ad936x_rx_data_d <= ad936x_rx_data;
      ad936x_rx_frame_d3 <= ad936x_rx_frame_d2;
      ad936x_rx_frame_d2 <= ad936x_rx_frame_d;
      ad936x_rx_frame_d <= ad936x_rx_frame;
      ad936x_data_clk_d3 <= ad936x_data_clk_d2;
      ad936x_data_clk_d2 <= ad936x_data_clk_d;
      ad936x_data_clk_d <= ad936x_data_clk;

      // On a data_clk rising edge, capture ad936x_rx_data. Send "valid"
      // only at the end of a frame (when both I and Q are valid). Buffer the
      // in-phase sample so that we always present a synchronized pair.
      // Note: The AD9363 has a minimum hold time of 0ns, so we need to take
      // the data and rx_frame values from one clock cycle earlier to avoid
      // sampling the input during the transition.
      // Warning: This implementation blindly changes the data presented
      // without waiting for a handshake; this could cause issues if the
      // client falls behind.
      if (!ad936x_data_clk_d3 && ad936x_data_clk_d2) begin
        if (ad936x_rx_frame_d3) begin
          bbp_rx_data_i_buf <= ad936x_rx_data_d3;
        end else begin
          bbp_rx_data_q <= ad936x_rx_data_d3;
          bbp_rx_data_i <= bbp_rx_data_i_buf;
          // bbp_rx_data_valid will be asserted below.
        end
      end

      // Handle the bbp_rx_data_valid handshaking.
      if (!ad936x_data_clk_d3 && ad936x_data_clk_d2 &&
          !ad936x_rx_frame_d3) begin
        // Assert data_valid if we just clocked out new data.
        bbp_rx_data_valid <= 1'b1;
      end else if (bbp_rx_data_ready && bbp_rx_data_valid) begin
        // Otherwise, clear data_valid when we get a handshake.
        bbp_rx_data_valid <= 1'b0;
      end

      // On a data_clk rising edge, send ad936x_tx_data. Buffer the quadrature
      // sample so that we send a synchronized pair. Note that we ignore the
      // valid signal - we have to send something no matter what, so we just
      // accept the fact that we might send garbage. Also note that the ready
      // signal always goes high for exactly one clock cycle per transfer.
      if (!ad936x_data_clk_d3 && ad936x_data_clk_d2) begin
        if (!ad936x_tx_frame) begin
          ad936x_tx_frame <= 1'b1;
          ad936x_tx_data <= bbp_tx_data_i;
          bbp_tx_data_q_buf <= bbp_tx_data_q;
          bbp_tx_data_ready <= 1'b1;
        end else begin
          ad936x_tx_frame <= 1'b0;
          ad936x_tx_data <= bbp_tx_data_q_buf;
          bbp_tx_data_ready <= 1'b0;
        end
      end else begin
        bbp_tx_data_ready <= 1'b0;
      end
    end
  end
endmodule

