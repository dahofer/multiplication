module Multiplication
  class Polynomial
    @coefficients = [0]
    @algorithm = :naive
    attr_reader :coefficients

    ALGORITHM_OPTIONS = [
      :naive,
      :fast_fourier,
    ]

    def initialize(coefficients, algorithm = :naive)
      while (coefficients[-1] == 0)
        coefficients.pop
      end

      if (coefficients.length == 0)
        raise "Coefficients array is empty!"
      end

      @coefficients = coefficients
      @algorithm = algorithm
    end

    def *(other_polynomial)
      self.send(:"#{@algorithm}_multiply", *[self, other_polynomial])
    end

    def naive_multiply(our_polynomial, other_polynomial)
      product = Array.new(our_polynomial.max_power + other_polynomial.max_power + 1, 0)
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
      interpolated_points = fast_fourier_transform(our_polynomial.coefficients)
      other_interpolated_points = fast_fourier_transform(other_polynomial.coefficients)
      product_points = interpolated_points.zip(other_interpolated_points).map(&:*)
      inverse_fast_fourier_transform(product_points)
    end

    def calculate_root_of_unity(size, inverse = false)
      if inverse
        # e ^ -((2 * i * pi) / n)
        Math::E ** -((2 * Math::PI * Complex(0, 1)) / size)
      else
        # e ^ ((2 * i * pi) / n)
        Math::E ** ((2 * Math::PI * Complex(0, 1)) / size)
      end
    end

    def fast_fourier_transform(coefficients, inverse = false, double = false)
      # NOTE(hofer): Pad out coefficient length to a power of 2.
      padded_length = 2 ** (Math.log2(coefficients.length).ceil)
      while coefficients.length < padded_length
        coefficients.push(0)
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
            coefficients.first + Complex(0, 1) * coefficients.last,
            coefficients.first - coefficients.last,
            coefficients.first - Complex(0, 1) * coefficients.last,
          ]
        else
          return [
            coefficients.first + coefficients.last,
            coefficients.first - coefficients.last,
          ]
        end
      end

      omega = calculate_root_of_unity(coefficients.length * (double ? 2 : 1), inverse)

      coefficients_with_powers = coefficients.zip((0..coefficients.length - 1))
      even_coefficients_with_powers, odd_coefficients_with_powers =
                                     coefficients_with_powers.partition { |pair| pair.last % 2 == 0 }
      even_points = recursive_fast_fourier_transform(even_coefficients_with_powers.map(&:first), inverse, double)
      odd_points = recursive_fast_fourier_transform(odd_coefficients_with_powers.map(&:first), inverse, double)

      multiplied_odd_points = []
      omega_power = 1
      odd_points.each do |odd_point|
        multiplied_odd_points << omega_power * odd_point
        omega_power *= omega
      end

      plus_points = even_points.zip(multiplied_odd_points).map { |pair| pair.first + pair.last }
      minus_points = even_points.zip(multiplied_odd_points).map { |pair| pair.first - pair.last }

      return plus_points.concat minus_points
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

      scaled_coefficients.map { |coefficient| coefficient.real.round }
    end

    # TODO(hofer): Speed this up using Horner's rule.
    def evaluate_at(point)
      coefficients_and_powers = @coefficients.zip((0..max_power).to_a)
      coefficients_and_powers.reduce(0) { |sum, pair| sum += (pair.first * point ** pair.last) }
    end
  end
end
