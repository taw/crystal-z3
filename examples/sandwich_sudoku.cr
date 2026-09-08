#!/usr/bin/env crystal

require "../src/z3"

class SandwichSudokuSolver
  @data : Array(Array(Int32?))
  @col_counts : Array(Int32?)
  @row_counts : Array(Int32?)
  @xsize : Int32
  @ysize : Int32

  def initialize(path)
    data = File.read(path).strip.split("\n").map do |line|
      line.split.map { |c| c =~ /\A\d+\z/ ? c.to_i : nil }
    end
    @col_counts = data.shift
    @row_counts = data.map(&.shift)
    @xsize = @col_counts.size
    @ysize = @row_counts.size
    @data = data
    raise "Bad size" unless data.size == @ysize
    raise "Bad size" unless data.all? { |r| r.size == @ysize }
    @cells = Array(Array(Z3::IntExpr)).new
    @solver = Z3::Solver.new
  end

  def call
    @cells = (0..8).map do |y|
      (0..8).map do |x|
        cell_var(@data[y][x], x, y)
      end
    end

    @cells.each do |row|
      @solver.assert Z3.distinct(row)
    end
    @cells.transpose.each do |column|
      @solver.assert Z3.distinct(column)
    end
    @cells.each_slice(3) do |rows|
      rows.transpose.each_slice(3) do |square|
        @solver.assert Z3.distinct(square.flatten)
      end
    end

    9.times do |x|
      assert_sandwich "c#{x + 1}", @col_counts[x], col_vars(x)
    end

    9.times do |y|
      assert_sandwich "s#{y + 1}", @row_counts[y], row_vars(y)
    end

    if @solver.satisfiable?
      print_answer! @solver.model
    else
      puts "failed to solve"
    end
  end

  # The count is how much sits between the 1 and the 9, so `ss` and `se` are where
  # those two are and everything strictly between them adds up to it
  def assert_sandwich(name, count, vars)
    ss = Z3.int("#{name}-ss")
    se = Z3.int("#{name}-se")
    @solver.assert ss >= 0
    @solver.assert ss <= 8
    @solver.assert se >= 0
    @solver.assert se <= 8
    @solver.assert ss < se
    9.times do |i|
      @solver.assert ((vars[i] == 1) | (vars[i] == 9)) == ((ss == i) | (se == i))
    end
    e = (0...9).map do |i|
      Z3.and([i > ss, i < se]).ite(vars[i], 0)
    end
    @solver.assert Z3.add(e) == count.not_nil!
  end

  def row_vars(y)
    @cells[y]
  end

  def col_vars(x)
    @cells.map { |line| line[x] }
  end

  private def cell_var(cell, x, y)
    v = Z3.int("cell[#{x + 1},#{y + 1}]")
    @solver.assert v >= 1
    @solver.assert v <= 9
    @solver.assert v == cell if cell
    v
  end

  private def print_answer!(model)
    @cells.each do |row|
      puts row.map { |v| model[v] }.join(" ")
    end
  end
end

path = ARGV[0]? || "#{__DIR__}/sandwich_sudoku-1.txt"
SandwichSudokuSolver.new(path).call
