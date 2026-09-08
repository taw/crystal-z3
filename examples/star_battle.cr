#!/usr/bin/env crystal

require "../src/z3"

class StarBattle
  alias Point = Tuple(Int32, Int32)

  @data : Array(Array(String))
  @size : Int32
  @containers : Array(String)?

  def initialize(path)
    @data = File.read_lines(path).map(&.split)
    @size = @data.size
    raise "Bad size" unless @data.all? { |row| row.size == @size }
    raise "Bad size" unless containers.size == @size
    @solver = Z3::Solver.new
  end

  def call
    # Each row contains 2 stars
    @size.times do |y|
      @solver.assert Z3.exactly((0...@size).map { |x| cell_var(x, y) }, 2)
    end

    # Each column contains 2 stars
    @size.times do |x|
      @solver.assert Z3.exactly((0...@size).map { |y| cell_var(x, y) }, 2)
    end

    # Each container contains 2 stars
    coords.group_by { |(x, y)| @data[y][x] }.each do |_name, cells|
      @solver.assert Z3.exactly(cells.map { |(x, y)| cell_var(x, y) }, 2)
    end

    # Can't be adjacent
    coords.each do |(x, y)|
      @solver.assert cell_var(x, y).implies no_star(x + 1, y)
      @solver.assert cell_var(x, y).implies no_star(x - 1, y + 1)
      @solver.assert cell_var(x, y).implies no_star(x, y + 1)
      @solver.assert cell_var(x, y).implies no_star(x + 1, y + 1)
    end

    if @solver.satisfiable?
      print_answer @solver.model
    else
      puts "failed to solve"
    end
  end

  private def coords
    (0...@size).flat_map do |y|
      (0...@size).map do |x|
        {x, y}
      end
    end
  end

  private def containers
    @containers ||= @data.flatten.uniq.sort
  end

  private def cell_var(x, y)
    Z3.bool("c#{x},#{y}")
  end

  # There is no star outside the grid to speak of, so a cell out there is simply true
  private def no_star(x, y) : Z3::BoolExpr | Bool
    return true unless (0...@size).includes?(x) && (0...@size).includes?(y)
    ~cell_var(x, y)
  end

  private def container_at(x, y) : String?
    return nil unless (0...@size).includes?(x)
    return nil unless (0...@size).includes?(y)
    @data[y][x]
  end

  private def print_corner(x, y)
    if [
         container_at(x, y),
         container_at(x, y - 1),
         container_at(x - 1, y),
         container_at(x - 1, y - 1),
       ].uniq.size == 1
      print " "
    else
      print "+"
    end
  end

  private def print_vertical(x, y)
    if x == 0 || container_at(x, y) != container_at(x - 1, y)
      print "|"
    else
      print " "
    end
  end

  private def print_horizontal(x, y)
    if y == 0 || container_at(x, y) != container_at(x, y - 1)
      print "-"
    else
      print " "
    end
  end

  private def print_cell(model, x, y)
    if model[cell_var(x, y)].to_b
      print "*"
    else
      print " "
    end
  end

  private def print_answer(model)
    (0..@size).each do |y|
      (0..@size).each do |x|
        print_corner x, y
        next if x == @size
        print_horizontal x, y
      end
      print "\n"

      next if y == @size
      (0..@size).each do |x|
        print_vertical x, y
        next if x == @size
        print_cell model, x, y
      end
      print "\n"
    end
  end
end

path = ARGV[0]? || "#{__DIR__}/star_battle-1.txt"
StarBattle.new(path).call
