module Z3
  # Everything `Solver` and `Optimize` both do, expressed in terms of `#check`,
  # `#model`, `#assert` and `#push` / `#pop`, which they each implement themselves.
  module Checkable
    # The splat is untyped because Crystal requires at least one argument for a
    # splat with a type restriction, and `#check` with no assumptions is the common
    # case. `BoolSort.cast` is what refuses anything which isn't a Bool.
    def satisfiable?(*assumptions) : Bool
      case check(*assumptions)
      when .sat?
        true
      when .unsat?
        false
      else
        raise Z3::Exception.new("Satisfiability unknown")
      end
    end

    def unsatisfiable?(*assumptions) : Bool
      case check(*assumptions)
      when .unsat?
        true
      when .sat?
        false
      else
        raise Z3::Exception.new("Satisfiability unknown")
      end
    end

    # Asserts the negation of the claim and prints the verdict - "Proven" if nothing
    # satisfies it, a counterexample if something does. The assertion is scoped, so
    # this leaves the solver as it found it. The Ruby gem prints to stdout; `io` is
    # here so the output can be captured.
    def prove!(claim : BoolExpr, io : IO = STDOUT) : Nil
      push
      assert(~claim)
      case check
      when .sat?
        io.puts "Counterexample exists"
        model.each { |name, value| io.puts "* #{name} = #{value}" }
      when .unknown?
        io.puts "Unknown"
      else
        io.puts "Proven"
      end
    ensure
      pop
    end
  end
end
