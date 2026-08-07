module Z3
  class RealSort
    @@sort = LibZ3.mk_real_sort(API::Context)

    def self.[](expr : RealExpr)
      expr
    end

    def self.var(name : String)
      RealExpr.new API.mk_const(name, @@sort)
    end

    def self.[](num : Int | BigRational)
      RealExpr.new API.mk_numeral(num, @@sort)
    end

    def self.[](num : Float64)
      raise Z3::Exception.new("Can't convert non-finite float to Z3 Real") unless num.finite?
      RealExpr.new API.mk_numeral(num, @@sort)
    end

    def self.cast(value) : RealExpr
      case value
      when RealExpr
        value
      when Int, BigRational, Float64
        self[value]
      else
        raise Z3::Exception.new("Can't convert #{value.inspect} into #{self}")
      end
    end

    def self.from_ast(ast : LibZ3::Ast) : RealExpr
      RealExpr.new ast
    end

    def self.to_unsafe
      @@sort
    end

    def self.to_s(io)
      io << "Real"
    end
  end
end
