require "spec"
require "../src/z3"

# Expectations are Z3 constraints, so `have_solution(c == 6)` asks whether the model
# the solver returned satisfies `c == 6` - not merely whether some model could.
class SolutionExpectation
  def initialize(@expected : Array(Z3::BoolExpr))
  end

  def match(asts)
    solver = setup_solver(asts)
    return false unless solver.satisfiable?
    model = solver.model
    @expected.all? { |expectation| holds?(model, expectation) }
  end

  def failure_message(asts)
    solver = setup_solver(asts)
    unless solver.satisfiable?
      return "Expected #{asts.inspect} to have a solution, but no solution was found"
    end
    model = solver.model
    failed = @expected.reject { |expectation| holds?(model, expectation) }
    "Solution found, but it does not match expectations:\n" +
      failed.map { |expectation| "  #{describe(model, expectation)}" }.join("\n")
  end

  def negative_failure_message(asts)
    "Expected #{asts.inspect} not to have a solution satisfying " +
      @expected.map(&.to_s).join(", ") + ", but it does"
  end

  private def holds?(model, expectation)
    model.eval(expectation, true).value
  end

  # Expectations are nearly always `lhs == rhs`, so a failure can name the left hand
  # side and say what the model gave it instead. Anything else is printed whole.
  # TODO: this gets a lot less ad hoc once we have a printer of our own
  private def describe(model, expectation)
    args = Z3::API.app_args(expectation)
    return "#{expectation} is false" unless args.size == 2
    lhs, rhs = args
    "#{lhs} (actual #{model.eval(lhs, true)}, expected #{rhs})"
  end

  private def setup_solver(asts)
    solver = Z3::Solver.new
    asts.each { |ast| solver.assert(ast) }
    solver
  end
end

class NoSolutionExpectation
  def match(asts)
    !setup_solver(asts).satisfiable?
  end

  def failure_message(asts)
    "Expected #{asts.inspect} to have no solution, but one was found:\n#{setup_solver(asts).model}"
  end

  def negative_failure_message(asts)
    "Expected #{asts.inspect} to have a solution, but none was found"
  end

  private def setup_solver(asts)
    solver = Z3::Solver.new
    asts.each { |ast| solver.assert(ast) }
    solver
  end
end

class SameTermExpectation
  def initialize(@expected : Z3::AnyExpr)
  end

  def match(actual)
    actual.same_term?(@expected)
  end

  def failure_message(actual)
    "Expected #{actual} to be the same term as #{@expected}"
  end

  def negative_failure_message(actual)
    "Expected #{actual} not to be the same term as #{@expected}"
  end
end

module Spec::Expectations
  def have_solution(*expected : Z3::BoolExpr)
    SolutionExpectation.new expected.to_a
  end

  def have_no_solution
    NoSolutionExpectation.new
  end

  def be_same_term(expected : Z3::AnyExpr)
    SameTermExpectation.new expected
  end
end
