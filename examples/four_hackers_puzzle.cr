#!/usr/bin/env crystal

require "../src/z3"

# One of the things the puzzle assigns attributes to - a hacker here, and the
# connection they made, since the four are also ordered.
#
# The Ruby version spells these `hacker.name` and `hacker.name("Phineus")` through
# `method_missing`. The attributes are named at runtime, so Crystal can't have that
# - `hacker["name"]` and `hacker["name", "Phineus"]` are the same two questions.
class LogicPuzzleCase
  getter index : Int32

  def initialize(@puzzle : LogicPuzzle, @index : Int32)
  end

  # The variable holding this case's value for the attribute
  def [](key : String)
    @puzzle.vars[key][@index]
  end

  # The claim that this case's value for the attribute is that one
  def [](key : String, value : String)
    @puzzle.attribute(@index, key, value)
  end
end

abstract class LogicPuzzle
  getter vars = {} of String => Array(Z3::IntExpr)
  getter dict = {} of String => Array(String)
  getter cases : Array(LogicPuzzleCase)
  getter solver = Z3::Solver.new

  # In puzzles of this kind, all assignments are of same size
  def initialize(@count : Int32)
    @cases = Array(LogicPuzzleCase).new(@count)
    @count.times { |i| @cases << LogicPuzzleCase.new(self, i) }
  end

  abstract def add_assertions!

  def each(&)
    @cases.each { |c| yield c }
  end

  def attribute_values(name : String, *vals : String)
    raise "All assignments must have same number of elements" unless vals.size == @count
    vars = (0...@count).map { |i| Z3.int("#{i}-#{name}") }
    vars.each do |v|
      @solver.assert v >= 0
      @solver.assert v < @count
    end
    @solver.assert Z3.distinct(vars)
    @dict[name] = vals.to_a
    @vars[name] = vars
  end

  def has_key?(key)
    @vars.has_key?(key)
  end

  def attribute(idx, key, val)
    raise "Attribute #{key} not defined" unless @vars.has_key?(key)
    val_idx = @dict[key].index(val) || raise "Value #{val} for attribute #{key} not possible"
    @vars[key][idx] == val_idx
  end

  def call
    add_assertions!
    if @solver.satisfiable?
      @solver.model.each do |k, v|
        # Z3 quotes any name which isn't an SMT-LIB symbol, and every one of these
        # starts with a digit - so `to_s` says `|0-name|` where the Ruby gem's own
        # printer says `0-name`. That printer is still to be ported.
        key = k.to_s.strip('|')
        _, name = key.split("-", 2)
        puts "#{key} = #{@dict[name][v.to_s.to_i]}"
      end
    else
      puts "Puzzle has no solutions"
    end
  end

  def implies!(a, b)
    @solver.assert a.implies(b)
  end
end

class FourHackersPuzzle < LogicPuzzle
  def initialize
    super(4)
    attribute_values "name", "Armand", "Dragonene", "Frogger", "Phineus"
    attribute_values "alias", "Badger", "Griffin", "Lennard", "Monks"
    attribute_values "country", "Belgium", "England", "Norway", "Yemen"
    attribute_values "language", "C", "Java", "Lisp", "Perl"
    attribute_values "amount", "10000", "80000", "160000", "640000"
  end

  def add_assertions!
    each do |hacker|
      implies!(hacker["name", "Phineus"], hacker["amount", "10000"])
      implies!(hacker["alias", "Lennard"], hacker["amount", "160000"])
      implies!(hacker["alias", "Lennard"], ~hacker["country", "England"])
      # 2nd connection less money transferred than C coder
      implies!(hacker["language", "C"], cases[1]["amount"] < hacker["amount"])
      implies!(hacker["language", "C"], ~hacker["country", "Norway"])
      implies!(hacker["name", "Armand"], hacker["alias", "Monks"])
    end

    # Armand stole more than Frogger
    each do |a|
      each do |b|
        implies!(
          a["name", "Armand"] & b["name", "Frogger"],
          a["amount"] > b["amount"]
        )
      end
    end

    each do |hacker|
      implies!(hacker["name", "Dragonene"], hacker["country", "Belgium"])
    end

    # Dragonene less money than Perl coder
    each do |a|
      each do |b|
        implies!(
          a["name", "Dragonene"] & b["language", "Perl"],
          a["amount"] < b["amount"]
        )
      end
    end
    # perl coder made the connection before Dragonene?
    each do |a|
      each do |b|
        implies!(
          a["name", "Dragonene"] & b["language", "Perl"],
          a.index > b.index
        )
      end
    end
    # Lisp coder more money than Griffin
    each do |a|
      each do |b|
        implies!(
          a["alias", "Griffin"] & b["language", "Lisp"],
          a["amount"] < b["amount"]
        )
      end
    end
    # 3rd connection used Java
    @solver.assert cases[2]["language", "Java"]
    # Badger stole more than Yemen coder
    each do |a|
      each do |b|
        implies!(
          a["alias", "Badger"] & b["country", "Yemen"],
          a["amount"] > b["amount"]
        )
      end
    end
  end
end

FourHackersPuzzle.new.call

# There is little we can do but wait, so we may as well take another job.
# It seems there has been a bank robbery. Scotland Yard has turned to us for help in
# figuring out who did it. We have been the given the following information:
#
#     There were 4 hackers each connecting one after another.
#     Each hacker has a name and another alias too.
#     Each hacker connected from a different country.
#     Each hacker connected using a different programming language.
#     Each hacker transferred a different amount of money.
#
#     The 4 hacker names: Armand Dragonene Frogger Phineus
#     The 4 hacker aliases: Badger Griffin Lennard Monks
#     The 4 countries: Belgium England Norway Yemen
#     The 4 coding langauges: C Java Lisp Perl
#     The 4 amounts: 10000 80000 160000 640000
#     You must also determine the order the hackers connected: 1st, 2nd, 3rd, 4th
#
# Extracted rules:
#   Phineus => 10000
#   Lennard => 160000 && !England
#   2nd connection less money transferred than C coder
#   C coder !Norwary
#   Armand (Monks)
#   Armand stole more than Frogger
#   Dragonene => Belgium
#   Dragonene less money than Perl coder
#   perl coder made the connection before Dragonene?
#   Lisp coder more money than Griffin
#   3rd connection used Java
#   Badger stole more than Yemen coder
