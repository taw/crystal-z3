require "./spec_helper"

describe Z3::CharExpr do
  a = Z3.char("a")
  b = Z3.char("b")
  i = Z3.int("i")
  x = Z3.bool("x")

  it "CharSort[]" do
    Z3::CharSort['a'].value.should eq('a')
    Z3::CharSort[97].value.should eq('a')
    # Z3's alphabet covers everything up to 0x2FFFF, so most of Unicode fits
    Z3::CharSort['ą'].value.should eq('ą')
    Z3::CharSort['🦀'].value.should eq('🦀')
    Z3::CharSort['a'].should be_same_term(Z3::CharSort[97])
  end

  it "CharSort[] outside Z3's alphabet" do
    expect_raises(Z3::Exception) { Z3::CharSort[-1] }
    expect_raises(Z3::Exception) { Z3::CharSort[Z3::CharSort::MAX_CODE_POINT + 1] }
    expect_raises(Z3::Exception) { Z3::CharSort['\u{30000}'] }
  end

  it "CharSort.var" do
    [a == 'q'].should have_solution(a == 'q')
  end

  it "==" do
    [a == 'b', b == 'b', x == (a == b)].should have_solution(x == true)
    [a == 'b', b == 'c', x == (a == b)].should have_solution(x == false)
    ['b' == a, a == b].should have_solution(b == 'b')
  end

  it "!=" do
    [a == 'b', b == 'b', x == (a != b)].should have_solution(x == false)
    [a == 'b', b == 'c', x == (a != b)].should have_solution(x == true)
  end

  it "<" do
    [a == 'b', b == 'c', x == (a < b)].should have_solution(x == true)
    [a == 'b', b == 'b', x == (a < b)].should have_solution(x == false)
    [a == 'c', b == 'b', x == (a < b)].should have_solution(x == false)
    [a == 'b', x == ('a' < a)].should have_solution(x == true)
  end

  it "<=" do
    [a == 'b', b == 'c', x == (a <= b)].should have_solution(x == true)
    [a == 'b', b == 'b', x == (a <= b)].should have_solution(x == true)
    [a == 'c', b == 'b', x == (a <= b)].should have_solution(x == false)
  end

  it ">" do
    [a == 'b', b == 'c', x == (a > b)].should have_solution(x == false)
    [a == 'b', b == 'b', x == (a > b)].should have_solution(x == false)
    [a == 'c', b == 'b', x == (a > b)].should have_solution(x == true)
  end

  it ">=" do
    [a == 'b', b == 'c', x == (a >= b)].should have_solution(x == false)
    [a == 'b', b == 'b', x == (a >= b)].should have_solution(x == true)
    [a == 'c', b == 'b', x == (a >= b)].should have_solution(x == true)
  end

  it "to_i" do
    [a == 'a', i == a.to_i].should have_solution(i == 97)
    Z3::CharSort['a'].to_i.simplify.value.should eq(97)
  end

  # Z3 won't evaluate char.to_bv, in a model or otherwise, so this asserts the
  # constraint rather than reading a value back
  it "to_bv" do
    Z3::CharSort['a'].to_bv.size.should eq(18)
    solver = Z3::Solver.new
    solver.assert Z3::CharSort['a'].to_bv == 97
    solver.satisfiable?.should be_true
    [Z3::CharSort['a'].to_bv == 98].should have_no_solution
  end

  it "CharSort.from_bv" do
    Z3::CharSort.from_bv(Z3::BitvecSort.new(18u32)[97]).value.should eq('a')
    expect_raises(Z3::Exception) { Z3::CharSort.from_bv(Z3::BitvecSort.new(8u32)[97]) }
  end

  it "digit?" do
    [a == '7', x == a.digit?].should have_solution(x == true)
    [a == 'q', x == a.digit?].should have_solution(x == false)
  end

  it "value" do
    Z3::CharSort['a'].value.should eq('a')
    Z3::CharSort['a'].to_c.should eq('a')
    expect_raises(Z3::Exception) { a.value }
  end

  it "const?" do
    Z3::CharSort['a'].const?.should be_true
    a.const?.should be_false
  end

  it "solving" do
    [a > 'a', a < 'c'].should have_solution(a == 'b')
    [a < 'a', a > 'c'].should have_no_solution
  end
end
