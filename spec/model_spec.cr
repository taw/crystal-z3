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
    model.eval(e).unsigned_value.should eq(42)
    expect_raises(Z3::Exception) { model.eval(f).unsigned_value }
  end

  it "[] bit vector" do
    solver = Z3::Solver.new
    solver.assert e == 42
    model = solver.model
    model[e].to_s.should eq("42")
    model[f].to_s.should eq("0")
    model[e].unsigned_value.should eq(42)
    model[f].unsigned_value.should eq(0)
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

  it "#model_eval evaluates without knowing the sort statically" do
    solver = Z3::Solver.new
    solver.assert c == 42
    model = solver.model
    model.model_eval(c).to_s.should eq("42")
    model.model_eval(d).to_s.should eq("d")
    model.model_eval(d, true).to_s.should eq("0")
  end

  # #consts are the declarations, #each_const yields the variables
  it "#consts are FuncDecls" do
    solver = Z3::Solver.new
    solver.assert a == true
    solver.assert c == 42
    decls = solver.model.consts
    decls.map(&.name).sort.should eq(["a", "c"])
    decls.map(&.arity).should eq([0, 0])
  end

  it "#each_const yields variables and their values" do
    solver = Z3::Solver.new
    solver.assert a == true
    solver.assert c == 42
    pairs = {} of String => String
    solver.model.each_const { |var, value| pairs[var.to_s] = value.to_s }
    pairs.should eq({"a" => "true", "c" => "42"})
  end

  describe "functions" do
    it "#funcs, #num_funcs and #func_interp" do
      fd = Z3.function("mf", Z3::IntSort, Z3::IntSort)
      solver = Z3::Solver.new
      solver.assert fd[1].as(Z3::IntExpr) == 10
      solver.assert fd[2].as(Z3::IntExpr) == 20
      model = solver.model
      model.num_funcs.should eq(1)
      decl = model.funcs[0]
      decl.name.should eq("mf")

      interp = model.func_interp(decl)
      interp.arity.should eq(1)
      interp[1].to_s.should eq("10")
      interp[2].to_s.should eq("20")
      # every argument list the model never had to pin down gets the else branch
      interp[999].to_s.should eq(interp.default.to_s)
    end

    it "#each_func yields declarations and interpretations" do
      fd = Z3.function("mg", Z3::IntSort, Z3::IntSort)
      solver = Z3::Solver.new
      solver.assert fd[1].as(Z3::IntExpr) == 7
      seen = {} of String => String
      solver.model.each_func { |decl, interp| seen[decl.name] = interp[1].to_s }
      seen.should eq({"mg" => "7"})
    end

    # Z3 puts every recursive definition made in the context into every model,
    # whether or not the query mentioned it - those are not what this model decided
    it "#funcs leaves recursive definitions out" do
      rec = Z3.rec_function("model_rec", Z3::IntSort, Z3::IntSort)
      rec.define { |args| args[0].as(Z3::IntExpr) + 1 }
      solver = Z3::Solver.new
      solver.assert c == 42
      solver.model.funcs.map(&.name).should_not contain("model_rec")
    end

    it "#each yields constants and then functions" do
      fd = Z3.function("mh", Z3::IntSort, Z3::IntSort)
      solver = Z3::Solver.new
      solver.assert fd[1].as(Z3::IntExpr) == 5
      solver.assert c == 42
      names = [] of String
      solver.model.each { |key, _value| names << key.to_s }
      names.should contain("c")
      names.should contain("mh")
    end
  end

  describe "#has_interp?" do
    it "is whether the model says anything about it at all" do
      fd = Z3.function("mi", Z3::IntSort, Z3::IntSort)
      solver = Z3::Solver.new
      solver.assert c == 42
      solver.assert fd[1].as(Z3::IntExpr) == 5
      model = solver.model
      model.has_interp?(c).should be_true
      model.has_interp?(fd).should be_true
      model.has_interp?(Z3.int("never_mentioned")).should be_false
    end

    it "refuses anything which is not a variable" do
      solver = Z3::Solver.new
      solver.assert c == 42
      expect_raises(Z3::Exception, "variable") { solver.model.has_interp?(c + 1) }
    end
  end
end
