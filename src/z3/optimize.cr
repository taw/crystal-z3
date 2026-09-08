module Z3
  # A solver with objectives. Everything `Solver` does with assertions it does too,
  # plus `#maximize`, `#minimize` and `#assert_soft` - soft constraints being the ones
  # Z3 is allowed to break, paying their weight when it does, which is MaxSAT.
  #
  # Z3's objective value readers aren't bound, so read the maximised term out of the
  # model rather than expecting one from `#maximize`, which answers the objective's
  # index the way Z3 does.
  class Optimize
    include Checkable

    @optimize : LibZ3::Optimize
    @model : Model?
    @check : CheckResult?

    def initialize
      @optimize = API.mk_optimize
      # TODO: pair with optimize_dec_ref when we add proper reference counting / GC.
      API.optimize_inc_ref(@optimize)
      @model = nil
      @check = nil
    end

    def assert(expr)
      reset_cache
      API.optimize_assert(self, expr)
    end

    # `tracker` is a Bool const standing in for `expr`, and it's what shows up in
    # `#unsat_core` if the solver blames this assertion
    def assert_and_track(expr, tracker)
      reset_cache
      API.optimize_assert_and_track(self, expr, tracker)
    end

    # A constraint Z3 may break, at the cost of `weight`. The weight is a String
    # because that's Z3's own interface to it.
    def assert_soft(expr, weight : String = "1")
      reset_cache
      API.optimize_assert_soft(self, expr, weight)
    end

    def maximize(expr)
      reset_cache
      API.optimize_maximize(self, expr)
    end

    def minimize(expr)
      reset_cache
      API.optimize_minimize(self, expr)
    end

    def push
      reset_cache
      API.optimize_push(self)
    end

    # Z3's optimizer pops one scope at a time, unlike a Solver
    def pop
      reset_cache
      API.optimize_pop(self)
    end

    def check(*assumptions) : CheckResult
      reset_cache
      list = [] of BoolExpr
      assumptions.each { |assumption| list << BoolSort.cast(assumption) }
      @check = CheckResult.from_lbool(API.optimize_check(self, list))
    end

    def model
      @model ||= begin
        check unless @check
        raise Z3::Exception.new("Model not satisfiable") unless @check == CheckResult::Sat
        Model.new(API.optimize_get_model(self))
      end
    end

    def assertions
      API.optimize_get_assertions(self)
    end

    def unsat_core
      API.optimize_get_unsat_core(self)
    end

    # A hint at which value to try for a variable first, the same warm start
    # `Solver.simple` takes - but Bool and Bitvec only.
    #
    # Z3's optimizer gets arithmetic ones wrong in both directions: an Int hint is
    # dropped by its `elim_01` preprocessing before the search ever sees it, and a Real
    # hint which does arrive comes back out of that preprocessing scaled, so an Optimize
    # with an objective can answer with a model that fails its own assertions. Those two
    # raise here rather than being passed through; `Solver.simple` honours arithmetic
    # warm starts correctly and is where one belongs until Z3 is fixed.
    def set_initial_value(var : AnyExpr, value)
      API.const_decl(var)
      sort = var.sort
      if sort.is_a?(IntSort.class) || sort.is_a?(RealSort.class)
        raise Z3::Exception.new(
          "Optimize drops Int initial values and answers unsoundly for Real ones, " \
          "use Solver.simple for an arithmetic warm start")
      end
      API.optimize_set_initial_value(self, var, sort.cast(value))
      self
    end

    # Parses SMT-LIB2 and adds its assertions on top of whatever's already asserted,
    # the same way `Solver#from_string` does - except that this parser knows
    # `(maximize ...)`, `(minimize ...)` and `(assert-soft ...)` too, so a string can
    # bring objectives along with its assertions.
    def from_string(str : String)
      reset_cache
      API.optimize_from_string(self, str)
      self
    end

    def from_file(path : String)
      reset_cache
      API.optimize_from_file(self, path)
      self
    end

    def statistics
      API.optimize_get_statistics(self)
    end

    def help
      API.optimize_get_help(self)
    end

    def reason_unknown
      API.optimize_get_reason_unknown(self)
    end

    def to_s(io)
      io << API.optimize_to_string(self).chomp
    end

    def to_unsafe
      @optimize
    end

    private def reset_cache
      @model = nil
      @check = nil
    end
  end
end
