module Z3
  class IntExpr
    def initialize(@expr : LibZ3::Ast)
    end

    def sort
      IntSort
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
      IntExpr.new API.mk_mul([self, sort[other]])
    end

    def +(other)
      IntExpr.new API.mk_add([self, sort[other]])
    end

    def -(other)
      IntExpr.new API.mk_sub([self, sort[other]])
    end

    def /(other)
      IntExpr.new API.mk_div(self, sort[other])
    end

    def rem(other)
      IntExpr.new API.mk_rem(self, sort[other])
    end

    def mod(other)
      IntExpr.new API.mk_mod(self, sort[other])
    end

    # It doesn't match Crystal on a negative right side, but nobody does modulo a
    # negative anyway, and the Python Z3 API does the same thing
    def %(other)
      mod(other)
    end

    def **(other)
      IntExpr.new API.mk_power(self, sort[other])
    end

    def -
      IntExpr.new API.mk_unary_minus(self)
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
      IntExpr.new API.mk_abs(self)
    end

    # Z3 spells this the other way round, as "other divides self"
    def divisible_by?(other)
      BoolExpr.new API.mk_divides(sort[other], self)
    end

    def to_real
      RealExpr.new API.mk_int2real(self)
    end

    # Takes the low `n` bits, so it wraps rather than failing on values which don't
    # fit - `Z3.int("a").to_bv(8)` of 256 is 0. Which Integer comes back out depends
    # on how you read it again: BitvecExpr#signed_value or #unsigned_value.
    def to_bv(n : Int)
      raise Z3::Exception.new("Bitvec width must be a positive Integer") unless n >= 1
      BitvecExpr.new API.mk_int2bv(n.to_u32, self), BitvecSort.new(n.to_u32)
    end

    def to_bitvec(n : Int)
      to_bv(n)
    end

    def simplify
      IntExpr.new API.simplify(self)
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

    # Every sort which can hand back a Crystal object spells it #value. Z3 Ints are
    # unbounded, so this is a BigInt - #to_i is the Int32 one, as everywhere else in
    # Crystal.
    def value : BigInt
      return BigInt.new(API.get_numeral_string(self)) if const?
      s = simplify
      return BigInt.new(API.get_numeral_string(s)) if s.const?
      raise Z3::Exception.new("Can't convert expression #{self} into Integer")
    end

    def to_i : Int32
      value.to_i
    end

    def to_i64 : Int64
      value.to_i64
    end

    def to_big_i : BigInt
      value
    end

    def inspect(io)
      io << "IntExpr<"
      to_s(io)
      io << ">"
    end

    def to_unsafe
      @expr
    end
  end
end
