require "./spec_helper"

describe Z3::BoolExpr do
  a = Z3.bool("a")
  b = Z3.bool("b")
  c = Z3.bool("c")
  x = Z3.int("x")

  it "&" do
    [a ==  true, b ==  true, c == (a & b)].should have_solution({c =>  true})
    [a ==  true, b == false, c == (a & b)].should have_solution({c => false})
    [a == false, b ==  true, c == (a & b)].should have_solution({c => false})
    [a == false, b == false, c == (a & b)].should have_solution({c => false})
  end

  it "|" do
    [a ==  true, b ==  true, c == (a | b)].should have_solution({c =>  true})
    [a ==  true, b == false, c == (a | b)].should have_solution({c =>  true})
    [a == false, b ==  true, c == (a | b)].should have_solution({c =>  true})
    [a == false, b == false, c == (a | b)].should have_solution({c => false})
  end

  it "^" do
    [a ==  true, b ==  true, c == (a ^ b)].should have_solution({c => false})
    [a ==  true, b == false, c == (a ^ b)].should have_solution({c =>  true})
    [a == false, b ==  true, c == (a ^ b)].should have_solution({c =>  true})
    [a == false, b == false, c == (a ^ b)].should have_solution({c => false})
  end

  it "!=" do
    [a ==  true, b ==  true, c == (a != b)].should have_solution({c => false})
    [a ==  true, b == false, c == (a != b)].should have_solution({c =>  true})
    [a == false, b ==  true, c == (a != b)].should have_solution({c =>  true})
    [a == false, b == false, c == (a != b)].should have_solution({c => false})
  end

  it "implies" do
    [a ==  true, b ==  true, c == a.implies(b)].should have_solution({c =>  true})
    [a ==  true, b == false, c == a.implies(b)].should have_solution({c => false})
    [a == false, b ==  true, c == a.implies(b)].should have_solution({c =>  true})
    [a == false, b == false, c == a.implies(b)].should have_solution({c =>  true})
  end

  it "iff" do
    [a ==  true, b ==  true, c == a.iff(b)].should have_solution({c =>  true})
    [a ==  true, b == false, c == a.iff(b)].should have_solution({c => false})
    [a == false, b ==  true, c == a.iff(b)].should have_solution({c => false})
    [a == false, b == false, c == a.iff(b)].should have_solution({c =>  true})
  end

  it "==" do
    [a ==  true, b ==  true, c == (a == b)].should have_solution({c =>  true})
    [a ==  true, b == false, c == (a == b)].should have_solution({c => false})
    [a == false, b ==  true, c == (a == b)].should have_solution({c => false})
    [a == false, b == false, c == (a == b)].should have_solution({c =>  true})
  end

  # ! not possible
  it "~" do
    [a ==  true, b == ~a].should have_solution({b => false})
    [a == false, b == ~a].should have_solution({b =>  true})
  end

  it "if then else" do
    [a ==  true, x == a.ite(2, 3)].should have_solution({x => 2})
    [a == false, x == a.ite(2, 3)].should have_solution({x => 3})
    [a == true,  b == a.ite(true, false)].should have_solution({b => true})
    [a == false, b == a.ite(true, false)].should have_solution({b => false})
    [a == true,  b == a.ite(false, true)].should have_solution({b => false})
    [a == false, b == a.ite(false, true)].should have_solution({b => true})
  end

  it "if then else on Real" do
    r = Z3.real("r")
    [a ==  true, r == a.ite(Z3::RealSort[1] / 2, Z3::RealSort[3])].should have_solution({r => "1/2"})
    [a == false, r == a.ite(Z3::RealSort[1] / 2, Z3::RealSort[3])].should have_solution({r => 3})
    [a ==  true, r == a.ite(2, Z3::RealSort[3])].should have_solution({r => 2})
    [a == false, r == a.ite(Z3::RealSort[2], 3.5)].should have_solution({r => "7/2"})
  end

  it "if then else on Bitvec" do
    v = Z3.bitvec("v", 8)
    w = Z3.bitvec("w", 8)
    [a ==  true, v == a.ite(w, 3), w == 200].should have_solution({v => 200})
    [a == false, v == a.ite(w, 3), w == 200].should have_solution({v => 3})
    [a ==  true, v == a.ite(2, w), w == 200].should have_solution({v => 2})
    # Both branches have to be the same size
    expect_raises(Z3::Exception) { a.ite(v, Z3.bitvec("z", 12)) }
  end

  it "simplify" do
    t = Z3::BoolSort[true]
    f = Z3::BoolSort[false]
    ((t&f).to_s).should eq("(and true false)")
    ((t&f).simplify.to_s).should eq("false")
  end

  it "to_s and inspect" do
    t = Z3::BoolSort[true]
    f = Z3::BoolSort[false]
    t.to_s.should eq("true")
    f.to_s.should eq("false")
    a.to_s.should eq("a")
    t.inspect.should eq("BoolExpr<true>")
    f.inspect.should eq("BoolExpr<false>")
    a.inspect.should eq("BoolExpr<a>")
  end

  it "const?" do
    Z3::BoolSort[true].const?.should be_true
    Z3::BoolSort[false].const?.should be_true
    (Z3::BoolSort[true] | Z3::BoolSort[false]).const?.should be_false
    a.const?.should be_false
    (a | b).const?.should be_false
  end

  # Every sort which can hand back a Crystal object spells it #value, and on Bool
  # #to_b is the same method
  it "value" do
    Z3::BoolSort[true].value.should eq(true)
    Z3::BoolSort[false].value.should eq(false)
    (Z3::BoolSort[true] | Z3::BoolSort[false]).value.should eq(true)
    (Z3::BoolSort[true] & Z3::BoolSort[false]).value.should eq(false)
    expect_raises(Z3::Exception) { a.value }
    expect_raises(Z3::Exception) { (a | b).value }
  end

  it "to_b" do
    Z3::BoolSort[true].to_b.should eq(true)
    Z3::BoolSort[false].to_b.should eq(false)
    (Z3::BoolSort[true] | Z3::BoolSort[false]).to_b.should eq(true)
    expect_raises(Z3::Exception) { a.to_b }
    expect_raises(Z3::Exception) { (a | b).to_b }
  end

  it "Z3.or" do
    [a == Z3.or([] of Z3::BoolExpr)].should have_solution({a => false})
    [a == Z3.or([true, false])].should have_solution({a => true})
    [a == Z3.or([false, false])].should have_solution({a => false})
    [a == Z3.or([false, b]), b == false].should have_solution({a => false})
    [a == Z3.or([false, b]), b == true].should have_solution({a => true})
    [a == Z3.or([true, false, b]), b == true].should have_solution({a => true})
  end

  it "Z3.and" do
    [a == Z3.and([] of Z3::BoolExpr)].should have_solution({a => true})
    [a == Z3.and([true, false])].should have_solution({a => false})
    [a == Z3.and([true, true])].should have_solution({a => true})
    [a == Z3.and([true, b]), b == false].should have_solution({a => false})
    [a == Z3.and([true, b]), b == true].should have_solution({a => true})
    [a == Z3.and([true, false, b]), b == true].should have_solution({a => false})
  end
end
