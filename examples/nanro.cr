#!/usr/bin/env crystal

require "../src/z3"

# https://www.gmpuzzles.com/blog/nanro-rules-and-info/

class Nanro
  alias Point = Tuple(Int32, Int32)

  @regions : Array(Array(String))
  @hints : Array(Array(Int32?))
  @cells_by_region : Hash(String?, Array(Point))?
  @xsize : Int32
  @ysize : Int32

  def initialize(path)
    data = File.read_lines(path).map(&.split)
    @ysize = data.size
    @xsize = data[0].size
    raise "Bad size" unless data.all? { |row| row.size == @ysize }
    @regions = data.map { |row|
      row.map { |cell| cell.gsub(/\d|\./, "") }
    }
    @hints = data.map { |row|
      row.map { |cell| cell[1].number? ? cell[1].to_i : nil }
    }
    @solver = Z3::Solver.new
  end

  def assert_each_cell_is_0_or_rvar
    each_xy do |x, y|
      @solver.assert Z3.or([
        cvar(x, y) == 0,
        cvar(x, y) == rvar(region_at(x, y)),
      ])
    end
  end

  def assert_rvar_equals_number_of_numbered_cells_in_region
    cells_by_region.each do |r, xys|
      nonzeroes = xys.map { |(x, y)| (cvar(x, y) == 0).ite(0, 1) }
      @solver.assert rvar(r) == Z3.add(nonzeroes)
      @solver.assert rvar(r) >= 1
    end
  end

  def assert_hints_obeyed
    each_xy do |x, y|
      hint = hint_at(x, y)
      @solver.assert cvar(x, y) == hint if hint
    end
  end

  def assert_no_numbered_squares
    each_xy do |x, y|
      next unless on_board?(x + 1, y + 1)
      @solver.assert Z3.or([
        cvar(x, y) == 0,
        cvar(x + 1, y) == 0,
        cvar(x, y + 1) == 0,
        cvar(x + 1, y + 1) == 0,
      ])
    end
  end

  def assert_no_same_number_between_regions
    each_xy do |x, y|
      neighbours(x, y).each do |(nx, ny)|
        next if region_at(x, y) == region_at(nx, ny)
        @solver.assert (cvar(x, y) != 0).implies(cvar(x, y) != cvar(nx, ny))
      end
    end
  end

  # Every numbered cell counts its distance to the one the loop starts at, so a
  # second group of them would have nowhere to count from
  def assert_numbered_cells_all_connected
    max_value = @xsize * @ysize + 10

    each_xy do |x, y|
      @solver.assert nvar(x, y) >= 0
      @solver.assert (cvar(x, y) == 0).implies(nvar(x, y) == max_value)
      @solver.assert (cvar(x, y) != 0).implies(nvar(x, y) < max_value)

      nval = neighbours(x, y)
        .map { |(nx, ny)|
          (cvar(nx, ny) == 0).ite(max_value, nvar(nx, ny) + 1)
        }
        .reduce { |a, b| (a <= b).ite(a, b) }

      @solver.assert (cvar(x, y) != 0).implies(Z3.or([nvar(x, y) == 0, nvar(x, y) == nval]))
    end

    starts = [] of Z3::BoolExpr
    each_xy { |x, y| starts << (nvar(x, y) == 0) }
    @solver.assert Z3.exactly(starts, 1)
  end

  def call
    assert_hints_obeyed
    assert_no_numbered_squares
    assert_each_cell_is_0_or_rvar
    assert_rvar_equals_number_of_numbered_cells_in_region
    assert_no_same_number_between_regions
    assert_numbered_cells_all_connected

    if @solver.satisfiable?
      print_answer! @solver.model
    else
      puts "failed to solve"
    end
  end

  private def neighbours(x, y)
    [
      {x + 1, y},
      {x - 1, y},
      {x, y + 1},
      {x, y - 1},
    ].select { |(nx, ny)| on_board?(nx, ny) }
  end

  private def cells_by_region
    @cells_by_region ||= begin
      cells = [] of Point
      each_xy { |x, y| cells << {x, y} }
      cells.group_by { |(x, y)| region_at(x, y) }
    end
  end

  private def rvar(r)
    Z3.int("r[#{r}]")
  end

  private def cvar(x, y)
    Z3.int("c[#{x},#{y}]")
  end

  private def nvar(x, y)
    Z3.int("n[#{x},#{y}]")
  end

  private def each_xy(&)
    @ysize.times do |y|
      @xsize.times do |x|
        yield x, y
      end
    end
  end

  private def on_board?(x, y)
    x >= 0 && y >= 0 && x < @xsize && y < @ysize
  end

  private def region_at(x, y) : String?
    return nil unless on_board?(x, y)
    @regions[y][x]
  end

  private def hint_at(x, y) : Int32?
    return nil unless on_board?(x, y)
    @hints[y][x]
  end

  private def print_corner?(x, y)
    [
      region_at(x, y),
      region_at(x - 1, y),
      region_at(x, y - 1),
      region_at(x - 1, y - 1),
    ].uniq.size > 1
  end

  private def print_edge?(x1, y1, x2, y2)
    region_at(x1, y1) != region_at(x2, y2)
  end

  private def corner_output(x, y)
    print_corner?(x, y) ? "*" : " "
  end

  private def vedge_output(x, y)
    print_edge?(x, y, x, y - 1) ? "---" : "   "
  end

  private def hedge_output(x, y)
    print_edge?(x, y, x - 1, y) ? "|" : " "
  end

  private def print_answer!(model)
    (0..@ysize).each do |y|
      (0..@xsize).each do |x|
        print corner_output(x, y)
        next if x == @xsize
        print vedge_output(x, y)
      end
      print "\n"

      next if y == @ysize

      (0..@xsize).each do |x|
        print hedge_output(x, y)
        next if x == @xsize
        print "   "
      end
      print "\n"

      (0..@xsize).each do |x|
        print hedge_output(x, y)
        next if x == @xsize
        print " "
        c = model[cvar(x, y)].to_i
        if c == 0
          print " "
        else
          print c
        end
        print " "
      end
      print "\n"

      (0..@xsize).each do |x|
        print hedge_output(x, y)
        next if x == @xsize
        print "   "
      end
      print "\n"
    end
  end
end

path = ARGV[0]? || "#{__DIR__}/nanro-1.txt"
Nanro.new(path).call
