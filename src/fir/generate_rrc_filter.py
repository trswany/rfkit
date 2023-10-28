"""A tool to generate coefficients for root-raised cosine filters.

Usually, the coefficients should have a width of 2 bits more than the input
data word size. This limits the amount of quantization noise that is introduced
by the filter.

Matching filters should usually have an odd number of taps so that the filter
delay is an integer number of samples. This provides a sample at the symbol's
ideal sampling point and makes symbol decoding more accurate.

Typical usage example:
  python3 generate_rrc_filter.py --alpha=0.5 --symbol_rate=500e3 \
                                 --sample_rate=2e6 --num_taps=21
"""

from absl import app
from absl import flags
import math
import numpy
from typing import Sequence

FLAGS = flags.FLAGS
flags.DEFINE_float('alpha', None, 'Roll-off factor.',
                   lower_bound=0,upper_bound=1)
flags.DEFINE_float('symbol_rate', None, 'Symbol rate, in symbols/sec.',
                   lower_bound=0)
flags.DEFINE_float('sample_rate', None, 'Sampling frequency in hertz.',
                   lower_bound=0)
flags.DEFINE_integer('num_taps', None, 'Number of taps in the filter.',
                     lower_bound=0)
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

  # Calculate the rrc impulse response manually. I originally tried to use
  # commpy.rrcosfilter(), but it was assymetric and appears to have bugs.
  # The taps of a FIR filter are the quantized values of the impulse response
  # of the desired filter.
  times = (numpy.arange(FLAGS.num_taps)-(FLAGS.num_taps-1)/2) / FLAGS.sample_rate
  print('Times:')
  print(times)

  coefficients = numpy.zeros(FLAGS.num_taps, dtype=float)
  for index, time in enumerate(times):
    if time == 0.0:
      coefficients[index] = (1 - FLAGS.alpha) + ((4 * FLAGS.alpha) / numpy.pi)
    elif abs(time) == 1 / (4 * FLAGS.alpha * FLAGS.symbol_rate):
      coefficients[index] = (1 + 2 / numpy.pi) * numpy.sin(numpy.pi / (4 * FLAGS.alpha))
      coefficients[index] += (1 - 2 / numpy.pi) * numpy.cos(numpy.pi / (4 * FLAGS.alpha))
      coefficients[index] *= FLAGS.alpha / numpy.sqrt(2)
    else:
      coefficients[index] = numpy.sin(numpy.pi * time * FLAGS.symbol_rate * (1 - FLAGS.alpha))
      coefficients[index] += 4 * FLAGS.alpha * time * FLAGS.symbol_rate * numpy.cos(numpy.pi * time * FLAGS.symbol_rate * (1 + FLAGS.alpha))
      coefficients[index] /= numpy.pi * time * FLAGS.symbol_rate * (1 - numpy.square(4 * FLAGS.alpha * time * FLAGS.symbol_rate))

  print('Floating-point coefficients:')
  print(coefficients)
  print(f'DC gain of floating-point coefficients: {sum(coefficients)}')

  # Scale the coefficients so they fit into 14-bit 2's-complement signed ints.
  limiting_value = max(coefficients.min(), coefficients.max(), key=abs)
  print(f'Limiting coefficient value: {limiting_value}')
  max_value = (2 ** (FLAGS.coefficient_width_bits - 1)) - 1
  min_value = -(2 ** (FLAGS.coefficient_width_bits - 1))
  if limiting_value > 0:
    coefficients = (coefficients / abs(limiting_value)) * abs(max_value)
  elif limiting_value < 0:
    coefficients = (coefficients / abs(limiting_value)) * abs(min_value)
  print(f'DC gain of scaled coefficients: {sum(coefficients)}')
  print(f'Max gain of scaled coefficients: {sum(numpy.abs(coefficients))}')

  # Scale the coefficients down a bit more so that the gain is a power of 2.
  # This will allow us to get back to 0-gain by simply chopping off bits.
  num_bits_to_truncate = math.floor(math.log2(sum(coefficients)))
  coefficients = ((coefficients / sum(coefficients)) * (2 ** num_bits_to_truncate))
  print(f'DC gain of scaled coefficients: {sum(coefficients)}')

  # Convert the coefficients to fixed-point.
  fixed_point_coefficients = (coefficients).astype(int)
  print('Fixed-point coefficients:')
  print(fixed_point_coefficients)
  print(f'DC gain of fixed-point coefficients: {sum(fixed_point_coefficients)}')

  print('Fixed-point coefficients for copying to verilog:')
  for coefficient in fixed_point_coefficients:
    print(f'{coefficient:+}')

  # Calculate how much the width of the data will need to grow to avoid losing
  # any precision. The final output word length is the original word length
  # plus this "bit growth" number.
  max_bit_growth = math.ceil(math.log2(numpy.sum(numpy.abs(fixed_point_coefficients))))
  print(f'Max bit growth: {max_bit_growth}')
  print(f'Required word length of accumulators: {FLAGS.input_sample_width_bits + max_bit_growth}')
  print(f'Number of bits to truncate to get back to unity DC gain: {num_bits_to_truncate}')

if __name__ == '__main__':
    app.run(main)
