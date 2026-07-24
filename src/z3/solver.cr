module Z3
  class Solver
    def initialize
      @solver = API.mk_solver
      # A solver at refcount 0 has unstable internals (e.g. #assertions crashes),
      # so hold a reference for its whole lifetime.
      # TODO: pair with solver_dec_ref when we add proper reference counting / GC.
      API.solver_inc_ref(@solver)
      @model = nil
      @check = nil
    end

    def assert(expr)
      reset_cache
      API.solver_assert(self, expr)
    end

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

    def check
      @check = API.solver_check(self)
    end

    def model
      @model ||= begin
        check unless @check
        raise Z3::Exception.new("Model not satisfiable") unless @check == LibZ3::LBool::True
        Model.new(API.solver_get_model(self))
      end
    end

    def satisfiable?
      case check
      when LibZ3::LBool::True
        true
      when LibZ3::LBool::False
        false
      else
        raise Z3::Exception.new("Unknown result")
      end
    end

    def assertions
      API.solver_get_assertions(self)
    end

    def unsat_core
      API.solver_get_unsat_core(self)
    end

    def statistics
      API.solver_get_statistics(self)
    end

    def reason_unknown
      API.solver_get_reason_unknown(self)
    end

    def to_s(io)
      io << API.solver_to_string(self).chomp
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
