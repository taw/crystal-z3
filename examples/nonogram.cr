#!/usr/bin/env crystal

require "../src/z3"

class Nonogram
  @cells : Array(Array(Z3::BoolExpr))

  def initialize(@columns : Array(Array(Int32)), @rows : Array(Array(Int32)))
    @solver = Z3::Solver.new
    @xsize = @columns.size
    @ysize = @rows.size
    @cells = Array(Array(Z3::BoolExpr)).new
  end

  def print_answer!(model)
    @ysize.times do |y|
      @xsize.times do |x|
        if model[@cells[y][x]].to_b
          print "█"
        else
          print "·"
        end
      end
      print "\n"
    end
  end

  def print_all_answers!
    if @solver.satisfiable?
      model = @solver.model
      print_answer! model
      # `model.negate` is "any variable differs from what it is here", which is
      # exactly the constraint a uniqueness check needs. The group start/end
      # variables are determined by the picture, so a second model would be a
      # second picture.
      @solver.assert model.negate
      if @solver.satisfiable?
        puts "solution is not unique"
        print_answer! @solver.model
      else
        puts "solution is unique"
      end
    else
      puts "failed to solve"
    end
  end

  # One start and one end variable per group of filled cells, in order and with a
  # gap between them
  def setup_vars(nums, prefix, size)
    results = [] of Tuple(Z3::IntExpr, Z3::IntExpr)
    (0...nums.size).each do |i|
      vs = Z3.int("#{prefix},#{i + 1},s")
      ve = Z3.int("#{prefix},#{i + 1},e")
      @solver.assert ve - vs == nums[i] - 1
      @solver.assert vs >= 0
      @solver.assert ve < size
      results << {vs, ve}
    end

    (0...nums.size - 1).each do |i|
      ve0 = results[i][1]
      vs1 = results[i + 1][0]
      @solver.assert vs1 >= ve0 + 2
    end

    results
  end

  def setup_cell_constraints(cells, cvars)
    (0...cells.size).each do |i|
      rule_i = Z3.or(
        cvars.map { |(vs, ve)| Z3.and([vs <= i, i <= ve]) }
      )
      @solver.assert cells[i] == rule_i
    end
  end

  def call
    @cells = (0...@ysize).map { |y|
      (0...@xsize).map { |x|
        Z3.bool("cell[#{x + 1},#{y + 1}]")
      }
    }

    column_vars = (0...@xsize).map { |i|
      setup_vars(@columns[i], "c%d" % (i + 1), @ysize)
    }
    row_vars = (0...@ysize).map { |i|
      setup_vars(@rows[i], "r%d" % (i + 1), @xsize)
    }

    @xsize.times do |i|
      setup_cell_constraints(@cells.map { |row| row[i] }, column_vars[i])
    end

    @ysize.times do |i|
      setup_cell_constraints(@cells[i], row_vars[i])
    end

    print_all_answers!
  end
end

nonogram = Nonogram.new(
  [
    [2],
    [1, 2],
    [2, 3],
    [2, 3],
    [3, 1, 1],
    [2, 1, 1],
    [1, 1, 1, 2, 2],
    [1, 1, 3, 1, 3],
    [2, 6, 4],
    [3, 3, 9, 1],
    [5, 3, 2],
    [3, 1, 2, 2],
    [2, 1, 7],
    [3, 3, 2],
    [2, 4],
    [2, 1, 2],
    [2, 2, 1],
    [2, 2],
    [1],
    [1],
  ],
  [
    [3],
    [5],
    [3, 1],
    [2, 1],
    [3, 3, 4],
    [2, 2, 7],
    [6, 1, 1],
    [4, 2, 2],
    [1, 1],
    [3, 1],
    [6],
    [2, 7],
    [6, 3, 1],
    [1, 2, 2, 1, 1],
    [4, 1, 1, 3],
    [4, 2, 2],
    [3, 3, 1],
    [3, 3],
    [3],
    [2, 1],
  ]
)

nonogram.call
