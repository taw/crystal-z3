require "./spec_helper"

describe Z3::Optimize do
  x = Z3.int("ox")
  y = Z3.int("oy")

  it "#maximize" do
    opt = Z3::Optimize.new
    opt.assert x >= 0
    opt.assert y >= 0
    opt.assert x + y <= 10
    opt.maximize(x * 2 + y)
    opt.satisfiable?.should be_true
    opt.model[x].to_i.should eq(10)
    opt.model[y].to_i.should eq(0)
  end

  it "#minimize" do
    opt = Z3::Optimize.new
    opt.assert x >= 3
    opt.assert y >= 0
    opt.minimize(x + y)
    opt.satisfiable?.should be_true
    opt.model[x].to_i.should eq(3)
    opt.model[y].to_i.should eq(0)
  end

  # Soft constraints are the ones Z3 is allowed to break, paying their weight when
  # it does, so it breaks the cheap one
  it "#assert_soft" do
    a = Z3.bool("sa")
    b = Z3.bool("sb")
    opt = Z3::Optimize.new
    opt.assert(a | b)
    opt.assert(~a | ~b)
    opt.assert_soft(a, "1")
    opt.assert_soft(b, "5")
    opt.satisfiable?.should be_true
    opt.model[a].to_b.should be_false
    opt.model[b].to_b.should be_true
  end

  it "#assert_soft defaults to weight 1" do
    a = Z3.bool("sc")
    opt = Z3::Optimize.new
    opt.assert_soft(a)
    opt.satisfiable?.should be_true
    opt.model[a].to_b.should be_true
  end

  it "#push and #pop" do
    opt = Z3::Optimize.new
    opt.assert x > 0
    opt.satisfiable?.should be_true
    opt.push
    opt.assert x < 0
    opt.satisfiable?.should be_false
    opt.pop
    opt.satisfiable?.should be_true
  end

  it "#unsatisfiable?" do
    opt = Z3::Optimize.new
    opt.assert x > 5
    opt.assert x < 2
    opt.unsatisfiable?.should be_true
  end

  it "#check takes assumptions" do
    p1 = Z3.bool("op1")
    opt = Z3::Optimize.new
    opt.assert p1.implies(x > 5)
    opt.assert x < 2
    opt.check.should eq(Z3::CheckResult::Sat)
    opt.check(p1).should eq(Z3::CheckResult::Unsat)
  end

  it "#assertions" do
    opt = Z3::Optimize.new
    opt.assert x + y == 4
    opt.assertions.map(&.to_s).should contain("(= (+ ox oy) 4)")
  end

  it "#assert_and_track and #unsat_core" do
    opt = Z3::Optimize.new
    opt.assert_and_track(x > 5, Z3.bool("oq1"))
    opt.assert_and_track(x < 2, Z3.bool("oq2"))
    opt.satisfiable?.should be_false
    opt.unsat_core.map(&.to_s).sort.should eq(["oq1", "oq2"])
  end

  # This parser knows the optimization commands, so a string can bring its
  # objectives along with its assertions
  it "#from_string" do
    opt = Z3::Optimize.new
    opt.from_string("(declare-const oz Int)(assert (< oz 12))(maximize oz)")
    opt.satisfiable?.should be_true
    opt.model[Z3.int("oz")].to_i.should eq(11)
  end

  it "#from_file" do
    path = File.tempname("z3", ".smt2")
    File.write(path, "(declare-const ow Int)(assert (> ow 3))(minimize ow)")
    begin
      opt = Z3::Optimize.new
      opt.from_file(path)
      opt.satisfiable?.should be_true
      opt.model[Z3.int("ow")].to_i.should eq(4)
    ensure
      File.delete(path)
    end
  end

  it "#statistics" do
    opt = Z3::Optimize.new
    opt.assert x > 0
    opt.check
    opt.statistics.should be_a(Hash(String, UInt32 | Float64))
  end

  it "#help and #to_s" do
    opt = Z3::Optimize.new
    opt.assert x > 0
    opt.help.should_not be_empty
    opt.to_s.should contain("ox")
  end

  it "#reason_unknown" do
    opt = Z3::Optimize.new
    opt.assert x > 0
    opt.check
    opt.reason_unknown.should be_a(String)
  end

  describe "#set_initial_value" do
    # Unhinted Z3 answers sv=true, sv2=false here, so both halves of this are the hint
    it "is the value the solver tries first" do
      b = Z3.bool("sv")
      c = Z3.bool("sv2")
      opt = Z3::Optimize.new
      opt.assert b | c
      opt.set_initial_value(b, false).should be(opt)
      opt.set_initial_value(c, true)
      opt.satisfiable?.should be_true
      opt.model[b].to_b.should be_false
      opt.model[c].to_b.should be_true
    end

    # A hint and nothing more - it cannot make a wrong answer right
    it "is overridden when it does not fit the assertions" do
      b = Z3.bool("sv3")
      opt = Z3::Optimize.new
      opt.assert b
      opt.set_initial_value(b, false)
      opt.satisfiable?.should be_true
      opt.model[b].to_b.should be_true
    end

    # Z3's optimizer drops an Int hint in preprocessing and hands a Real one back
    # scaled, so those raise here rather than being passed through
    it "refuses arithmetic hints, which Z3 gets wrong" do
      expect_raises(Z3::Exception, "Solver.simple") do
        Z3::Optimize.new.set_initial_value(x, 42)
      end
      expect_raises(Z3::Exception, "Solver.simple") do
        Z3::Optimize.new.set_initial_value(Z3.real("orv"), 1)
      end
    end

    it "refuses anything which isn't a variable" do
      expect_raises(Z3::Exception, "variable") do
        Z3::Optimize.new.set_initial_value(Z3.bool("sw") & true, true)
      end
    end
  end

  it "#prove!" do
    opt = Z3::Optimize.new
    io = IO::Memory.new
    opt.prove!(x + 0 == x, io)
    io.to_s.should eq("Proven\n")
    # and the claim leaves no trace
    opt.assertions.should be_empty
  end
end
