require "./spec_helper"

describe Z3 do
  it ".version" do
    Z3.version.should match(/\A\d+\.\d+\.\d+\.\d+\z/)
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
    [a == Z3.add([Z3.real(1), Z3.real(2), Z3.real(3)])].should have_solution({a => 6})
    [a == Z3.mul([Z3.real(2), Z3.real(3), Z3.real(4)])].should have_solution({a => 24})
    [a == Z3.add([] of Z3::RealExpr)].should have_solution({a => 0})
    [a == Z3.mul([] of Z3::RealExpr)].should have_solution({a => 1})
  end

  it "Z3.and / Z3.or (Bitvec)" do
    a = Z3.bitvec("a", 8)
    bv8 = Z3::BitvecSort.new(8)
    [a == Z3.and([bv8[0b1100], bv8[0b1010]])].should have_solution({a => 0b1000})
    [a == Z3.or([bv8[0b1100], bv8[0b1010]])].should have_solution({a => 0b1110})
  end
end
