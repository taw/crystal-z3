#!/usr/bin/env crystal

require "../src/z3"

# Inspired by Hungry Cat Picross app
#
# With pluses, it means continuous
# Without pluses, it is not continuous

class ColorNonogram
  alias Point = Tuple(Int32, Int32)
  # How many cells of a colour a line has, and whether they're all in one run
  alias ColorCount = Tuple(Int32, Bool)

  @colors : Array(String)
  @cols : Array(Array(ColorCount))
  @rows : Array(Array(ColorCount))

  def initialize(path)
    data = File.read_lines(path)
    @colors = data.shift.split
    @csize = @colors.size
    raise "Expected an empty line" unless data.shift.empty?
    @cols = [] of Array(ColorCount)
    @rows = [] of Array(ColorCount)
    target = @cols
    while row = data.shift?
      if row.empty?
        target = @rows
        next
      end
      target << parse_row(row)
    end
    @xsize = @cols.size
    @ysize = @rows.size
    @board = {} of Point => Z3::IntExpr
    @solver = Z3::Solver.new
  end

  def call
    sanity_checks
    setup_board_vars
    constraint_lines

    if @solver.satisfiable?
      print_board! @solver.model
    else
      puts "There is no solution"
    end
  end

  private def constraint_lines
    @ysize.times do |y|
      constraint_line @rows[y], row_vars(y)
    end
    @xsize.times do |x|
      constraint_line @cols[x], col_vars(x)
    end
  end

  private def constraint_line(color_constraints, line_vars)
    color_constraints.each_with_index do |(expected_total, expected_continuity), color_index|
      correct_color = line_vars.map { |vi| vi == color_index }
      @solver.assert Z3.exactly(correct_color, expected_total)
      # For 0 / 1 this is all
      if expected_total >= 2
        continuity = continuity_somewhere(correct_color, expected_total)
        @solver.assert continuity == expected_continuity
      end
    end
  end

  private def continuity_somewhere(correct, total)
    Z3.or((0...correct.size).map { |start_i|
      continuity_at(correct, total, start_i)
    })
  end

  private def continuity_at(correct, total, start_index) : Z3::BoolExpr
    end_index = start_index + total - 1
    return Z3::BoolSort[false] unless correct[end_index]?
    Z3.and(correct[start_index, total])
  end

  private def row_vars(y)
    (0...@xsize).map { |x| @board[{x, y}] }
  end

  private def col_vars(x)
    (0...@ysize).map { |y| @board[{x, y}] }
  end

  # What the Ruby version gets from the Paint gem: the number painted its own
  # colour, as a 24 bit terminal escape. A colour with no name here prints plain.
  COLORS = {
    "red"    => {255, 0, 0},
    "black"  => {0, 0, 0},
    "white"  => {255, 255, 255},
    "brown"  => {165, 42, 42},
    "green"  => {0, 128, 0},
    "blue"   => {0, 0, 255},
    "yellow" => {255, 255, 0},
    "orange" => {255, 165, 0},
    "purple" => {128, 0, 128},
    "grey"   => {128, 128, 128},
    "gray"   => {128, 128, 128},
    "pink"   => {255, 192, 203},
  }

  private def print_board!(model)
    @ysize.times do |y|
      @xsize.times do |x|
        v = model[@board[{x, y}]].to_i
        print paint(v, @colors[v]), " "
      end
      print "\n"
    end
  end

  private def paint(value, color)
    rgb = COLORS[color]?
    return value.to_s unless rgb
    r, g, b = rgb
    "\e[38;2;#{r};#{g};#{b}m#{value}\e[0m"
  end

  private def setup_board_vars
    @xsize.times do |x|
      @ysize.times do |y|
        v = Z3.int("c#{x},#{y}")
        @solver.assert v >= 0
        @solver.assert v < @csize
        @board[{x, y}] = v
      end
    end
  end

  # Z3 will return can't solve, but we might as well get better errors
  private def sanity_checks
    @rows.each do |row|
      raise "Wrong row count" unless row.sum(&.first) == @xsize
    end

    @cols.each do |col|
      raise "Wrong col count" unless col.sum(&.first) == @ysize
    end
  end

  private def parse_row(row)
    parts = row.split.map { |x| parse_part(x) }
    unless parts.size == @csize
      raise "Incorrect row size, expected #{@csize}: #{row.inspect}"
    end
    parts
  end

  private def parse_part(x) : ColorCount
    case x
    when "."
      {0, false}
    when /\A(\d+)\z/
      {$1.to_i, false}
    when /\A(\d+)\+\z/
      {$1.to_i, true}
    else
      raise "Incorrect part #{x.inspect}"
    end
  end
end

path = ARGV[0]? || "#{__DIR__}/color_nonogram-1.txt"
ColorNonogram.new(path).call
