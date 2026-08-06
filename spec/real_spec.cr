require "./spec_helper"

describe Z3::RealExpr do
  a = Z3.real("a")
  b = Z3.real("b")
  c = Z3.real("c")
  x = Z3.bool("x")

  it "+" do
    [a == 2, b == 4, c == a + b].should have_solution({c => 6})
    [a == BigRational.new(1,3), b == BigRational.new(3,2), c == a + b].should have_solution({c => "11/6"})
  end

  # Crystal has no coerce protocol, so every reversed operator is spelled out
  it "operators with the literal on the left" do
    [a == 2, b == 10 + a].should have_solution({b => 12})
    [a == 2, b == 10 - a].should have_solution({b => 8})
    [a == 2, b == 10 * a].should have_solution({b => 20})
    [a == 2, b == 10 / a].should have_solution({b => 5})
    [a == 2, b == 0.5 + a].should have_solution({b => "5/2"})
    [a == 2, b == BigRational.new(1, 2) + a].should have_solution({b => "5/2"})
    [a == 2, x == (3 > a)].should have_solution({x => true})
    [a == 2, x == (3.5 <= a)].should have_solution({x => false})
    [a == 2, x == (BigRational.new(1, 2) < a)].should have_solution({x => true})
    [a == 2, x == (2 == a)].should have_solution({x => true})
    [a == 2, x == (2 != a)].should have_solution({x => false})
  end

  it "-" do
    [a == 2, b == 4, c == a - b].should have_solution({c => -2})
  end

  it "*" do
    [a == 2, b == 4, c == a * b].should have_solution({c => 8})
  end

  it "/" do
    [a ==  10, b ==  3, c == a / b].should have_solution({c => "10/3"})
    [a == -10, b ==  3, c == a / b].should have_solution({c => "-10/3"})
    [a ==  10, b == -3, c == a / b].should have_solution({c => "-10/3"})
    [a == -10, b == -3, c == a / b].should have_solution({c => "10/3"})
  end

  it "==" do
    [a == 2, b == 2, x == (a == b)].should have_solution({x => true})
    [a == 2, b == 3, x == (a == b)].should have_solution({x => false})
  end

  it "!=" do
    [a == 2, b == 2, x == (a != b)].should have_solution({x => false})
    [a == 2, b == 3, x == (a != b)].should have_solution({x => true})
  end

  it ">" do
    [a == 3, b == 2, x == (a > b)].should have_solution({x => true})
    [a == 2, b == 2, x == (a > b)].should have_solution({x => false})
    [a == 1, b == 2, x == (a > b)].should have_solution({x => false})
  end

  it ">=" do
    [a == 3, b == 2, x == (a >= b)].should have_solution({x => true})
    [a == 2, b == 2, x == (a >= b)].should have_solution({x => true})
    [a == 1, b == 2, x == (a >= b)].should have_solution({x => false})
  end

  it "<" do
    [a == 3, b == 2, x == (a < b)].should have_solution({x => false})
    [a == 2, b == 2, x == (a < b)].should have_solution({x => false})
    [a == 1, b == 2, x == (a < b)].should have_solution({x => true})
  end

  it "<=" do
    [a == 3, b == 2, x == (a <= b)].should have_solution({x => false})
    [a == 2, b == 2, x == (a <= b)].should have_solution({x => true})
    [a == 1, b == 2, x == (a <= b)].should have_solution({x => true})
  end

  it "**" do
    [a == 3, b == 4, c == (a ** b)].should have_solution({c => 81})
    [a == 81, b == 0.25, c == (a ** b)].should have_solution({c => 3})
  end

  it "zero?" do
    [a == 0, x == a.zero?].should have_solution({x => true})
    [a == 100, x == a.zero?].should have_solution({x => false})
    [a == -200, x == a.zero?].should have_solution({x => false})
  end

  it "nonzero?" do
    [a == 0, x == a.nonzero?].should have_solution({x => false})
    [a == 100, x == a.nonzero?].should have_solution({x => true})
    [a == -200, x == a.nonzero?].should have_solution({x => true})
  end

  it "positive?" do
    [a == 0, x == a.positive?].should have_solution({x => false})
    [a == 100, x == a.positive?].should have_solution({x => true})
    [a == -200, x == a.positive?].should have_solution({x => false})
  end

  it "negative?" do
    [a == 0, x == a.negative?].should have_solution({x => false})
    [a == 100, x == a.negative?].should have_solution({x => false})
    [a == -200, x == a.negative?].should have_solution({x => true})
  end

  it "abs" do
    [a == 3, b == 2, c == (a - b).abs].should have_solution({c => 1})
    [a == 2, b == 3, c == (a - b).abs].should have_solution({c => 1})
    [a == 2.5, b == -a.abs].should have_solution({b => "-5/2"})
  end

  it "integer?" do
    [a == 2.0, x == a.integer?].should have_solution({x => true})
    [a == -3, x == a.integer?].should have_solution({x => true})
    [a == 2.5, x == a.integer?].should have_solution({x => false})
    [a == BigRational.new(1, 3), x == a.integer?].should have_solution({x => false})
  end

  it "unary -" do
    [a == 3, b == -a].should have_solution({b => -3})
    [a == 0, b == -a].should have_solution({b => 0})
    [a == 3.5, b == -a].should have_solution({b => "-7/2"})
    [a == BigRational.new(4, 3), b == -a].should have_solution({b => "-4/3"})
  end

  # Many expressions will not convert to a rational with .simplify
  # Then you get a complex S-expression
  # We need to add some way to extract that
  it "to_s" do
    Z3.real(7).to_s.should eq("7")
    Z3.real(-7).to_s.should eq("-7")
    (Z3.real(10) / Z3.real(3)).simplify.to_s.should eq("10/3")
    (Z3.real(-10) / Z3.real(3)).simplify.to_s.should eq("-10/3")
  end

  # SMT-LIB's to_int rounds towards negative infinity, which is Crystal's Float#floor
  # and not Crystal's Float#to_i
  it "#floor (toward -infinity)" do
    i = Z3.int("i")
    [a == 3.7, i == a.floor].should have_solution({i => 3})
    [a == -3.2, i == a.floor].should have_solution({i => -4})
    [a == 2.0, i == a.floor].should have_solution({i => 2})
    [a == -2.0, i == a.floor].should have_solution({i => -2})
    # The old spelling, kept as an alias
    [a == -3.2, i == a.to_int].should have_solution({i => -4})
  end

  # There is no #value on Real - see #to_r and #to_f for why
  it "#to_r is exact for rationals" do
    Z3.real(7).to_r.should eq(BigRational.new(7))
    Z3.real(-7).to_r.should eq(BigRational.new(-7))
    (Z3.real(10) / Z3.real(3)).to_r.should eq(BigRational.new(10, 3))
    (Z3.real(7) / Z3.real(2)).to_r.should eq(BigRational.new(7, 2))
    Z3::RealSort[2.5].to_r.should eq(BigRational.new(5, 2))
    Z3::RealSort[BigRational.new(1, 3)].to_r.should eq(BigRational.new(1, 3))
    expect_raises(Z3::Exception) { a.to_r }
  end

  it "#to_f" do
    Z3.real(7).to_f.should eq(7.0)
    (Z3.real(7) / Z3.real(2)).to_f.should eq(3.5)
    (Z3.real(10) / Z3.real(3)).to_f.should be_close(3.3333, 0.001)
    expect_raises(Z3::Exception) { a.to_f }
  end

  describe "algebraic numbers" do
    # An irrational root, which Z3 answers with an algebraic number instead of
    # giving up. It's a perfectly good literal with no exact Crystal equivalent.
    root_two = begin
      solver = Z3::Solver.new
      solver.assert(a * a == 2)
      solver.assert(a > 0)
      solver.satisfiable?
      solver.model[a]
    end

    it "#algebraic?" do
      root_two.algebraic?.should be_true
      Z3::RealSort[2.5].algebraic?.should be_false
      Z3.real(7).algebraic?.should be_false
    end

    # The whole reason Real has no #value
    it "#to_r refuses them rather than rounding" do
      expect_raises(Z3::Exception, /algebraic number/) { root_two.to_r }
    end

    it "#to_f always works, because a Float is allowed to be approximate" do
      root_two.to_f.should be_close(Math.sqrt(2), 1e-15)
    end

    it "#lower_bound / #upper_bound bracket them" do
      root_two.lower_bound(0).should eq(BigRational.new(11, 8))
      root_two.upper_bound(0).should eq(BigRational.new(3, 2))
      (root_two.lower_bound ** 2).should be < 2
      (root_two.upper_bound ** 2).should be > 2
      # Asking for more precision has to give a tighter bracket, not a looser one
      root_two.lower_bound(30).should be > root_two.lower_bound(0)
      root_two.upper_bound(30).should be < root_two.upper_bound(0)
    end

    it "an exact value is its own bound" do
      Z3::RealSort[BigRational.new(1, 3)].lower_bound.should eq(BigRational.new(1, 3))
      Z3::RealSort[BigRational.new(1, 3)].upper_bound.should eq(BigRational.new(1, 3))
    end
  end
end
