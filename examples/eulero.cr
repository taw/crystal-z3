#!/usr/bin/env crystal

require "../src/z3"

# https://www.janko.at/Raetsel/Eulero/index.htm

class Eulero
  @data : Array(Array(String))

  def initialize(path)
    @data = File.read_lines(path).map(&.split)
    @size = @data.size
    raise "Bad size" unless @data.all? { |row| row.size == @size }
    raise "Bad data" unless @data.flatten.all? { |c| c =~ /\A[A-Z.][1-9.]\z/ }
    @solver = Z3::Solver.new
  end

  def lvar(x, y)
    Z3.int("l[#{x},#{y}]")
  end

  def nvar(x, y)
    Z3.int("n[#{x},#{y}]")
  end

  def xvar(x, y)
    Z3.int("x[#{x},#{y}]")
  end

  def assert_vars
    @size.times do |y|
      @size.times do |x|
        @solver.assert lvar(x, y) >= 1
        @solver.assert lvar(x, y) <= @size
        @solver.assert nvar(x, y) >= 1
        @solver.assert nvar(x, y) <= @size
        @solver.assert xvar(x, y) == @size * lvar(x, y) + nvar(x, y)

        dl = @data[y][x][0]
        dn = @data[y][x][1]
        @solver.assert lvar(x, y) == (dl.ord - 'A'.ord + 1) if dl.ascii_uppercase?
        @solver.assert nvar(x, y) == (dn.ord - '1'.ord + 1) if '1' <= dn <= '9'
      end
    end
  end

  def assert_cols
    @size.times do |x|
      @solver.assert Z3.distinct((0...@size).map { |y| lvar(x, y) })
      @solver.assert Z3.distinct((0...@size).map { |y| nvar(x, y) })
    end
  end

  def assert_rows
    @size.times do |y|
      @solver.assert Z3.distinct((0...@size).map { |x| lvar(x, y) })
      @solver.assert Z3.distinct((0...@size).map { |x| nvar(x, y) })
    end
  end

  def assert_distinct
    xvars = (0...@size).map { |x| (0...@size).map { |y| xvar(x, y) } }.flatten
    @solver.assert Z3.distinct(xvars)
  end

  def call
    assert_vars
    assert_cols
    assert_rows
    assert_distinct

    if @solver.satisfiable?
      print_solution @solver.model
    else
      puts "There is no solution"
    end
  end

  def print_solution(model)
    @size.times do |y|
      @size.times do |x|
        l = model[lvar(x, y)].to_i
        n = model[nvar(x, y)].to_i
        print ('A'.ord + l - 1).chr
        print ('1'.ord + n - 1).chr
        print " "
      end
      print "\n"
    end
  end
end

path = ARGV[0]? || "#{__DIR__}/eulero-1.txt"
Eulero.new(path).call
