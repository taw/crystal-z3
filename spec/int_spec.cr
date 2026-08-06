require "./spec_helper"

describe Z3::IntExpr do
  a = Z3.int("a")
  b = Z3.int("b")
  c = Z3.int("c")
  x = Z3.bool("x")

  it "+" do
    [a == 10, b == 20, c == a + b].should have_solution(c == 30)
    [a == 2, b == 10 + a].should have_solution(b == 12)
    [a == 2, b == a + 10].should have_solution(b == 12)
  end

  it "*" do
    [a == 10, b == 20, c == a * b].should have_solution(c == 200)
    [a == 2, b == 10 * a].should have_solution(b == 20)
    [a == 2, b == a * 10].should have_solution(b == 20)
  end

  it "-" do
    [a == 10, b == 25, c == a - b].should have_solution(c == -15)
    [a == 2, b == 10 - a].should have_solution(b == 8)
    [a == 2, b == a - 10].should have_solution(b == -8)
  end

  it "/" do
    [a ==  10, b ==  3, c == a / b].should have_solution(c ==  3)
    [a == -10, b ==  3, c == a / b].should have_solution(c == -4)
    [a ==  10, b == -3, c == a / b].should have_solution(c == -3)
    [a == -10, b == -3, c == a / b].should have_solution(c ==  4)
  end

  # Can't say these make much sense, but let's document what Z3 actually does
  it "rem" do
    [a ==  10, b ==  3, c == a.rem(b)].should have_solution(c == 10 -  3 *  3)
    [a == -10, b ==  3, c == a.rem(b)].should have_solution(c == -10 -  3 * -4)
    [a ==  10, b == -3, c == a.rem(b)].should have_solution(c == -( 10 - -3 * -3))
    [a == -10, b == -3, c == a.rem(b)].should have_solution(c == -(-10 - -3 *  4))
  end

  it "mod" do
    [a ==  10, b ==  3, c == a.mod(b)].should have_solution(c == 1)
    [a ==  10, b == -3, c == a.mod(b)].should have_solution(c == 1)
    [a == -10, b ==  3, c == a.mod(b)].should have_solution(c == 2)
    [a == -10, b == -3, c == a.mod(b)].should have_solution(c == 2)
  end

  # It doesn't match Crystal on a negative right side, but nobody does modulo a
  # negative anyway - the Python Z3 API does the same thing
  it "%" do
    [a ==  10, b ==  3, c == a % b].should have_solution(c == 1)
    [a ==  10, b == -3, c == a % b].should have_solution(c == 1)
    [a == -10, b ==  3, c == a % b].should have_solution(c == 2)
    [a == -10, b == -3, c == a % b].should have_solution(c == 2)
  end

  it "==" do
    [a == 2, b == 2, x == (a == b)].should have_solution(x == true)
    [a == 2, b == 3, x == (a == b)].should have_solution(x == false)
  end

  it "!=" do
    [a == 2, b == 2, x == (a != b)].should have_solution(x == false)
    [a == 2, b == 3, x == (a != b)].should have_solution(x == true)
  end

  it ">" do
    [a == 3, b == 2, x == (a > b)].should have_solution(x == true)
    [a == 2, b == 2, x == (a > b)].should have_solution(x == false)
    [a == 1, b == 2, x == (a > b)].should have_solution(x == false)
  end

  it ">=" do
    [a == 3, b == 2, x == (a >= b)].should have_solution(x == true)
    [a == 2, b == 2, x == (a >= b)].should have_solution(x == true)
    [a == 1, b == 2, x == (a >= b)].should have_solution(x == false)
  end

  it "<" do
    [a == 3, b == 2, x == (a < b)].should have_solution(x == false)
    [a == 2, b == 2, x == (a < b)].should have_solution(x == false)
    [a == 1, b == 2, x == (a < b)].should have_solution(x == true)
  end

  it "<=" do
    [a == 3, b == 2, x == (a <= b)].should have_solution(x == false)
    [a == 2, b == 2, x == (a <= b)].should have_solution(x == true)
    [a == 1, b == 2, x == (a <= b)].should have_solution(x == true)
  end

  it "**" do
    [a == 3, b == 4, c == (a ** b)].should have_solution(c == 81)
  end

  it "unary -" do
    [a == 3, b == -a].should have_solution(b == -3)
  end

  it "zero?" do
    [a == 0, x == a.zero?].should have_solution(x == true)
    [a == 100, x == a.zero?].should have_solution(x == false)
    [a == -200, x == a.zero?].should have_solution(x == false)
  end

  it "nonzero?" do
    [a == 0, x == a.nonzero?].should have_solution(x == false)
    [a == 100, x == a.nonzero?].should have_solution(x == true)
    [a == -200, x == a.nonzero?].should have_solution(x == true)
  end

  it "positive?" do
    [a == 0, x == a.positive?].should have_solution(x == false)
    [a == 100, x == a.positive?].should have_solution(x == true)
    [a == -200, x == a.positive?].should have_solution(x == false)
  end

  it "negative?" do
    [a == 0, x == a.negative?].should have_solution(x == false)
    [a == 100, x == a.negative?].should have_solution(x == false)
    [a == -200, x == a.negative?].should have_solution(x == true)
  end

  it "abs" do
    [a == 3, b == 2, c == (a - b).abs].should have_solution(c == 1)
    [a == 2, b == 3, c == (a - b).abs].should have_solution(c == 1)
    [a == 2, b == 2, c == (a - b).abs].should have_solution(c == 0)
  end

  # Z3 spells it the other way round, as "3 divides 12"
  it "divisible_by?" do
    [a == 12, x == a.divisible_by?(3)].should have_solution(x == true)
    [a == 12, x == a.divisible_by?(5)].should have_solution(x == false)
    [a == 0, x == a.divisible_by?(7)].should have_solution(x == true)
    [a == -12, x == a.divisible_by?(3)].should have_solution(x == true)
    [a.divisible_by?(4), a > 10, a < 15].should have_solution(a == 12)
  end

  # The divisor is a decl parameter, so it has to be printed explicitly or every
  # `divisible_by?` looks the same
  it "divisible_by? prints its parameter" do
    a.divisible_by?(3).to_s.should eq("((_ divisible 3) a)")
    a.divisible_by?(5).to_s.should eq("((_ divisible 5) a)")
  end

  it "simplify" do
    u = Z3::IntSort[5]
    v = Z3::IntSort[3]
    ((u+v).to_s).should eq("(+ 5 3)")
    ((u+v).simplify.to_s).should eq("8")
  end

  it "to_s and inspect" do
    u = Z3::IntSort[5]
    v = Z3::IntSort[-3]
    u.to_s.should eq "5"
    v.to_s.should eq "-3"
    a.to_s.should eq "a"
    u.inspect.should eq "IntExpr<5>"
    v.inspect.should eq "IntExpr<-3>"
    a.inspect.should eq "IntExpr<a>"
  end

  it "const?" do
    Z3::IntSort[5].const?.should be_true
    Z3::IntSort[-5].const?.should be_true
    (Z3::IntSort[5] + Z3::IntSort[5]).const?.should be_false
    a.const?.should be_false
    (a + b).const?.should be_false
  end

  # #value is the name every sort uses for "the Crystal object behind this literal".
  # Z3 Ints are unbounded, so it's a BigInt, and #to_i is the Int32 one.
  it "value" do
    Z3::IntSort[5].value.should eq(5)
    Z3::IntSort[-10].value.should eq(-10)
    (Z3::IntSort[2] + Z3::IntSort[2]).value.should eq(4)
    Z3::IntSort[5].value.should be_a(BigInt)
    # Bigger than any Crystal Int, and still exact
    Z3::IntSort[BigInt.new(2) ** 100].value.should eq(BigInt.new(2) ** 100)
    expect_raises(Z3::Exception){ a.value }
    expect_raises(Z3::Exception){ (a + b).value }
  end

  it "to_i / to_i64 / to_big_i" do
    Z3::IntSort[5].to_i.should eq(5)
    Z3::IntSort[-10].to_i.should eq(-10)
    (Z3::IntSort[2] + Z3::IntSort[2]).to_i.should eq(4)
    Z3::IntSort[5].to_i.should be_a(Int32)
    Z3::IntSort[5].to_i64.should be_a(Int64)
    Z3::IntSort[5].to_big_i.should be_a(BigInt)
    expect_raises(Z3::Exception){ a.to_i }
    expect_raises(Z3::Exception){ (a + b).to_i }
  end

  it "#to_real" do
    r = Z3.real("r")
    [a == 5, r == a.to_real].should have_solution(r == 5)
    [a == 5, r == a.to_real / 2].should have_solution(r == BigRational.new(5, 2))
  end

  # Takes the low bits, so it wraps rather than failing on values which don't fit
  it "#to_bv" do
    v = Z3.bitvec("v", 8)
    [a == 5, v == a.to_bv(8)].should have_solution(v == 5)
    [a == -1, v == a.to_bv(8)].should have_solution(v == 255)
    [a == 300, v == a.to_bv(8)].should have_solution(v == 44)
    a.to_bv(8).size.should eq(8)
    # The old spelling, kept as an alias
    a.to_bitvec(8).size.should eq(8)
    expect_raises(Z3::Exception) { a.to_bv(0) }
  end

  it "Z3.distinct" do
    [
      2 >= a,
      a >= b,
      b >= c,
      c >= 0,
      Z3.distinct([a, b, c]),
    ].should have_solution(
      a == 2,
      b == 1,
      c == 0
    )
  end

  it "Z3.add" do
    [
      a == 10,
      b == 20,
      c == Z3.add([a, 30, b])
    ].should have_solution(
      c == 60,
    )
    [
      a == Z3.add([] of Z3::IntExpr),
    ].should have_solution(
      a == 0,
    )
    [
      a == Z3.add([b]),
      b == 10,
    ].should have_solution(
      a == 10,
    )
    [
      a == Z3.add([10]),
    ].should have_solution(
      a == 10,
    )
  end

  it "Z3.mul" do
    [
      a == 10,
      b == 20,
      c == Z3.mul([a, 30, b])
    ].should have_solution(
      c == 6000,
    )
    [
      a == Z3.mul([] of Z3::IntExpr),
    ].should have_solution(
      a == 1,
    )
    [
      a == Z3.mul([b]),
      b == 10,
    ].should have_solution(
      a == 10,
    )
    [
      a == Z3.mul([10]),
    ].should have_solution(
      a == 10,
    )
  end
end
