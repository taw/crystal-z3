module Z3
  # The way an operation rounds, as a Z3 value - IEEE says every arithmetic
  # operation names one, so every `FloatExpr` method which rounds takes one.
  #
  # The sort has exactly five elements, and they're the class methods below. It's
  # also an ordinary sort, so `RoundingModeSort.var("m")` hands the choice to the
  # solver, and a model answers with one of the five.
  class RoundingModeSort
    @@sort = LibZ3.mk_fpa_rounding_mode_sort(API::Context)

    def self.[](expr : RoundingModeExpr)
      expr
    end

    def self.var(name : String)
      RoundingModeExpr.new API.mk_const(name, @@sort)
    end

    # Ties are the values exactly between two floats, which is the only case the
    # first two disagree on - 2.5 rounds to 2.0 one way and 3.0 the other
    def self.nearest_ties_even
      RoundingModeExpr.new API.mk_fpa_round_nearest_ties_to_even
    end

    def self.nearest_ties_away
      RoundingModeExpr.new API.mk_fpa_round_nearest_ties_to_away
    end

    def self.towards_zero
      RoundingModeExpr.new API.mk_fpa_round_toward_zero
    end

    def self.towards_negative
      RoundingModeExpr.new API.mk_fpa_round_toward_negative
    end

    def self.towards_positive
      RoundingModeExpr.new API.mk_fpa_round_toward_positive
    end

    # A rounding mode has no Crystal counterpart to be cast from - the five above
    # are the only values there are
    def self.cast(value) : RoundingModeExpr
      case value
      when RoundingModeExpr
        self[value]
      else
        raise Z3::Exception.new("Can't convert #{value.inspect} into #{self}")
      end
    end

    def self.from_ast(ast : LibZ3::Ast) : RoundingModeExpr
      RoundingModeExpr.new ast
    end

    def self.to_unsafe
      @@sort
    end

    def self.to_s(io)
      io << "RoundingMode"
    end
  end
end
