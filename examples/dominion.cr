#!/usr/bin/env crystal

require "../src/z3"

# https://www.janko.at/Raetsel/Dominion/index.htm

class Dominion
  alias Point = Tuple(Int32, Int32)

  @data : Array(String)
  @vars : Hash(Char, Int32)
  @xsize : Int32
  @ysize : Int32

  def initialize(path)
    @data = File.read_lines(path)
    @ysize = @data.size
    @xsize = @data[0].size
    raise "Bad size" unless @data.all? { |line| line.size == @xsize }
    @vars = {} of Char => Int32
    (@data.flat_map(&.chars).uniq - ['.']).sort.each_with_index { |v, c| @vars[v] = c + 1 }
    @areas_count = @vars.size
    @primary = Set(Point).new
    @solver = Z3::Solver.new
  end

  def on_board?(x, y)
    x >= 0 && y >= 0 && x < @xsize && y < @ysize
  end

  def given(x, y) : Int32?
    return nil unless on_board?(x, y)
    @vars[@data[y][x]]?
  end

  def var(x, y)
    Z3.int("c[#{x},#{y}]")
  end

  def dvar(x, y)
    Z3.int("d[#{x},#{y}]")
  end

  def domino?(x, y)
    var(x, y) == 0
  end

  def neighbours(x, y)
    [
      {x - 1, y},
      {x + 1, y},
      {x, y - 1},
      {x, y + 1},
    ].select { |(nx, ny)| on_board?(nx, ny) }
  end

  def count_neighbour_dominoes(x, y)
    Z3.add(neighbours(x, y).map { |(nx, ny)| domino?(nx, ny).ite(1, 0) })
  end

  # One cell of each area is the one everything else in it counts its distance to
  def assign_primary
    seen = Set(Int32).new
    each_xy do |x, y|
      g = given(x, y)
      next unless g
      next if seen.includes?(g)
      @primary << {x, y}
      seen << g
    end
  end

  def primary?(x, y)
    @primary.includes?({x, y})
  end

  def each_xy(&)
    @ysize.times do |y|
      @ysize.times do |x|
        yield x, y
      end
    end
  end

  def assert_cells_are_assigned_to_areas
    each_xy do |x, y|
      @solver.assert var(x, y) >= 0
      @solver.assert var(x, y) <= @areas_count
      g = given(x, y)
      @solver.assert var(x, y) == g if g
    end
  end

  def assert_dominos
    each_xy do |x, y|
      @solver.assert(
        domino?(x, y).implies(count_neighbour_dominoes(x, y) == 1)
      )
    end
  end

  def assert_areas_separated
    each_xy do |x, y|
      v = var(x, y)
      neighbours(x, y).each do |(nx, ny)|
        n = var(nx, ny)
        @solver.assert Z3.or([n == 0, v == 0, n == v])
      end
    end
  end

  def assert_each_area_connected
    # Just some bogus big value
    max_value = @xsize * @ysize + 10
    each_xy do |x, y|
      @solver.assert dvar(x, y) >= 0
      @solver.assert dvar(x, y) < max_value

      next_ds_same_area = neighbours(x, y).map { |(nx, ny)| (var(nx, ny) == var(x, y)).ite(dvar(nx, ny) + 1, max_value) }
      next_d = next_ds_same_area.reduce { |a, b| (a <= b).ite(a, b) }
      @solver.assert(
        dvar(x, y) == Z3.or([primary?(x, y), domino?(x, y)]).ite(0, next_d)
      )
    end
  end

  def call
    assign_primary

    assert_cells_are_assigned_to_areas
    assert_dominos
    assert_areas_separated

    assert_each_area_connected

    if @solver.satisfiable?
      print_solution @solver.model
    else
      puts "There is no solution"
    end
  end

  def print_solution(model)
    names = @vars.invert
    @ysize.times do |y|
      @ysize.times do |x|
        c = model[var(x, y)].to_i
        print names[c]? || "*"
      end
      print "\n"
    end
  end
end

path = ARGV[0]? || "#{__DIR__}/dominion-1.txt"
Dominion.new(path).call
