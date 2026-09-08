module Z3
  # An IEEE 754 float. Arithmetic rounds, so `#add` and friends take a rounding
  # mode and there are no `+` / `-` / `*` / `/` operators - IEEE has no such thing
  # as an addition which doesn't say how it rounds.
  #
  # The comparisons are IEEE's, not Z3's `=`: `+zero == -zero` is true, and
  # `NaN == NaN` is false. `#same_term?` is what asks whether two expressions are
  # the same term.
  class FloatExpr
    def initialize(@expr : LibZ3::Ast, @sort : FloatSort)
    end

    def sort
      @sort
    end

    def ebits
      @sort.ebits
    end

    def sbits
      @sort.sbits
    end

    def ==(other)
      BoolExpr.new API.mk_fpa_eq(self, sort[other])
    end

    # `fp.eq` has no negation of its own, and Z3's `distinct` is term inequality -
    # which answers differently for the zeroes and for NaN
    def !=(other)
      ~(self == other)
    end

    def <(other)
      BoolExpr.new API.mk_fpa_lt(self, sort[other])
    end

    def <=(other)
      BoolExpr.new API.mk_fpa_leq(self, sort[other])
    end

    def >(other)
      BoolExpr.new API.mk_fpa_gt(self, sort[other])
    end

    def >=(other)
      BoolExpr.new API.mk_fpa_geq(self, sort[other])
    end

    # Arithmetic is #add / #sub / #mul / #div rather than the operators, because
    # every one of them rounds and IEEE says the rounding has to be spelled out
    def add(other, mode : RoundingModeExpr)
      FloatExpr.new API.mk_fpa_add(mode, self, sort[other]), sort
    end

    def sub(other, mode : RoundingModeExpr)
      FloatExpr.new API.mk_fpa_sub(mode, self, sort[other]), sort
    end

    def mul(other, mode : RoundingModeExpr)
      FloatExpr.new API.mk_fpa_mul(mode, self, sort[other]), sort
    end

    def div(other, mode : RoundingModeExpr)
      FloatExpr.new API.mk_fpa_div(mode, self, sort[other]), sort
    end

    def +(other)
      raise Z3::Exception.new("Use #add for Float, not +, as it needs a rounding mode")
    end

    def -(other)
      raise Z3::Exception.new("Use #sub for Float, not -, as it needs a rounding mode")
    end

    def *(other)
      raise Z3::Exception.new("Use #mul for Float, not *, as it needs a rounding mode")
    end

    def /(other)
      raise Z3::Exception.new("Use #div for Float, not /, as it needs a rounding mode")
    end

    def %(other)
      raise Z3::Exception.new("Use #rem for Float, not %")
    end

    # The IEEE remainder, which is exact and so takes no rounding mode
    def rem(other)
      FloatExpr.new API.mk_fpa_rem(self, sort[other]), sort
    end

    def sqrt(mode : RoundingModeExpr)
      FloatExpr.new API.mk_fpa_sqrt(mode, self), sort
    end

    # Nearest float with no fractional part, rounded `mode`'s way - so which of 2.0
    # and 3.0 you get for 2.5 is the rounding mode's business, not this method's
    def round_to_integral(mode : RoundingModeExpr)
      FloatExpr.new API.mk_fpa_round_to_integral(mode, self), sort
    end

    # `(self * other) + addend`, rounded once at the end rather than after the
    # multiply and again after the add
    def fused_multiply_add(other, addend, mode : RoundingModeExpr)
      FloatExpr.new API.mk_fpa_fma(mode, self, sort[other], sort[addend]), sort
    end

    def min(other)
      FloatExpr.new API.mk_fpa_min(self, sort[other]), sort
    end

    def max(other)
      FloatExpr.new API.mk_fpa_max(self, sort[other]), sort
    end

    def abs
      FloatExpr.new API.mk_fpa_abs(self), sort
    end

    def -
      FloatExpr.new API.mk_fpa_neg(self), sort
    end

    # Z3 Bools, like every other sort's predicates, not Crystal ones. NaN answers
    # false to all of them, itself excepted.
    def nan?
      BoolExpr.new API.mk_fpa_is_nan(self)
    end

    def infinite?
      BoolExpr.new API.mk_fpa_is_infinite(self)
    end

    def zero?
      BoolExpr.new API.mk_fpa_is_zero(self)
    end

    # Neither zero nor NaN, so this is not `~zero?` - the two zeroes and NaN are
    # the three values which are neither positive nor negative
    def nonzero?
      (~zero?) & (~nan?)
    end

    def normal?
      BoolExpr.new API.mk_fpa_is_normal(self)
    end

    def subnormal?
      BoolExpr.new API.mk_fpa_is_subnormal(self)
    end

    def positive?
      BoolExpr.new API.mk_fpa_is_positive(self)
    end

    def negative?
      BoolExpr.new API.mk_fpa_is_negative(self)
    end

    # Exact - a Real can hold every float value, where the other direction rounds.
    # Z3 leaves the answer unspecified for NaN and the infinities.
    def to_real
      RealExpr.new API.mk_fpa_to_real(self)
    end

    # The IEEE 754 bits of this float, as one Bitvec of the sort's full width.
    # NaN has many encodings and Z3 doesn't promise which one you get.
    def to_ieee_bv
      BitvecExpr.new API.mk_fpa_to_ieee_bv(self), BitvecSort.new(ebits + sbits)
    end

    def to_bv(size, mode)
      raise Z3::Exception.new("Use #to_signed_bv or #to_unsigned_bv for Float, not #to_bv")
    end

    # Rounds to an integer, unlike #to_ieee_bv which reinterprets the same bits.
    # Z3 leaves the answer unspecified when the value doesn't fit in `size` bits.
    def to_signed_bv(size : Int, mode : RoundingModeExpr)
      BitvecExpr.new API.mk_fpa_to_sbv(mode, self, size.to_u32), BitvecSort.new(size.to_u32)
    end

    def to_unsigned_bv(size : Int, mode : RoundingModeExpr)
      BitvecExpr.new API.mk_fpa_to_ubv(mode, self, size.to_u32), BitvecSort.new(size.to_u32)
    end

    # The three IEEE fields as Bitvec expressions, and as Crystal Strings. Like
    # #value, all five only work on a literal - they take the value apart rather
    # than building a term which would. The significand is one bit narrower than
    # the sort's `sbits`, since IEEE doesn't store the leading bit.
    def sign_bv
      BitvecExpr.new API.fpa_get_numeral_sign_bv(self), BitvecSort.new(1u32)
    end

    def exponent_bv(biased : Bool)
      BitvecExpr.new API.fpa_get_numeral_exponent_bv(self, biased), BitvecSort.new(ebits)
    end

    def significand_bv
      BitvecExpr.new API.fpa_get_numeral_significand_bv(self), BitvecSort.new(sbits - 1)
    end

    def exponent_string(biased : Bool)
      API.fpa_get_numeral_exponent_string(self, biased)
    end

    def significand_string
      API.fpa_get_numeral_significand_string(self)
    end

    def simplify
      FloatExpr.new API.simplify(self), sort
    end

    # Every float literal is an application, NaN and the infinities included, so
    # this can't be the `AstKind` question it is on Int and Bitvec - Z3 has a
    # separate call for it
    def const?
      API.fpa_is_numeral(self)
    end

    # Leaves Z3 for a Crystal Float64, where #to_real and #to_ieee_bv build
    # expressions. A Crystal Float64 is an IEEE double, so every Float(11, 53) or
    # narrower value converts exactly, NaN, the infinities and the two zeroes
    # included.
    #
    # A wider sort raises whatever it holds, even when that value happens to fit -
    # Float(15, 113)'s 1.5 is a Float64's 1.5, but a sort which can't round-trip
    # through a Float64 doesn't get a #value which works only sometimes.
    def value : Float64
      unless ebits <= 11 && sbits <= 53
        raise Z3::Exception.new("#{sort} values don't fit in a Crystal Float64, which is an IEEE double - only Float(11, 53) and narrower have a #value, use #to_real or #significand_string / #exponent_string")
      end
      v = as_literal
      # Deliberately not #nan? / #infinite? / #zero?, which build symbolic BoolExprs -
      # these ask about the literal in Crystal, and #value is the only thing needing it
      return Float64::NAN if API.fpa_is_numeral_nan(v)
      negative = API.fpa_is_numeral_negative(v)
      return negative ? -Float64::INFINITY : Float64::INFINITY if API.fpa_is_numeral_inf(v)
      return negative ? -0.0 : 0.0 if API.fpa_is_numeral_zero(v)
      # Z3's significand is in [0, 2) and its unbiased exponent stays at the sort's
      # minimum for subnormals, so one expression covers normal and subnormal alike.
      # Both strings are exact, and the sort check above means the Float64 is too.
      exact = parse_decimal(v.significand_string) * power_of_two(v.exponent_string(false).to_i)
      negative ? -(exact.to_f) : exact.to_f
    end

    def to_f : Float64
      value
    end

    def to_s(io)
      if const?
        io << numeral_to_s
      else
        # We should use our own printer, these are just S-Expressions
        io << API.ast_to_string(self)
      end
    end

    def inspect(io)
      io << "FloatExpr(" << ebits << ", " << sbits << ")<"
      to_s(io)
      io << ">"
    end

    # Whether this is the same term as `other`. Z3 hash-conses its expressions, so
    # this is structural equality - `Z3.int("a") + 1` built twice is one term. It is
    # a named method rather than `==` because `==` builds a Z3 expression instead of
    # answering a Crystal Bool - see the Limitations section of the README.
    #
    # It's also the only equality which tells `+zero` from `-zero` and says NaN is
    # NaN, both of which `==` answers the other way round, IEEE's way.
    def same_term?(other : AnyExpr)
      API.is_eq_ast(self, other)
    end

    def to_unsafe
      @expr
    end

    # Z3 prints a float numeral as the S-expression which builds it. This is the
    # spelling the Ruby gem's printer uses, which says which value it is.
    private def numeral_to_s
      return "NaN" if API.fpa_is_numeral_nan(self)
      negative = API.fpa_is_numeral_negative(self)
      return negative ? "-oo" : "+oo" if API.fpa_is_numeral_inf(self)
      return negative ? "-zero" : "+zero" if API.fpa_is_numeral_zero(self)
      exponent = exponent_string(false).to_i
      String.build do |io|
        io << "-" if negative
        io << significand_string << "B"
        io << "+" if exponent >= 0
        io << exponent
      end
    end

    # Model values arrive already reduced, anything else has to be simplified first
    private def as_literal : FloatExpr
      return self if const?
      s = simplify
      return s if s.const?
      raise Z3::Exception.new("Can't convert expression #{self} into a Float64")
    end

    private def power_of_two(exponent : Int32) : BigRational
      power = BigInt.new(1) << exponent.abs
      exponent >= 0 ? BigRational.new(power, 1) : BigRational.new(1, power)
    end

    private def parse_decimal(str : String) : BigRational
      integer, _, fraction = str.partition(".")
      return BigRational.new(BigInt.new(integer), 1) if fraction.empty?
      BigRational.new(BigInt.new(integer + fraction), BigInt.new(10) ** fraction.size)
    end
  end
end
