#!/usr/bin/env crystal

require "../src/z3"

class MiracleSudokuSolver
  @data : Array(Array(Int32?))

  def initialize(path)
    @data = File.read(path).strip.split("\n").map do |line|
      line.split.map { |c| c == "." ? nil : c.to_i }
    end
    raise "Bad size" unless @data.size == 9
    raise "Bad size" unless @data.all? { |row| row.size == 9 }
    @cells = Array(Array(Z3::IntExpr)).new
    @solver = Z3::Solver.new
  end

  def king_moves
    [
      {-1, -1},
      {-1, 0},
      {-1, +1},
      {0, -1},
      {0, +1},
      {+1, -1},
      {+1, 0},
      {+1, +1},
    ]
  end

  def knight_moves
    [
      {-2, -1},
      {-2, +1},
      {-1, -2},
      {-1, +2},
      {+1, -2},
      {+1, +2},
      {+2, -1},
      {+2, +1},
    ]
  end

  def orthogonal_moves
    [
      {-1, 0},
      {+1, 0},
      {0, -1},
      {0, +1},
    ]
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

    each_coord do |x, y|
      (king_moves + knight_moves).each do |(dx, dy)|
        x2 = x + dx
        y2 = y + dy
        next unless in_bounds?(x2, y2)
        @solver.assert var_at(x, y) != var_at(x2, y2)
      end

      orthogonal_moves.each do |(dx, dy)|
        x2 = x + dx
        y2 = y + dy
        next unless in_bounds?(x2, y2)
        @solver.assert var_at(x, y) != var_at(x2, y2) + 1
        @solver.assert var_at(x, y) != var_at(x2, y2) - 1
      end
    end

    if @solver.satisfiable?
      print_answer! @solver.model
    else
      puts "failed to solve"
    end
  end

  def each_coord(&)
    9.times do |x|
      9.times do |y|
        yield x, y
      end
    end
  end

  def in_bounds?(x, y)
    (0..8).includes?(x) && (0..8).includes?(y)
  end

  def var_at(x, y)
    @cells[y][x]
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

path = ARGV[0]? || "#{__DIR__}/miracle_sudoku-1.txt"
MiracleSudokuSolver.new(path).call
