//------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2023 Tom Swanson <trswany@gmail.com>
// SPDX-License-Identifier: MIT
//------------------------------------------------------------------------------

// cic_decimator is a parameterized multi-stage CIC decimating filter.
//
// Some notes:
// - A DecimationFactor of R means that this filter produces one output word
//   for every R-th input word. In other words, the output sample rate is 1/R
//   times the input sample rate.
// - The comb stages are placed after decimation so that they can run at the
//   reduced sample rate. This also reduces the required delay length by a
//   factor of DecimationFactor.
// - The DelayLength parameter is the actual (1/DecimationFactor reduced) delay
//   length that the comb stages will have.
// - To avoid overflow, the InternalLengthBits must be set large enough to handle
//   the bit growth from the accumulators. From the reference article:
//   "When two's complement fixed-point arithmetic is used, the number of bits
//   in an Mth-order CIC decimation filter's integrator and comb registers must
//   accommodate the filter's input signal's maximum amplitude times the
//   filter's total gain of (NR)M
// - The compensating FIR filter also adds some bit growth; see that module
//   for details.
// - This implementation is pretty simple, and there are more advanced
//   implementations that mitigate the bit-growth.
// - This module doesn't have an in_ready output because it's always ready.
// - The integrator stages will overflow, but that's expected and required.
//   Those stages must have signed overflow (no saturation), and the comb stages
//   will correct for the overflow.
// - The word length of all integrator and comb stages must match so that the
//   integrator overflow correction happens correctly in the comb stages.
//
// To pick the parameters:
// - Choose InputLengthBits and DecimationFactor as required by the design.
// - DelayLength should usually be 1 or 2. This parameter affects the frequency
//   response of each filter stage.
// - FilterOrder should be around 3. Higher orders improve the attenuation of
//   aliases but come at significant cost in terms of bit growth.
// - Set InternalLengthBits =
//     InputLengthBits + ceil(FilterOrder*log2(DelayLength * DecimationFactor))
// - Set OutputLengthBits = InternalLengthBits + growth from compensating filter
//
// References:
// - A Beginner's Guide To Cascaded Integrator-Comb (CIC) Filters
//   https://www.dsprelated.com/showarticle/1337.php
// - An Intuitive Look at Moving Average and CIC Filters
//   https://tomverbeure.github.io/2020/09/30/Moving-Average-and-CIC-Filters.html
//
// Inputs:
// * clk: clock
// * rst: synchronous reset
// * in: 2's-complement input data
// * in_valid: data will be clocked into the filter when in_valid is true
// * out_ready: downstream module is ready to clock in the output word
//
// Outputs:
// * out: 2's-complement output data
// * out_valid: a new word is being presented on the output

`timescale 1ns/1ps

module cic_decimator #(
  parameter int InputLengthBits = 12,
  parameter int DecimationFactor = 50,
  parameter int DelayLength = 1,
  parameter int FilterOrder = 3,
  parameter int InternalLengthBits = 29,  // Warning: avoid overflow, see above.
  parameter int OutputLengthBits = 36  // Warning: avoid overflow, see above.
) (
  input logic clk,
  input logic rst,
  input logic signed [InputLengthBits-1:0] in,
  output logic signed [OutputLengthBits-1:0] out,
  input logic in_valid, out_ready,
  output logic out_valid
);
  // Wires for hooking up integrators and combs.
  wire signed [InternalLengthBits-1:0] integrator_data [FilterOrder+1];
  wire integrator_data_valid [FilterOrder+1];
  wire signed [InternalLengthBits-1:0] comb_data [FilterOrder+1];
  wire comb_data_valid [FilterOrder+1];

  // Connect the input to the integrators. Make sure to sign-extend.
  assign integrator_data[0] = {{InternalLengthBits-InputLengthBits{in[InputLengthBits-1]}}, in};
  assign integrator_data_valid[0] = in_valid;

  // Integrators
  for (genvar i = 0; i < FilterOrder; i = i + 1) begin : gen_integrators
    integrator #(
      .WordLengthBits(InternalLengthBits)
    ) integrator_inst (
      .clk(clk),
      .rst(rst),
      .in(integrator_data[i]),
      .in_valid(integrator_data_valid[i]),
      .out(integrator_data[i+1]),
      .out_ready(1'b1),
      .out_valid(integrator_data_valid[i+1])
    );
  end

  // Decimator
  decimator #(
    .WordLengthBits(InternalLengthBits),
    .DecimationFactor(DecimationFactor)
  ) decimator_inst (
    .clk(clk),
    .rst(rst),
    .in(integrator_data[FilterOrder]),
    .in_valid(integrator_data_valid[FilterOrder]),
    .out(comb_data[0]),
    .out_ready(1'b1),
    .out_valid(comb_data_valid[0])
  );

  // Combs
  for (genvar j = 0; j < FilterOrder; j = j + 1) begin : gen_combs
    comb #(
      .WordLengthBits(InternalLengthBits),
      .DelayLength(DelayLength)
    ) comb_inst (
      .clk(clk),
      .rst(rst),
      .in(comb_data[j]),
      .in_valid(comb_data_valid[j]),
      .out(comb_data[j+1]),
      .out_ready(1'b1),
      .out_valid(comb_data_valid[j+1])
    );
  end

  // Compensating filter
  compensator #(
    .InputLengthBits(InternalLengthBits),
    .OutputLengthBits(OutputLengthBits),
    .FilterOrder(FilterOrder)
  ) compensator_inst (
    .clk(clk),
    .rst(rst),
    .in(comb_data[FilterOrder]),
    .in_valid(comb_data_valid[FilterOrder]),
    .out(out),
    .out_ready(out_ready),
    .out_valid(out_valid)
  );
endmodule
