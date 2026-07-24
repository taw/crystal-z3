require "./spec_helper"

describe Z3::Model do
  a = Z3.bool("a")
  b = Z3.bool("b")
  c = Z3.int("c")
  d = Z3.int("d")
  e = Z3.bitvec("e", 16)
  f = Z3.bitvec("f", 16)
  g = Z3.real("g")
  h = Z3.real("h")

  it "eval boolean" do
    solver = Z3::Solver.new
    solver.assert a == true
    model = solver.model
    model.eval(a).to_s.should eq("true")
    model.eval(b).to_s.should eq("b")
    model.eval(a).to_b.should eq(true)
    expect_raises(Z3::Exception) { model.eval(b).to_b }
  end

  it "[] boolean" do
    solver = Z3::Solver.new
    solver.assert a == true
    model = solver.model
    model[a].to_s.should eq("true")
    model[b].to_s.should eq("false")
    model[a].to_b.should eq(true)
    model[b].to_b.should eq(false)
  end

  it "eval integer" do
    solver = Z3::Solver.new
    solver.assert c == 42
    model = solver.model
    model.eval(c).to_s.should eq("42")
    model.eval(d).to_s.should eq("d")
    model.eval(c).to_i.should eq(42)
    expect_raises(Z3::Exception) { model.eval(d).to_i }
  end

  it "[] integer" do
    solver = Z3::Solver.new
    solver.assert c == 42
    model = solver.model
    model[c].to_s.should eq("42")
    model[d].to_s.should eq("0")
    model[c].to_i.should eq(42)
    model[d].to_i.should eq(0)
  end

  it "eval bit vector" do
    solver = Z3::Solver.new
    solver.assert e == 42
    model = solver.model
    model.eval(e).to_s.should eq("42")
    model.eval(f).to_s.should eq("f")
    model.eval(e).to_i.should eq(42)
    expect_raises(Z3::Exception) { model.eval(f).to_i }
  end

  it "[] bit vector" do
    solver = Z3::Solver.new
    solver.assert e == 42
    model = solver.model
    model[e].to_s.should eq("42")
    model[f].to_s.should eq("0")
    model[e].to_i.should eq(42)
    model[f].to_i.should eq(0)
  end

  it "eval real" do
    solver = Z3::Solver.new
    solver.assert g == 3.5
    model = solver.model
    model.eval(g).to_s.should eq("7/2")
    model.eval(h).to_s.should eq("h")
  end

  it "[] real" do
    solver = Z3::Solver.new
    solver.assert g == 3.5
    model = solver.model
    model[g].to_s.should eq("7/2")
    model[h].to_s.should eq("0")
  end

  it "#num_consts, #consts, #each" do
    solver = Z3::Solver.new
    solver.assert a == true
    solver.assert c == 42
    model = solver.model
    model.num_consts.should eq(2)
    model.consts.map(&.to_s).sort.should eq(["a", "c"])
    pairs = {} of String => String
    model.each { |var, value| pairs[var.to_s] = value.to_s }
    pairs.should eq({"a" => "true", "c" => "42"})
  end

  it "#negate excludes the current model" do
    solver = Z3::Solver.new
    solver.assert c == 42
    model = solver.model
    # c == 42 has a unique solution, so ruling it out makes the problem unsat
    solver.assert model.negate
    solver.satisfiable?.should be_false
  end

  it "#negate enumerates solutions" do
    solver = Z3::Solver.new
    solver.assert c >= 1
    solver.assert c <= 3
    seen = [] of Int32
    3.times do
      break unless solver.satisfiable?
      value = solver.model[c].to_i
      seen << value
      solver.assert solver.model.negate
    end
    seen.sort.should eq([1, 2, 3])
    solver.satisfiable?.should be_false
  end

  it "#negate of a model with no consts constrains nothing" do
    solver = Z3::Solver.new
    model = solver.model
    model.negate.to_b.should eq(false)
  end
end
