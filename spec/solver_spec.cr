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
    solver.check.should eq(Z3::CheckResult::Unknown)
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
  it "#check answers a CheckResult" do
    solver = Z3::Solver.new
    solver.assert(a > 5)
    solver.check.should eq(Z3::CheckResult::Sat)
    solver.assert(a < 2)
    solver.check.should eq(Z3::CheckResult::Unsat)
  end

  it "#unsatisfiable?" do
    solver = Z3::Solver.new
    solver.assert(a > 5)
    solver.assert(a < 2)
    solver.unsatisfiable?.should be_true
    solver.reset
    solver.unsatisfiable?.should be_false
  end

  # Assumptions are taken as true for one check and leave no trace on the solver,
  # and they are what #unsat_core blames
  describe "#check with assumptions" do
    it "holds only for that check" do
      p1 = Z3.bool("p1")
      solver = Z3::Solver.new
      solver.assert p1.implies(a > 5)
      solver.assert a < 2
      solver.check.should eq(Z3::CheckResult::Sat)
      solver.check(p1).should eq(Z3::CheckResult::Unsat)
      solver.check.should eq(Z3::CheckResult::Sat)
    end

    it "is what #unsat_core blames" do
      p1 = Z3.bool("p1")
      solver = Z3::Solver.new
      solver.assert p1.implies(a > 5)
      solver.assert a < 2
      solver.satisfiable?(p1).should be_false
      solver.unsat_core.map(&.to_s).should eq(["p1"])
    end

    it "takes a plain Bool too" do
      solver = Z3::Solver.new
      solver.assert(a > 5)
      solver.satisfiable?(true).should be_true
      solver.satisfiable?(false).should be_false
    end
  end

  describe "alternative solvers" do
    it ".simple is the plain incremental core" do
      simple = Z3::Solver.simple
      simple.simple?.should be_true
      simple.assert(a > 5)
      simple.satisfiable?.should be_true
      simple.model[a].to_i.should be > 5
    end

    it ".for_logic specializes to one SMT-LIB logic" do
      solver = Z3::Solver.for_logic("QF_LIA")
      solver.simple?.should be_false
      solver.assert(a > 5)
      solver.assert(a < 7)
      solver.satisfiable?.should be_true
      solver.model[a].to_i.should eq(6)
    end

    # We have no logic name list to check against, so this comes straight from Z3
    it ".for_logic raises on unknown logics" do
      expect_raises(Z3::Exception) { Z3::Solver.for_logic("QF_NO_SUCH_LOGIC") }
    end

    it "Solver.new is neither" do
      Z3::Solver.new.simple?.should be_false
    end
  end

  it "#units and #non_units" do
    solver = Z3::Solver.new
    solver.assert Z3.bool("u1")
    solver.assert Z3.bool("u2") | Z3.bool("u3")
    solver.units.map(&.to_s).should eq(["u1"])
    solver.non_units.map(&.to_s).sort.should eq(["u2", "u3"])
  end

  describe "#trail" do
    it "is the literals the search has assigned" do
      simple = Z3::Solver.simple
      simple.assert Z3.bool("t1")
      simple.trail.should be_empty
      simple.check.should eq(Z3::CheckResult::Sat)
      simple.trail.map(&.to_s).should contain("t1")
    end

    it "is only implemented by Solver.simple" do
      expect_raises(Z3::Exception) { Z3::Solver.new.trail }
    end
  end

  describe "#consequences" do
    p1 = Z3.bool("c_p")
    q1 = Z3.bool("c_q")
    r1 = Z3.bool("c_r")

    it "reports what follows from the assertions" do
      solver = Z3::Solver.new
      solver.assert p1.implies(q1)
      solver.assert q1.implies(r1)
      solver.assert p1
      result = solver.consequences([p1, q1, r1])
      result.size.should eq(3)
      result.map(&.to_s).sort.should eq(["(=> true c_p)", "(=> true c_q)", "(=> true c_r)"])
    end

    it "reports what follows only under an assumption" do
      solver = Z3::Solver.new
      solver.assert p1.implies(q1)
      solver.consequences([q1], [p1]).map(&.to_s).should eq(["(=> c_p c_q)"])
      solver.consequences([q1]).should be_empty
    end

    it "raises unless the assertions are satisfiable" do
      solver = Z3::Solver.new
      solver.assert p1
      solver.assert ~p1
      expect_raises(Z3::Exception, "Unsat") { solver.consequences([p1]) }
    end
  end

  describe "#cube" do
    it "enumerates case splits, ending with false" do
      solver = Z3::Solver.new
      solver.assert Z3.bool("k_p") | Z3.bool("k_q")
      cubes = (0...3).map { solver.cube.map(&.to_s) }
      cubes.map(&.size).should eq([1, 1, 1])
      cubes.last.should eq(["false"])
    end

    it "splits on the variables it is given" do
      p2 = Z3.bool("k2_p")
      q2 = Z3.bool("k2_q")
      solver = Z3::Solver.new
      solver.assert p2 | q2
      cube = solver.cube([p2, q2])
      cube.size.should eq(1)
      ["k2_p", "k2_q"].should contain(cube[0].to_s)
    end

    # Nothing to case split on, rather than "no solution"
    it "is empty when the assertions already decide everything" do
      solver = Z3::Solver.new
      solver.assert Z3.bool("k3_p")
      solver.cube.should be_empty
    end
  end

  describe "#set_initial_value" do
    x = Z3.int("iv_x")

    # The value Z3 picks unhinted is 0, so this is the hint landing
    it "is the value the solver tries first" do
      simple = Z3::Solver.simple
      simple.assert x >= 0
      simple.assert x <= 100
      simple.set_initial_value(x, 42).should be(simple)
      simple.satisfiable?.should be_true
      simple.model[x].to_i.should eq(42)
    end

    # A hint and nothing more - it can't make a wrong answer right
    it "is overridden when it does not fit the assertions" do
      simple = Z3::Solver.simple
      simple.assert x >= 0
      simple.assert x <= 10
      simple.set_initial_value(x, 42)
      simple.satisfiable?.should be_true
      simple.model[x].to_i.should be <= 10
    end

    it "cannot make an unsatisfiable problem satisfiable" do
      simple = Z3::Solver.simple
      simple.assert x > 5
      simple.assert x < 3
      simple.set_initial_value(x, 4)
      simple.unsatisfiable?.should be_true
    end

    it "casts the value into the sort of the variable" do
      simple = Z3::Solver.simple
      expect_raises(Z3::Exception) { simple.set_initial_value(x, "nope") }
    end

    # Every other solver takes the call and quietly does nothing with it, which is
    # worse than refusing, so we refuse for them
    it "raises on any solver which would ignore it" do
      expect_raises(Z3::Exception, "Only Solver.simple") do
        Z3::Solver.new.set_initial_value(x, 42)
      end
    end

    it "raises on anything which is not a variable" do
      expect_raises(Z3::Exception, "variable") do
        Z3::Solver.simple.set_initial_value(x + 1, 42)
      end
    end
  end

  # Cancelling a #check in progress needs another fiber, so this only pins down
  # that an unused interrupt disturbs nothing
  it "#interrupt" do
    solver = Z3::Solver.new
    solver.assert a > 5
    solver.interrupt.should be(solver)
    solver.satisfiable?.should be_true
  end

  describe "SMT-LIB2 input" do
    it "#from_string" do
      solver = Z3::Solver.new
      solver.from_string("(declare-const sc Int)(assert (> sc 5))(assert (< sc 7))")
      solver.assertions.map(&.to_s).should eq(["(> sc 5)", "(< sc 7)"])
    end

    # Whatever the string declares is an ordinary const in the one shared context
    it "#from_string declares consts Crystal can then use" do
      solver = Z3::Solver.new
      solver.from_string("(declare-const sd Int)(assert (= sd 6))")
      solver.satisfiable?.should be_true
      solver.model[Z3.int("sd")].to_i.should eq(6)
    end

    it "#from_file" do
      path = File.tempname("z3", ".smt2")
      File.write(path, "(declare-const se Int)(assert (= se 8))")
      begin
        solver = Z3::Solver.new
        solver.from_file(path)
        solver.satisfiable?.should be_true
        solver.model[Z3.int("se")].to_i.should eq(8)
      ensure
        File.delete(path)
      end
    end
  end

  it "#help" do
    Z3::Solver.new.help.should_not be_empty
  end

  it "#to_dimacs" do
    solver = Z3::Solver.new
    solver.assert Z3.bool("d1") | Z3.bool("d2")
    solver.to_dimacs.should contain("p cnf")
  end

  describe "#prove!" do
    it "proves a claim nothing can break" do
      solver = Z3::Solver.new
      io = IO::Memory.new
      solver.prove!(a + 0 == a, io)
      io.to_s.should eq("Proven\n")
    end

    it "reports a counterexample and leaves no trace" do
      solver = Z3::Solver.new
      io = IO::Memory.new
      solver.prove!(a > b, io)
      io.to_s.should contain("Counterexample exists")
      solver.num_scopes.should eq(0)
      solver.assertions.should be_empty
    end
  end
end
