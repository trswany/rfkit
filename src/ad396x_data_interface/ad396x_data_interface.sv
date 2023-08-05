//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// ad396x_data_interface is an adapter for the AD396x IC's I/Q data interface.
// This module is designed to be compatible with both the AD3961 and the AD3963.
// This module currently only supports dual-port, full-duplex, single-data rate,
// CMOS configuration but could be adapted to support more modes in the future.
// Its main purpose is to synchronize the asynchronous data bus and provide a
// standard valid/ready handshake architecture for the rest of the modules.
//
// Dual-port: use both 12-bit chip interfaces (12-bits of TX, 12-bits of RX).
// Full-duplex: both TX and RX channels are running concurrently.
// Single data rate: RX data captured on the rising edge of ad396x_data_clk.
// CMOS: the data lines are single-ended; this shouldn't affect the HDL.
//
// clk must run substantially faster than ad396x_data_clk. This interface drops
// samples in the case of RX overruns and sends garbage data in the case of TX
// underruns.
//
// * Baseband Processor (BBP) Side Inputs+Outputs
// * clk: clock. The AD396x's asynchronous inputs will be sync'ed to this clk.
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
// * ad396x_rx_data: 12-bit input, RX in-phase and quadrature samples.
// * ad396x_rx_frame: framing pulse to disambiguate I and Q RX samples.
// * ad396x_data_clk: input, clk for reading rx_data.
// * ad396x_data_clk_fb: output, sync'ed copy of ad396x_data_clk for tx data.
// * ad396x_tx_data: 12-bit output, TX in-phase and quadrature samples.
// * ad396x_tx_frame: framing pulse to disambiguate I and Q TX samples.

`timescale 1ns/1ps

module ad396x_data_interface (
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
  input logic [11:0] ad396x_rx_data,
  input logic ad396x_rx_frame,
  input logic ad396x_data_clk,
  output logic ad396x_data_clk_fb,
  output logic [11:0] ad396x_tx_data,
  output logic ad396x_tx_frame
);
  logic [11:0] ad396x_rx_data_d, ad396x_rx_data_d2;
  logic [11:0] bbp_rx_data_i_buf, bbp_tx_data_q_buf;
  logic ad396x_rx_frame_d, ad396x_rx_frame_d2;
  logic ad396x_data_clk_d, ad396x_data_clk_d2, ad396x_data_clk_d3;

  // clk_fb is just the synchronized version of data_clk.
  assign ad396x_data_clk_fb = ad396x_data_clk_d2;

  always @(posedge clk) begin
    if (rst) begin
      bbp_rx_data_i <= '0;
      bbp_rx_data_q <= '0;
      bbp_rx_data_valid <= '0;
      bbp_tx_data_ready <= '0;
      ad396x_tx_data <= '0;
      ad396x_tx_frame <= '0;
      ad396x_rx_data_d <= '0;
      ad396x_rx_data_d2 <= '0;
      ad396x_rx_frame_d <= '0;
      ad396x_rx_frame_d2 <= '0;
      ad396x_data_clk_d <= '0;
      ad396x_data_clk_d2 <= '0;
      ad396x_data_clk_d3 <= '0;
      bbp_rx_data_i_buf <= '0;
      bbp_tx_data_q_buf <= '0;
    end else begin
      // Synchronize the ad396x inputs because they're from a different domain.
      ad396x_rx_data_d2 <= ad396x_rx_data_d;
      ad396x_rx_data_d <= ad396x_rx_data;
      ad396x_rx_frame_d2 <= ad396x_rx_frame_d;
      ad396x_rx_frame_d <= ad396x_rx_frame;
      ad396x_data_clk_d3 <= ad396x_data_clk_d2;
      ad396x_data_clk_d2 <= ad396x_data_clk_d;
      ad396x_data_clk_d <= ad396x_data_clk;

      // On a data_clk rising edge, capture ad396x_rx_data. Send "valid"
      // only at the end of a frame (when both I and Q are valid). Buffer the
      // in-phase sample so that we always present a synchronized pair.
      // Warning: This implementation blindly changes the data presented
      // without waiting for a handshake; this could cause issues if the
      // client falls behind.
      if (!ad396x_data_clk_d3 && ad396x_data_clk_d2) begin
        if (ad396x_rx_frame_d2) begin
          bbp_rx_data_i_buf <= ad396x_rx_data_d2;
        end else begin
          bbp_rx_data_q <= ad396x_rx_data_d2;
          bbp_rx_data_i <= bbp_rx_data_i_buf;
          // bbp_rx_data_valid will be asserted below.
        end
      end

      // Handle the bbp_rx_data_valid handshaking.
      if (!ad396x_data_clk_d3 && ad396x_data_clk_d2 &&
          !ad396x_rx_frame_d2) begin
        // Assert data_valid if we just clocked out new data.
        bbp_rx_data_valid <= 1'b1;
      end else if (bbp_rx_data_ready && bbp_rx_data_valid) begin
        // Otherwise, clear data_valid when we get a handshake.
        bbp_rx_data_valid <= 1'b0;
      end

      // On a data_clk rising edge, send ad396x_tx_data. Buffer the quadrature
      // sample so that we send a synchronized pair. Note that we ignore the
      // valid signal - we have to send something no matter what, so we just
      // accept the fact that we might send garbage. Also note that the ready
      // signal always goes high for exactly one clock cycle per transfer.
      if (!ad396x_data_clk_d3 && ad396x_data_clk_d2) begin
        if (!ad396x_tx_frame) begin
          ad396x_tx_frame <= 1'b1;
          ad396x_tx_data <= bbp_tx_data_i;
          bbp_tx_data_q_buf <= bbp_tx_data_q;
          bbp_tx_data_ready <= 1'b1;
        end else begin
          ad396x_tx_frame <= 1'b0;
          ad396x_tx_data <= bbp_tx_data_q_buf;
          bbp_tx_data_ready <= 1'b0;
        end
      end else begin
        bbp_tx_data_ready <= 1'b0;
      end
    end
  end
endmodule

