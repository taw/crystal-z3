module Z3
  class CharSort
    @@sort = LibZ3.mk_char_sort(API::Context)

    # Z3's alphabet is Unicode code points 0 to 0x2FFFF, so it stops short of
    # Crystal's 0x10FFFF. Z3 itself doesn't check, it just misbehaves.
    MAX_CODE_POINT = 0x2FFFF

    def self.[](expr : CharExpr)
      expr
    end

    def self.var(name : String)
      CharExpr.new API.mk_const(name, @@sort)
    end

    # Crystal has a Char type, so unlike Ruby's z3 gem there is no need to read a one
    # character String as a character. A code point works too, since that is what a
    # Z3 Char is.
    def self.[](c : Char)
      self[c.ord]
    end

    def self.[](code_point : Int)
      raise Z3::Exception.new("Char code point must be between 0 and 0x#{MAX_CODE_POINT.to_s(16).upcase}") unless 0 <= code_point <= MAX_CODE_POINT
      CharExpr.new API.mk_char(code_point.to_u32)
    end

    # The other direction of CharExpr#to_bv. Z3 wants the full 18 bits, which is as
    # wide as its alphabet goes.
    def self.from_bv(bv : BitvecExpr)
      raise Z3::Exception.new("Bitvec(18) expected, got Bitvec(#{bv.size})") unless bv.size == 18
      CharExpr.new API.mk_char_from_bv(bv)
    end

    def self.cast(value) : CharExpr
      case value
      when CharExpr, Char, Int
        self[value]
      else
        raise Z3::Exception.new("Can't convert #{value.inspect} into #{self}")
      end
    end

    def self.from_ast(ast : LibZ3::Ast) : CharExpr
      CharExpr.new ast
    end

    def self.to_unsafe
      @@sort
    end

    def self.to_s(io)
      io << "Char"
    end
  end
end
