#!/usr/bin/env crystal

require "../src/z3"

class Kakurasu
  alias Point = Tuple(Int32, Int32)

  @col_sums : Array(Int32)
  @row_sums : Array(Int32)
  @xsize : Int32
  @ysize : Int32

  def initialize(path)
    data = File.read_lines(path).select(/\S/)
    raise "Data needs to have two lines (cols, rows)" unless data.size == 2
    @col_sums = data[0].split.map(&.to_i)
    @row_sums = data[1].split.map(&.to_i)

    @xsize = @col_sums.size
    @ysize = @row_sums.size
    @bvars = {} of Point => Z3::BoolExpr
    @cvars = {} of Int32 => Array(Z3::IntExpr)
    @rvars = {} of Int32 => Array(Z3::IntExpr)
    @solver = Z3::Solver.new
  end

  def call
    # setup
    @ysize.times do |y|
      @xsize.times do |x|
        b = Z3.bool("b#{x},#{y}")
        r = Z3.int("r#{x},#{y}")
        c = Z3.int("c#{x},#{y}")
        @solver.assert (~b).implies(r == 0)
        @solver.assert (~b).implies(c == 0)
        @solver.assert b.implies(r == (x + 1))
        @solver.assert b.implies(c == (y + 1))
        @bvars[{x, y}] = b
        (@cvars[x] ||= [] of Z3::IntExpr) << c
        (@rvars[y] ||= [] of Z3::IntExpr) << r
      end
    end

    # Row sums weight cells by their column index, column sums by their row index
    @ysize.times do |y|
      @solver.assert Z3.add(@rvars[y]) == @row_sums[y]
    end

    @xsize.times do |x|
      @solver.assert Z3.add(@cvars[x]) == @col_sums[x]
    end

    if @solver.satisfiable?
      print_board! @solver.model
    else
      puts "failed to solve"
    end
  end

  private def print_board!(model)
    @ysize.times do |y|
      @xsize.times do |x|
        if model[@bvars[{x, y}]].to_b
          print "[X]"
        else
          print "[ ]"
        end
      end
      print "\n"
    end
  end
end

path = ARGV[0]? || "#{__DIR__}/kakurasu-1.txt"
Kakurasu.new(path).call
