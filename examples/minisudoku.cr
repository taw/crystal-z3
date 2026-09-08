#!/usr/bin/env crystal

require "../src/z3"

class MiniSudokuSolver
  @data : Array(Array(Int32?))

  def initialize(path)
    @data = File.read_lines(path).map do |line|
      line.split.map { |c| c == "_" ? nil : c.to_i }
    end
    @cells = Array(Array(Z3::IntExpr)).new
    @solver = Z3::Solver.new
  end

  def call
    @cells = (0..5).map do |j|
      (0..5).map do |i|
        cell_var(@data[j][i], i, j)
      end
    end

    @cells.each do |row|
      @solver.assert Z3.distinct(row)
    end
    @cells.transpose.each do |column|
      @solver.assert Z3.distinct(column)
    end
    @cells.each_slice(2) do |rows|
      rows.transpose.each_slice(3) do |square|
        @solver.assert Z3.distinct(square.flatten)
      end
    end

    if @solver.satisfiable?
      print_answer @solver.model
    else
      puts "failed to solve"
    end
  end

  private def cell_var(cell, i, j)
    v = Z3.int("cell[#{i + 1},#{j + 1}]")
    @solver.assert v >= 1
    @solver.assert v <= 6
    @solver.assert v == cell if cell
    v
  end

  private def print_answer(model)
    @cells.each do |row|
      puts row.map { |v| model[v] }.join(" ")
    end
  end
end

path = ARGV[0]? || "#{__DIR__}/minisudoku-1.txt"
MiniSudokuSolver.new(path).call
