module Z3
  class IntSort
    @@sort = LibZ3.mk_int_sort(API::Context)

    def self.[](expr : IntExpr)
      expr
    end

    def self.var(name : String)
      IntExpr.new API.mk_const(name, @@sort)
    end

    def self.[](v : Int)
      IntExpr.new API.mk_numeral(v, @@sort)
    end

    def self.cast(value) : IntExpr
      case value
      when IntExpr
        value
      when Int
        self[value]
      else
        raise Z3::Exception.new("Can't convert #{value.inspect} into #{self}")
      end
    end

    def self.from_ast(ast : LibZ3::Ast) : IntExpr
      IntExpr.new ast
    end

    def self.to_unsafe
      @@sort
    end

    def self.to_s(io)
      io << "Int"
    end
  end
end
