require 'spec_helper'

module Multiplication
  class Polynomial
    context "initialization" do
      it "truncates leading zeroes" do
        expect(Multiplication::Polynomial.new([1, 0]).to_s).to eq "1"
      end

      it "doesn't like empty arrays" do
        expect { Multiplication::Polynomial.new([]) }.to raise_error("Coefficients array is empty!")
      end
    end
    
    context "to_s" do
      def test_string_conversion(coefficients, expected_string)
        test_polynomial = Multiplication::Polynomial.new(coefficients)
        expect(test_polynomial.to_s).to eq expected_string
      end
      
      it "converts polynomials as expected" do
        test_string_conversion([3,1,2], "2x^2 + x + 3")
        test_string_conversion([-3,1,2], "2x^2 + x - 3")
        test_string_conversion([3,0,2], "2x^2 + 3")
        test_string_conversion([0,0,2], "2x^2")
        test_string_conversion([-3,0,0], "-3")
        test_string_conversion([-3,1.0,2], "2x^2 + x - 3")
        test_string_conversion([3, 1, 2, 0], "2x^2 + x + 3")
        test_string_conversion([3, 1, -2], "-2x^2 + x + 3")
      end
    end

    context "multiplication" do
      def test_multiply(coefficients1, coefficients2, expected_coefficients)
        p1 = Multiplication::Polynomial.new(coefficients1)
        p2 = Multiplication::Polynomial.new(coefficients2)
        expected_polynomial = Multiplication::Polynomial.new(expected_coefficients)
        expect((p1 * p2).to_s).to eq expected_polynomial.to_s
      end

      it "multiplies polynomials as expected" do
        test_multiply([3,1,2], [2], [6,2,4])
        test_multiply([3,1,2], [2,1,4], [6,5,17,6,8])
      end
    end
  end
end
