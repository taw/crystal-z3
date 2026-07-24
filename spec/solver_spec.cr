require "./spec_helper"

describe Z3::Solver do
  a = Z3.int("a")
  b = Z3.int("b")

  it "push/pop" do
    solver = Z3::Solver.new
    solver.assert(a == b)
    solver.satisfiable?.should be_true
    solver.push
    solver.assert(a != b)
    solver.satisfiable?.should be_false
    solver.pop
    solver.satisfiable?.should be_true
  end

  it "#num_scopes" do
    solver = Z3::Solver.new
    solver.num_scopes.should eq(0)
    solver.push
    solver.push
    solver.num_scopes.should eq(2)
    solver.pop
    solver.num_scopes.should eq(1)
  end

  it "#reset" do
    solver = Z3::Solver.new
    solver.assert(a != a)
    solver.satisfiable?.should be_false
    solver.reset
    solver.satisfiable?.should be_true
  end

  it "#assertions" do
    solver = Z3::Solver.new
    solver.assert(a + b == 4)
    solver.assert(b >= 2)
    strs = solver.assertions.map(&.to_s)
    strs.should contain("(= (+ a b) 4)")
    strs.should contain("(>= b 2)")
  end

  it "#assert_and_track and #unsat_core" do
    solver = Z3::Solver.new
    solver.assert_and_track(a > 5, Z3.bool("p1"))
    solver.assert_and_track(a < 2, Z3.bool("p2"))
    solver.assert_and_track(b == 0, Z3.bool("p3"))
    solver.satisfiable?.should be_false
    # Z3 picks the order, and p3 is not part of the contradiction
    solver.unsat_core.map(&.to_s).sort.should eq(["p1", "p2"])
  end

  it "#unsat_core is empty unless the solver got to blame something" do
    solver = Z3::Solver.new
    solver.assert_and_track(a > 5, Z3.bool("p1"))
    solver.satisfiable?.should be_true
    solver.unsat_core.should be_empty
  end

  it "#statistics" do
    solver = Z3::Solver.new
    solver.assert(a + b == 4)
    solver.check
    stats = solver.statistics
    stats.should be_a(Hash(String, UInt32 | Float64))
    stats.size.should be > 0
  end

  it "#reason_unknown" do
    solver = Z3::Solver.new
    solver.assert(a ** a == a)
    solver.check.should eq(LibZ3::LBool::Undefined)
    solver.reason_unknown.should contain("incomplete")
  end

  it "#to_s" do
    solver = Z3::Solver.new
    solver.assert(a + b == 4)
    solver.assert(b >= 2)
    # Z3 picks the order it declares consts in, so only the parts we control are checked
    solver.to_s.should contain("(declare-fun a () Int)")
    solver.to_s.should contain("(declare-fun b () Int)")
    solver.to_s.should contain("(assert (= (+ a b) 4))")
    solver.to_s.should contain("(assert (>= b 2))")
  end
end
