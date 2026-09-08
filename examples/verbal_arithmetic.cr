#!/usr/bin/env crystal

require "../src/z3"

class VerbalArithmetic
  @a : Array(Z3::IntExpr)
  @b : Array(Z3::IntExpr)
  @c : Array(Z3::IntExpr)

  def initialize(a : String, b : String, c : String)
    @solver = Z3::Solver.new
    @vars = {} of Char => Z3::IntExpr
    @a = a.chars.map { |v| var(v) }
    @b = b.chars.map { |v| var(v) }
    @c = c.chars.map { |v| var(v) }
  end

  def call
    @solver.assert @a[0] != 0
    @solver.assert @b[0] != 0
    @solver.assert @c[0] != 0
    @solver.assert word_value(@a) + word_value(@b) == word_value(@c)
    @solver.assert Z3.distinct(@vars.values)

    if @solver.satisfiable?
      print_answer @solver.model
    else
      puts "failed to solve"
    end
  end

  private def var(name : Char)
    @vars[name] ||= begin
      v = Z3.int(name.to_s)
      @solver.assert v >= 0
      @solver.assert v <= 9
      v
    end
  end

  private def word_value(word)
    word[1..].reduce(word[0]) { |x, y| 10 * x + y }
  end

  private def print_answer(model)
    [@a, @b, @c].each do |word|
      p word.map { |v| [v.to_s, model[v].to_i] }
    end
  end
end

VerbalArithmetic.new("SEND", "MORE", "MONEY").call
