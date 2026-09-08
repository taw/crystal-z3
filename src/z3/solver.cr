module Z3
  class Solver
    include Checkable

    # Spelled out because Crystal can only guess an instance variable's type from a
    # LibZ3 call it can see, and every call goes through API's error checking now
    @solver : LibZ3::Solver
    @model : Model?
    @check : CheckResult?

    # `solver` is how the alternative constructors below pass in their own, and
    # `simple` says which kind it is, because Z3 offers no way to ask one - see
    # `#simple?`. `Solver.new` is the general purpose one and you almost always want it:
    # it inspects the assertions and assembles a tactic to match them.
    def initialize(solver : LibZ3::Solver = API.mk_solver, @simple : Bool = false)
      @solver = solver
      # A solver at refcount 0 has unstable internals (e.g. #assertions crashes),
      # so hold a reference for its whole lifetime.
      # TODO: pair with solver_dec_ref when we add proper reference counting / GC.
      API.solver_inc_ref(@solver)
      @model = nil
      @check = nil
    end

    # Just the incremental SMT core, which is usually weaker than `Solver.new` - but
    # it's the only solver which implements `#trail` and `#set_initial_value`.
    def self.simple
      new(API.mk_simple_solver, true)
    end

    # Specializes the solver for one SMT-LIB2 logic ("QF_LIA", "QF_BV", ...), which can
    # be much faster. Z3 rejects a logic name it doesn't know, and we have no list to
    # check against, so that error comes straight from it - but an assertion outside
    # the logic is not reliably refused, so don't count on being told.
    def self.for_logic(logic : String)
      new(API.mk_solver_for_logic(logic), false)
    end

    # Whether this is the plain incremental SMT core rather than a solver built out of
    # tactics. It matters because two Z3 features are implemented by that solver and no
    # other - `#trail` and `#set_initial_value` - and Z3 won't say which kind a solver
    # is, so this is remembered from however it was built.
    def simple?
      @simple
    end

    def assert(expr)
      reset_cache
      API.solver_assert(self, expr)
    end

    # `tracker` is a Bool const standing in for `expr`, and it's what shows up in
    # `#unsat_core` if the solver blames this assertion
    def assert_and_track(expr, tracker)
      reset_cache
      API.solver_assert_and_track(self, expr, tracker)
    end

    def push
      reset_cache
      API.solver_push(self)
    end

    def pop(n = 1)
      reset_cache
      API.solver_pop(self, n)
    end

    def reset
      reset_cache
      API.solver_reset(self)
    end

    def num_scopes
      API.solver_get_num_scopes(self)
    end

    # Assumptions are Bool exprs taken as true for this one check and nothing after it -
    # unlike `#assert` they leave no trace on the solver, so there's no `#push` / `#pop`
    # to pair up. They're also what `#unsat_core` blames, so an `Unsat` names the
    # assumptions responsible without any of `#assert_and_track`'s tracker variables.
    def check(*assumptions) : CheckResult
      reset_cache
      list = [] of BoolExpr
      assumptions.each { |assumption| list << BoolSort.cast(assumption) }
      lbool =
        if list.empty?
          API.solver_check(self)
        else
          API.solver_check_assumptions(self, list)
        end
      @check = CheckResult.from_lbool(lbool)
    end

    def model
      @model ||= begin
        check unless @check
        raise Z3::Exception.new("Model not satisfiable") unless @check == CheckResult::Sat
        Model.new(API.solver_get_model(self))
      end
    end

    def assertions
      API.solver_get_assertions(self)
    end

    # Only the trackers passed to `#assert_and_track`, and the assumptions passed to
    # `#check`, can ever show up here - plainly asserted formulas are never blamed
    def unsat_core
      API.solver_get_unsat_core(self)
    end

    # Everything about `variables` which follows from the assertions. This solves, so
    # it's much more work than `#assertions`.
    def consequences(variables : Array(BoolExpr), assumptions : Array(BoolExpr) = [] of BoolExpr)
      reset_cache
      lbool, consequences = API.solver_get_consequences(self, assumptions, variables)
      result = CheckResult.from_lbool(lbool)
      unless result == CheckResult::Sat
        raise Z3::Exception.new("Consequences need satisfiable assertions, these are #{result}")
      end
      consequences
    end

    # One case split, for divide-and-conquer solving - each call returns the next cube,
    # and `[false]` once they're exhausted, after which it starts over. `variables` is
    # which literals to split on, or `[]` to let Z3 choose.
    def cube(variables : Array(BoolExpr) = [] of BoolExpr, backtrack_level : Int = 0)
      reset_cache
      API.solver_cube(self, variables, backtrack_level.to_u32)
    end

    # The assertions Z3 has boiled down to a single literal, and everything it hasn't -
    # together they're a partition of what the solver currently knows
    def units
      API.solver_get_units(self)
    end

    def non_units
      API.solver_get_non_units(self)
    end

    # The literals the solver currently has assigned, in assignment order.
    # Only `Solver.simple` implements it - every other kind raises.
    def trail
      API.solver_get_trail(self)
    end

    # A hint at which value to try for a variable first - a warm start, for feeding a
    # known-good solution back in. It stays a hint: an impossible one is overridden
    # rather than believed, and it can't make an unsat problem sat. It survives `#check`
    # and `#push` / `#pop`, and setting it again replaces it.
    #
    # Only `Solver.simple` implements it. Every other kind takes the call and silently
    # ignores it, which is worse than refusing, so this refuses on their behalf.
    #
    # Z3 acts on it for Bool (the initial phase), Int and Real (the Simplex tableau is
    # calibrated towards it) and Bitvec (a phase per bit). Other sorts - String and Seq
    # among them - it accepts and ignores, and there's no way to be told which is which.
    def set_initial_value(var : AnyExpr, value)
      unless simple?
        raise Z3::Exception.new("Only Solver.simple takes initial values, every other solver ignores them")
      end
      API.const_decl(var)
      API.solver_set_initial_value(self, var, var.sort.cast(value))
      self
    end

    # Cancels a `#check` in progress, so it returns `Unknown` instead of an answer.
    # It's meant for another fiber or a signal handler - on an idle solver it does
    # nothing, and the flag is cleared by the time the next `#check` starts.
    def interrupt
      API.solver_interrupt(self)
      self
    end

    # Parses SMT-LIB2 and adds its assertions on top of whatever's already asserted.
    # Anything it declares goes into the shared context, so `(declare-const a Int)`
    # here is the same variable as `Z3.int("a")` in Crystal - but the parser starts
    # with an empty symbol table every time, so each string has to declare what it uses.
    def from_string(str : String)
      reset_cache
      API.solver_from_string(self, str)
      self
    end

    def from_file(path : String)
      reset_cache
      API.solver_from_file(self, path)
      self
    end

    def statistics
      API.solver_get_statistics(self)
    end

    def help
      API.solver_get_help(self)
    end

    def reason_unknown
      API.solver_get_reason_unknown(self)
    end

    def to_s(io)
      io << API.solver_to_string(self).chomp
    end

    def to_dimacs(include_names = true)
      API.solver_to_dimacs_string(self, include_names).chomp
    end

    def to_unsafe
      @solver
    end

    private def reset_cache
      @model = nil
      @check = nil
    end
  end
end
