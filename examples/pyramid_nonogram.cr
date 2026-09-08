#!/usr/bin/env crystal

require "../src/z3"

class PyramidNonogram
  def initialize(@size : Int32)
    @solver = Z3::Solver.new
    @stripe_index = 0
  end

  def bottom_to_right(*args : Array(Int32?))
    (0...@size).each do |i|
      match! bottom_to_right_stripe(i), args[i]
    end
  end

  def right_to_left(*args : Array(Int32?))
    (0...@size).each do |i|
      match! right_to_left_stripe(i), args[i]
    end
  end

  def left_to_bottom(*args : Array(Int32?))
    (0...@size).each do |i|
      match! left_to_bottom_stripe(i), args[i]
    end
  end

  def call
    if @solver.satisfiable?
      print_answer! @solver.model
    else
      puts "There is no solution"
    end
  end

  private def match!(cells, constraints)
    @stripe_index += 1
    prefix = "#{@stripe_index}"
    group_vars = [] of Tuple(Z3::IntExpr, Z3::IntExpr)
    # Groups have size specified by constraints
    # and start and end within specified cell range
    (0...constraints.size).each do |i|
      vs = Z3.int("#{prefix},#{i + 1},s")
      ve = Z3.int("#{prefix},#{i + 1},e")
      if size = constraints[i]
        @solver.assert ve - vs == size - 1
      end
      @solver.assert vs >= 0
      @solver.assert ve < cells.size
      group_vars << {vs, ve}
    end

    # Gap between groups are at least one
    (0...constraints.size - 1).each do |i|
      ve0 = group_vars[i][1]
      vs1 = group_vars[i + 1][0]
      @solver.assert vs1 >= ve0 + 2
    end

    # Cell is on  iff  it belongs to a group
    (0...cells.size).each do |i|
      rule_i = if constraints.empty?
                 Z3::BoolSort[false]
               else
                 Z3.or(group_vars.map { |(vs, ve)| Z3.and([vs <= i, i <= ve]) })
               end
      @solver.assert cells[i] == rule_i
    end
  end

  private def right_to_left_stripe(y)
    (-y..y).map { |x| cell(x, y) }.reverse
  end

  private def bottom_to_right_stripe(i)
    (0...@size).to_a.reverse.flat_map { |y|
      [{-y + 2*i, y}, {-y + 2*i + 1, y}]
    }.select { |(x, y)| (-y..y).includes?(x) }.map { |(x, y)| cell(x, y) }
  end

  private def left_to_bottom_stripe(i)
    (0...@size).to_a.flat_map { |y|
      [{y - 2*i - 1, y}, {y - 2*i, y}]
    }.select { |(x, y)| (-y..y).includes?(x) }.map { |(x, y)| cell(x, y) }
  end

  private def cell(x, y)
    Z3.bool("c#{x},#{y}")
  end

  private def print_answer!(model)
    (0...@size).each do |y|
      (-@size..@size).each do |x|
        if (-y..y).includes?(x)
          value = model[cell(x, y)].to_b
          cell = if (x + y).odd?
                   value ? "▼" : "▽"
                 else
                   value ? "▲" : "△"
                 end
        else
          cell = " "
        end
        print cell
      end
      print "\n"
    end
  end
end

# Example from:
# http://www.rankk.org/challenges/images/nonogrampyramid.png
u = nil # nil means group of unknown size
pyramid_nonogram = PyramidNonogram.new(12)
pyramid_nonogram.bottom_to_right(
  [2, 1, 1, 5, 3, 2],
  [1, 2, 1, 1, 1],
  [3, 1, 1, 3],
  [1, 1, 1, 2],
  [3, 2, 2, 3],
  [2, 1, 1, 1],
  [2, 2],
  [1, 3, 1],
  [2, 3],
  [1, 1],
  [1],
  [1],
)
pyramid_nonogram.right_to_left(
  [] of Int32?,
  [1, 1],
  [1],
  [1, 1, 2],
  [1, 2, 2],
  [2, 3],
  [1, 1, 2, 2],
  [4, 2, 1],
  [1, 2, 2],
  [3, 1, 1, 2, 3, 1],
  [1, 3, 1, 2],
  [2, 3, 1, 4, 1, 2],
)
pyramid_nonogram.left_to_bottom(
  [u, u, u, u, u, u, u],
  [u, u, u, u, u],
  [u, u, u, u, u],
  [u, u, u, u, u, u],
  [u, u, u],
  [u, u, u, u],
  [u, u, u],
  [u, u],
  [] of Int32?,
  [u, u],
  [u],
  [u],
)
pyramid_nonogram.call
