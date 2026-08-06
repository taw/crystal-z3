require "./spec_helper"

describe Z3::BitvecExpr do
  a = Z3.bitvec("a", 8)
  b = Z3.bitvec("b", 8)
  c = Z3.bitvec("c", 8)
  d = Z3.bitvec("d", 12)
  e = Z3.bitvec("e", 4)
  x = Z3.bool("x")
  bv8 = Z3::BitvecSort.new(8)

  it "==" do
    [a == 2, b == -254, x == (a == b)].should have_solution(x == true)
    [a == 2, b == 2, x == (a == b)].should have_solution(x == true)
    [a == 2, b == 3, x == (a == b)].should have_solution(x == false)
  end

  it "!=" do
    [a == 2, b == -254, x == (a != b)].should have_solution(x == false)
    [a == 2, b == 2, x == (a != b)].should have_solution(x == false)
    [a == 2, b == 3, x == (a != b)].should have_solution(x == true)
  end

  it "+" do
    [a == 2, b == 40, c == (a + b)].should have_solution(c == 42)
    [a == 200, b == 40, c == (a + b)].should have_solution(c == 240)
    [a == -1, b == -1, c == (a + b)].should have_solution(c == 254)
  end

  it "-" do
    [a == 50, b == 8, c == (a - b)].should have_solution(c == 42)
    [a == 200, b == 40, c == (a - b)].should have_solution(c == 160)
    [a == 40, b == 200, c == (a - b)].should have_solution(c == 96)
  end

  it "*" do
    [a == 3, b == 40, c == (a * b)].should have_solution(c == 120)
    [a == 30, b == 42, c == (a * b)].should have_solution(c == 236)
  end

  it "/" do
    expect_raises(Z3::Exception) { a / b }
    [a == 200, b == 20, c == a.unsigned_div(b)].should have_solution(c == 10)
    [a == 200, b == 20, c == a.signed_div(b)].should have_solution(c == 254)
  end

  it "%" do
    expect_raises(Z3::Exception) { a % b }
    [a == 200, b == 20, c == a.signed_mod(b)].should have_solution(c == 4)
    [a == 200, b == 20, c == a.signed_rem(b)].should have_solution(c == 240)
    [a == 200, b == 20, c == a.unsigned_rem(b)].should have_solution(c == 0)
  end

  # Crystal has no coerce protocol, so every reversed operator is spelled out.
  # A literal takes its size from the expression it's paired with.
  it "operators with the literal on the left" do
    [a == 2, b == 40 + a].should have_solution(b == 42)
    [a == 8, b == 50 - a].should have_solution(b == 42)
    [a == 3, b == 40 * a].should have_solution(b == 120)
    [a == 50, b == 27 & a].should have_solution(b == 18)
    [a == 50, b == 27 | a].should have_solution(b == 59)
    [a == 50, b == 27 ^ a].should have_solution(b == 41)
    [a == 2, x == (2 == a)].should have_solution(x == true)
    [a == 2, x == (3 != a)].should have_solution(x == true)
  end

  it "&" do
    [a == 50, b == 27, c == (a & b)].should have_solution(c == 18)
  end

  it "|" do
    [a == 50, b == 27, c == (a | b)].should have_solution(c == 59)
  end

  it "^" do
    [a == 50, b == 27, c == (a ^ b)].should have_solution(c == 41)
  end

  it "xnor" do
    [a == 50, b == 27, c == a.xnor(b)].should have_solution(c == 214)
  end

  it "nand" do
    [a == 50, b == 27, c == a.nand(b)].should have_solution(c == 237)
  end

  it "nor" do
    [a == 50, b == 27, c == a.nor(b)].should have_solution(c == 196)
  end

  it "unary -" do
    [a == 50, b == -a].should have_solution(b == 206)
  end

  # ! can't be overriden in Crystal
  it "~" do
    [a == 50, b == ~a].should have_solution(b == 205)
  end

  it ">> (sign-dependent)" do
    [a == 234, b == 2, c == a.unsigned_rshift(b)].should have_solution(c == 58)
    [a == 234, b == 2, c == a.signed_rshift(b)].should have_solution(c == 250)
    expect_raises(Z3::Exception) { a.rshift(b) }
    expect_raises(Z3::Exception) { a >> b }
  end

  # There's only one way to shift left so these are all aliases
  # but it would be confusing API to have different names for left and right shifts
  it "<< (sign-independent)" do
    [a == 234, b == 2, c == a.signed_lshift(b)].should have_solution(c == 168)
    [a == 234, b == 2, c == a.unsigned_lshift(b)].should have_solution(c == 168)
    [a == 234, b == 2, c == a.lshift(b)].should have_solution(c == 168)
    [a == 234, b == 2, c == (a << b)].should have_solution(c == 168)
  end

  it ">" do
    expect_raises(Z3::Exception) { a > b }
    [a == 100, b ==  20, x == a.unsigned_gt(b)].should have_solution(x == true)
    [a == 100, b == 100, x == a.unsigned_gt(b)].should have_solution(x == false)
    [a == 100, b == 120, x == a.unsigned_gt(b)].should have_solution(x == false)
    [a == 100, b == 200, x == a.unsigned_gt(b)].should have_solution(x == false)
    [a == 100, b ==  20, x == a.signed_gt(b)].should have_solution(x == true)
    [a == 100, b == 100, x == a.signed_gt(b)].should have_solution(x == false)
    [a == 100, b == 120, x == a.signed_gt(b)].should have_solution(x == false)
    [a == 100, b == 200, x == a.signed_gt(b)].should have_solution(x == true)
  end

  it ">=" do
    expect_raises(Z3::Exception) { a >= b }
    [a == 100, b ==  20, x == a.unsigned_ge(b)].should have_solution(x == true)
    [a == 100, b == 100, x == a.unsigned_ge(b)].should have_solution(x == true)
    [a == 100, b == 120, x == a.unsigned_ge(b)].should have_solution(x == false)
    [a == 100, b == 200, x == a.unsigned_ge(b)].should have_solution(x == false)
    [a == 100, b ==  20, x == a.signed_ge(b)].should have_solution(x == true)
    [a == 100, b == 100, x == a.signed_ge(b)].should have_solution(x == true)
    [a == 100, b == 120, x == a.signed_ge(b)].should have_solution(x == false)
    [a == 100, b == 200, x == a.signed_ge(b)].should have_solution(x == true)
  end

  it "<" do
    expect_raises(Z3::Exception) { a < b }
    [a == 100, b ==  20, x == a.unsigned_lt(b)].should have_solution(x == false)
    [a == 100, b == 100, x == a.unsigned_lt(b)].should have_solution(x == false)
    [a == 100, b == 120, x == a.unsigned_lt(b)].should have_solution(x ==  true)
    [a == 100, b == 200, x == a.unsigned_lt(b)].should have_solution(x ==  true)
    [a == 100, b ==  20, x == a.signed_lt(b)].should have_solution(x == false)
    [a == 100, b == 100, x == a.signed_lt(b)].should have_solution(x == false)
    [a == 100, b == 120, x == a.signed_lt(b)].should have_solution(x ==  true)
    [a == 100, b == 200, x == a.signed_lt(b)].should have_solution(x == false)
  end

  it "<=" do
    expect_raises(Z3::Exception) { a <= b }
    [a == 100, b ==  20, x == a.unsigned_le(b)].should have_solution(x == false)
    [a == 100, b == 100, x == a.unsigned_le(b)].should have_solution(x ==  true)
    [a == 100, b == 120, x == a.unsigned_le(b)].should have_solution(x ==  true)
    [a == 100, b == 200, x == a.unsigned_le(b)].should have_solution(x ==  true)
    [a == 100, b ==  20, x == a.signed_le(b)].should have_solution(x == false)
    [a == 100, b == 100, x == a.signed_le(b)].should have_solution(x ==  true)
    [a == 100, b == 120, x == a.signed_le(b)].should have_solution(x ==  true)
    [a == 100, b == 200, x == a.signed_le(b)].should have_solution(x == false)
  end

  it "zero_ext / sign_ext" do
    [a ==  100, d ==  a.zero_ext(4)].should have_solution(d == 100)
    [a == -100, d ==  a.zero_ext(4)].should have_solution(d == 2**8-100)
    [a ==  100, d ==  a.sign_ext(4)].should have_solution(d == 100)
    [a == -100, d ==  a.sign_ext(4)].should have_solution(d == 2**12-100)
    a.zero_ext(4).size.should eq(12)
    a.sign_ext(4).size.should eq(12)
    expect_raises(Z3::Exception) { a.zero_ext(-1) }
    expect_raises(Z3::Exception) { a.sign_ext(-1) }
  end

  it "rotate_left / rotate_right" do
    [a == 0b0101_0110, b == a.rotate_left(1)].should have_solution(b == 0b101_0110_0)
    [a == 0b0101_0110, b == a.rotate_left(4)].should have_solution(b == 0b0110_0101)
    [a == 0b0101_0110, b == a.rotate_right(1)].should have_solution(b == 0b0_0101_011)
    [a == 0b0101_0110, b == a.rotate_right(4)].should have_solution(b == 0b0110_0101)
    expect_raises(Z3::Exception) { a.rotate_left(-1) }
    expect_raises(Z3::Exception) { a.rotate_right(-1) }
  end

  it "rotate_left / rotate_right by a Bitvec" do
    [a == 0b0101_0110, c == 1, b == a.rotate_left(c)].should have_solution(b == 0b101_0110_0)
    [a == 0b0101_0110, c == 4, b == a.rotate_left(c)].should have_solution(b == 0b0110_0101)
    [a == 0b0101_0110, c == 1, b == a.rotate_right(c)].should have_solution(b == 0b0_0101_011)
    [a == 0b0101_0110, c == 4, b == a.rotate_right(c)].should have_solution(b == 0b0110_0101)
    # A rotation Z3 has to solve for, which the fixed version can't express at all
    [a == 0b0000_0001, b == 0b0001_0000, a.rotate_left(c) == b, c.unsigned_lt(8)].should have_solution(c == 4)
    expect_raises(Z3::Exception) { a.rotate_left(d) }
  end

  it "bit" do
    # Bit 0 is the low one, so this reads backwards from how the literal is written
    [true, false, true, false, false, true, false, true].each_with_index do |set, i|
      [a == 0b1010_0101, x == a.bit(i)].should have_solution(x == set)
    end
    expect_raises(Z3::Exception) { a.bit(8) }
    expect_raises(Z3::Exception) { a.bit(-1) }
  end

  it "repeat" do
    [e == 0b1101, a == e.repeat(2)].should have_solution(a == 0b1101_1101)
    [e == 0b0011, d == e.repeat(3)].should have_solution(d == 0b0011_0011_0011)
    e.repeat(3).size.should eq(12)
    expect_raises(Z3::Exception) { a.repeat(0) }
  end

  # Z3 answers with a one-bit Bitvec, which is why there are Bool versions too
  it "redand / redor" do
    a.redand.size.should eq(1)
    a.redor.size.should eq(1)
    [a == 0b1111_1111, x == a.all_bits_set?].should have_solution(x == true)
    [a == 0b1111_1110, x == a.all_bits_set?].should have_solution(x == false)
    [a == 0b0000_0000, x == a.any_bits_set?].should have_solution(x == false)
    [a == 0b0000_0001, x == a.any_bits_set?].should have_solution(x == true)
  end

  it "zero?" do
    [a == 0, x == a.zero?].should have_solution(x == true)
    [a == 100, x == a.zero?].should have_solution(x == false)
    [a == 200, x == a.zero?].should have_solution(x == false)
  end

  it "nonzero?" do
    [a == 0, x == a.nonzero?].should have_solution(x == false)
    [a == 100, x == a.nonzero?].should have_solution(x == true)
    [a == 200, x == a.nonzero?].should have_solution(x == true)
  end

  # Inherently signed
  it "positive?" do
    [a == 0, x == a.positive?].should have_solution(x == false)
    [a == 100, x == a.positive?].should have_solution(x == true)
    [a == 200, x == a.positive?].should have_solution(x == false)
  end

  # Inherently signed
  it "negative?" do
    [a == 0, x == a.negative?].should have_solution(x == false)
    [a == 100, x == a.negative?].should have_solution(x == false)
    [a == 200, x == a.negative?].should have_solution(x == true)
  end

  # Inherently signed
  it "abs" do
    [a == 0, b == a.abs].should have_solution(b == 0)
    [a == 100, b == a.abs].should have_solution(b == 100)
    [a == 200, b == a.abs].should have_solution(b == 56)
  end

  # This (hi, lo) API from Z3 feels bad in Crystal
  # we should probably drop it and accept Range instead
  it "extract" do
    [a == 0b0101_0110, e == a.extract(3, 0)].should have_solution(e == 0b0110)
    [a == 0b0101_0110, e == a.extract(7, 4)].should have_solution(e == 0b0101)
    a.extract(7, 4).size.should eq(4)
    expect_raises(Z3::Exception) { a.extract(8, 4) }
    expect_raises(Z3::Exception) { a.extract(2, 3) }
    expect_raises(Z3::Exception) { a.extract(2, -1) }
  end

  it "concat" do
    [a == 0b0101_0110, e == 0b1101, d == a.concat(e)].should have_solution(d == 0b0101_0110_1101)
    [a == 0b0101_0110, e == 0b1101, d == e.concat(a)].should have_solution(d == 0b1101_0101_0110)
  end

  it "simplify" do
    u = bv8[100]
    v = bv8[50]
    ((u+v).to_s).should eq("(bvadd #x64 #x32)")
    ((u+v).simplify.to_s).should eq("150")
  end

  it "to_s and inspect" do
    u = bv8[5]
    v = bv8[-3]
    u.to_s.should eq "5"
    v.to_s.should eq "253"
    a.to_s.should eq "a"
    u.inspect.should eq "BitvecExpr(8)<5>"
    v.inspect.should eq "BitvecExpr(8)<253>"
    a.inspect.should eq "BitvecExpr(8)<a>"
  end

  it "const?" do
    bv8[100].const?.should be_true
    bv8[-100].const?.should be_true
    (bv8[100] + bv8[50]).const?.should be_false
    a.const?.should be_false
    (a + b).const?.should be_false
  end

  # #value leaves Z3 for a Crystal Integer, where #to_i builds a Z3 Int expression -
  # the two families are named alike but they are not the same thing
  it "signed_value / unsigned_value" do
    bv8[200].unsigned_value.should eq(200)
    bv8[200].signed_value.should eq(-56)
    bv8[7].signed_value.should eq(7)
    bv8[-1].unsigned_value.should eq(255)
    bv8[-10].unsigned_value.should eq(246)
    # The boundary the sign flips at
    bv8[127].signed_value.should eq(127)
    bv8[128].signed_value.should eq(-128)
    # One bit wide, where the only two values are 0 and -1 signed
    Z3::BitvecSort.new(1)[1].signed_value.should eq(-1)
    Z3::BitvecSort.new(1)[1].unsigned_value.should eq(1)
    # Simplified first, so it doesn't have to be written as a literal
    (bv8[200] + bv8[1]).unsigned_value.should eq(201)
    expect_raises(Z3::Exception) { a.unsigned_value }
    expect_raises(Z3::Exception) { (a + b).signed_value }
    expect_raises(Z3::Exception) { a.value }
  end

  it "signed_to_i / unsigned_to_i" do
    i = Z3.int("i")
    [a == 200, i == a.unsigned_to_i].should have_solution(i == 200)
    [a == 200, i == a.signed_to_i].should have_solution(i == -56)
    [a == 7, i == a.signed_to_i].should have_solution(i == 7)
    expect_raises(Z3::Exception) { a.to_i }
  end

  it "add overflow / underflow" do
    expect_raises(Z3::Exception) { a.add_no_overflow?(b) }
    expect_raises(Z3::Exception) { a.unsigned_add_no_underflow?(b) }
    [a == 100, b ==  20, x == a.signed_add_no_overflow?(b)].should have_solution(x == true)
    [a == 100, b == 100, x == a.signed_add_no_overflow?(b)].should have_solution(x == false)
    [a == 200, b == 100, x == a.unsigned_add_no_overflow?(b)].should have_solution(x == false)
    [a == 100, b == 100, x == a.unsigned_add_no_overflow?(b)].should have_solution(x == true)
    [a == -50, b == -50, x == a.add_no_underflow?(b)].should have_solution(x == true)
    [a == -100, b == -100, x == a.add_no_underflow?(b)].should have_solution(x == false)
  end

  # Subtraction is addition's mirror image: only signed can overflow here...
  it "sub overflow" do
    expect_raises(Z3::Exception) { a.unsigned_sub_no_overflow?(b) }
    [a ==   50, b ==   50, x == a.sub_no_overflow?(b)].should have_solution(x == true)
    [a ==  100, b == -100, x == a.sub_no_overflow?(b)].should have_solution(x == false)
    [a ==  127, b ==   -1, x == a.sub_no_overflow?(b)].should have_solution(x == false)
    [a == -128, b ==    1, x == a.sub_no_overflow?(b)].should have_solution(x == true)
    [a ==   50, b ==   50, x == a.signed_sub_no_overflow?(b)].should have_solution(x == true)
    [a ==  127, b ==   -1, x == a.signed_sub_no_overflow?(b)].should have_solution(x == false)
  end

  # ...and both signs can underflow here, so this is the one which takes a sign
  it "sub underflow" do
    expect_raises(Z3::Exception) { a.sub_no_underflow?(b) }
    [a ==  100, b ==   50, x == a.signed_sub_no_underflow?(b)].should have_solution(x == true)
    [a == -100, b ==  100, x == a.signed_sub_no_underflow?(b)].should have_solution(x == false)
    [a == -128, b ==    1, x == a.signed_sub_no_underflow?(b)].should have_solution(x == false)
    [a ==  100, b ==   50, x == a.unsigned_sub_no_underflow?(b)].should have_solution(x == true)
    [a ==   50, b ==  100, x == a.unsigned_sub_no_underflow?(b)].should have_solution(x == false)
  end

  it "neg overflow" do
    expect_raises(Z3::Exception) { a.unsigned_neg_no_overflow? }
    [a == 5, x == a.signed_neg_no_overflow?].should have_solution(x == true)
    [a == -128, x == a.signed_neg_no_overflow?].should have_solution(x == false)
  end

  it "mul overflow / underflow" do
    expect_raises(Z3::Exception) { a.mul_no_overflow?(b) }
    expect_raises(Z3::Exception) { a.unsigned_mul_no_underflow?(b) }
    [a == 10, b == 10, x == a.signed_mul_no_overflow?(b)].should have_solution(x == true)
    [a == 20, b == 20, x == a.signed_mul_no_overflow?(b)].should have_solution(x == false)
    [a == 10, b == 10, x == a.unsigned_mul_no_overflow?(b)].should have_solution(x == true)
    [a == 20, b == 20, x == a.unsigned_mul_no_overflow?(b)].should have_solution(x == false)
    [a == 10, b == -10, x == a.mul_no_underflow?(b)].should have_solution(x == true)
    [a == 100, b == -100, x == a.mul_no_underflow?(b)].should have_solution(x == false)
  end

  it "div overflow" do
    expect_raises(Z3::Exception) { a.unsigned_div_no_overflow?(b) }
    [a == 100, b == 2, x == a.signed_div_no_overflow?(b)].should have_solution(x == true)
    [a == -128, b == -1, x == a.signed_div_no_overflow?(b)].should have_solution(x == false)
  end
end
