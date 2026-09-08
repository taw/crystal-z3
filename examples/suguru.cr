#!/usr/bin/env crystal

require "../src/z3"

class Suguru
  alias Point = Tuple(Int32, Int32)

  @data : Array(String)
  @xsize : Int32
  @ysize : Int32

  def initialize(path)
    @data = File.read_lines(path)
    @ysize = (@data.size - 1) // 2
    @xsize = (@data[0].size - 1) // 2
    raise "Bad size" unless @data.size == 2 * @ysize + 1
    raise "Bad size" unless @data.all? { |row| row.size == 2 * @xsize + 1 }
    @solver = Z3::Solver.new
  end

  def call
    connections = calculate_connections
    containers = calculate_containers(connections)

    @ysize.times do |y|
      @ysize.times do |x|
        v = cell_data(x, y)
        @solver.assert cell(x, y) == v if v
      end
    end

    containers.each do |_name, cells|
      @solver.assert Z3.distinct(cells)
      cells.each do |c|
        @solver.assert c >= 1
        @solver.assert c <= cells.size
      end
    end

    @ysize.times do |y|
      @xsize.times do |x|
        @solver.assert cell(x, y) != cell(x + 1, y)
        @solver.assert cell(x, y) != cell(x - 1, y + 1)
        @solver.assert cell(x, y) != cell(x, y + 1)
        @solver.assert cell(x, y) != cell(x + 1, y + 1)
      end
    end

    if @solver.satisfiable?
      print_answer @solver.model
    else
      puts "failed to solve"
    end
  end

  # Every cell starts in a container of its own, and each open wall merges the two
  # containers it's between
  private def calculate_containers(connections)
    containers = {} of String => Array(Point)
    cell_assignments = {} of Point => String
    (0...@xsize).each do |x|
      (0...@ysize).each do |y|
        name = "#{x},#{y}"
        containers[name] = [{x, y}]
        cell_assignments[{x, y}] = name
      end
    end

    connections.each do |(c1, c2)|
      # Already in same container
      ct1 = cell_assignments[c1]
      ct2 = cell_assignments[c2]
      next if ct1 == ct2
      containers.delete(ct2).not_nil!.each do |c3|
        cell_assignments[c3] = ct1
        containers[ct1] << c3
      end
    end

    result = {} of String => Array(Z3::IntExpr)
    containers.each do |name, cells|
      result[name] = cells.map { |(x, y)| cell(x, y) }
    end
    result
  end

  private def calculate_connections
    result = [] of Tuple(Point, Point)

    @ysize.times do |y|
      (0..@xsize - 2).each do |x|
        result << { {x, y}, {x + 1, y} } if cell_open_right?(x, y)
      end
    end

    @xsize.times do |x|
      (0..@ysize - 2).each do |y|
        result << { {x, y}, {x, y + 1} } if cell_open_down?(x, y)
      end
    end

    result
  end

  private def cell_open_right?(x, y)
    @data[2*y + 1][2*x + 2] == ' '
  end

  private def cell_open_down?(x, y)
    @data[2*y + 2][2*x + 1] == ' '
  end

  private def cell_data(x, y) : Int32?
    # The loop which calls this runs past the right edge of the grid, where Ruby
    # reads nil and takes it for a 0 - so the cells out there are pinned to 0,
    # which nothing in the puzzle can be
    v = @data[2*y + 1][2*x + 1]?
    return 0 if v.nil?
    return nil if v == ' '
    v.to_i
  end

  private def cell(x, y)
    Z3.int("c#{x},#{y}")
  end

  private def print_answer(model)
    output = @data.dup
    @ysize.times do |y|
      @xsize.times do |x|
        # This only works for 1-9, could use hex or something for more
        value = model[cell(x, y)].to_s
        output[2*y + 1] = output[2*y + 1].sub(2*x + 1, value[0])
      end
    end

    output.each { |line| puts line }
  end
end

path = ARGV[0]? || "#{__DIR__}/suguru-1.txt"
Suguru.new(path).call
