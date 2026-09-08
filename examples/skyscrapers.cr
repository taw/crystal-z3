#!/usr/bin/env crystal

require "../src/z3"

class SkyscrapersSolver
  @top : Array(Int32?)
  @bottom : Array(Int32?)
  @left : Array(Int32?)
  @right : Array(Int32?)
  @grid : Array(Array(Int32?))
  @size : Int32

  def initialize(path)
    data = File.read_lines(path).map do |line|
      line.split.map do |x|
        if x =~ /\d+/
          x.to_i
        elsif x == "." || x == "-"
          nil
        else
          raise "Unrecognized symbol #{x.inspect} in input"
        end
      end
    end

    @top = data.shift
    @bottom = data.pop
    @left = data.map(&.shift)
    @right = data.map(&.pop)
    @size = @top.size
    raise "Grid must be square" unless ([@top.size, @bottom.size, @left.size, @right.size] + data.map(&.size)).uniq.size == 1
    @grid = data
    @gridvars = Array(Array(Z3::IntExpr)).new
    @solver = Z3::Solver.new
  end

  def call
    setup_grid_vars
    setup_constraints

    if @solver.satisfiable?
      print_answer @solver.model
    else
      puts "No solution"
    end
  end

  private def setup_grid_vars
    @gridvars = (0...@size).map do |y|
      (0...@size).map do |x|
        v = Z3.int("g#{x},#{y}")
        if known = @grid[y][x]
          @solver.assert v == known
        else
          @solver.assert v >= 1
          @solver.assert v <= @size
        end
        v
      end
    end
    (@gridvars + @gridvars.transpose).each do |row|
      @solver.assert Z3.distinct(row)
    end
  end

  private def setup_constraints
    @size.times do |i|
      setup_visibility "L#{i}", @left[i], @gridvars[i]
      setup_visibility "R#{i}", @right[i], @gridvars[i].reverse
      setup_visibility "T#{i}", @top[i], @gridvars.map { |row| row[i] }
      setup_visibility "B#{i}", @bottom[i], @gridvars.map { |row| row[i] }.reverse
    end
  end

  private def setup_visibility(label, expected, vars)
    return unless expected
    # Variables between cells:
    # - count seen
    # - max seen

    count_vars = (0..@size).map { |i| Z3.int("#{label}-c#{i}") }
    max_vars = (0..@size).map { |i| Z3.int("#{label}-m#{i}") }

    @solver.assert count_vars.first == expected
    @solver.assert max_vars.first == 0

    @size.times do |i|
      count_near = count_vars[i]
      count_far = count_vars[i + 1]
      max_near = max_vars[i]
      max_far = max_vars[i + 1]
      current = vars[i]
      visible = Z3.bool("#{label}-v#{i}")
      @solver.assert visible == (current > max_near)
      @solver.assert count_near == visible.ite(count_far + 1, count_far)
      @solver.assert max_far == visible.ite(current, max_near)
    end

    @solver.assert count_vars.last == 0
    # This is redundant:
    @solver.assert max_vars.last == @size
  end

  private def print_answer(model)
    @size.times do |y|
      @size.times do |x|
        v = model[@gridvars[y][x]]
        print "#{v} "
      end
      print "\n"
    end
  end
end

path = ARGV[0]? || "#{__DIR__}/skyscrapers-1.txt"
SkyscrapersSolver.new(path).call
