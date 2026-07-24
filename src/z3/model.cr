module Z3
  class Model
    def initialize(model : LibZ3::Model)
      @model = model
      # Without this the solver reclaims the model as soon as it produces another
      # one, leaving any expression that embeds a model value dangling.
      # TODO: pair with model_dec_ref when we add proper reference counting / GC.
      API.model_inc_ref(@model)
    end

    {% for type in %w[BoolExpr IntExpr BitvecExpr RealExpr] %}
      def eval(expr : {{type.id}}, complete=false)
        result = API.model_eval(self, expr, complete)
        raise Z3::Exception.new("Incorrect type returned") unless result.is_a?({{type.id}})
        result
      end
    {% end %}

    def [](expr)
      eval(expr, true)
    end

    def num_consts
      API.model_get_num_consts(self)
    end

    # Yields each constant in the model as a `{variable, value}` pair, sorted by
    # name. We have no FuncDecl wrapper yet, so we rebuild the variable from the
    # const's name and range sort.
    def each(&)
      entries = [] of {String, AnyExpr, AnyExpr}
      num_consts.times do |i|
        decl = API.model_get_const_decl(self, i)
        name = API.get_decl_name(decl)
        range = API.get_range(decl)
        var = API.new_from_ast_pointer(API.mk_const(name, range))
        value = API.model_get_const_interp(self, decl)
        entries << {name, var, value}
      end
      entries.sort_by! { |entry| entry[0] }
      entries.each do |(_name, var, value)|
        yield var, value
      end
    end

    def consts
      result = [] of AnyExpr
      each { |var, _value| result << var }
      result
    end

    # A formula asserting the model must differ somewhere - useful for
    # enumerating all solutions.
    def negate
      diffs = [] of BoolExpr
      each do |var, value|
        diffs << BoolExpr.new(API.mk_ne(var, value))
      end
      # A model with no consts constrains nothing, so there is nothing to differ in
      return BoolSort[false] if diffs.empty?
      BoolExpr.new API.mk_or(diffs)
    end

    # This needs to go eventually
    def to_s(io)
      io << API.model_to_string(@model).chomp
    end

    def to_unsafe
      @model
    end
  end
end
