module Z3
  class BoolSort
    @@sort = LibZ3.mk_bool_sort(API::Context)

    def self.[](expr : BoolExpr)
      expr
    end

    def self.var(name : String)
      BoolExpr.new API.mk_const(name, @@sort)
    end

    def self.[](t : Bool)
      if t
        BoolExpr.new API.mk_true
      else
        BoolExpr.new API.mk_false
      end
    end

    def self.cast(value) : BoolExpr
      case value
      when BoolExpr, Bool
        self[value]
      else
        raise Z3::Exception.new("Can't convert #{value.inspect} into #{self}")
      end
    end

    def self.from_ast(ast : LibZ3::Ast) : BoolExpr
      BoolExpr.new ast
    end

    def self.to_unsafe
      @@sort
    end

    def self.to_s(io)
      io << "Bool"
    end
  end
end
