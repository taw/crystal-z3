module Z3
  # Z3 represents a String as a Seq(Char), so this is the very same sort as
  # `SeqSort.new(CharSort)` - which is why that hands back StringSort
  class StringSort
    @@sort = LibZ3.mk_string_sort(API::Context)

    def self.[](expr : StringExpr)
      expr
    end

    def self.var(name : String)
      StringExpr.new API.mk_const(name, @@sort)
    end

    # A Z3 string is a sequence of code points, so a Crystal String converts character
    # by character, not byte by byte - which means it has to be valid UTF-8
    def self.[](value : String)
      raise Z3::Exception.new("String is not valid UTF-8") unless value.valid_encoding?
      code_points = value.codepoints.map do |code_point|
        raise Z3::Exception.new("Character 0x#{code_point.to_s(16).upcase} is outside Z3's alphabet (0 to 0x#{CharSort::MAX_CODE_POINT.to_s(16).upcase})") if code_point > CharSort::MAX_CODE_POINT
        code_point.to_u32
      end
      StringExpr.new API.mk_u32string(code_points)
    end

    def self.element_sort
      CharSort
    end

    # These live here rather than as `IntExpr#to_str` and friends, because `to_s` is
    # already every AST's printed form. StringExpr#to_i and #to_code go the other way.

    # The decimal digits of a nonnegative Int. SMT-LIB says a negative number has no
    # string form at all, and Z3 answers "" for one rather than "-1".
    def self.from_int(int : IntExpr | Int)
      StringExpr.new API.mk_int_to_str(IntSort[int])
    end

    # The one character string for a code point, or "" if it isn't one.
    # StringExpr#to_code is this backwards.
    def self.from_code(int : IntExpr | Int)
      StringExpr.new API.mk_string_from_code(IntSort[int])
    end

    # Decimal digits again, but of a Bitvec read either way - the same eight bits
    # give "253" unsigned and "-3" signed
    def self.from_unsigned_bv(bv : BitvecExpr)
      StringExpr.new API.mk_ubv_to_str(bv)
    end

    def self.from_signed_bv(bv : BitvecExpr)
      StringExpr.new API.mk_sbv_to_str(bv)
    end

    def self.cast(value) : StringExpr
      case value
      when StringExpr, String
        self[value]
      else
        raise Z3::Exception.new("Can't convert #{value.inspect} into #{self}")
      end
    end

    def self.from_ast(ast : LibZ3::Ast) : StringExpr
      StringExpr.new ast
    end

    def self.to_unsafe
      @@sort
    end

    def self.to_s(io)
      io << "String"
    end
  end
end
