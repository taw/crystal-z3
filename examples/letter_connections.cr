#!/usr/bin/env crystal

# NOTE: This solver can fill empty spaces with phantom loops,
#       so it's not technically totally legit true
# As in:
#  A..
#  A..
#
#  Into:
#  A* A→ A↓
#  A↑ A↑ A←
#
# Instead of more correct:
#
#  A* A← A←
#  A→ A→ A↑
#
# This affects few enough real world puzzles and would complicate solution enough
# that I let it be.

require "../src/z3"

class LetterConnections
  alias Point = Tuple(Int32, Int32)

  ARROWS = "←↑→↓"

  @xsize : Int32
  @ysize : Int32

  def initialize(path)
    data = File.read(path).strip.split("\n")
    @xsize = data[0].size
    @ysize = data.size
    @letters = {} of Char => Int32
    @rletters = {} of Int32 => Char
    @starts = {} of Char => Point
    @ends = {} of Char => Point
    @special_ends = {} of Point => Char
    @special_starts = {} of Point => Char
    @line = {} of Point => Z3::IntExpr
    @dir = {} of Point => Z3::IntExpr
    @solver = Z3::Solver.new

    cells = {} of Point => Char
    each_coordinate { |x, y| cells[{x, y}] = data[y][x] }

    cells.to_a.sort_by { |(point, _letter)| point }.each do |(point, letter)|
      next if letter == '.'
      x, y = point
      if @letters.has_key?(letter)
        raise "Letter #{letter} occurs more than twice" if @ends.has_key?(letter)
        @ends[letter] = {x, y}
        @special_ends[{x, y}] = letter
      else
        i = @letters.size
        @letters[letter] = i
        @rletters[i] = letter
        @starts[letter] = {x, y}
        @special_starts[{x, y}] = letter
      end
    end
    @letters.each_key do |letter|
      raise "Letter #{letter} occurs only once" unless @ends.has_key?(letter)
    end
  end

  def call
    each_coordinate { |x, y| @line[{x, y}] = line_var(x, y) }
    each_coordinate { |x, y| @dir[{x, y}] = dir_var(x, y) }

    @letters.each do |letter, i|
      @solver.assert @line[@starts[letter]] == i
      @solver.assert @line[@ends[letter]] == i
    end

    (0...@ysize).each do |y|
      (0...@xsize).each do |x|
        next if @special_ends.has_key?({x, y})
        # Direction Left
        if x == 0
          @solver.assert @dir[{x, y}] != 0
        else
          @solver.assert (@dir[{x, y}] == 0).implies(@line[{x, y}] == @line[{x - 1, y}])
          @solver.assert (@dir[{x, y}] == 0).implies(@dir[{x - 1, y}] != 2)
        end
        # Direction Up
        if y == 0
          @solver.assert @dir[{x, y}] != 1
        else
          @solver.assert (@dir[{x, y}] == 1).implies(@line[{x, y}] == @line[{x, y - 1}])
          @solver.assert (@dir[{x, y}] == 1).implies(@dir[{x, y - 1}] != 3)
        end
        # Direction Right
        if x == @xsize - 1
          @solver.assert @dir[{x, y}] != 2
        else
          @solver.assert (@dir[{x, y}] == 2).implies(@line[{x, y}] == @line[{x + 1, y}])
          @solver.assert (@dir[{x, y}] == 2).implies(@dir[{x + 1, y}] != 0)
        end
        # Direction Down
        if y == @ysize - 1
          @solver.assert @dir[{x, y}] != 3
        else
          @solver.assert (@dir[{x, y}] == 3).implies(@line[{x, y}] == @line[{x, y + 1}])
          @solver.assert (@dir[{x, y}] == 3).implies(@dir[{x, y + 1}] != 1)
        end
      end
    end

    # Everything except start node has one incoming arrow
    # End nodes not counted for this
    (0...@ysize).each do |y|
      (0...@xsize).each do |x|
        next if @special_starts.has_key?({x, y})
        incoming = potential_incoming(x, y).map { |(i, j, d)| @dir[{i, j}] == d }
        @solver.assert Z3.exactly(incoming, 1)
      end
    end

    if @solver.satisfiable?
      print_answer! @solver.model
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

  private def line_var(x, y)
    v = Z3.int("l#{x},#{y}")
    @solver.assert v >= 0
    @solver.assert v < @letters.size
    v
  end

  private def dir_var(x, y)
    v = Z3.int("d#{x},#{y}")
    @solver.assert v >= 0
    @solver.assert v <= 3
    v
  end

  private def potential_incoming(x0, y0)
    [
      {x0 + 1, y0, 0},
      {x0 - 1, y0, 2},
      {x0, y0 + 1, 1},
      {x0, y0 - 1, 3},
    ].select do |(x, y, _d)|
      @dir.has_key?({x, y}) && !@special_ends.has_key?({x, y})
    end
  end

  private def print_answer!(model)
    (0...@ysize).each do |y|
      (0...@xsize).each do |x|
        li = model[@line[{x, y}]].to_i
        l = @rletters[li]
        d = model[@dir[{x, y}]].to_i
        if {x, y} == @starts[l]
          print "#{ARROWS[d]}#{l} "
        elsif {x, y} == @ends[l]
          print "*#{l} "
        else
          print "#{ARROWS[d]}#{l.downcase} "
        end
      end
      puts
    end
  end
end

path = ARGV[0]? || "#{__DIR__}/letter_connections-1.txt"
LetterConnections.new(path).call
