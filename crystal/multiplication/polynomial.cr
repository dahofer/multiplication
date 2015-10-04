require "complex"
require "big_int"

module Multiplication
  class Polynomial
    ZERO = Complex.new(0, 0)
    @coefficients = [ZERO] of Complex
    @algorithm = :naive
    @degree = 0
    getter :coefficients
    getter :degree

    ALGORITHM_OPTIONS = [
      :naive,
      :fast_fourier,
    ]

    def initialize(coefficients, algorithm = :naive)
      while (coefficients.last == ZERO)
        coefficients.pop
      end

      if (coefficients.length == 0)
        raise "Coefficients array is empty!"
      end

      @degree = coefficients.length

      @coefficients = coefficients

      @algorithm = algorithm
    end

    def *(other_polynomial)
      # self.send(:"#{@algorithm}_multiply", *[self, other_polynomial])
      if @algorithm == :naive
        self.naive_multiply(self, other_polynomial)
      elsif @algorithm == :fast_fourier
        self.fast_fourier_multiply(self, other_polynomial)
      else
        raise "Unknown multiplication algorithm: #{@algorithm}"
      end
    end

    def naive_multiply(our_polynomial, other_polynomial)
      product = Array.new(our_polynomial.max_power + other_polynomial.max_power + 1, ZERO)
      our_polynomial.coefficients.each_with_index do |coefficient, i|
        other_polynomial.coefficients.each_with_index do |other_coefficient, j|
          if !(coefficient.nil? || other_coefficient.nil?)
            product[i+j] += coefficient * other_coefficient
          end
        end
      end

      return Polynomial.new(product)
    end

    def term_to_string(pair)
      coefficient = pair.first

      return nil if (coefficient == 0 || coefficient == 0.0)

      power = pair[1]
      if (power < max_power)
        if (coefficient > 0)
          sign = "+"
        else
          sign = "-"
          coefficient *= -1
        end
      end

      string_coefficient = coefficient == 1 ? "" : coefficient.to_s

      if power == 0
        return "#{sign} #{coefficient}"
      elsif power == max_power
        return "#{string_coefficient}x^#{power}"
      elsif power == 1
        return "#{sign} #{string_coefficient}x"
      else
        return "#{sign} #{string_coefficient}x^#{power}"
      end
    end

    def to_s
      coefficients_and_powers = @coefficients.zip((0..max_power).to_a).reverse
      terms = coefficients_and_powers.map(&method(:term_to_string)).compact
      terms.join(" ").strip
    end

    def max_power
      @coefficients.length - 1
    end

    def fast_fourier_multiply(our_polynomial, other_polynomial)
      max_length = [our_polynomial.coefficients.length, other_polynomial.coefficients.length].max
      # NOTE(hofer): In case of differing lengths, pad out the
      # polynomial with the lesser max power.
      while our_polynomial.coefficients.length < max_length
        our_polynomial.coefficients << ZERO
      end
      while other_polynomial.coefficients.length < max_length
        other_polynomial.coefficients << ZERO
      end

      interpolated_points = fast_fourier_transform(our_polynomial.coefficients, false, true)
      other_interpolated_points = fast_fourier_transform(other_polynomial.coefficients, false, true)
      product_points = [] of Complex
      interpolated_points.each_with_index do |point, i|
        product_points << point * other_interpolated_points[i]
      end
      return self.class.new(inverse_fast_fourier_transform(product_points))
    end

    def calculate_root_of_unity(size, inverse = false)
      radians = (2 * Math::PI) / size
      if inverse
        # e ^ -((2 * i * pi) / n)
        radians *= -1
        Complex.new(Math.cos(radians), Math.sin(radians))
      else
        # e ^ ((2 * i * pi) / n)
        Complex.new(Math.cos(radians), Math.sin(radians))
      end
    end

    def fast_fourier_transform(coefficients, inverse = false, double = false)
      return coefficients if coefficients.length <= 1

      # NOTE(hofer): Pad out coefficient length to a power of 2.
      padded_length = 2 ** (Math.log2(coefficients.length).ceil)
      while coefficients.length < padded_length
        coefficients.push(ZERO)
      end

      return recursive_fast_fourier_transform(coefficients, inverse, double)
    end

    # NOTE(hofer): This expects coefficients.length to be a power of 2.
    def recursive_fast_fourier_transform(coefficients, inverse = false, double = false)
      # NOTE(hofer): Evaluation at the second or fourth root of unity and its
      # powers up to unity (ie i, -1, -i, 1).
      if coefficients.length == 2
        if double
          return [
            coefficients.first + coefficients.last,
            coefficients.first + coefficients.last * Complex.new(0, 1),
            coefficients.first - coefficients.last,
            coefficients.first - coefficients.last * Complex.new(0, 1),
          ] of Complex
        else
          return [
            coefficients.first + coefficients.last,
            coefficients.first - coefficients.last,
          ] of Complex
        end
      end

      omega = calculate_root_of_unity(coefficients.length * (double ? 2 : 1), inverse)

      coefficients_with_powers = coefficients.zip((0..coefficients.length - 1).to_a)
      even_coefficients_with_powers, odd_coefficients_with_powers =
                                     coefficients_with_powers.partition { |pair| pair.last % 2 == 0 }
      even_points = recursive_fast_fourier_transform(even_coefficients_with_powers.map { |x| x.first }, inverse, double)
      odd_points = recursive_fast_fourier_transform(odd_coefficients_with_powers.map { |x| x.first }, inverse, double)

      multiplied_odd_points = [] of Complex
      omega_power = Complex.new(1, 0)
      odd_points.each do |odd_point|
        multiplied_odd_points << omega_power * odd_point
        omega_power *= omega
      end

      plus_points = even_points.zip(multiplied_odd_points).map { |pair| pair.first + pair.last }
      minus_points = even_points.zip(multiplied_odd_points).map { |pair| pair.first - pair.last }

      return plus_points.concat(minus_points)
    end

    def inverse_fast_fourier_transform(points)
      unscaled_coefficients = fast_fourier_transform(points, true)
      n = unscaled_coefficients.length
      scaled_coefficients = unscaled_coefficients.map { |coefficient| coefficient / n }
      scaled_coefficients.each do |coefficient|
        raise "Unexpectedly large imaginary component! #{coefficient}" if coefficient.imag.abs > 0.001
        real_part = coefficient.real
        if (real_part - real_part.round).abs > 0.01
          raise "Real component is > 0.01 away from an integer! #{coefficient}"
        end
      end

      scaled_coefficients
    end

    # TODO(hofer): Speed this up using Horner's rule.
    def evaluate_at(point)
      result = BigInt.new(0)

      (0..@degree-1).to_a.reverse.each do |i|
        coefficient = @coefficients[i]
        next if coefficient.real.abs < 0.001
        int_coefficient = BigInt.new(coefficient.real.round.to_i64)
        int_power = BigInt.new(1)
        i.times do
          int_power *= point
        end
        power = int_coefficient * int_power
        result += power
      end

      return result
    end
  end
end
