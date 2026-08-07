require "./spec_helper"

describe Z3 do
  it ".version" do
    Z3.version.should match(/\A\d+\.\d+\.\d+\.\d+\z/)
  end

  # Variables come from `Sort.var(name)`, constants from `Sort[value]`.
  # A String is never a value, so `IntSort["a"]` is a compile error, not a variable.
  it "Sort.var / Sort[]" do
    Z3::IntSort.var("a").to_s.should eq("a")
    Z3::BoolSort.var("b").to_s.should eq("b")
    Z3::RealSort.var("c").to_s.should eq("c")
    Z3::BitvecSort.new(8).var("d").to_s.should eq("d")
    Z3::CharSort.var("e").to_s.should eq("e")

    Z3::IntSort[42].to_s.should eq("42")
    Z3::BoolSort[true].to_s.should eq("true")
    Z3::RealSort[2.5].to_s.should eq("5/2")
    Z3::BitvecSort.new(8)[42].to_s.should eq("42")
    Z3::CharSort['a'].value.should eq('a')
  end

  it "Z3.distinct (Char)" do
    p = Z3.char("p")
    q = Z3.char("q")
    r = Z3.char("r")
    solver = Z3::Solver.new
    solver.assert Z3.distinct([p, q, r])
    # Three distinct Chars need three code points, and 'a' to 'b' is only two
    [p, q, r].each do |char|
      solver.assert char >= 'a'
      solver.assert char <= 'b'
    end
    solver.satisfiable?.should be_false
  end

  it "Z3.distinct (Real)" do
    a = Z3.real("a")
    b = Z3.real("b")
    solver = Z3::Solver.new
    solver.assert a == 1
    solver.assert b == 1
    solver.assert Z3.distinct([a, b])
    solver.satisfiable?.should be_false
  end

  it "Z3.distinct (Bool)" do
    p = Z3.bool("p")
    q = Z3.bool("q")
    r = Z3.bool("r")
    solver = Z3::Solver.new
    # Three distinct Bools is impossible, there are only two values
    solver.assert Z3.distinct([p, q, r])
    solver.satisfiable?.should be_false
  end

  it "Z3.distinct (Bitvec)" do
    a = Z3.bitvec("a", 8)
    b = Z3.bitvec("b", 8)
    solver = Z3::Solver.new
    solver.assert a == 5
    solver.assert b == 5
    solver.assert Z3.distinct([a, b])
    solver.satisfiable?.should be_false
  end

  it "Z3.add / Z3.mul (Real)" do
    a = Z3.real("a")
    [a == Z3.add([Z3::RealSort[1], Z3::RealSort[2], Z3::RealSort[3]])].should have_solution(a == 6)
    [a == Z3.mul([Z3::RealSort[2], Z3::RealSort[3], Z3::RealSort[4]])].should have_solution(a == 24)
    [a == Z3.add([] of Z3::RealExpr)].should have_solution(a == 0)
    [a == Z3.mul([] of Z3::RealExpr)].should have_solution(a == 1)
  end

  it "Z3.and / Z3.or (Bitvec)" do
    a = Z3.bitvec("a", 8)
    bv8 = Z3::BitvecSort.new(8)
    [a == Z3.and([bv8[0b1100], bv8[0b1010]])].should have_solution(a == 0b1000)
    [a == Z3.or([bv8[0b1100], bv8[0b1010]])].should have_solution(a == 0b1110)
  end
end
