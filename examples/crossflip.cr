#!/usr/bin/env crystal

require "../src/z3"

class CrossFlipSolver
  @board : Array(Array(Int32))
  @xsize : Int32
  @ysize : Int32

  def initialize(board : String)
    # 0 - light
    # 1 - dark
    # 2 - wall
    @board = board.split(",").map { |line| line.chars.map(&.to_i) }
    @ysize = @board.size
    @xsize = @board[0].size
    @solver = Z3::Solver.new
  end

  def board(x, y)
    @board[y][x]
  end

  def wall?(x, y)
    board(x, y) == 2
  end

  def click(x, y)
    Z3.bool("click[#{x},#{y}]")
  end

  def cells_visible_from(x0, y0)
    result = [click(x0, y0)]
    (x0 + 1...@xsize).each do |x|
      break if wall?(x, y0)
      result << click(x, y0)
    end
    (0..x0 - 1).reverse_each do |x|
      break if wall?(x, y0)
      result << click(x, y0)
    end
    (y0 + 1...@ysize).each do |y|
      break if wall?(x0, y)
      result << click(x0, y)
    end
    (0..y0 - 1).reverse_each do |y|
      break if wall?(x0, y)
      result << click(x0, y)
    end
    result
  end

  def call
    @ysize.times do |y|
      @xsize.times do |x|
        if wall?(x, y)
          @solver.assert click(x, y) == false
        else
          starts_light = (board(x, y) == 0)
          # Z3 has no n-ary xor, so this is the fold the Ruby gem's Z3.Xor does
          ends_light = cells_visible_from(x, y).reduce { |a, b| a ^ b } ^ starts_light
          @solver.assert ends_light
        end
      end
    end

    raise "This can't be solved, go away!" unless @solver.satisfiable?
    model = @solver.model

    @ysize.times do |y|
      @xsize.times do |x|
        clicked = model[click(x, y)].to_b
        print clicked ? "[x] " : "[ ] "
      end
      print "\n"
    end
  end
end

board = "1021,1000"
CrossFlipSolver.new(board).call
