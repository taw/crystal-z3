module Z3
  class RealExpr
    def initialize(@expr : LibZ3::Ast)
    end

    def sort
      RealSort
    end

    def ==(other)
      BoolExpr.new API.mk_eq(self, sort[other])
    end

    def !=(other)
      BoolExpr.new API.mk_ne(self, sort[other])
    end

    def >=(other)
      BoolExpr.new API.mk_ge(self, sort[other])
    end

    def >(other)
      BoolExpr.new API.mk_gt(self, sort[other])
    end

    def <=(other)
      BoolExpr.new API.mk_le(self, sort[other])
    end

    def <(other)
      BoolExpr.new API.mk_lt(self, sort[other])
    end

    def *(other)
      RealExpr.new API.mk_mul([self, sort[other]])
    end

    def +(other)
      RealExpr.new API.mk_add([self, sort[other]])
    end

    def -(other)
      RealExpr.new API.mk_sub([self, sort[other]])
    end

    def /(other)
      RealExpr.new API.mk_div(self, sort[other])
    end

    def **(other)
      RealExpr.new API.mk_power(self, sort[other])
    end

    def -
      RealExpr.new API.mk_unary_minus(self)
    end

    def zero?
      self == 0
    end

    def nonzero?
      self != 0
    end

    def positive?
      self > 0
    end

    def negative?
      self < 0
    end

    def abs
      RealExpr.new API.mk_abs(self)
    end

    # SMT-LIB's `to_int` rounds towards negative infinity, so this is Crystal's
    # Float#floor. Deliberately not #to_i, which truncates towards zero instead -
    # `(-2.5).to_i` is -2 in Crystal, but this is -3.
    def floor
      IntExpr.new API.mk_real2int(self)
    end

    def to_int
      floor
    end

    # A Z3 Bool, like #zero? and the other predicates, not a Crystal one
    def integer?
      BoolExpr.new API.mk_is_int(self)
    end

    def simplify
      RealExpr.new API.simplify(self)
    end

    def const?
      API.get_ast_kind(self) == LibZ3::AstKind::Numeral
    end

    def to_s(io)
      if const?
        io << API.get_numeral_string(self)
      else
        # We should use our own printer, these are just S-Expressions
        io << API.ast_to_string(self)
      end
    end

    # Z3 answers an irrational root with an algebraic number rather than giving up,
    # and those are `app`s rather than numerals, so #const? won't spot them
    def algebraic?
      API.is_algebraic_number(self)
    end

    # There's no #value here, unlike every other sort which can hand back a Crystal
    # object. Z3's Reals include the algebraic numbers, and √2 has no exact Crystal
    # equivalent at all - so instead there's #to_r, which is exact and refuses when it
    # can't be, and #to_f, which is an approximation and says so by being a Float64.
    def to_r : BigRational
      v = as_literal
      if v.algebraic?
        raise Z3::Exception.new("Can't convert algebraic number #{v} into an exact BigRational, use #to_f or #lower_bound / #upper_bound")
      end
      parse_rational(API.get_numeral_string(v))
    end

    # Always available, because a Float is allowed to be approximate
    def to_f : Float64
      v = as_literal
      return v.to_r.to_f unless v.algebraic?
      # Far more precision than a Float can hold, so both ends of the interval round
      # to the same double and it doesn't matter which one we take
      v.lower_bound.to_f
    end

    # Rationals bracketing the value, as tightly as `precision` asks for.
    # An exact value is its own bound.
    def lower_bound(precision = 20) : BigRational
      v = as_literal
      return v.to_r unless v.algebraic?
      RealExpr.new(API.get_algebraic_number_lower(v, precision.to_u32)).to_r
    end

    def upper_bound(precision = 20) : BigRational
      v = as_literal
      return v.to_r unless v.algebraic?
      RealExpr.new(API.get_algebraic_number_upper(v, precision.to_u32)).to_r
    end

    # Model values arrive already reduced, anything else has to be simplified first
    private def as_literal : RealExpr
      return self if const? || algebraic?
      s = simplify
      return s if s.const? || s.algebraic?
      raise Z3::Exception.new("Can't convert expression #{self} into a number")
    end

    private def parse_rational(str)
      if str.includes?("/")
        num, den = str.split("/", 2)
        BigRational.new(BigInt.new(num), BigInt.new(den))
      else
        BigRational.new(BigInt.new(str))
      end
    end

    def inspect(io)
      to_s(io)
    end

    def to_unsafe
      @expr
    end
  end
end
