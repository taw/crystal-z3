require "./spec_helper"

describe Z3::RoundingModeExpr do
  m = Z3.rounding_mode("m")
  n = Z3.rounding_mode("n")
  x = Z3.bool("x")

  ties_even = Z3::RoundingModeSort.nearest_ties_even
  ties_away = Z3::RoundingModeSort.nearest_ties_away
  to_zero = Z3::RoundingModeSort.towards_zero
  to_negative = Z3::RoundingModeSort.towards_negative
  to_positive = Z3::RoundingModeSort.towards_positive
  all_modes = [ties_even, ties_away, to_zero, to_negative, to_positive]

  it "RoundingModeSort.to_s" do
    Z3::RoundingModeSort.to_s.should eq("RoundingMode")
  end

  it "has exactly five values" do
    solver = Z3::Solver.new
    solver.assert Z3.distinct(all_modes)
    solver.satisfiable?.should be_true
    # A sixth value would have to be one of those five
    [Z3.distinct(all_modes + [m])].should have_no_solution
  end

  it "==" do
    [m == to_zero, n == to_zero, x == (m == n)].should have_solution(x == true)
    [m == to_zero, n == to_positive, x == (m == n)].should have_solution(x == false)
  end

  it "!=" do
    [m == to_zero, n == to_zero, x == (m != n)].should have_solution(x == false)
    [m == to_zero, n == to_positive, x == (m != n)].should have_solution(x == true)
  end

  it "ite" do
    [x == true, m == x.ite(to_zero, to_positive)].should have_solution(m == to_zero)
    [x == false, m == x.ite(to_zero, to_positive)].should have_solution(m == to_positive)
  end

  it "same_term?" do
    to_zero.should be_same_term(to_zero)
    to_zero.should_not be_same_term(to_positive)
  end

  it "to_s" do
    ties_even.to_s.should eq("roundNearestTiesToEven")
    ties_away.to_s.should eq("roundNearestTiesToAway")
    to_zero.to_s.should eq("roundTowardZero")
    to_negative.to_s.should eq("roundTowardNegative")
    to_positive.to_s.should eq("roundTowardPositive")
    m.to_s.should eq("m")
  end

  it "comes back out of a model" do
    solver = Z3::Solver.new
    solver.assert m == to_negative
    solver.satisfiable?.should be_true
    solver.model[m].should be_same_term(to_negative)
    solver.model[m].sort.should eq(Z3::RoundingModeSort)
  end

  it "cast" do
    Z3::RoundingModeSort.cast(to_zero).should be_same_term(to_zero)
    expect_raises(Z3::Exception) { Z3::RoundingModeSort.cast(42) }
  end

  # The solver picking the rounding mode is the point of it being a sort at all
  it "a variable rounding mode" do
    double = Z3::FloatSort.new(:double)
    a = double.var("a")
    # 2.5 rounds to 2.0 under ties-even and to 3.0 under ties-away, so the solver
    # has to pick a mode which rounds up - and two of the five do
    [a == double[2.5].round_to_integral(m), a == 3.0]
      .should have_solution((m == ties_away) | (m == to_positive))
    [a == double[2.5].round_to_integral(m), a == 2.0]
      .should have_solution((m == ties_even) | (m == to_zero) | (m == to_negative))
  end
end
