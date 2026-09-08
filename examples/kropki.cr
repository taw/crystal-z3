#!/usr/bin/env crystal

require "../src/z3"

# Based on https://play.google.com/store/apps/details?id=com.alexuvarov.android.kropki.puzzle&hl=en_GB
#
# NxN grid
# Each cell contains numbers 1 to N
# Each row and each column contains distinct numbers
# If there's black dot (o) between cells, one is twice the other
# If there's white dot (*) between cells, one is the other plus one
# If there's no dot, neither of these is true
# (for 1/2, dot can be of either color)

class Kropki
  @data : Array(String)
  @size : Int32

  def initialize(path)
    @data = File.read_lines(path)
    @size = (@data.size - 1) // 2
    raise "Bad size" unless @data.size == 2 * @size + 1
    raise "Bad size" unless @data.all? { |row| row.size == 2 * @size + 1 }
    @solver = Z3::Solver.new
  end

  def call
    # Cells contain numbers 1 - N
    @size.times do |y|
      @size.times do |x|
        @solver.assert cell(x, y) >= 1
        @solver.assert cell(x, y) <= @size
      end
    end

    # Each row and column distinct
    @size.times do |y|
      @solver.assert Z3.distinct((0...@size).map { |x| cell(x, y) })
    end
    @size.times do |x|
      @solver.assert Z3.distinct((0...@size).map { |y| cell(x, y) })
    end

    # Horizontal dots
    @size.times do |y|
      (0...@size).each do |x|
        dot_constraints cell(x, y), cell(x + 1, y), @data[2*y + 1][2*x + 2]
      end
    end

    # Vertical dots
    @size.times do |x|
      (0...@size).each do |y|
        dot_constraints cell(x, y), cell(x, y + 1), @data[2*y + 2][2*x + 1]
      end
    end

    if @solver.satisfiable?
      print_answer @solver.model
    else
      puts "failed to solve"
    end
  end

  private def dot_constraints(c1, c2, dot)
    if dot == 'o'
      @solver.assert Z3.or([c1 == c2 + 1, c2 == c1 + 1])
    elsif dot == '*'
      @solver.assert Z3.or([c1 == c2 * 2, c2 == c1 * 2])
    else
      @solver.assert c1 != c2 + 1
      @solver.assert c2 != c1 + 1
      @solver.assert c1 != c2 * 2
      @solver.assert c2 != c1 * 2
    end
  end

  private def cell(x, y)
    Z3.int("c#{x},#{y}")
  end

  private def print_answer(model)
    output = @data.dup
    @size.times do |y|
      @size.times do |x|
        # This only works for 1-9, could use hex or something for more
        value = model[cell(x, y)].to_s
        output[2*y + 1] = output[2*y + 1].sub(2*x + 1, value[0])
      end
    end

    output.each { |line| puts line }
  end
end

path = ARGV[0]? || "#{__DIR__}/kropki-1.txt"
Kropki.new(path).call
