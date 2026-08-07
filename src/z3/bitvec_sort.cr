module Z3
  class BitvecSort
    def initialize(@size : UInt32)
      raise Z3::Exception.new("Bitvec width must be a positive Integer") unless @size >= 1
      @sort = LibZ3.mk_bv_sort(API::Context, @size)
    end

    def [](expr : BitvecExpr)
      raise Z3::Exception.new("Incompatible bitvector sizes #{@size} != #{expr.size}") unless @size == expr.size
      expr
    end

    def var(name : String)
      BitvecExpr.new API.mk_const(name, self), self
    end

    def [](v : Int)
      BitvecExpr.new API.mk_numeral(v, self), self
    end

    def cast(value) : BitvecExpr
      case value
      when BitvecExpr, Int
        self[value]
      else
        raise Z3::Exception.new("Can't convert #{value.inspect} into #{self}")
      end
    end

    def from_ast(ast : LibZ3::Ast) : BitvecExpr
      BitvecExpr.new ast, self
    end

    def size
      @size
    end

    # Z3 hash-conses its sorts, so two Bitvec sorts of the same size are one sort
    def ==(other : BitvecSort)
      @sort == other.to_unsafe
    end

    def to_unsafe
      @sort
    end

    def to_s(io)
      io << "Bitvec(" << @size << ")"
    end
  end
end
