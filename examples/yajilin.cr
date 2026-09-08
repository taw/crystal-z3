#!/usr/bin/env crystal

require "../src/z3"

class Yajilin
  @data : Array(Array(String?))
  @xsize : Int32
  @ysize : Int32

  def initialize(path)
    @data = File.read_lines(path).map { |line|
      line.split.map { |x| x == "." ? nil : x }
    }
    @xsize = @data.size
    @ysize = @data[0].size
    raise "Bad size" unless @data.all? { |row| row.size == @xsize }
    @solver = Z3::Solver.new
  end

  def on_board?(x, y)
    x >= 0 && y >= 0 && x < @xsize && y < @ysize
  end

  # true = white
  # false = black
  def cvar(x, y)
    Z3.bool("c[#{x},#{y}]")
  end

  # true - connected
  # right from (x,y)
  def hvar(x, y)
    Z3.bool("h[#{x},#{y}]")
  end

  def hvar?(x, y) : Z3::BoolExpr?
    return nil unless on_board?(x, y) && x != @xsize - 1
    hvar(x, y)
  end

  # true - connected
  # down from (x,y)
  def vvar(x, y)
    Z3.bool("v[#{x},#{y}]")
  end

  def vvar?(x, y) : Z3::BoolExpr?
    return nil unless on_board?(x, y) && y != @ysize - 1
    vvar(x, y)
  end

  # Every cell has a number that shows its position within the loop
  def nvar(x, y)
    Z3.int("n[#{x},#{y}]")
  end

  def hint_cell?(x, y)
    !@data[y][x].nil?
  end

  def neighbours(x, y)
    [
      {x + 1, y},
      {x - 1, y},
      {x, y + 1},
      {x, y - 1},
    ].select { |(nx, ny)|
      on_board?(nx, ny) && !hint_cell?(nx, ny)
    }
  end

  def neighbour_cvars(x, y)
    neighbours(x, y).map { |(nx, ny)| cvar(nx, ny) }
  end

  def connections_at(x, y)
    [
      hvar?(x, y),
      hvar?(x - 1, y),
      vvar?(x, y),
      vvar?(x, y - 1),
    ].compact
  end

  def count_loops_at(x, y)
    Z3.add(connections_at(x, y).map(&.ite(1, 0)))
  end

  def assert_connections
    each_xy do |x, y|
      if hint_cell?(x, y)
        @solver.assert count_loops_at(x, y) == 0
      else
        @solver.assert cvar(x, y).implies(count_loops_at(x, y) == 2)
        @solver.assert (~cvar(x, y)).implies(count_loops_at(x, y) == 0)
      end
    end
  end

  def assert_no_black_multiples
    each_xy do |x, y|
      next if hint_cell?(x, y)
      @solver.assert (~cvar(x, y)).implies(Z3.and(neighbour_cvars(x, y)))
    end
  end

  def stripe_left(x0, y)
    (0...x0).reject { |x| hint_cell?(x, y) }.map { |x| cvar(x, y) }
  end

  def stripe_right(x0, y)
    (x0 + 1...@xsize).reject { |x| hint_cell?(x, y) }.map { |x| cvar(x, y) }
  end

  def stripe_up(x, y0)
    (0...y0).reject { |y| hint_cell?(x, y) }.map { |y| cvar(x, y) }
  end

  def stripe_down(x, y0)
    (y0 + 1...@ysize).reject { |y| hint_cell?(x, y) }.map { |y| cvar(x, y) }
  end

  def assert_arrows
    each_xy do |x, y|
      hint = @data[y][x]
      next unless hint
      count = hint[0].to_i
      stripe = case hint[1]
               when '<', '←' then stripe_left(x, y)
               when '>', '→' then stripe_right(x, y)
               when '^', '↑' then stripe_up(x, y)
               when '_', '↓' then stripe_down(x, y)
               else               raise "Unknown arrow #{hint}"
               end

      # cvar is true for white, so ~cvar counts the black cells the arrow sees
      @solver.assert Z3.exactly(stripe.map { |c| ~c }, count)
    end
  end

  def each_xy(&)
    @ysize.times do |y|
      @xsize.times do |x|
        yield x, y
      end
    end
  end

  def connections_and_nvars(x, y)
    [
      {x + 1, y, hvar?(x, y)},
      {x - 1, y, hvar?(x - 1, y)},
      {x, y + 1, vvar?(x, y)},
      {x, y - 1, vvar?(x, y - 1)},
    ].select { |(nx, ny, _convar)|
      on_board?(nx, ny) && !hint_cell?(nx, ny)
    }.map { |(nx, ny, convar)| {nvar(nx, ny), convar.not_nil!} }
  end

  # Loop will have Ns of 0+, all distinct and consecutive
  # Non-loop will have Ns of MAX + cell_number
  def assert_single_loop
    max_value = 1000

    each_xy do |x, y|
      cell_idx = x + y * @xsize
      @solver.assert nvar(x, y) >= 0
      if hint_cell?(x, y)
        @solver.assert nvar(x, y) == max_value + cell_idx
      else
        @solver.assert (~cvar(x, y)).implies(nvar(x, y) == max_value + cell_idx)

        nval = connections_and_nvars(x, y)
          .map { |(n, c)| c.ite(n + 1, max_value) }
          .reduce { |a, b| (a <= b).ite(a, b) }

        @solver.assert cvar(x, y).implies((nvar(x, y) == 0) | (nvar(x, y) == nval))
        @solver.assert cvar(x, y).implies(nvar(x, y) < max_value)
      end
    end

    # only one loop start
    starts = [] of Z3::BoolExpr
    each_xy { |x, y| starts << (nvar(x, y) == 0) }
    @solver.assert Z3.exactly(starts, 1)
  end

  def call
    assert_connections
    assert_no_black_multiples
    assert_arrows
    assert_single_loop

    if @solver.satisfiable?
      print_answer @solver.model
    else
      puts "failed to solve"
    end
  end

  def hint_data(x, y)
    u = @data[y][x].not_nil!
    arrow = case u[1]
            when '<' then "←"
            when '>' then "→"
            when '_' then "↓"
            when '^' then "↑"
            else          u[1].to_s
            end
    "#{u[0]}#{arrow}"
  end

  # TODO: make it nicer
  def print_answer(model)
    @ysize.times do |y|
      @xsize.times do |x|
        if hint_cell?(x, y)
          print hint_data(x, y)
        else
          print model[cvar(x, y)].to_b ? "* " : "# "
        end

        next if x == @xsize - 1
        if model[hvar(x, y)].to_b
          print "-"
        else
          print " "
        end
      end
      print "\n"

      next if y == @ysize - 1
      @xsize.times do |x|
        if model[vvar(x, y)].to_b
          print "|  "
        else
          print "   "
        end
      end

      print "\n"
    end
  end

  def print_debug_loop_info(model)
    print "\n"
    @ysize.times do |y|
      @xsize.times do |x|
        print "%8d" % model[nvar(x, y)].to_i
      end
      print "\n"
    end
  end
end

path = ARGV[0]? || "#{__DIR__}/yajilin-1.txt"
Yajilin.new(path).call
