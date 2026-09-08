require "./spec_helper"

describe Z3::FloatExpr do
  half = Z3::FloatSort.new(:half)
  single = Z3::FloatSort.new(:single)
  double = Z3::FloatSort.new(:double)
  quadruple = Z3::FloatSort.new(:quadruple)

  a = Z3.float("a", :double)
  b = Z3.float("b", :double)
  c = Z3.float("c", :double)
  x = Z3.bool("x")
  m = Z3.rounding_mode("m")

  ties_even = Z3::RoundingModeSort.nearest_ties_even
  to_zero = Z3::RoundingModeSort.towards_zero

  positive_zero = double.positive_zero
  negative_zero = double.negative_zero
  positive_infinity = double.positive_infinity
  negative_infinity = double.negative_infinity
  nan = double.nan

  it "FloatSort.to_s" do
    Z3::FloatSort.new(5, 11).to_s.should eq("Float(5, 11)")
    Z3::FloatSort.new(15, 113).to_s.should eq("Float(15, 113)")
  end

  it "FloatSort ebits / sbits" do
    single.ebits.should eq(8)
    single.sbits.should eq(24)
    double.ebits.should eq(11)
    double.sbits.should eq(53)
  end

  it "FloatSort shortcut syntax" do
    Z3::FloatSort.new(16).should eq(half)
    Z3::FloatSort.new(32).should eq(single)
    Z3::FloatSort.new(64).should eq(double)
    Z3::FloatSort.new(128).should eq(quadruple)
    Z3::FloatSort.new(5, 11).should eq(half)
    Z3::FloatSort.new(8, 24).should eq(single)
    Z3::FloatSort.new(11, 53).should eq(double)
    Z3::FloatSort.new(15, 113).should eq(quadruple)
    half.should_not eq(single)
    double.should_not eq(quadruple)
  end

  it "FloatSort rejects unknown shortcuts" do
    expect_raises(Z3::Exception, /Unknown float type octuple/) { Z3::FloatSort.new(:octuple) }
    expect_raises(Z3::Exception, /Unknown float type 42/) { Z3::FloatSort.new(42) }
    expect_raises(Z3::Exception) { Z3::FloatSort.new(0, 0) }
  end

  describe "FloatSort#[]" do
    it "overflows to a signed infinity" do
      single[1e300].to_s.should eq("+oo")
      single[-1e300].to_s.should eq("-oo")
      # half's largest finite value is 65504
      half[70000.0].to_s.should eq("+oo")
      half[-70000.0].to_s.should eq("-oo")
      half[65504.0].to_s.should eq("1.9990234375B+15")
    end

    it "underflows to a signed zero" do
      single[1e-300].to_s.should eq("+zero")
      single[-1e-300].to_s.should eq("-zero")
      half[1e-30].to_s.should eq("+zero")
    end

    it "keeps values which fit" do
      single[1.5].to_s.should eq("1.5B+0")
      single[-7.25].to_s.should eq("-1.8125B+2")
      double[1e300].to_s.should eq("1.49322178960515028478539534262381494045257568359375B+996")
      single[3.4028234663852886e38].to_s.should eq("1.99999988079071044921875B+127")
    end

    it "passes through zeroes, infinities and NaN" do
      single[0.0].to_s.should eq("+zero")
      single[-0.0].to_s.should eq("-zero")
      single[Float64::INFINITY].to_s.should eq("+oo")
      single[-Float64::INFINITY].to_s.should eq("-oo")
      single[Float64::NAN].to_s.should eq("NaN")
    end

    # Crystal's Float64#to_f32! rounds a double to IEEE single exactly as C would,
    # so rounding first must give the same result as converting directly
    it "rounds to nearest, like Crystal and C do" do
      [0.1, 0.2, 3.14159265358979, 1e-30, 1e30, -0.1, 2.0**-140, 2.0**-149,
       1234 * 0.5**137, 1e-45, 3.5e38].each do |value|
        single[value].to_s.should eq(single[value.to_f32!.to_f64].to_s)
      end
    end

    it "answers a numeral, not an unfolded conversion" do
      [1e300, 1e-300, 0.1, 1.5, 1234 * 0.5**137].each do |value|
        single[value].const?.should be_true
      end
    end

    it "is usable in constraints" do
      f = single.var("f")
      # 1e300 is +oo in single, and nothing is greater than +oo
      [f < 1e300, f == 1.0].should have_solution(f == single[1.0])
      [f > 1e300].should have_no_solution
    end

    it "converts Integers which fit a Float64 exactly" do
      single[2].to_s.should eq("1B+1")
      double[-1024].to_s.should eq("-1B+10")
      double[(1i64 << 53)].to_s.should eq("1B+53")
      expect_raises(Z3::Exception, /no exact Float value/) { double[(1i64 << 53) + 1] }
    end

    it "rejects everything else" do
      expect_raises(Z3::Exception) { single.cast("1.5") }
      expect_raises(Z3::Exception) { single.cast(BigRational.new(1, 3)) }
      expect_raises(Z3::Exception) { single.cast(nil) }
    end

    it "rejects a float of another sort" do
      expect_raises(Z3::Exception, /Incompatible float sorts/) { single[double[1.5]] }
      single[single[1.5]].should be_same_term(single[1.5])
    end
  end

  describe "building from other sorts" do
    it "#from_ieee_bv" do
      single.from_ieee_bv(Z3::BitvecSort.new(32)[0x3F800000]).simplify.to_s.should eq("1B+0")
      single.from_ieee_bv(Z3::BitvecSort.new(32)[0xC0000000]).simplify.to_s.should eq("-1B+1")
      single.from_ieee_bv(single[-7.25].to_ieee_bv).simplify.to_s.should eq(single[-7.25].to_s)
    end

    it "#from_ieee_bv wants a Bitvec of exactly the sort's width" do
      expect_raises(Z3::Exception, "Bitvec(32) expected as an IEEE bit pattern, got Bitvec(8)") do
        single.from_ieee_bv(Z3::BitvecSort.new(8)[1])
      end
    end

    it "#from_components" do
      sign = Z3::BitvecSort.new(1)[0]
      # 128 biased is an unbiased exponent of 1, and a zero significand means 1.0
      exponent = Z3::BitvecSort.new(8)[128]
      significand = Z3::BitvecSort.new(23)[0]
      single.from_components(sign, exponent, significand).simplify.to_s.should eq("1B+1")

      original = single[-7.25]
      single.from_components(original.sign_bv, original.exponent_bv(true), original.significand_bv)
        .simplify.to_s.should eq(original.to_s)
    end

    it "#from_components checks every width" do
      ok_sign = Z3::BitvecSort.new(1)[0]
      ok_exponent = Z3::BitvecSort.new(8)[128]
      ok_significand = Z3::BitvecSort.new(23)[0]
      expect_raises(Z3::Exception, "Bitvec(1) expected as a sign, got Bitvec(8)") do
        single.from_components(ok_exponent, ok_exponent, ok_significand)
      end
      expect_raises(Z3::Exception, "Bitvec(8) expected as an exponent, got Bitvec(1)") do
        single.from_components(ok_sign, ok_sign, ok_significand)
      end
      # One narrower than sbits - IEEE doesn't store the leading bit
      expect_raises(Z3::Exception, "Bitvec(23) expected as a significand, got Bitvec(24)") do
        single.from_components(ok_sign, ok_exponent, Z3::BitvecSort.new(24)[0])
      end
    end

    it "#from_float rounds between float sorts" do
      single.from_float(double[1.5], ties_even).simplify.to_s.should eq("1.5B+0")
      single.from_float(double[1e300], ties_even).simplify.to_s.should eq("+oo")
      single.from_float(double[1.5], ties_even).sort.should eq(single)
    end

    it "#from_real rounds a Real" do
      double.from_real(BigRational.new(1, 2), ties_even).simplify.to_s.should eq("1B-1")
      double.from_real(Z3.real("r"), ties_even).sort.should eq(double)
      double.from_real(1, ties_even).simplify.to_s.should eq("1B+0")
    end

    # Reads the Bitvec as a number, where #from_ieee_bv reads the same bits as a
    # float already - so the same 8 bits give -3.0 signed and 253.0 unsigned
    it "#from_signed_bv / #from_unsigned_bv" do
      bits = Z3::BitvecSort.new(8)[-3]
      double.from_signed_bv(bits, ties_even).simplify.to_s.should eq("-1.5B+1")
      double.from_unsigned_bv(bits, ties_even).simplify.to_s.should eq("1.9765625B+7")
    end

    it "#from_significand_and_exponent" do
      double.from_significand_and_exponent(BigRational.new(5, 4), 3, ties_even).simplify.to_s.should eq("1.25B+3")
      double.from_significand_and_exponent(1, 0, ties_even).simplify.to_s.should eq("1B+0")
    end
  end

  it "add" do
    [a == 2.0, b == 4.0, c == a.add(b, m)].should have_solution(c == double[6.0])
    [a == 2.0, c == a.add(4.0, m)].should have_solution(c == double[6.0])
  end

  it "sub" do
    [a == 2.0, b == 0.5, c == a.sub(b, m)].should have_solution(c == double[1.5])
  end

  it "mul" do
    [a == -2.0, b == 0.5, c == a.mul(b, m)].should have_solution(c == double[-1.0])
  end

  it "div" do
    [a == 12.0, b == 3.0, c == a.div(b, m)].should have_solution(c == double[4.0])
  end

  it "rem" do
    [a == 13.5, b == 3.0, c == a.rem(b)].should have_solution(c == double[1.5])
  end

  # IEEE has no arithmetic which doesn't say how it rounds, so the operators refuse
  it "the arithmetic operators refuse" do
    expect_raises(Z3::Exception, /Use #add/) { a + b }
    expect_raises(Z3::Exception, /Use #sub/) { a - b }
    expect_raises(Z3::Exception, /Use #mul/) { a * b }
    expect_raises(Z3::Exception, /Use #div/) { a / b }
    expect_raises(Z3::Exception, /Use #rem/) { a % b }
  end

  it "abs" do
    [a == 7.5, c == a.abs].should have_solution(c == double[7.5])
    [a == -7.5, c == a.abs].should have_solution(c == double[7.5])
    [a == negative_infinity, c == a.abs].should have_solution(c == positive_infinity)
    # `c == nan` is false for every c, NaN included, so this asks the other way
    [a == nan, c == a.abs].should have_no_solution
  end

  it "-" do
    [a == 7.5, c == -a].should have_solution(c == double[-7.5])
    [a == -7.5, c == -a].should have_solution(c == double[7.5])
  end

  it "max" do
    [a == 2.0, b == 3.0, c == a.max(b)].should have_solution(c == double[3.0])
  end

  it "min" do
    [a == 2.0, b == 3.0, c == a.min(b)].should have_solution(c == double[2.0])
  end

  it "sqrt" do
    [a == 9.0, c == a.sqrt(ties_even)].should have_solution(c == double[3.0])
    [a == 2.0, c == a.sqrt(ties_even)].should have_solution(c == double[Math.sqrt(2)])
  end

  # Which way a tie goes is the rounding mode's business, not this method's
  it "round_to_integral" do
    [a == 2.5, c == a.round_to_integral(ties_even)].should have_solution(c == double[2.0])
    [a == 3.5, c == a.round_to_integral(ties_even)].should have_solution(c == double[4.0])
    [a == 2.9, c == a.round_to_integral(to_zero)].should have_solution(c == double[2.0])
    [a == -2.9, c == a.round_to_integral(to_zero)].should have_solution(c == double[-2.0])
  end

  it "fused_multiply_add" do
    d = double.var("d")
    [a == 2.0, b == 3.0, c == 1.0, d == a.fused_multiply_add(b, c, ties_even)]
      .should have_solution(d == double[7.0])
  end

  it "comparisons" do
    [a == 3.0, b == 3.0, x == (a >= b)].should have_solution(x == true)
    [a == 3.0, b == 3.0, x == (a > b)].should have_solution(x == false)
    [a == 3.0, b == 3.0, x == (a <= b)].should have_solution(x == true)
    [a == 3.0, b == 3.0, x == (a < b)].should have_solution(x == false)
    [a == 3.0, b == 3.0, x == (a == b)].should have_solution(x == true)
    [a == 3.0, b == 3.0, x == (a != b)].should have_solution(x == false)

    [a == 3.0, b == 2.0, x == (a >= b)].should have_solution(x == true)
    [a == 3.0, b == 2.0, x == (a > b)].should have_solution(x == true)
    [a == 3.0, b == 2.0, x == (a <= b)].should have_solution(x == false)
    [a == 3.0, b == 2.0, x == (a < b)].should have_solution(x == false)
    [a == 3.0, b == 2.0, x == (a == b)].should have_solution(x == false)
    [a == 3.0, b == 2.0, x == (a != b)].should have_solution(x == true)
  end

  # IEEE equality, not term equality
  it "== is IEEE equality" do
    [x == (positive_zero == negative_zero)].should have_solution(x == true)
    [x == (nan == nan)].should have_solution(x == false)
    [x == (nan != nan)].should have_solution(x == true)
  end

  # Crystal has no coerce protocol, so every reversed operator is spelled out.
  # Arithmetic isn't among them - it needs a rounding mode.
  it "operators with the literal on the left" do
    [a == 2.0, x == (2.0 == a)].should have_solution(x == true)
    [a == 2.0, x == (2 == a)].should have_solution(x == true)
    [a == 2.0, x == (3.0 != a)].should have_solution(x == true)
    [a == 2.0, x == (3.0 > a)].should have_solution(x == true)
    [a == 2.0, x == (3.0 >= a)].should have_solution(x == true)
    [a == 2.0, x == (3.0 < a)].should have_solution(x == false)
    [a == 2.0, x == (3 <= a)].should have_solution(x == false)
  end

  it "zero?" do
    [x == positive_zero.zero?].should have_solution(x == true)
    [x == negative_zero.zero?].should have_solution(x == true)
    [x == positive_infinity.zero?].should have_solution(x == false)
    [x == double[1.5].zero?].should have_solution(x == false)
    [x == nan.zero?].should have_solution(x == false)
  end

  # Same as positive or negative - the two zeroes and NaN are neither
  it "nonzero?" do
    [x == positive_zero.nonzero?].should have_solution(x == false)
    [x == negative_zero.nonzero?].should have_solution(x == false)
    [x == positive_infinity.nonzero?].should have_solution(x == true)
    [x == negative_infinity.nonzero?].should have_solution(x == true)
    [x == double[1.5].nonzero?].should have_solution(x == true)
    [x == nan.nonzero?].should have_solution(x == false)
  end

  it "infinite?" do
    [x == positive_zero.infinite?].should have_solution(x == false)
    [x == positive_infinity.infinite?].should have_solution(x == true)
    [x == negative_infinity.infinite?].should have_solution(x == true)
    [x == double[1.5].infinite?].should have_solution(x == false)
    [x == nan.infinite?].should have_solution(x == false)
  end

  it "nan?" do
    [x == positive_zero.nan?].should have_solution(x == false)
    [x == positive_infinity.nan?].should have_solution(x == false)
    [x == double[1.5].nan?].should have_solution(x == false)
    [x == nan.nan?].should have_solution(x == true)
  end

  it "normal?" do
    [x == positive_zero.normal?].should have_solution(x == false)
    [x == positive_infinity.normal?].should have_solution(x == false)
    [x == nan.normal?].should have_solution(x == false)
    [x == double[1.5].normal?].should have_solution(x == true)
    [x == double[1234 * 0.5**1040].normal?].should have_solution(x == false)
  end

  it "subnormal?" do
    [x == positive_zero.subnormal?].should have_solution(x == false)
    [x == positive_infinity.subnormal?].should have_solution(x == false)
    [x == nan.subnormal?].should have_solution(x == false)
    [x == double[1.5].subnormal?].should have_solution(x == false)
    [x == double[1234 * 0.5**1040].subnormal?].should have_solution(x == true)
  end

  it "positive?" do
    [x == positive_zero.positive?].should have_solution(x == true)
    [x == negative_zero.positive?].should have_solution(x == false)
    [x == positive_infinity.positive?].should have_solution(x == true)
    [x == negative_infinity.positive?].should have_solution(x == false)
    [x == double[1.5].positive?].should have_solution(x == true)
    [x == double[-1.5].positive?].should have_solution(x == false)
    [x == nan.positive?].should have_solution(x == false)
  end

  it "negative?" do
    [x == positive_zero.negative?].should have_solution(x == false)
    [x == negative_zero.negative?].should have_solution(x == true)
    [x == positive_infinity.negative?].should have_solution(x == false)
    [x == negative_infinity.negative?].should have_solution(x == true)
    [x == double[1.5].negative?].should have_solution(x == false)
    [x == double[-1.5].negative?].should have_solution(x == true)
    [x == nan.negative?].should have_solution(x == false)
  end

  # Exact, where the other direction rounds - every float is a Real.
  #
  # Simplified rather than solved like everything else in this file, because Z3
  # gets fp.to_real wrong as soon as it meets a Real constraint: asserting
  # `r == a.to_real` with `a == 0.5` gives a model saying `r = 2`, in which that
  # same constraint evaluates to false. The term built here is right, and
  # simplifying it shows that without going near the part Z3 breaks on.
  it "to_real" do
    double[2.5].to_real.simplify.to_s.should eq("5/2")
    double[-0.5].to_real.simplify.to_s.should eq("-1/2")
    double[-7.25].to_real.simplify.to_s.should eq("-29/4")
    double[-3.0].to_real.simplify.to_s.should eq("-3")
    double[0.0].to_real.simplify.to_s.should eq("0")
    a.to_real.sort.should eq(Z3::RealSort)
  end

  it "to_ieee_bv" do
    f = single.var("f")
    bv = Z3.bitvec("bv", 32)
    [f == 1.0, bv == f.to_ieee_bv].should have_solution(bv == 0x3F800000)
    [f == -2.0, bv == f.to_ieee_bv].should have_solution(bv == 0xC0000000)
    f.to_ieee_bv.sort.should eq(Z3::BitvecSort.new(32))
    a.to_ieee_bv.sort.should eq(Z3::BitvecSort.new(64))
  end

  # Rounds to an integer, where #to_ieee_bv reinterprets the very same bits
  it "to_signed_bv / to_unsigned_bv" do
    bv = Z3.bitvec("bv", 8)
    [a == 2.9, bv == a.to_unsigned_bv(8, to_zero)].should have_solution(bv == 2)
    [a == 2.9, bv == a.to_signed_bv(8, to_zero)].should have_solution(bv == 2)
    [a == -2.5, bv == a.to_signed_bv(8, to_zero)].should have_solution(bv == 254)
    [a == 2.5, bv == a.to_unsigned_bv(8, ties_even)].should have_solution(bv == 2)
    a.to_signed_bv(8, to_zero).sort.should eq(Z3::BitvecSort.new(8))
    expect_raises(Z3::Exception, /to_signed_bv/) { a.to_bv(8, ties_even) }
  end

  # The pieces #exponent_string and #significand_string give as Strings, as Bitvecs.
  # The significand is one narrower than sbits - IEEE doesn't store the leading bit.
  it "sign_bv / exponent_bv / significand_bv" do
    f = single[1.0]
    f.sign_bv.sort.should eq(Z3::BitvecSort.new(1))
    f.exponent_bv(true).sort.should eq(Z3::BitvecSort.new(8))
    f.significand_bv.sort.should eq(Z3::BitvecSort.new(23))
    f.sign_bv.unsigned_value.should eq(0)
    f.exponent_bv(true).unsigned_value.should eq(127)
    f.significand_bv.unsigned_value.should eq(0)
    single[-1.0].sign_bv.unsigned_value.should eq(1)
  end

  it "exponent_string / significand_string" do
    single[-7.25].significand_string.should eq("1.8125")
    single[-7.25].exponent_string(false).should eq("2")
    single[-7.25].exponent_string(true).should eq("129")
    # Both only work on a literal, and Z3 says so itself for anything else
    expect_raises(Z3::Exception) { a.significand_string }
  end

  # A Crystal Float64 is an IEEE double, so a double or narrower always converts
  it "value" do
    double[1.5].value.should eq(1.5)
    double[-7.25].value.should eq(-7.25)
    double[0.1].value.should eq(0.1)
    double[Float64::MAX].value.should eq(Float64::MAX)
    single[0.1].value.should eq(0.10000000149011612)
    half[1.5].value.should eq(1.5)
    double[1.5].to_f.should eq(1.5)
  end

  # Subnormals go through the same code, with the significand below 1 and the
  # exponent stuck at the sort's minimum
  it "value of subnormals" do
    double[1234 * 0.5**1040].value.should eq(1234 * 0.5**1040)
    single[1234 * 0.5**137].value.should eq(1234 * 0.5**137)
    half[2.0**-24].value.should eq(2.0**-24)
  end

  # Crystal has all of these too, and the two zeroes are different Float64s
  it "value of zeroes, infinities and NaN" do
    positive_zero.value.should eq(0.0)
    negative_zero.value.should eq(-0.0)
    (1 / positive_zero.value).should eq(Float64::INFINITY)
    (1 / negative_zero.value).should eq(-Float64::INFINITY)
    positive_infinity.value.should eq(Float64::INFINITY)
    negative_infinity.value.should eq(-Float64::INFINITY)
    nan.value.nan?.should be_true
  end

  # It's the sort which has to fit, not the value - a quadruple's 1.5 would convert
  # exactly, but a sort a Float64 can't round-trip doesn't get a #value which works
  # only for the values which happen to be small enough
  it "value of sorts wider than a double" do
    expect_raises(Z3::Exception, /Float\(15, 113\) values don't fit in a Crystal Float64/) { quadruple[1.5].value }
    expect_raises(Z3::Exception, /don't fit in a Crystal Float64/) { quadruple.nan.value }
    expect_raises(Z3::Exception, /don't fit/) { Z3::FloatSort.new(12, 53)[1.5].value }
    expect_raises(Z3::Exception, /don't fit/) { Z3::FloatSort.new(11, 54)[1.5].value }
    Z3::FloatSort.new(11, 53)[1.5].value.should eq(1.5)
    Z3::FloatSort.new(8, 24)[1.5].value.should eq(1.5)
  end

  # Every float literal is an application, so this can't lean on the AST kind
  it "value of expressions" do
    double[2.0].add(double[0.5], ties_even).value.should eq(2.5)
    expect_raises(Z3::Exception, /Can't convert expression a into a Float64/) { a.value }
    expect_raises(Z3::Exception, /Can't convert expression/) { a.add(b, ties_even).value }
  end

  it "value out of a model" do
    solver = Z3::Solver.new
    solver.assert a == 1.25
    solver.satisfiable?.should be_true
    solver.model[a].value.should eq(1.25)
    solver.model[a].sort.should eq(double)
  end

  it "to_s" do
    double[1.0].to_s.should eq("1B+0")
    double[2.0].to_s.should eq("1B+1")
    double[0.5].to_s.should eq("1B-1")
    positive_zero.to_s.should eq("+zero")
    negative_zero.to_s.should eq("-zero")
    positive_infinity.to_s.should eq("+oo")
    negative_infinity.to_s.should eq("-oo")
    nan.to_s.should eq("NaN")
    a.to_s.should eq("a")

    # Subnormals
    double[1234 * 0.5**1040].to_s.should eq("0.00470733642578125B-1022")
    single[1234 * 0.5**136].to_s.should eq("1.205078125B-126")
    single[1234 * 0.5**137].to_s.should eq("0.6025390625B-126")
    single[1234 * 0.5**138].to_s.should eq("0.30126953125B-126")
  end

  it "to_s of negative numerals" do
    double[-1.0].to_s.should eq("-1B+0")
    double[-2.0].to_s.should eq("-1B+1")
    double[-0.5].to_s.should eq("-1B-1")
    double[-7.5].to_s.should eq("-1.875B+2")
    single[-1.5].to_s.should eq("-1.5B+0")
  end

  it "inspect" do
    double[1.5].inspect.should eq("FloatExpr(11, 53)<1.5B+0>")
  end

  it "ite" do
    [x == true, c == x.ite(a, b), a == 1.5, b == 2.5].should have_solution(c == double[1.5])
    [x == false, c == x.ite(a, 2.5)].should have_solution(c == double[2.5])
    [x == true, c == x.ite(1.5, b)].should have_solution(c == double[1.5])
    [x == true, c == x.ite(2, b)].should have_solution(c == double[2.0])
  end

  # Z3's own `distinct`, which is term inequality - so it tells the zeroes apart
  # where `==` does not
  it "distinct" do
    [Z3.distinct([a, b, c]), a == 1.0, b == 2.0].should have_solution(c != double[1.0], c != double[2.0])
    [Z3.distinct([positive_zero, negative_zero])].should have_solution(x == x)
    [Z3.distinct([a, b]), a == positive_zero, b == negative_zero].should have_solution(b.negative?)
  end

  it "same_term?" do
    double[1.5].should be_same_term(double[1.5])
    double[1.5].should_not be_same_term(double[2.5])
    # The one equality which tells the zeroes apart and says NaN is NaN
    positive_zero.should_not be_same_term(negative_zero)
    nan.should be_same_term(double.nan)
  end

  it "sorts of different widths don't mix" do
    expect_raises(Z3::Exception, /Incompatible float sorts/) { a == single[1.5] }
    expect_raises(Z3::Exception, /Incompatible float sorts/) { a.add(single[1.5], ties_even) }
  end
end
