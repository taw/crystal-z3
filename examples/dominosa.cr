#!/usr/bin/env crystal

require "../src/z3"

class Dominosa
  @data : Array(Array(Int32))
  @xsize : Int32
  @ysize : Int32

  def initialize(path)
    @data = File.read_lines(path).map { |line| line.split.map(&.to_i) }
    @solver = Z3::Solver.new
    @ysize = @data.size
    @xsize = @data[0].size
  end

  def connect_var(x1, y1, x2, y2)
    Z3.bool("#{x1},#{y1}-#{x2},#{y2}")
  end

  def valid?(x, y)
    return false if x < 0 || y < 0
    return false if x >= @xsize || y >= @ysize
    true
  end

  def down_var(x, y)
    return nil unless valid?(x, y + 1)
    connect_var(x, y, x, y + 1)
  end

  def up_var(x, y)
    return nil unless valid?(x, y - 1)
    connect_var(x, y - 1, x, y)
  end

  def right_var(x, y)
    return nil unless valid?(x + 1, y)
    connect_var(x, y, x + 1, y)
  end

  def left_var(x, y)
    return nil unless valid?(x - 1, y)
    connect_var(x - 1, y, x, y)
  end

  def each_x(&)
    @xsize.times do |x|
      yield x, x == @xsize - 1
    end
  end

  def each_y(&)
    @ysize.times do |y|
      yield y, y == @ysize - 1
    end
  end

  # Each of the dominoes is in the solution exactly once
  def assert_no_duplicate_connections
    all = Hash(Tuple(Int32, Int32), Array(Z3::BoolExpr)).new

    each_y do |y, last_y|
      each_x do |x, last_x|
        unless last_x
          c = right_var(x, y).not_nil!
          (all[domino(@data[y][x], @data[y][x + 1])] ||= [] of Z3::BoolExpr) << c
        end

        unless last_y
          c = down_var(x, y).not_nil!
          (all[domino(@data[y][x], @data[y + 1][x])] ||= [] of Z3::BoolExpr) << c
        end
      end
    end

    all.each do |_, vars|
      @solver.assert Z3.exactly(vars, 1)
    end
  end

  # Every cell is connected to exactly one of its neighbours
  def assert_solution_made_of_dominoes
    @ysize.times do |y|
      @xsize.times do |x|
        vars = [
          down_var(x, y),
          right_var(x, y),
          left_var(x, y),
          up_var(x, y),
        ].compact
        @solver.assert Z3.exactly(vars, 1)
      end
    end
  end

  def call
    assert_no_duplicate_connections
    assert_solution_made_of_dominoes

    if @solver.satisfiable?
      print_solution @solver.model
    else
      puts "There is no solution"
    end
  end

  # A domino is its two halves whichever way round they are
  private def domino(a, b)
    a <= b ? {a, b} : {b, a}
  end

  private def print_connection(model, var)
    print model[var].to_b ? "*" : " "
  end

  private def print_solution(model)
    each_y do |y, last_y|
      each_x do |x, last_x|
        print @data[y][x]
        print_connection model, right_var(x, y).not_nil! unless last_x
      end
      print "\n"

      unless last_y
        each_x do |x, last_x|
          print_connection model, down_var(x, y).not_nil!
          print " " unless last_x
        end
        print "\n"
      end
    end
  end
end

path = ARGV[0]? || "#{__DIR__}/dominosa-1.txt"
Dominosa.new(path).call
