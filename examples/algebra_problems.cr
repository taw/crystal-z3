#!/usr/bin/env crystal

require "../src/z3"

# http://www.analyzemath.com/Algebra1/Algebra1.html
abstract class AlgebraProblem
  getter solver = Z3::Solver.new

  abstract def call

  def print_solution!(number)
    puts "Solution to problem %s:" % number
    if @solver.satisfiable?
      @solver.model.each do |n, v|
        puts "* #{n} = #{v}"
      end
    else
      puts "* Can't solve the problem"
    end
  end
end

# Problem 1: Solve the equation
#   5(-3x - 2) - (x - 3) = -4(4x + 5) + 13
class AlgebraProblem01 < AlgebraProblem
  def call
    x = Z3.real("x")
    solver.assert 5*(-3*x - 2) - (x - 3) == -4*(4*x + 5) + 13
    print_solution! "01"
    # No nice way to say x is unconstrained
  end
end

# Problem 3: If x < 2, simplify
#   |x - 2| = 4|-6|
# (actually I misread original, whatever)
class AlgebraProblem03 < AlgebraProblem
  def call
    x = Z3.real("x")
    xm2abs = Z3.real("|x-2|")
    solver.assert xm2abs == (x - 2).abs
    m6abs = Z3.real("|-6|")
    # The gem writes this as `Z3.Const(-6)`, which picks the sort from the Ruby
    # value. There is no `Z3.const` here, and a Real is what it's compared against.
    solver.assert m6abs == Z3::RealSort[-6].abs
    solver.assert x < 2
    solver.assert xm2abs == 4*m6abs
    print_solution! "03"
  end
end

# Problem 4: Find the distance between the points (-4 , -5) and (-1 , -1).
class AlgebraProblem04 < AlgebraProblem
  def declare_distance(a_b, ax, ay, bx, by)
    solver.assert a_b >= 0
    solver.assert a_b**2 == (ax - bx)**2 + (ay - by)**2
  end

  def call
    ax = Z3.real("ax")
    ay = Z3.real("ay")
    bx = Z3.real("bx")
    by = Z3.real("by")
    a_b = Z3.real("|a-b|")
    declare_distance(a_b, ax, ay, bx, by)
    solver.assert ax == -4
    solver.assert ay == -5
    solver.assert bx == -1
    solver.assert by == -1
    print_solution! "04"
  end
end

# Problem 5: Find the x intercept of the graph of the equation
#   2x - 4y = 9
class AlgebraProblem05 < AlgebraProblem
  def call
    x = Z3.real("x")
    y = Z3.real("y")
    solver.assert 2*x - 4*y == 9
    solver.assert y == 0
    print_solution! "05"
  end
end

# Problem 6: Evaluate f(2) - f(1) for f(x) = 6x + 1
class AlgebraProblem06 < AlgebraProblem
  def declare_f(x, y)
    solver.assert y == 6*x + 1
  end

  def call
    x1 = Z3.real("x1")
    y1 = Z3.real("y1")
    x2 = Z3.real("x2")
    y2 = Z3.real("y2")
    answer = Z3.real("answer")
    solver.assert x2 == 2
    solver.assert x1 == 1
    declare_f(x1, y1)
    declare_f(x2, y2)
    solver.assert answer == y2 - y1
    print_solution! "06"
  end
end

# Problem 10: Solve the equation
#   |-2x + 2| - 3 = -3
class AlgebraProblem10 < AlgebraProblem
  def call
    x = Z3.real("x")
    y = Z3.real("|-2x + 2|")
    solver.assert y == (-2*x + 2).abs
    solver.assert y - 3 == -3
    print_solution! "10"
  end
end

AlgebraProblem01.new.call
AlgebraProblem03.new.call
AlgebraProblem04.new.call
AlgebraProblem05.new.call
AlgebraProblem06.new.call
AlgebraProblem10.new.call
