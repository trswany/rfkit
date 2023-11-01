"""A tool to generate a basic windowed low-pass filter.

Typical usage example:
  python3 generate_low_pass_filter.py --sample_rate=2e6 --num_taps=11
                                      --cutoff=100e3
"""

from absl import app
from absl import flags
import math
import numpy
from scipy import signal
from typing import Sequence

FLAGS = flags.FLAGS
flags.DEFINE_float('sample_rate', None, 'Sampling frequency in hertz.',
                   lower_bound=0)
flags.DEFINE_float('cutoff', None, 'Cutoff frequency in hertz.',
                   lower_bound=0)
flags.DEFINE_integer('num_taps', None, 'Number of taps in the filter.',
                     lower_bound=1)
flags.DEFINE_integer('input_sample_width_bits', 12,
                     'Number of bits to use to store input samples.',
                     lower_bound=0)
flags.DEFINE_integer('coefficient_width_bits', 14,
                     'Number of bits to use to store coefficients.',
                     lower_bound=0)

flags.mark_flag_as_required('sample_rate')
flags.mark_flag_as_required('cutoff')
flags.mark_flag_as_required('num_taps')

def main(argv: Sequence[str]):
  print('Parameters:')
  print(f'- sample_rate: {FLAGS.sample_rate} samples/sec')
  print(f'- cutoff_hz: {FLAGS.cutoff} hertz')
  print(f'- num_taps: {FLAGS.num_taps}')
  print(f'- input_sample_width_bits: {FLAGS.input_sample_width_bits}')
  print(f'- coefficient_width_bits: {FLAGS.coefficient_width_bits}')

  coefficients = signal.firwin(FLAGS.num_taps, FLAGS.cutoff, width=None,
                               window='hamming', pass_zero=True,
                               scale=True, fs=FLAGS.sample_rate)
  print('Floating-point coefficients:')
  print(coefficients)

  # Scale the coefficients so they fit into N-bit 2's-complement signed ints.
  limiting_value = max(coefficients.min(), coefficients.max(), key=abs)
  max_value = (2 ** (FLAGS.coefficient_width_bits - 1)) - 1
  min_value = -(2 ** (FLAGS.coefficient_width_bits - 1))
  if limiting_value > 0:
    coefficients = (coefficients / abs(limiting_value)) * abs(max_value)
  elif limiting_value < 0:
    coefficients = (coefficients / abs(limiting_value)) * abs(min_value)

  print('Scaled floating-point coefficients:')
  print(coefficients)

  # Convert coefficients to integers.
  coefficients_fixed = (numpy.rint(coefficients)).astype(int)

  print('Fixed-point coefficients:')
  print(coefficients_fixed)

  # Maximum possible gain:
  max_gain = numpy.sum(numpy.abs(coefficients_fixed))
  print(f'Maximum gain: {max_gain} ({numpy.log2(max_gain)} bits)')

  # Word length width required for accumulators:
  max_bit_growth = numpy.ceil(numpy.log2(max_gain)).astype(int)
  print(f'Required accumulator length: {FLAGS.input_sample_width_bits + max_bit_growth} bits')

if __name__ == '__main__':
    app.run(main)