"""A tool to generate coefficients for root-raised cosine filters.

Typical usage example:
  python3 generate_rrc_filter.py --alpha=0.5 --symbol_rate=500e3 \
                                 --sample_rate=2e6 --num_taps=20
"""

from absl import app
from absl import flags
from commpy.filters import rrcosfilter
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

# The taps of a FIR filter are the quantized values of the impulse response of
# the desired filter. We will use the scikit-commpy rrcosfilter function to
# generate the coefficients for us.

# Usually, the coefficients should have a width of 2 bits more than the input
# data word size. This limits the amount of quantization noise that is
# introduced by the filter.

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

  # Use commpy to generate the filter coefficients.
  _, coefficients = rrcosfilter(N=FLAGS.num_taps, alpha=FLAGS.alpha,
                                Ts=(1/FLAGS.symbol_rate),
                                Fs=FLAGS.sample_rate)


  # Calculate the rrc impulse response manually. I originally tried to use
  # commpy.rrcosfilter(), but it was assymetric and appears to have bugs.
  times = (numpy.arange(FLAGS.num_taps)-(FLAGS.num_taps-1)/2) / FLAGS.sample_rate
  print('Times:')
  print(times)

  # https://ntrs.nasa.gov/api/citations/20120008631/downloads/20120008631.pdf
  coefficients = numpy.zeros(FLAGS.num_taps, dtype=float)
  for index, time in enumerate(times):
    if time == 0.0:
      coefficients[index] = 1 / (2 * numpy.sqrt(1 / FLAGS.symbol_rate))
      coefficients[index] *= (1 + FLAGS.alpha * (4 / numpy.pi - 1))
    elif abs(time) == 1 / (4 * FLAGS.alpha * FLAGS.symbol_rate):
      coefficients[index] = (1 + 2 / numpy.pi) * numpy.sin(numpy.pi / (4 * FLAGS.alpha))
      coefficients[index] += (1 - 2 / numpy.pi) * numpy.cos(numpy.pi / (4 * FLAGS.alpha))
      coefficients[index] *= FLAGS.alpha / (2 * numpy.sqrt(2 / FLAGS.symbol_rate))
      coefficients[index] = -1
    else:
      coefficients[index] = 2 * FLAGS.alpha / (numpy.pi * numpy.sqrt(1 / FLAGS.symbol_rate))
      coefficients[index] *= (numpy.cos((1 + FLAGS.alpha) * numpy.pi * time * FLAGS.symbol_rate) + numpy.sin((1 - FLAGS.alpha) * numpy.pi * time * FLAGS.symbol_rate) / (4 * FLAGS.alpha * time * FLAGS.symbol_rate))
      coefficients[index] /= (1 - numpy.square(4 * FLAGS.alpha * time * FLAGS.symbol_rate))

  print('Floating-point coefficients:')
  print(coefficients)
  print(f'DC gain of floating-point coefficients: {sum(coefficients)}')

  # Scale the coefficients so they fit into 14-bit 2's-complement signed ints.
  max_abs_coefficient = numpy.max(numpy.abs(coefficients))
  print(f'max_abs_coefficient: {max_abs_coefficient}')
  max_fixed_point_coefficient_value = (2 ** (FLAGS.coefficient_width_bits - 1)) - 1
  print('Maximum value of '
        f'{FLAGS.coefficient_width_bits}-bit 2\'s-complement number: '
        f'{max_fixed_point_coefficient_value}')
  coefficients = (coefficients / max_abs_coefficient) * max_fixed_point_coefficient_value
  print(f'DC gain of scaled coefficients: {sum(coefficients)}')

  # Scale the coefficients down a bit more so that the gain is a power of 2.
  # This will allow us to get back to 0-gain by simply chopping off bits.
  num_bits_to_truncate = math.floor(math.log2(sum(coefficients)))
  print(f'Number of bits to truncate to get back to 0 gain: {num_bits_to_truncate}')
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
  worst_case_bit_growth = (FLAGS.coefficient_width_bits +
                           math.ceil(math.log2(FLAGS.num_taps)))
  print(f'Worse-case max bit growth: {worst_case_bit_growth}')
  true_max_bit_growth = math.ceil(math.log2(numpy.sum(numpy.abs(fixed_point_coefficients))))
  print(f'True max bit growth: {true_max_bit_growth}')
  print(f'Required word length of accumulators: {FLAGS.input_sample_width_bits + true_max_bit_growth}')

if __name__ == '__main__':
    app.run(main)
