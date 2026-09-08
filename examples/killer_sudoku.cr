#!/usr/bin/env crystal

require "../src/z3"

class KillerSudokuSolver
  @knowns : Array(Array(Int32?))
  @cages : Array(Array(String))

  def initialize(path)
    knowns, cages, cage_counts = File.read(path).split(/\n{2,}/)
    @knowns = knowns.strip.split("\n").map do |line|
      line.split.map { |c| c == "." ? nil : c.to_i }
    end
    @cages = cages.strip.split("\n").map(&.split)
    @size = @knowns.size
    raise "Bad size" unless @knowns.all? { |line| line.size == @size }
    raise "Bad size" unless @cages.size == @size
    raise "Bad size" unless @cages.all? { |line| line.size == @size }
    @cage_counts = {} of String => Int32
    cage_counts.strip.split("\n").each do |line|
      name, count = line.split
      @cage_counts[name] = count.to_i
    end
    @cells = Array(Array(Z3::IntExpr)).new
    @solver = Z3::Solver.new
    @boxsize = case @size
               when 9 then 3
               when 4 then 2
               else        raise "Bad size"
               end
  end

  def call
    @cells = (0...@size).map do |j|
      (0...@size).map do |i|
        cell_var(@knowns[j][i], i, j)
      end
    end

    @cells.each do |row|
      @solver.assert Z3.distinct(row)
    end
    @cells.transpose.each do |column|
      @solver.assert Z3.distinct(column)
    end
    @cells.each_slice(@boxsize) do |rows|
      rows.transpose.each_slice(@boxsize) do |square|
        @solver.assert Z3.distinct(square.flatten)
      end
    end

    by_cage = {} of String => Array(Z3::IntExpr)
    (0...@size).each do |j|
      (0...@size).each do |i|
        (by_cage[@cages[j][i]] ||= [] of Z3::IntExpr) << @cells[j][i]
      end
    end

    by_cage.each do |cage_name, cells|
      @solver.assert Z3.add(cells) == @cage_counts[cage_name]
      @solver.assert Z3.distinct(cells)
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
    @solver.assert v <= @size
    @solver.assert v == cell if cell
    v
  end

  private def print_answer(model)
    @cells.each do |row|
      puts row.map { |v| model[v] }.join(" ")
    end
  end
end

path = ARGV[0]? || "#{__DIR__}/killer_sudoku-1.txt"
KillerSudokuSolver.new(path).call
