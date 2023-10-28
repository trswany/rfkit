"""A tool to generate coefficients for a band-edge FIR filter.

This tool assumes that the signal has been trasmitted using a
root-raised cosine pulse-shaping filter with a known, fixed rolloff factor.

Typical usage example:
  python3 generate_band_edge_filter.py --alpha=0.5 --symbol_rate=500e3 \
                                       --sample_rate=2e6 --num_taps=21
"""

from absl import app
from absl import flags
import math
import numpy
from typing import Sequence

FLAGS = flags.FLAGS
flags.DEFINE_float('alpha', None, 'Roll-off factor of the RRC matched filter.',
                   lower_bound=0,upper_bound=1)
flags.DEFINE_float('symbol_rate', None, 'Symbol rate, in symbols/sec.',
                   lower_bound=0)
flags.DEFINE_float('sample_rate', None, 'Sampling frequency in hertz.',
                   lower_bound=0)
flags.DEFINE_integer('num_taps', None, 'Number of taps in the filter.',
                     lower_bound=1)
flags.DEFINE_integer('input_sample_width_bits', 12,
                     'Number of bits to use to store input samples.',
                     lower_bound=0)
flags.DEFINE_integer('coefficient_width_bits', 14,
                     'Number of bits to use to store coefficients.',
                     lower_bound=0)

flags.mark_flag_as_required('alpha')
flags.mark_flag_as_required('symbol_rate')
flags.mark_flag_as_required('sample_rate')
flags.mark_flag_as_required('num_taps')

def main(argv: Sequence[str]):
  print('Parameters:')
  print(f'- alpha: {FLAGS.alpha}')
  print(f'- symbol_rate: {FLAGS.symbol_rate} symbols/sec')
  print(f'- sample_rate: {FLAGS.sample_rate} samples/sec')
  print(f'- num_taps: {FLAGS.num_taps}')
  print(f'- input_sample_width_bits: {FLAGS.input_sample_width_bits}')
  print(f'- coefficient_width_bits: {FLAGS.coefficient_width_bits}')

  # The filter should be long enough to cover 2-3 symbols.
  print('Length of filter, in symbols: '
        f'{(FLAGS.num_taps / FLAGS.sample_rate) * FLAGS.symbol_rate}')

  print('Raised-cosine filter baseband bandwidth: '
          f'{(0.5 * (1 + FLAGS.alpha) * FLAGS.symbol_rate):e}')

  times = (numpy.arange(FLAGS.num_taps)-(FLAGS.num_taps-1)/2)
  print('Times:')
  print(times)

  # Generate the IDFT of a half-cycle sine wave (in the frequency domain)
  # centered around 0Hz. The ideal band-edge filter would be a quarter-sine,
  # but this is un-realizable due to the discontinuity, so we do a half-sine.
  coefficients = numpy.zeros(FLAGS.num_taps, dtype=float)
  for index, time in enumerate(times):
    coefficients[index] = numpy.sinc(2 * FLAGS.alpha * time / (FLAGS.sample_rate / FLAGS.symbol_rate) - 0.5)
    coefficients[index] += numpy.sinc(2 * FLAGS.alpha * time / (FLAGS.sample_rate / FLAGS.symbol_rate) + 0.5)

  # Shift that up to (1+alpha)*(symbol_rate/2). To accomplish this, we multiply
  # the time-domain impulse response (the coefficients) by e^(j*2*pi*phi).
  # The negative band-edge version of this (the one shifted the same amount but
  # down to negative frequencies) is just the complex conjugate of this filter.
  phi = (times * (1 + FLAGS.alpha)) / (2 * FLAGS.sample_rate / FLAGS.symbol_rate)
  coefficients = numpy.multiply(coefficients, numpy.exp(1j * 2 * numpy.pi * phi))
  print('Complex floating-point coefficients:')
  print(coefficients)

  # Now some tricks. To keep the implementation in the FPGA easy and cheap, we
  # want to use FIR filters with purely real coefficients. This can be done by
  # splitting the filter into real and complex weights and then applying both
  # those independently to both the I and Q data and re-assembling the parts.
  # We can simplify things, though, if we look at the math we're about to do
  # in the next stage.
  #
  #        | -> Positive Band-Edge Filter -> Magnitude^2 ->
  #        |                                              |
  # s(t) - |                                             [-] ->
  #        |                                              |
  #        | -> Negative Band-Edge Filter -> Magnitude^2 ->
  #
  # If we do the math, we can simplify things down to this:
  # 4[s_r(t)*h_i(t)][s_i(t)*h_r(t)] - 4[s_r(t)*h_r(t)][s_i(t)*h_i(t)]
  #
  # If we ignore the factor of 4, this results in 4 real-valued FIR filters,
  # two simple multiplies, and one subtraction.

  coeff_real = numpy.real(coefficients)
  coeff_imag = numpy.imag(coefficients)

  # Scale the coefficients so they fit into N-bit 2's-complement signed ints.
  limiting_value_real = max(coeff_real.min(), coeff_real.max(), key=abs)
  limiting_value_imag = max(coeff_imag.min(), coeff_imag.max(), key=abs)
  limiting_value = max(limiting_value_real, limiting_value_imag, key=abs)
  max_value = (2 ** (FLAGS.coefficient_width_bits - 1)) - 1
  min_value = -(2 ** (FLAGS.coefficient_width_bits - 1))
  if limiting_value > 0:
    coeff_real = (coeff_real / abs(limiting_value)) * abs(max_value)
    coeff_imag = (coeff_imag / abs(limiting_value)) * abs(max_value)
  elif limiting_value < 0:
    coeff_real = (coeff_real / abs(limiting_value)) * abs(min_value)
    coeff_imag = (coeff_imag / abs(limiting_value)) * abs(min_value)

  print('Scaled floating-point coefficients:')
  print(coeff_real)
  print(coeff_imag)

  # Convert coefficients to integers.
  coeff_real_fixed = (numpy.rint(coeff_real)).astype(int)
  coeff_imag_fixed = (numpy.rint(coeff_imag)).astype(int)

  print('Fixed-point coefficients:')
  print(coeff_real_fixed)
  print(coeff_imag_fixed)

  # Maximum possible gain:
  max_gain_real = numpy.sum(numpy.abs(coeff_real_fixed))
  max_gain_imag = numpy.sum(numpy.abs(coeff_imag_fixed))
  print(f'Maximum gain, real: {max_gain_real} ({numpy.log2(max_gain_real)} bits)')
  print(f'Maximum gain, imag: {max_gain_imag} ({numpy.log2(max_gain_imag)} bits)')

  # Word length width required for accumulators:
  max_bit_growth_real = numpy.ceil(numpy.log2(max_gain_real)).astype(int)
  max_bit_growth_imag = numpy.ceil(numpy.log2(max_gain_imag)).astype(int)
  print(f'Required accumulator length, real: {FLAGS.input_sample_width_bits + max_bit_growth_real} bits')
  print(f'Required accumulator length, imag: {FLAGS.input_sample_width_bits + max_bit_growth_imag} bits')

if __name__ == '__main__':
    app.run(main)