#!/usr/bin/env crystal

require "../src/z3"

class Bridges
  alias Point = Tuple(Int32, Int32)

  @data : Hash(Point, Int32?)
  @xsize : Int32
  @ysize : Int32

  def initialize(path)
    data = File.read(path).strip.split("\n").map do |line|
      line.split.map { |c| c == "_" ? nil : c.to_i }
    end
    @xsize = data[0].size
    @ysize = data.size
    @data = {} of Point => Int32?
    (0...@xsize).each do |x|
      (0...@ysize).each do |y|
        @data[{x, y}] = data[y][x]
      end
    end
    @vars = {} of Tuple(Int32, Int32, String) => Z3::IntExpr
    @solver = Z3::Solver.new
  end

  def call
    (0...@xsize).each do |x|
      (0...@ysize).each do |y|
        u = int012(x, y, "u")
        d = int012(x, y, "d")
        r = int012(x, y, "r")
        l = int012(x, y, "l")
        @vars[{x, y, "u"}] = u
        @vars[{x, y, "d"}] = d
        @vars[{x, y, "r"}] = r
        @vars[{x, y, "l"}] = l
        if island = @data[{x, y}]
          @solver.assert u + d + r + l == island
        else
          # Bridges pass through, and never cross
          @solver.assert u == d
          @solver.assert l == r
          @solver.assert (u == 0) | (l == 0)
        end
        # Nothing goes out of the map
        @solver.assert l == 0 if x == 0
        @solver.assert r == 0 if x == @xsize - 1
        @solver.assert u == 0 if y == 0
        @solver.assert d == 0 if y == @ysize - 1
      end
    end

    (0...@xsize).each do |x|
      (0...@ysize).each do |y|
        @solver.assert @vars[{x, y, "r"}] == @vars[{x + 1, y, "l"}] if x != @xsize - 1
        @solver.assert @vars[{x, y, "d"}] == @vars[{x, y + 1, "u"}] if y != @ysize - 1
      end
    end

    if @solver.satisfiable?
      print_answer! @solver.model
    else
      puts "failed to solve"
    end
  end

  private def print_answer!(model)
    picture = (0...@ysize*3).map { Array.new(3*@xsize, ' ') }

    @data.each do |(x, y), v|
      if v.nil?
        u = model[@vars[{x, y, "u"}]].to_i
        l = model[@vars[{x, y, "l"}]].to_i
        if u > 0
          picture[y*3 + 1][x*3 + 1] = " |‖"[u]
        elsif l > 0
          picture[y*3 + 1][x*3 + 1] = " -="[l]
        else
          picture[y*3 + 1][x*3 + 1] = ' '
        end
      else
        picture[y*3 + 1][x*3 + 1] = v.to_s[0]
      end
    end

    @data.each do |(x, y), _|
      u = model[@vars[{x, y, "u"}]].to_i
      d = model[@vars[{x, y, "d"}]].to_i
      l = model[@vars[{x, y, "l"}]].to_i
      r = model[@vars[{x, y, "r"}]].to_i

      picture[y*3 + 1][x*3] = " -="[l]
      picture[y*3 + 1][x*3 + 2] = " -="[r]
      picture[y*3][x*3 + 1] = " |‖"[u]
      picture[y*3 + 2][x*3 + 1] = " |‖"[d]
    end

    picture.each do |row|
      puts row.join
    end
  end

  private def int012(x, y, d)
    v = Z3.int("#{x},#{y},#{d}")
    @solver.assert v >= 0
    @solver.assert v <= 2
    v
  end
end

path = ARGV[0]? || "#{__DIR__}/bridges-1.txt"
Bridges.new(path).call
