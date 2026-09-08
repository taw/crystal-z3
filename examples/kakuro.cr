#!/usr/bin/env crystal

require "../src/z3"

class Kakuro
  # A clue cell holds the two sums it starts - down and right - and an ordinary
  # cell holds nothing at all
  alias Point = Tuple(Int32, Int32)
  alias Clue = Tuple(Int32, Int32)

  @xsize : Int32
  @ysize : Int32
  @data : Hash(Point, Clue?)

  def initialize(path)
    rows = File.read(path).strip.split("\n").map do |line|
      line.split.map { |cell| parse_cell(cell) }
    end
    @xsize = rows[0].size
    @ysize = rows.size
    @data = map_coordinates { |x, y| rows[y][x] }
    @cells = {} of Point => Z3::IntExpr
    @solver = Z3::Solver.new
  end

  def call
    each_coordinate do |x, y|
      @cells[{x, y}] = cell_var(x, y) if @data[{x, y}].nil?
    end

    (0...@ysize).each do |y|
      (0...@xsize).each do |x|
        cell = @data[{x, y}]
        next if cell.nil?
        a, b = cell
        setup_line!(x, y, 0, 1, a)
        setup_line!(x, y, 1, 0, b)
      end
    end

    if @solver.satisfiable?
      print_board! @solver.model
    else
      puts "failed to solve"
    end
  end

  private def each_coordinate(&)
    (0...@xsize).each do |x|
      (0...@ysize).each do |y|
        yield x, y
      end
    end
  end

  private def map_coordinates(&)
    result = {} of Point => Clue?
    each_coordinate { |x, y| result[{x, y}] = yield x, y }
    result
  end

  private def print_board!(model)
    (0...@ysize).each do |y|
      (0...@xsize).each do |x|
        cell = @data[{x, y}]
        if cell.nil?
          print " [#{model[@cells[{x, y}]]}] "
        elsif cell == {0, 0}
          print "  x  "
        else
          a, b = cell
          print "#{a == 0 ? "  " : "%2d" % a}/#{b == 0 ? "  " : "%-2d" % b}"
        end
        print " "
      end
      print "\n"
    end
  end

  private def parse_cell(cell) : Clue?
    if cell == "_"
      nil
    elsif cell == "x"
      {0, 0}
    else
      a, b = cell.split("/")
      {a.to_i? || 0, b.to_i? || 0}
    end
  end

  private def cell_var(x, y)
    v = Z3.int("c#{x},#{y}")
    @solver.assert v >= 1
    @solver.assert v <= 9
    v
  end

  private def setup_line!(x0, y0, dx, dy, sum)
    return if sum == 0
    vs = [] of Z3::IntExpr
    x, y = x0 + dx, y0 + dy
    while (v = @cells[{x, y}]?)
      vs << v
      x += dx
      y += dy
    end
    return if vs.empty?
    @solver.assert Z3.distinct(vs)
    @solver.assert Z3.add(vs) == sum
  end
end

path = ARGV[0]? || "#{__DIR__}/kakuro-1.txt"
Kakuro.new(path).call
