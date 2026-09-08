module Z3
  # One of the five rounding modes, or a variable which the solver resolves to one
  # of them. `RoundingModeSort` is where the five come from.
  class RoundingModeExpr
    def initialize(@expr : LibZ3::Ast)
    end

    def sort
      RoundingModeSort
    end

    def ==(other)
      BoolExpr.new API.mk_eq(self, sort[other])
    end

    def !=(other)
      BoolExpr.new API.mk_ne(self, sort[other])
    end

    def simplify
      RoundingModeExpr.new API.simplify(self)
    end

    def to_s(io)
      # We should use our own printer, these are just S-Expressions
      io << API.ast_to_string(self)
    end

    def inspect(io)
      io << "RoundingModeExpr<"
      to_s(io)
      io << ">"
    end

    # Whether this is the same term as `other`. Z3 hash-conses its expressions, so
    # this is structural equality - `Z3.int("a") + 1` built twice is one term. It is
    # a named method rather than `==` because `==` builds a Z3 expression instead of
    # answering a Crystal Bool - see the Limitations section of the README.
    def same_term?(other : AnyExpr)
      API.is_eq_ast(self, other)
    end

    def to_unsafe
      @expr
    end
  end
end
