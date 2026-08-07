require "./spec_helper"

describe Z3::BoolExpr do
  a = Z3.bool("a")
  b = Z3.bool("b")
  c = Z3.bool("c")
  x = Z3.int("x")

  it "&" do
    [a ==  true, b ==  true, c == (a & b)].should have_solution(c ==  true)
    [a ==  true, b == false, c == (a & b)].should have_solution(c == false)
    [a == false, b ==  true, c == (a & b)].should have_solution(c == false)
    [a == false, b == false, c == (a & b)].should have_solution(c == false)
  end

  it "|" do
    [a ==  true, b ==  true, c == (a | b)].should have_solution(c ==  true)
    [a ==  true, b == false, c == (a | b)].should have_solution(c ==  true)
    [a == false, b ==  true, c == (a | b)].should have_solution(c ==  true)
    [a == false, b == false, c == (a | b)].should have_solution(c == false)
  end

  it "^" do
    [a ==  true, b ==  true, c == (a ^ b)].should have_solution(c == false)
    [a ==  true, b == false, c == (a ^ b)].should have_solution(c ==  true)
    [a == false, b ==  true, c == (a ^ b)].should have_solution(c ==  true)
    [a == false, b == false, c == (a ^ b)].should have_solution(c == false)
  end

  it "!=" do
    [a ==  true, b ==  true, c == (a != b)].should have_solution(c == false)
    [a ==  true, b == false, c == (a != b)].should have_solution(c ==  true)
    [a == false, b ==  true, c == (a != b)].should have_solution(c ==  true)
    [a == false, b == false, c == (a != b)].should have_solution(c == false)
  end

  it "implies" do
    [a ==  true, b ==  true, c == a.implies(b)].should have_solution(c ==  true)
    [a ==  true, b == false, c == a.implies(b)].should have_solution(c == false)
    [a == false, b ==  true, c == a.implies(b)].should have_solution(c ==  true)
    [a == false, b == false, c == a.implies(b)].should have_solution(c ==  true)
  end

  it "iff" do
    [a ==  true, b ==  true, c == a.iff(b)].should have_solution(c ==  true)
    [a ==  true, b == false, c == a.iff(b)].should have_solution(c == false)
    [a == false, b ==  true, c == a.iff(b)].should have_solution(c == false)
    [a == false, b == false, c == a.iff(b)].should have_solution(c ==  true)
  end

  it "==" do
    [a ==  true, b ==  true, c == (a == b)].should have_solution(c ==  true)
    [a ==  true, b == false, c == (a == b)].should have_solution(c == false)
    [a == false, b ==  true, c == (a == b)].should have_solution(c == false)
    [a == false, b == false, c == (a == b)].should have_solution(c ==  true)
  end

  # ! not possible
  it "~" do
    [a ==  true, b == ~a].should have_solution(b == false)
    [a == false, b == ~a].should have_solution(b ==  true)
  end

  it "if then else" do
    [a ==  true, x == a.ite(2, 3)].should have_solution(x == 2)
    [a == false, x == a.ite(2, 3)].should have_solution(x == 3)
    [a == true,  b == a.ite(true, false)].should have_solution(b == true)
    [a == false, b == a.ite(true, false)].should have_solution(b == false)
    [a == true,  b == a.ite(false, true)].should have_solution(b == false)
    [a == false, b == a.ite(false, true)].should have_solution(b == true)
  end

  it "if then else on Real" do
    r = Z3.real("r")
    [a ==  true, r == a.ite(Z3::RealSort[1] / 2, Z3::RealSort[3])].should have_solution(r == BigRational.new(1, 2))
    [a == false, r == a.ite(Z3::RealSort[1] / 2, Z3::RealSort[3])].should have_solution(r == 3)
    [a ==  true, r == a.ite(2, Z3::RealSort[3])].should have_solution(r == 2)
    [a == false, r == a.ite(Z3::RealSort[2], 3.5)].should have_solution(r == BigRational.new(7, 2))
  end

  it "if then else on Bitvec" do
    v = Z3.bitvec("v", 8)
    w = Z3.bitvec("w", 8)
    [a ==  true, v == a.ite(w, 3), w == 200].should have_solution(v == 200)
    [a == false, v == a.ite(w, 3), w == 200].should have_solution(v == 3)
    [a ==  true, v == a.ite(2, w), w == 200].should have_solution(v == 2)
    # Both branches have to be the same size
    expect_raises(Z3::Exception) { a.ite(v, Z3.bitvec("z", 12)) }
  end

  it "if then else on Char" do
    ch1 = Z3.char("ch1")
    ch2 = Z3.char("ch2")
    [a ==  true, ch1 == a.ite(ch2, 'x'), ch2 == 'y'].should have_solution(ch1 == 'y')
    [a == false, ch1 == a.ite(ch2, 'x'), ch2 == 'y'].should have_solution(ch1 == 'x')
    [a ==  true, ch1 == a.ite('x', ch2), ch2 == 'y'].should have_solution(ch1 == 'x')
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
    [a == Z3.or([] of Z3::BoolExpr)].should have_solution(a == false)
    [a == Z3.or([true, false])].should have_solution(a == true)
    [a == Z3.or([false, false])].should have_solution(a == false)
    [a == Z3.or([false, b]), b == false].should have_solution(a == false)
    [a == Z3.or([false, b]), b == true].should have_solution(a == true)
    [a == Z3.or([true, false, b]), b == true].should have_solution(a == true)
  end

  it "Z3.at_most" do
    [a, b, c, Z3.at_most([a, b, c], 2)].should have_no_solution
    [a, b, Z3.at_most([a, b, c], 2)].should have_solution(c == false)
    [a, b, c, Z3.at_most([a, b, c], 0)].should have_no_solution
    [a, b, c, Z3.at_most([a, b, c], 3)].should have_solution(a == true, b == true, c == true)
  end

  it "Z3.at_least" do
    [~a, ~b, ~c, Z3.at_least([a, b, c], 1)].should have_no_solution
    [~a, Z3.at_least([a, b, c], 2)].should have_solution(b == true, c == true)
    [~a, ~b, ~c, Z3.at_least([a, b, c], 0)].should have_solution(a == false, b == false, c == false)
  end

  it "Z3.exactly" do
    [~a, Z3.exactly([a, b, c], 2)].should have_solution(b == true, c == true)
    [a, b, c, Z3.exactly([a, b, c], 2)].should have_no_solution
    [~a, ~b, ~c, Z3.exactly([a, b, c], 1)].should have_no_solution
    [a, b, c, Z3.exactly([a, b, c], 3)].should have_solution(a == true, b == true, c == true)
  end

  it "cardinality constraints reject bad bounds" do
    expect_raises(Z3::Exception) { Z3.at_most([a, b], -1) }
    expect_raises(Z3::Exception) { Z3.at_least([] of Z3::BoolExpr, 1) }
    expect_raises(Z3::Exception) { Z3.exactly([] of Z3::BoolExpr, 0) }
    expect_raises(Z3::Exception) { Z3.at_most([] of Tuple(Z3::BoolExpr, Int32), 0) }
  end

  it "Z3.at_most with weights" do
    [a, c, Z3.at_most([{a, 3}, {b, 2}, {c, 5}], 7)].should have_no_solution
    [a, b, Z3.at_most([{a, 3}, {b, 2}, {c, 5}], 7)].should have_solution(c == false)
    [a, b, c, Z3.at_most([{a, 3}, {b, 2}, {c, 5}], 10)].should have_solution(a == true, b == true, c == true)
  end

  it "Z3.at_least with weights" do
    [~c, Z3.at_least([{a, 3}, {b, 2}, {c, 5}], 5)].should have_solution(a == true, b == true)
    [~a, ~b, Z3.at_least([{a, 3}, {b, 2}, {c, 5}], 6)].should have_no_solution
  end

  # A weighted total of 5 is reachable two ways here, a+b or c on its own, and Z3 is
  # free to return either - so each way is pinned down to a single solution
  it "Z3.exactly with weights" do
    [~c, Z3.exactly([{a, 3}, {b, 2}, {c, 5}], 5)].should have_solution(a == true, b == true)
    [c, Z3.exactly([{a, 3}, {b, 2}, {c, 5}], 5)].should have_solution(a == false, b == false)
    [~a, ~b, Z3.exactly([{a, 3}, {b, 2}, {c, 5}], 4)].should have_no_solution
  end

  # A count is between 0 and n, so a negative bound on one is a mistake. A weighted
  # total isn't, so the same bound has to be allowed there.
  it "weighted constraints allow negative weights and bounds" do
    [b, Z3.at_most([{a, -3}, {b, 2}], 0)].should have_solution(a == true)
    [~b, Z3.at_most([{a, -3}, {b, 2}], -1)].should have_solution(a == true, b == false)
    [~a, Z3.at_most([{a, -3}, {b, 2}], -1)].should have_no_solution
    [~b, Z3.at_least([{a, 1}, {b, 0}], 1)].should have_solution(a == true, b == false)
  end

  # All weights 1 isn't merely equivalent to the list form, it's the same term
  it "unit weights build the unweighted term" do
    Z3.at_most([{a, 1}, {b, 1}, {c, 1}], 2).should be_same_term(Z3.at_most([a, b, c], 2))
    Z3.at_least([{a, 1}, {b, 1}, {c, 1}], 2).should be_same_term(Z3.at_least([a, b, c], 2))
    Z3.exactly([{a, 1}, {b, 1}, {c, 1}], 2).should be_same_term(Z3.exactly([a, b, c], 2))
  end

  # The bound and the weights are decl parameters rather than arguments, so a
  # constraint which differs only in one of them is still a different term
  it "the bound and the weights are part of the term" do
    Z3.at_most([a, b], 1).should_not be_same_term(Z3.at_most([a, b], 2))
    Z3.at_most([{a, 3}, {b, 2}], 4).should_not be_same_term(Z3.at_most([{a, 3}, {b, 2}], 5))
    Z3.at_most([{a, 3}, {b, 2}], 4).should_not be_same_term(Z3.at_most([{a, 2}, {b, 3}], 4))
  end

  it "Z3.and" do
    [a == Z3.and([] of Z3::BoolExpr)].should have_solution(a == true)
    [a == Z3.and([true, false])].should have_solution(a == false)
    [a == Z3.and([true, true])].should have_solution(a == true)
    [a == Z3.and([true, b]), b == false].should have_solution(a == false)
    [a == Z3.and([true, b]), b == true].should have_solution(a == true)
    [a == Z3.and([true, false, b]), b == true].should have_solution(a == false)
  end
end
