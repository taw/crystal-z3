#!/usr/bin/env crystal

require "../src/z3"

class Aquarium
  @data : Array(Array(String))
  @cols : Array(Int32)
  @rows : Array(Int32)
  @xsize : Int32
  @containers : Array(String)?
  @ysize : Int32

  def initialize(path)
    data = File.read_lines(path).map(&.split)
    @cols = data.shift.map(&.to_i)
    @rows = data.map(&.shift).map(&.to_i)
    @xsize = @cols.size
    @ysize = @rows.size
    raise "Bad size" unless data.all? { |row| row.size == @xsize }
    @data = data
    @solver = Z3::Solver.new
  end

  def call
    # How cells relate to containers
    @ysize.times do |y|
      @xsize.times do |x|
        @solver.assert cell_var(x, y) == container_var(@data[y][x], y)
      end
    end

    # Row sums
    @ysize.times do |y|
      @solver.assert Z3.exactly((0...@xsize).map { |x| cell_var(x, y) }, @rows[y])
    end

    # Col sums
    @xsize.times do |x|
      @solver.assert Z3.exactly((0...@ysize).map { |y| cell_var(x, y) }, @cols[x])
    end

    # Container water flow
    containers.each do |name|
      (0...@ysize).each do |y|
        @solver.assert container_var(name, y).implies container_var(name, y + 1)
      end
    end

    if @solver.satisfiable?
      print_answer @solver.model
    else
      puts "failed to solve"
    end
  end

  private def containers
    @containers ||= @data.flatten.uniq.sort
  end

  private def container_var(name, level)
    Z3.bool("b#{name},#{level}")
  end

  private def cell_var(x, y)
    Z3.bool("c#{x},#{y}")
  end

  private def container_at(x, y) : String?
    return nil unless (0...@xsize).includes?(x)
    return nil unless (0...@ysize).includes?(y)
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
      print "#"
    else
      print " "
    end
  end

  private def print_answer(model)
    (0..@ysize).each do |y|
      (0..@xsize).each do |x|
        print_corner x, y
        next if x == @xsize
        print_horizontal x, y
      end
      print "\n"

      next if y == @ysize
      (0..@xsize).each do |x|
        print_vertical x, y
        next if x == @xsize
        print_cell model, x, y
      end
      print "\n"
    end
  end
end

path = ARGV[0]? || "#{__DIR__}/aquarium-1.txt"
Aquarium.new(path).call
