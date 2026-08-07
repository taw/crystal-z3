module Z3
  class SeqSort
    # Z3 has no String sort of its own, a String is just a Seq(Char) - so Seq(Char) has
    # to come back as StringSort, or we'd have two Crystal classes for one Z3 sort
    def self.new(element_sort : CharSort.class)
      StringSort
    end

    def initialize(@element_sort : AnySort)
      @sort = LibZ3.mk_seq_sort(API::Context, @element_sort.to_unsafe)
    end

    def element_sort
      @element_sort
    end

    def [](expr : SeqExpr)
      raise Z3::Exception.new("Incompatible sequence sorts #{self} != #{expr.sort}") unless self == expr.sort
      expr
    end

    # Z3 has no sequence literals, a sequence value is a concatenation of one element
    # sequences - and it rejects a concatenation of fewer than two of them
    def [](values : Array)
      units = values.map { |value| unit(value) }
      case units.size
      when 0
        empty
      when 1
        units[0]
      else
        SeqExpr.new API.mk_seq_concat(units), self
      end
    end

    def var(name : String)
      SeqExpr.new API.mk_const(name, self), self
    end

    def empty
      SeqExpr.new API.mk_seq_empty(self), self
    end

    # The one element sequence holding `value`, which is what every sequence value is
    # built out of
    def unit(value)
      SeqExpr.new API.mk_seq_unit(@element_sort.cast(value)), self
    end

    def cast(value) : SeqExpr
      case value
      when SeqExpr
        self[value]
      when Array
        self[value]
      else
        raise Z3::Exception.new("Can't convert #{value.inspect} into #{self}")
      end
    end

    def from_ast(ast : LibZ3::Ast) : SeqExpr
      SeqExpr.new ast, self
    end

    # Z3 hash-conses its sorts, so two Seq sorts over the same element sort are one sort
    def ==(other : SeqSort)
      @sort == other.to_unsafe
    end

    def to_unsafe
      @sort
    end

    def to_s(io)
      io << "Seq(" << @element_sort << ")"
    end
  end
end
