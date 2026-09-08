#!/usr/bin/env crystal

require "../src/z3"

class StitchesSolver
  alias Point = Tuple(Int32, Int32)
  # Two groups a stitch can run between, in a fixed order
  alias GroupPair = Tuple(String, String)

  @data : Array(Array(String))
  @col_counts : Array(Int32)
  @row_counts : Array(Int32)
  @xsize : Int32
  @ysize : Int32
  @groups : Array(String)
  @stitch_count : Int32

  def initialize(path)
    data = File.read(path).strip.split("\n").map(&.split)
    @col_counts = data.shift.map(&.to_i)
    @row_counts = data.map(&.shift).map(&.to_i)
    @xsize = @col_counts.size
    @ysize = @row_counts.size
    @data = data
    raise "Bad size" unless data.size == @ysize
    raise "Bad size" unless data.all? { |r| r.size == @ysize }
    raise "Counts don't match" unless @col_counts.sum == @row_counts.sum
    @solver = Z3::Solver.new
    @groups = @data.flatten.uniq
    @fg = {} of String => Tuple(Int32, Int32, Int32)
    @bg = {} of String => Tuple(Int32, Int32, Int32)
    @cell_vars = {} of Point => Z3::BoolExpr
    @hstitch = {} of Point => Z3::BoolExpr
    @vstitch = {} of Point => Z3::BoolExpr
    @stitch_groups = {} of GroupPair => Array(Z3::BoolExpr)
    @stitch_count = 0
  end

  def call
    assign_colors!
    setup_cell_vars!
    setup_stitch_vars!

    setup_cell_assertions!
    setup_stitch_assertions!
    setup_cell_stitch_assertions!

    if @solver.satisfiable?
      print_answer! @solver.model
    else
      puts "failed to solve"
    end
  end

  def assign_colors!
    @groups.each do |g|
      @fg[g] = {rand(256), rand(256), rand(256)}
      @bg[g] = {rand(256), rand(256), rand(256)}
    end
  end

  def setup_cell_vars!
    @xsize.times do |x|
      @ysize.times do |y|
        @cell_vars[{x, y}] = Z3.bool("c#{x},#{y}")
      end
    end
  end

  def row_of_cell_vars(y)
    (0...@xsize).map { |x| @cell_vars[{x, y}] }
  end

  def col_of_cell_vars(x)
    (0...@ysize).map { |y| @cell_vars[{x, y}] }
  end

  def setup_cell_assertions!
    @xsize.times do |x|
      @solver.assert Z3.exactly(col_of_cell_vars(x), @col_counts[x])
    end

    @ysize.times do |y|
      @solver.assert Z3.exactly(row_of_cell_vars(y), @row_counts[y])
    end
  end

  # A stitch only exists where two different groups meet
  def setup_stitch_vars!
    (@xsize - 1).times do |x|
      @ysize.times do |y|
        g1 = @data[y][x]
        g2 = @data[y][x + 1]
        next if g1 == g2
        v = Z3.bool("h#{x},#{y}")
        (@stitch_groups[pair(g1, g2)] ||= [] of Z3::BoolExpr) << v
        @hstitch[{x, y}] = v
      end
    end

    @xsize.times do |x|
      (@ysize - 1).times do |y|
        g1 = @data[y][x]
        g2 = @data[y + 1][x]
        next if g1 == g2
        v = Z3.bool("v#{x},#{y}")
        (@stitch_groups[pair(g1, g2)] ||= [] of Z3::BoolExpr) << v
        @vstitch[{x, y}] = v
      end
    end

    group_count = 2 * @stitch_groups.keys.size
    raise "Counts don't divide" unless @col_counts.sum % group_count == 0
    @stitch_count = @col_counts.sum // group_count
  end

  def setup_stitch_assertions!
    @stitch_groups.each do |_g, vars|
      @solver.assert Z3.exactly(vars, @stitch_count)
    end
  end

  def setup_cell_stitch_assertions!
    @xsize.times do |x|
      @ysize.times do |y|
        vars = [
          @hstitch[{x, y}]?,
          @hstitch[{x - 1, y}]?,
          @vstitch[{x, y}]?,
          @vstitch[{x, y - 1}]?,
        ].compact.map(&.ite(1, 0))
        if vars.empty?
          @solver.assert ~@cell_vars[{x, y}]
        else
          @solver.assert @cell_vars[{x, y}].ite(1, 0) == Z3.add(vars)
        end
      end
    end
  end

  def group_at(x, y) : String?
    return nil if x < 0 || y < 0
    return nil if x >= @xsize || y >= @ysize
    @data[y][x]
  end

  # Every group gets its own two colours, so the shapes are readable - anything
  # between two groups stays uncoloured
  def paint_for(s, x1, y1, x2 = x1, y2 = y1)
    g1 = group_at(x1, y1)
    g2 = group_at(x2, y2)
    return s unless g1 == g2 && g1
    fr, fg, fb = @fg[g1]
    br, bg, bb = @bg[g1]
    "\e[38;2;#{fr};#{fg};#{fb};48;2;#{br};#{bg};#{bb}m#{s}\e[0m"
  end

  def print_answer!(model)
    @ysize.times do |y|
      @xsize.times do |x|
        s = model[@cell_vars[{x, y}]].to_b ? "*" : " "
        print paint_for(s, x, y)
        stitch = @hstitch[{x, y}]?
        hs = stitch && model[stitch].to_b ? "-" : " "
        print paint_for(hs, x, y, x + 1, y)
      end
      print "\n"
      next if y == @ysize - 1
      @xsize.times do |x|
        stitch = @vstitch[{x, y}]?
        vs = stitch && model[stitch].to_b ? "|" : " "
        print paint_for(vs, x, y, x, y + 1)
        print paint_for(" ", x, y, x + 1, y + 1)
      end
      print "\n"
    end
  end

  private def pair(g1, g2)
    g1 <= g2 ? {g1, g2} : {g2, g1}
  end
end

path = ARGV[0]? || "#{__DIR__}/stitches-1.txt"
StitchesSolver.new(path).call
