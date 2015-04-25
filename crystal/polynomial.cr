class Polynomial
  @coefficients = [0]

  # 1.  attr_reader :coefficients

  def coefficients
    return @coefficients
  end

  def initialize(coefficients)
    while (coefficients[-1] == 0)
      coefficients.pop
    end

    if (coefficients.length == 0)
      raise "Coefficients array is empty!"
    end

    @coefficients = coefficients
  end

  def *(other_polynomial)
    naive_multiply(other_polynomial)
  end

  def naive_multiply(other_polynomial)
    product = Array.new(max_power + other_polynomial.max_power + 1, 0)
    @coefficients.each_with_index do |coefficient, i|
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
    #terms = coefficients_and_powers.map(&method(:term_to_string)).compact
    terms = coefficients_and_powers.map { |pair| term_to_string(pair) }.compact
    terms.join(" ").strip
  end

  def max_power
    @coefficients.length - 1
  end
end

a = Polynomial.new([3,1,2])
b = Polynomial.new([2,1,4])
c = a * b
if (c.to_s == "8x^4 + 6x^3 + 17x^2 + 5x + 6")
  puts "Yes!"
else
  puts "no."
  puts c.to_s
end
