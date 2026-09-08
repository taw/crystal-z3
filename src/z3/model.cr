module Z3
  class Model
    def initialize(model : LibZ3::Model)
      @model = model
      # Without this the solver reclaims the model as soon as it produces another
      # one, leaving any expression that embeds a model value dangling.
      # TODO: pair with model_dec_ref when we add proper reference counting / GC.
      API.model_inc_ref(@model)
    end

    {% for type in %w[BoolExpr IntExpr BitvecExpr RealExpr CharExpr StringExpr SeqExpr FloatExpr RoundingModeExpr] %}
      def eval(expr : {{type.id}}, complete=false)
        result = API.model_eval(self, expr, complete)
        raise Z3::Exception.new("Incorrect type returned") unless result.is_a?({{type.id}})
        result
      end
    {% end %}

    # `#eval` without the sort coming back with it, for the cases where the expression's
    # class isn't known statically - an argument of a `FuncDecl`, say
    def model_eval(expr, complete = false) : AnyExpr
      API.model_eval(self, expr, complete)
    end

    def [](expr)
      eval(expr, true)
    end

    def num_consts
      API.model_get_num_consts(self)
    end

    # The declarations of the variables the model assigned - `#each_const` is what
    # yields the variables themselves
    def consts : Array(FuncDecl)
      result = [] of FuncDecl
      num_consts.times { |i| result << FuncDecl.new(API.model_get_const_decl(self, i)) }
      result
    end

    # The uninterpreted functions the model decided the meaning of.
    #
    # Recursive definitions are left out. Z3 puts every one made in the context into
    # every model, of every solver, whether or not the query so much as mentioned it -
    # `define-fun-rec` is context-global the way it is in an SMT-LIB script. It isn't
    # something this model decided, it's the definition handed straight back, and its
    # `else` branch is a body over de Bruijn variables which no Expr can hold.
    def funcs : Array(FuncDecl)
      result = [] of FuncDecl
      API.model_get_num_funcs(self).times do |i|
        decl = FuncDecl.new(API.model_get_func_decl(self, i))
        result << decl unless decl.recursive?
      end
      result
    end

    def num_funcs
      funcs.size
    end

    def func_interp(decl : FuncDecl) : FuncInterp
      entries, default = API.model_get_func_interp(self, decl)
      FuncInterp.new(decl, entries, default)
    end

    # Whether the model says anything at all about this variable or function. It's the
    # question `#model_eval` can't answer: without completion an unassigned variable
    # evaluates to itself, and with it Z3 invents a value rather than telling you it had to.
    def has_interp?(decl : FuncDecl)
      API.model_has_interp(self, decl)
    end

    def has_interp?(var : AnyExpr)
      API.model_has_interp(self, API.const_decl(var))
    end

    # Yields each constant in the model as a `{variable, value}` pair, sorted by name
    def each_const(&)
      consts.sort_by(&.name).each do |decl|
        yield decl.range.var(decl.name), API.model_get_const_interp(self, decl)
      end
    end

    # Yields each function as a `{declaration, interpretation}` pair, sorted by name
    def each_func(&)
      funcs.sort_by(&.name).each do |decl|
        yield decl, func_interp(decl)
      end
    end

    # Constants first, then functions - so what's yielded is a variable and its value,
    # or a declaration and its interpretation, and both halves are unions
    def each(&)
      each_const do |var, value|
        yield var.as(AnyExpr | FuncDecl), value.as(AnyExpr | FuncInterp)
      end
      each_func do |decl, interp|
        yield decl.as(AnyExpr | FuncDecl), interp.as(AnyExpr | FuncInterp)
      end
    end

    # A formula asserting the model must differ somewhere - useful for
    # enumerating all solutions.
    #
    # Only constants are negated. Saying "some function differs somewhere" needs a
    # quantifier, so a model with functions in it can repeat under this.
    def negate
      diffs = [] of BoolExpr
      each_const do |var, value|
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
