module Z3
  # Real IEEE 754 floats, not Reals - `Float(11, 53)` is a double, with everything
  # that implies: two zeroes, two infinities, NaN, and rounding on every operation.
  #
  # A sort is its two bit counts, the exponent's and the significand's, and the four
  # IEEE widths can be named instead:
  #
  #     Z3::FloatSort.new(:double)     # also :half, :single, :quadruple
  #     Z3::FloatSort.new(64)          # also 16, 32, 128
  #     Z3::FloatSort.new(11, 53)      # the same sort again
  class FloatSort
    @sort : LibZ3::Sort
    @ebits : UInt32
    @sbits : UInt32

    def initialize(ebits : Int, sbits : Int)
      raise Z3::Exception.new("Float exponent and significand sizes must be positive Integers") unless ebits >= 1 && sbits >= 1
      @ebits = ebits.to_u32
      @sbits = sbits.to_u32
      # Z3 has its own minimums - two exponent bits and three significand bits -
      # and says so better than a check here could
      @sort = API.mk_fpa_sort(@ebits, @sbits)
    end

    # The four IEEE widths, by total size or by name. Each is only its two bit
    # counts, so this is `mk_fpa_sort` too - Z3's `mk_fpa_sort_16` and friends are
    # the same four sorts under their IEEE names.
    def self.new(width : Int | Symbol)
      case width
      when 16, :half
        new(5, 11)
      when 32, :single
        new(8, 24)
      when 64, :double
        new(11, 53)
      when 128, :quadruple
        new(15, 113)
      else
        raise Z3::Exception.new("Unknown float type #{width}, use FloatSort.new(exponent_bits, significand_bits)")
      end
    end

    def ebits
      @ebits
    end

    def sbits
      @sbits
    end

    def [](expr : FloatExpr)
      raise Z3::Exception.new("Incompatible float sorts #{self} != #{expr.sort}") unless self == expr.sort
      expr
    end

    # A Crystal Float64 is an IEEE double, so every value converts exactly into
    # `Float(11, 53)` - NaN, the infinities and the two zeroes included - and rounds
    # to nearest into anything narrower.
    def [](value : Float64)
      double = FloatSort.new(64)
      return FloatExpr.new(API.mk_fpa_numeral_double(value, double), self) if self == double
      # For every other sort the value has to be rounded, and Z3_mk_fpa_numeral_double
      # gets that wrong - it answers NaN on overflow and misencodes subnormals. Build
      # the exact double instead, and let Z3 round it the way IEEE says to.
      exact = FloatExpr.new(API.mk_fpa_numeral_double(value, double), double)
      from_float(exact, RoundingModeSort.nearest_ties_even).simplify
    end

    def [](value : Int)
      as_float = value.to_f
      # Crystal compares an Integer to a Float by converting the Integer, which calls
      # 2**53 + 1 equal to 2**53 - so the check is made on the exact side instead
      unless as_float.finite? && as_float.to_big_i == value.to_big_i
        raise Z3::Exception.new("#{value} has no exact Float value")
      end
      self[as_float]
    end

    def var(name : String)
      FloatExpr.new API.mk_const(name, self), self
    end

    # The values IEEE has and no Crystal literal spells. `self[Float64::NAN]` and
    # friends build the same three, since a Crystal Float64 has them too.
    def nan
      FloatExpr.new API.mk_fpa_nan(self), self
    end

    def positive_infinity
      FloatExpr.new API.mk_fpa_inf(self, false), self
    end

    def negative_infinity
      FloatExpr.new API.mk_fpa_inf(self, true), self
    end

    def positive_zero
      FloatExpr.new API.mk_fpa_zero(self, false), self
    end

    def negative_zero
      FloatExpr.new API.mk_fpa_zero(self, true), self
    end

    # Everything below builds a value of this sort out of some other expression.
    # All but #from_ieee_bv and #from_components round, so they need a rounding mode.

    # Reinterprets the IEEE 754 bits, so it's `FloatExpr#to_ieee_bv` backwards and
    # nothing is rounded. The Bitvec has to be exactly as wide as this sort.
    def from_ieee_bv(bv : BitvecExpr)
      expect_bitvec_of_size(bv, ebits + sbits, "an IEEE bit pattern")
      FloatExpr.new API.mk_fpa_to_fp_bv(bv, self), self
    end

    # The three IEEE fields separately, which is `#sign_bv` / `#exponent_bv` /
    # `#significand_bv` backwards. The significand excludes the leading bit IEEE
    # doesn't store, so it's one narrower than `sbits`.
    def from_components(sign : BitvecExpr, exponent : BitvecExpr, significand : BitvecExpr)
      expect_bitvec_of_size(sign, 1u32, "a sign")
      expect_bitvec_of_size(exponent, ebits, "an exponent")
      expect_bitvec_of_size(significand, sbits - 1, "a significand")
      FloatExpr.new API.mk_fpa_fp(sign, exponent, significand), self
    end

    def from_float(float : FloatExpr, mode : RoundingModeExpr)
      FloatExpr.new API.mk_fpa_to_fp_float(mode, float, self), self
    end

    def from_real(real, mode : RoundingModeExpr)
      FloatExpr.new API.mk_fpa_to_fp_real(mode, RealSort.cast(real), self), self
    end

    # Reads the Bitvec as a number and rounds it to this sort, where #from_ieee_bv
    # reads the very same bits as a float already
    def from_signed_bv(bv : BitvecExpr, mode : RoundingModeExpr)
      FloatExpr.new API.mk_fpa_to_fp_signed(mode, bv, self), self
    end

    def from_unsigned_bv(bv : BitvecExpr, mode : RoundingModeExpr)
      FloatExpr.new API.mk_fpa_to_fp_unsigned(mode, bv, self), self
    end

    # `significand * 2 ** exponent`, with a Real significand and an Int exponent -
    # the one constructor which isn't a conversion from some other representation
    def from_significand_and_exponent(significand, exponent, mode : RoundingModeExpr)
      FloatExpr.new API.mk_fpa_to_fp_int_real(mode, IntSort.cast(exponent), RealSort.cast(significand), self), self
    end

    def cast(value) : FloatExpr
      case value
      when FloatExpr, Float64, Int
        self[value]
      else
        raise Z3::Exception.new("Can't convert #{value.inspect} into #{self}")
      end
    end

    def from_ast(ast : LibZ3::Ast) : FloatExpr
      FloatExpr.new ast, self
    end

    # Z3 hash-conses its sorts, so two Float sorts of the same two sizes are one sort
    def ==(other : FloatSort)
      @sort == other.to_unsafe
    end

    def to_unsafe
      @sort
    end

    def to_s(io)
      io << "Float(" << @ebits << ", " << @sbits << ")"
    end

    private def expect_bitvec_of_size(bv : BitvecExpr, size : UInt32, what : String)
      raise Z3::Exception.new("Bitvec(#{size}) expected as #{what}, got Bitvec(#{bv.size})") unless bv.size == size
    end
  end
end
