require "./spec_helper"

describe Z3::FuncDecl do
  it "declares an uninterpreted function" do
    f = Z3.function("f", Z3::IntSort, Z3::IntSort)
    f.name.should eq("f")
    f.arity.should eq(1)
    f.domain(0).should eq(Z3::IntSort)
    f.range.should eq(Z3::IntSort)
    f.to_s.should eq("f")
    f.inspect.should eq("Z3::FuncDecl<f/1>")
  end

  it "declares functions of several arguments and mixed sorts" do
    f = Z3.function("mixed", Z3::IntSort, Z3::StringSort, Z3::BoolSort)
    f.arity.should eq(2)
    f.domain(0).should eq(Z3::IntSort)
    f.domain(1).should eq(Z3::StringSort)
    f.range.should eq(Z3::BoolSort)
  end

  it "#domain refuses an index it doesn't have" do
    f = Z3.function("f1", Z3::IntSort, Z3::IntSort)
    expect_raises(Z3::Exception, "arity is 1") { f.domain(1) }
  end

  it "needs at least a range sort" do
    expect_raises(Z3::Exception, "range sort") { Z3::FuncDecl.declare("nope", [] of Z3::AnySort) }
  end

  # Applying gives an expression of the range sort, which is only known at runtime -
  # so it comes back as AnyExpr and has to be narrowed
  it "#[] applies the function" do
    f = Z3.function("f2", Z3::IntSort, Z3::IntSort)
    f[3].to_s.should eq("(f2 3)")
    f[Z3.int("x")].to_s.should eq("(f2 x)")
    f[3].as(Z3::IntExpr).sort.should eq(Z3::IntSort)
    f.call(3).to_s.should eq("(f2 3)")
  end

  it "#[] refuses the wrong number of arguments" do
    f = Z3.function("f3", Z3::IntSort, Z3::IntSort)
    expect_raises(Z3::Exception, "takes 1 arguments") { f[1, 2] }
  end

  it "solves with an uninterpreted function" do
    f = Z3.function("f4", Z3::IntSort, Z3::IntSort)
    x = Z3.int("x")
    solver = Z3::Solver.new
    solver.assert f[f[x]].as(Z3::IntExpr) == x
    solver.assert f[x].as(Z3::IntExpr) != x
    solver.satisfiable?.should be_true
  end

  it ".fresh_function picks a name nothing has used" do
    a = Z3.fresh_function("tmp", Z3::IntSort, Z3::IntSort)
    b = Z3.fresh_function("tmp", Z3::IntSort, Z3::IntSort)
    a.name.should_not eq(b.name)
    a.should_not eq(b)
  end

  it "#== is real equality, since Z3 hash-conses declarations" do
    a = Z3.function("same", Z3::IntSort, Z3::IntSort)
    b = Z3.function("same", Z3::IntSort, Z3::IntSort)
    (a == b).should be_true
    # and so a FuncDecl works as a Hash key, unlike an expression
    ({a => 1})[b].should eq(1)
  end

  describe "recursive functions" do
    it "#recursive? tells the two kinds apart" do
      Z3.function("plain", Z3::IntSort, Z3::IntSort).recursive?.should be_false
      Z3.rec_function("rec", Z3::IntSort, Z3::IntSort).recursive?.should be_true
    end

    it "computes a factorial" do
      fact = Z3.rec_function("fact", Z3::IntSort, Z3::IntSort)
      fact.define do |args|
        n = args[0].as(Z3::IntExpr)
        (n <= 0).ite(1, n * fact[n - 1].as(Z3::IntExpr))
      end
      x = Z3.int("fact_x")
      solver = Z3::Solver.new
      solver.assert fact[5].as(Z3::IntExpr) == x
      solver.model[x].to_i.should eq(120)
    end

    it "defines mutually recursive functions" do
      even = Z3.rec_function("ev", Z3::IntSort, Z3::BoolSort)
      odd = Z3.rec_function("od", Z3::IntSort, Z3::BoolSort)
      even.define do |args|
        n = args[0].as(Z3::IntExpr)
        (n == 0).ite(true, odd[n - 1].as(Z3::BoolExpr))
      end
      odd.define do |args|
        n = args[0].as(Z3::IntExpr)
        (n == 0).ite(false, even[n - 1].as(Z3::BoolExpr))
      end

      solver = Z3::Solver.new
      solver.assert even[10].as(Z3::BoolExpr)
      solver.satisfiable?.should be_true

      solver = Z3::Solver.new
      solver.assert even[7].as(Z3::BoolExpr)
      solver.satisfiable?.should be_false
    end
  end
end
