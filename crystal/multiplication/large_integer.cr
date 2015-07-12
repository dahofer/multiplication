require "./polynomial"

module Multiplication
  class LargeInteger
    @value = 0

    getter :value

    def initialize(value)
      @value = value
    end

    def multiply(other_integer)
      return @value * other_integer.value
    end

    def create_polynomial(some_value, digits_per_chunk)
      digits = some_value.to_s.split.reverse
      new_base_digits = digits.each_slice(digits_per_chunk).to_a.map { |x| x.join }.map { |y| y.to_i }
      Polynomial.new(new_base_digits, :fast_fourier)
    end

    # NOTE(hofer): Fast Fourier based multiplication involves
    # operations using complex numbers in the intermediate steps.
    # This can lead to problems with numerical stability (eg overflow
    # or underflow).  To ensure the multiplication is numerically
    # stable we pick a base B proportional to log(N) + log(M) where N and M
    # are the numbers being multiplied and convert the numbers to that
    # base.  To make the conversion relatively easy we actually pick B
    # to be a power of 10.  So for instance if there were 600 digits
    # between the two numbers, we would choose B = 1000.

    # So the goal is to convert each operand to a polynomial where
    # each coefficient contains log(B) digits from the original
    # number, multiply the polynomials using the FFT, then evaluate
    # the product at B.

    # For instance, if B = 100 and we want to multiply 123,456 and
    # 890, we would convert these numbers to 12x^2 + 34x + 56 and 8x +
    # 90, multiply those two polynomials together, then evaluate the
    # product (96x^3 + 1352x^2 + 3508x + 5040) at x = 100.

    # For more details, see
    # http://numbers.computation.free.fr/Constants/Algorithms/fft.html
    def fft_multiply(other_integer)
      approximate_base_number = @value.to_s.length + other_integer.value.to_s.length
      digits_per_chunk = (Math.log10(approximate_base_number)).ceil.to_i
      our_polynomial = create_polynomial(@value, digits_per_chunk)
      other_polynomial = create_polynomial(other_integer.value, digits_per_chunk)
      product_polynomial = our_polynomial * other_polynomial

      return product_polynomial.evaluate_at(10 ** digits_per_chunk)
    end

    def split_integer(int_value)
      string_value = int_value.to_s
      chunks = string_value.split.each_slice(string_value.length / 2 + 1)
      return chunks.map(&:join).map(&:to_i)
    end

    # NOTE(hofer): (A * 10 ^ (n/2) + B) * (C * 10 ^ (n/2) + D)
    # Want: AC * 10 ^ n + (AD * BC) * 10 ^ n/2 + BD
    # This requires 3 multiplications:
    # 1. AC
    # 2. BD
    # 3. (A + B)(C + D) = AC + AD + BC + BD
    # plus 2 subtractions:
    # (3) - (1) - (2)
    def karatsuba_multiply(other_integer)
      our_chunks = split_integer(@value)
      other_chunks = split_integer(other_integer.value)
      first_part = our_chunks[0] * other_chunks[0]
      second_part = our_chunks[1] * other_chunks[1]
      total_sum = our_chunks.reduce(&:+) * other_chunks.reduce(&:+)
      third_part = total_sum - first_part - second_part

      first_part *= 10 ** (our_chunks[1].to_s.length + other_chunks[1].to_s.length)
      # TODO(hofer): Fix this.
      third_part *= 10 ** 1

      return first_part + second_part + third_part
    end
  end
end
