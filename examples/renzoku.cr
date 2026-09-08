#!/usr/bin/env crystal

require "../src/z3"

class Renzoku
  alias Point = Tuple(Int32, Int32)

  @data : Array(String)
  @size : Int32

  # This needs to be very exactly formatted
  def initialize(path)
    @data = File.read_lines(path)
    @size = (@data.size + 1) // 2
    @vars = {} of Point => Z3::IntExpr
    @solver = Z3::Solver.new
  end

  def cell_value(x, y) : Int32?
    v = @data[y*2][x*2]
    if v == '#'
      nil
    elsif v.number?
      v.to_i
    else
      raise "Bad cell value"
    end
  end

  def dot_right?(x, y)
    v = @data[y*2][x*2 + 1]
    case v
    when '.' then true
    when ' ' then false
    else          raise "Bad dot value"
    end
  end

  def dot_bottom?(x, y)
    line = @data[y*2 + 1]
    v = line[x*2]?
    case v
    when '.'      then true
    when ' ', nil then false
    else               raise "Bad dot value"
    end
  end

  def call
    @size.times do |y|
      @size.times do |x|
        v = Z3.int("v#{x},#{y}")
        @vars[{x, y}] = v
        cv = cell_value(x, y)
        if cv
          @solver.assert v == cv
        else
          @solver.assert (v >= 1) & (v <= @size)
        end
      end
    end

    @size.times do |x|
      @solver.assert Z3.distinct((0...@size).map { |y| @vars[{x, y}] })
    end

    @size.times do |y|
      @solver.assert Z3.distinct((0...@size).map { |x| @vars[{x, y}] })
    end

    # Dots right
    (0..@size - 1).each do |y|
      (0..@size - 2).each do |x|
        lv = @vars[{x, y}]
        rv = @vars[{x + 1, y}]
        if dot_right?(x, y)
          @solver.assert (lv == (rv + 1)) | (lv == (rv - 1))
        else
          @solver.assert lv != (rv + 1)
          @solver.assert lv != (rv - 1)
        end
      end
    end

    # Dots bottom
    (0..@size - 2).each do |y|
      (0..@size - 1).each do |x|
        tv = @vars[{x, y}]
        bv = @vars[{x, y + 1}]
        if dot_bottom?(x, y)
          @solver.assert (tv == (bv + 1)) | (tv == (bv - 1))
        else
          @solver.assert tv != (bv + 1)
          @solver.assert tv != (bv - 1)
        end
      end
    end

    if @solver.satisfiable?
      print_answer! @solver.model
    else
      puts "failed to solve"
    end
  end

  private def print_answer!(model)
    output = @data.dup
    @size.times do |y|
      @size.times do |x|
        v = model[@vars[{x, y}]].to_s
        output[2*y] = output[2*y].sub(2*x, v[0])
      end
    end

    output.each { |line| puts line }
  end
end

path = ARGV[0]? || "#{__DIR__}/renzoku-1.txt"
Renzoku.new(path).call
