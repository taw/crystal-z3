module Z3
  class BoolExpr
    def initialize(@expr : LibZ3::Ast)
    end

    def sort
      BoolSort
    end

    def ==(other)
      BoolExpr.new API.mk_eq(self, sort[other])
    end

    def !=(other)
      BoolExpr.new API.mk_ne(self, sort[other])
    end

    def &(other)
      BoolExpr.new API.mk_and([self, sort[other]])
    end

    def |(other)
      BoolExpr.new API.mk_or([self, sort[other]])
    end

    def ^(other)
      BoolExpr.new API.mk_xor(self, sort[other])
    end

    def implies(other)
      BoolExpr.new API.mk_implies(self, sort[other])
    end

    def iff(other)
      BoolExpr.new API.mk_iff(self, sort[other])
    end

    def ite(a : (IntExpr | Int), b : (IntExpr | Int)) : IntExpr
      IntExpr.new API.mk_ite(self, IntSort[a], IntSort[b])
    end

    def ite(a : (BoolExpr | Bool), b : (BoolExpr | Bool)) : BoolExpr
      BoolExpr.new API.mk_ite(self, BoolSort[a], BoolSort[b])
    end

    def ite(a : RealExpr, b : (RealExpr | Int | Float64 | BigRational)) : RealExpr
      RealExpr.new API.mk_ite(self, a, RealSort[b])
    end

    def ite(a : (Int | Float64 | BigRational), b : RealExpr) : RealExpr
      RealExpr.new API.mk_ite(self, RealSort[a], b)
    end

    # Both branches have to be the same sort, and a Bitvec's sort includes its size,
    # so the sizes have to match too - `sort[]` is what says so
    def ite(a : BitvecExpr, b : (BitvecExpr | Int)) : BitvecExpr
      BitvecExpr.new API.mk_ite(self, a, a.sort[b]), a.sort
    end

    def ite(a : Int, b : BitvecExpr) : BitvecExpr
      BitvecExpr.new API.mk_ite(self, b.sort[a], b), b.sort
    end

    def ite(a : CharExpr, b : (CharExpr | Char)) : CharExpr
      CharExpr.new API.mk_ite(self, a, CharSort[b])
    end

    def ite(a : Char, b : CharExpr) : CharExpr
      CharExpr.new API.mk_ite(self, CharSort[a], b)
    end

    def ~
      BoolExpr.new API.mk_not(self)
    end

    def simplify
      BoolExpr.new API.simplify(self)
    end

    def to_s(io)
      io << API.ast_to_string(self)
    end

    def inspect(io)
      io << "BoolExpr<"
      to_s(io)
      io << ">"
    end

    def const?
      API.get_bool_value(self) != LibZ3::LBool::Undefined
    end

    # Every sort which can hand back a Crystal object spells it #value
    def value : Bool
      v = API.get_bool_value(self)
      v = API.get_bool_value(simplify) if v == LibZ3::LBool::Undefined
      # Anything else is neither true nor false, so it has no Crystal value
      raise Z3::Exception.new("Can't convert expression #{self} into Bool") if v == LibZ3::LBool::Undefined
      v == LibZ3::LBool::True
    end

    def to_b : Bool
      value
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
