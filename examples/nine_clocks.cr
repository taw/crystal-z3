#!/usr/bin/env crystal
# From Tested on Humans Escape Room game

require "../src/z3"

class NineClocks
  alias Point = Tuple(Int32, Int32)

  def initialize
    @solver = Z3::Solver.new

    @inputs = {} of Point => Z3::BitvecExpr
    @outputs = {} of Point => Z3::BitvecExpr

    # Setup
    each_xy do |x, y|
      @inputs[{x, y}] = Z3.bitvec("i#{x},#{y}", 2)
      @outputs[{x, y}] = Z3.bitvec("o#{x},#{y}", 2)
    end

    # Rules
    each_xy do |x, y|
      neighbours = [] of Z3::BitvecExpr
      each_xy do |xx, yy|
        neighbours << @inputs[{xx, yy}] if (xx - x).abs + (yy - y).abs <= 1
      end
      # Z3 has no n-ary add for Bitvec, so this is the fold Z3.Add does
      @solver.assert @outputs[{x, y}] == neighbours.reduce { |a, b| a + b }
    end
  end

  def each_xy(&)
    3.times do |x|
      3.times do |y|
        yield x, y
      end
    end
  end

  def target_corner
    target(0, 0)
  end

  def target_edge
    target(0, 1)
  end

  def target_center
    target(1, 1)
  end

  def solve
    if @solver.satisfiable?
      model = @solver.model

      puts "IN:"
      print_grid model, @inputs

      puts "OUT:"
      print_grid model, @outputs
    else
      puts "Not satisfiable"
    end
  end

  private def target(tx, ty)
    each_xy do |x, y|
      if x == tx && y == ty
        @solver.assert @outputs[{x, y}] == 1
      else
        @solver.assert @outputs[{x, y}] == 0
      end
    end
    self
  end

  private def print_grid(model, vars)
    3.times do |x|
      3.times do |y|
        print model[vars[{x, y}]], " "
      end
      print "\n"
    end
  end
end

NineClocks.new.target_corner.solve
NineClocks.new.target_edge.solve
NineClocks.new.target_center.solve
