module Z3
  class CharExpr
    def initialize(@expr : LibZ3::Ast)
    end

    def sort
      CharSort
    end

    def ==(other)
      BoolExpr.new API.mk_eq(self, sort[other])
    end

    def !=(other)
      BoolExpr.new API.mk_ne(self, sort[other])
    end

    # Z3 only gives us `char.<=`, and the order is total, so the other three are that
    # one turned around and negated
    def <=(other)
      BoolExpr.new API.mk_char_le(self, sort[other])
    end

    def >=(other)
      BoolExpr.new API.mk_char_le(sort[other], self)
    end

    def <(other)
      ~(self >= other)
    end

    def >(other)
      ~(self <= other)
    end

    # The code point, as a Z3 Int - `CharSort['a'].to_i` is the term `char.to_int('a')`,
    # not the Crystal Integer 97. #value is the one which hands back a Crystal object.
    def to_i
      IntExpr.new API.mk_char_to_int(self)
    end

    # Z3's alphabet stops at 0x2FFFF, which is why 18 bits is always enough
    def to_bv
      BitvecExpr.new API.mk_char_to_bv(self), BitvecSort.new(18u32)
    end

    def digit?
      BoolExpr.new API.mk_char_is_digit(self)
    end

    def simplify
      CharExpr.new API.simplify(self)
    end

    # A Char literal is an application of an indexed decl rather than a numeral, so
    # the code point is easiest to get at by asking Z3 to simplify `char.to_int`
    def const?
      IntExpr.new(API.simplify(API.mk_char_to_int(self))).const?
    end

    # Every sort which can hand back a Crystal object spells it #value
    def value : Char
      code_point = IntExpr.new API.simplify(API.mk_char_to_int(self))
      raise Z3::Exception.new("Can't convert expression #{self} into Char") unless code_point.const?
      code_point.to_i.chr
    end

    def to_c : Char
      value
    end

    def to_s(io)
      io << API.ast_to_string(self)
    end

    def inspect(io)
      io << "CharExpr<"
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
