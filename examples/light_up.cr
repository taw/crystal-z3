#!/usr/bin/env crystal

require "../src/z3"

# Also known as Akari
class LightUp
  alias Point = Tuple(Int32, Int32)

  @data : Hash(Point, Char)
  @lamps : Hash(Point, Z3::BoolExpr)
  @xsize : Int32
  @ysize : Int32

  def initialize(path)
    data = File.read(path).split.map(&.strip.chars)
    @xsize = data[0].size
    @ysize = data.size
    @data = {} of Point => Char
    each_cell { |x, y| @data[{x, y}] = data[y][x] }
    @lamps = {} of Point => Z3::BoolExpr
    @solver = Z3::Solver.new
  end

  def call
    each_cell { |x, y| @lamps[{x, y}] = Z3.bool("l#{x},#{y}") }

    each_cell do |x, y|
      v = @data[{x, y}]
      if v == '.'
        # Every white cell must be lit: at least one lamp in its line of sight
        @solver.assert Z3.at_least(line_of_sight(x, y), 1)
      else
        # No lamps on walls; numbers count lamps next to node (diagonals don't count)
        @solver.assert ~@lamps[{x, y}]
        @solver.assert Z3.exactly(lamps_next_to_cell(x, y), v.to_i) if ('0'..'4').includes?(v)
      end
    end

    # No lamp is in raycast of another: at most one lamp per maximal white run
    (white_runs(:horizontal) + white_runs(:vertical)).each do |run|
      @solver.assert Z3.at_most(run.map { |xy| @lamps[xy] }, 1)
    end

    if @solver.satisfiable?
      print_answer! @solver.model
    else
      puts "failed to solve"
    end
  end

  private def lamps_next_to_cell(x0, y0)
    [{x0 - 1, y0}, {x0 + 1, y0}, {x0, y0 - 1}, {x0, y0 + 1}].compact_map { |xy| @lamps[xy]? }
  end

  # The white cell itself plus every white cell visible from it in a straight line
  private def line_of_sight(x0, y0)
    result = [@lamps[{x0, y0}]]
    [{1, 0}, {-1, 0}, {0, 1}, {0, -1}].each do |(dx, dy)|
      x, y = x0 + dx, y0 + dy
      while @data[{x, y}]? == '.'
        result << @lamps[{x, y}]
        x += dx
        y += dy
      end
    end
    result
  end

  # Maximal runs of white cells, broken up by walls, in either direction
  private def white_runs(direction)
    lines = if direction == :horizontal
              (0...@ysize).map { |y| (0...@xsize).map { |x| {x, y} } }
            else
              (0...@xsize).map { |x| (0...@ysize).map { |y| {x, y} } }
            end
    lines.flat_map do |line|
      line.chunks { |xy| @data[xy] == '.' }.select { |(white, _)| white }.map { |(_, run)| run }
    end
  end

  private def each_cell(&)
    (0...@ysize).each { |y| (0...@xsize).each { |x| yield x, y } }
  end

  private def print_answer!(model)
    (0...@ysize).each do |y|
      (0...@xsize).each do |x|
        if @data[{x, y}] != '.'
          print @data[{x, y}]
        elsif model[@lamps[{x, y}]].to_b
          print "*"
        else
          print " "
        end
      end
      puts
    end
  end
end

path = ARGV[0]? || "#{__DIR__}/light_up-1.txt"
LightUp.new(path).call
