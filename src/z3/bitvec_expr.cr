module Z3
  class BitvecExpr
    def initialize(@expr : LibZ3::Ast, @sort : BitvecSort)
    end

    def size
      @sort.size
    end

    def sort
      @sort
    end

    def ==(other)
      BoolExpr.new API.mk_eq(self, sort[other])
    end

    def !=(other)
      BoolExpr.new API.mk_ne(self, sort[other])
    end

    def +(other)
      BitvecExpr.new API.mk_bvadd(self, sort[other]), sort
    end

    def -(other)
      BitvecExpr.new API.mk_bvsub(self, sort[other]), sort
    end

    def *(other)
      BitvecExpr.new API.mk_bvmul(self, sort[other]), sort
    end

    def /(other)
      raise Z3::Exception.new("Use signed_div or unsigned_div")
    end

    def signed_div(other)
      BitvecExpr.new API.mk_bvsdiv(self, sort[other]), sort
    end

    def unsigned_div(other)
      BitvecExpr.new API.mk_bvudiv(self, sort[other]), sort
    end

    def signed_mod(other)
      BitvecExpr.new API.mk_bvsmod(self, sort[other]), sort
    end

    def signed_rem(other)
      BitvecExpr.new API.mk_bvsrem(self, sort[other]), sort
    end

    def unsigned_rem(other)
      BitvecExpr.new API.mk_bvurem(self, sort[other]), sort
    end

    def %(other)
      raise Z3::Exception.new("Use signed_mod or signed_rem or unsigned_rem")
    end

    def &(other)
      BitvecExpr.new API.mk_bvand(self, sort[other]), sort
    end

    def |(other)
      BitvecExpr.new API.mk_bvor(self, sort[other]), sort
    end

    def ^(other)
      BitvecExpr.new API.mk_bvxor(self, sort[other]), sort
    end

    def nand(other)
      BitvecExpr.new API.mk_bvnand(self, sort[other]), sort
    end

    def nor(other)
      BitvecExpr.new API.mk_bvnor(self, sort[other]), sort
    end

    def xnor(other)
      BitvecExpr.new API.mk_bvxnor(self, sort[other]), sort
    end

    def >(other)
      raise Z3::Exception.new("Use #signed_gt or #unsigned_gt for Bitvec, not >")
    end

    def >=(other)
      raise Z3::Exception.new("Use #signed_ge or #unsigned_ge for Bitvec, not >=")
    end

    def <(other)
      raise Z3::Exception.new("Use #signed_lt or #unsigned_lt for Bitvec, not <")
    end

    def <=(other)
      raise Z3::Exception.new("Use #signed_le or #unsigned_le for Bitvec, not <=")
    end

    def signed_lt(other)
      BoolExpr.new API.mk_bvslt(self, sort[other])
    end

    def signed_le(other)
      BoolExpr.new API.mk_bvsle(self, sort[other])
    end

    def signed_gt(other)
      BoolExpr.new API.mk_bvsgt(self, sort[other])
    end

    def signed_ge(other)
      BoolExpr.new API.mk_bvsge(self, sort[other])
    end

    def unsigned_lt(other)
      BoolExpr.new API.mk_bvult(self, sort[other])
    end

    def unsigned_le(other)
      BoolExpr.new API.mk_bvule(self, sort[other])
    end

    def unsigned_gt(other)
      BoolExpr.new API.mk_bvugt(self, sort[other])
    end

    def unsigned_ge(other)
      BoolExpr.new API.mk_bvuge(self, sort[other])
    end

    def add_no_overflow?(other)
      raise Z3::Exception.new("Use #signed_add_no_overflow? or #unsigned_add_no_overflow? for Bitvec, not #add_no_overflow?")
    end

    def signed_add_no_overflow?(other)
      BoolExpr.new API.mk_bvadd_no_overflow(self, sort[other], true)
    end

    def unsigned_add_no_overflow?(other)
      BoolExpr.new API.mk_bvadd_no_overflow(self, sort[other], false)
    end

    def add_no_underflow?(other)
      BoolExpr.new API.mk_bvadd_no_underflow(self, sort[other])
    end

    def signed_add_no_underflow?(other)
      BoolExpr.new API.mk_bvadd_no_underflow(self, sort[other])
    end

    def unsigned_add_no_underflow?(other)
      raise Z3::Exception.new("Unsigned + cannot underflow")
    end

    # Subtraction is addition's mirror image: only signed can overflow, and both
    # signs can underflow - so which of these takes a sign is the other way round
    def sub_no_overflow?(other)
      BoolExpr.new API.mk_bvsub_no_overflow(self, sort[other])
    end

    def signed_sub_no_overflow?(other)
      BoolExpr.new API.mk_bvsub_no_overflow(self, sort[other])
    end

    def unsigned_sub_no_overflow?(other)
      raise Z3::Exception.new("Unsigned - cannot overflow")
    end

    def sub_no_underflow?(other)
      raise Z3::Exception.new("Use #signed_sub_no_underflow? or #unsigned_sub_no_underflow? for Bitvec, not #sub_no_underflow?")
    end

    def signed_sub_no_underflow?(other)
      BoolExpr.new API.mk_bvsub_no_underflow(self, sort[other], true)
    end

    def unsigned_sub_no_underflow?(other)
      BoolExpr.new API.mk_bvsub_no_underflow(self, sort[other], false)
    end

    def unsigned_neg_no_overflow?
      raise Z3::Exception.new("There is no unsigned negation")
    end

    def signed_neg_no_overflow?
      BoolExpr.new API.mk_bvneg_no_overflow(self)
    end

    def neg_no_overflow?
      BoolExpr.new API.mk_bvneg_no_overflow(self)
    end

    def mul_no_overflow?(other)
      raise Z3::Exception.new("Use #signed_mul_no_overflow? or #unsigned_mul_no_overflow? for Bitvec, not #mul_no_overflow?")
    end

    def signed_mul_no_overflow?(other)
      BoolExpr.new API.mk_bvmul_no_overflow(self, sort[other], true)
    end

    def unsigned_mul_no_overflow?(other)
      BoolExpr.new API.mk_bvmul_no_overflow(self, sort[other], false)
    end

    def mul_no_underflow?(other)
      BoolExpr.new API.mk_bvmul_no_underflow(self, sort[other])
    end

    def signed_mul_no_underflow?(other)
      BoolExpr.new API.mk_bvmul_no_underflow(self, sort[other])
    end

    def unsigned_mul_no_underflow?(other)
      raise Z3::Exception.new("Unsigned * cannot underflow")
    end

    def div_no_overflow?(other)
      BoolExpr.new API.mk_bvsdiv_no_overflow(self, sort[other])
    end

    def signed_div_no_overflow?(other)
      BoolExpr.new API.mk_bvsdiv_no_overflow(self, sort[other])
    end

    def unsigned_div_no_overflow?(other)
      raise Z3::Exception.new("Unsigned / cannot overflow")
    end

    def >>(other)
      raise Z3::Exception.new("Use #signed_rshift or #unsigned_rshift for Bitvec, not >>")
    end

    def signed_rshift(other)
      BitvecExpr.new API.mk_bvashr(self, sort[other]), sort
    end

    def unsigned_rshift(other)
      BitvecExpr.new API.mk_bvlshr(self, sort[other]), sort
    end

    def rshift(other)
      raise Z3::Exception.new("Use #signed_rshift or #unsigned_rshift for Bitvec, not #rshift")
    end

    def <<(other)
      BitvecExpr.new API.mk_bvshl(self, sort[other]), sort
    end

    def signed_lshift(other)
      BitvecExpr.new API.mk_bvshl(self, sort[other]), sort
    end

    def unsigned_lshift(other)
      BitvecExpr.new API.mk_bvshl(self, sort[other]), sort
    end

    def lshift(other)
      BitvecExpr.new API.mk_bvshl(self, sort[other]), sort
    end

    # An Int rotates by a fixed amount, a Bitvec of the same size by whatever it turns
    # out to be - Z3 has a separate operation for each, and the fixed one gives the
    # solver much more to work with, so a literal never goes through the other
    def rotate_left(n : Int)
      raise Z3::Exception.new("Rotation amount must be a nonnegative Integer") unless n >= 0
      BitvecExpr.new API.mk_rotate_left(n.to_u32, self), sort
    end

    def rotate_left(n : BitvecExpr)
      BitvecExpr.new API.mk_ext_rotate_left(self, sort[n]), sort
    end

    def rotate_right(n : Int)
      raise Z3::Exception.new("Rotation amount must be a nonnegative Integer") unless n >= 0
      BitvecExpr.new API.mk_rotate_right(n.to_u32, self), sort
    end

    def rotate_right(n : BitvecExpr)
      BitvecExpr.new API.mk_ext_rotate_right(self, sort[n]), sort
    end

    def zero_ext(n : Int)
      raise Z3::Exception.new("Extension size must be a nonnegative Integer") unless n >= 0
      BitvecExpr.new API.mk_zero_ext(n.to_u32, self), BitvecSort.new(size + n.to_u32)
    end

    def sign_ext(n : Int)
      raise Z3::Exception.new("Extension size must be a nonnegative Integer") unless n >= 0
      BitvecExpr.new API.mk_sign_ext(n.to_u32, self), BitvecSort.new(size + n.to_u32)
    end

    def repeat(n : Int)
      raise Z3::Exception.new("Repeat count must be a positive Integer") unless n >= 1
      BitvecExpr.new API.mk_repeat(n.to_u32, self), BitvecSort.new(size * n.to_u32)
    end

    # A single bit, as a Bool. Deliberately not #[] - that would read like #extract
    # with a one-bit range, which gives a Bitvec(1) instead
    def bit(index : Int)
      raise Z3::Exception.new("Trying to take a bit out of range") unless index >= 0 && index < size
      BoolExpr.new API.mk_bit2bool(index.to_u32, self)
    end

    # Z3 answers these with a one-bit Bitvec rather than a Bool, which is what
    # #all_bits_set? and #any_bits_set? are for
    def redand
      BitvecExpr.new API.mk_bvredand(self), BitvecSort.new(1u32)
    end

    def redor
      BitvecExpr.new API.mk_bvredor(self), BitvecSort.new(1u32)
    end

    def all_bits_set?
      redand == 1
    end

    def any_bits_set?
      redor == 1
    end

    def zero?
      self == 0
    end

    def nonzero?
      self != 0
    end

    # Inherently signed
    def positive?
      signed_gt 0
    end

    # Inherently signed
    def negative?
      signed_lt 0
    end

    # Inherently signed
    def abs
      negative?.ite(-self, self)
    end

    def -
      BitvecExpr.new API.mk_bvneg(self), sort
    end

    def ~
      BitvecExpr.new API.mk_bvnot(self), sort
    end

    def extract(hi : Int, lo : Int)
      raise Z3::Exception.new("Trying to extract bits out of range") unless size > hi && hi >= lo && lo >= 0
      BitvecExpr.new API.mk_extract(hi.to_u32, lo.to_u32, self), BitvecSort.new(hi.to_u32 - lo.to_u32 + 1)
    end

    def concat(other : BitvecExpr)
      BitvecExpr.new API.mk_concat(self, other), BitvecSort.new(size + other.size)
    end

    def simplify
      BitvecExpr.new API.simplify(self), sort
    end

    def const?
      API.get_ast_kind(self) == LibZ3::AstKind::Numeral
    end

    def to_s(io)
      if const?
        io << API.get_numeral_string(self)
      else
        # We should use our own printer, these are just S-Expressions
        io << API.ast_to_string(self)
      end
    end

    # #to_i and friends build a Z3 Int expression out of this one. #value and friends
    # leave Z3 and give back a Crystal Integer, which only works on a literal. Both
    # come in pairs because a Bitvec carries no sign of its own - the same eight bits
    # are 200 read one way and -56 read the other.
    def to_i
      raise Z3::Exception.new("Use #signed_to_i or #unsigned_to_i for Bitvec, not #to_i")
    end

    def signed_to_i
      IntExpr.new API.mk_bv2int(self, true)
    end

    def unsigned_to_i
      IntExpr.new API.mk_bv2int(self, false)
    end

    def value
      raise Z3::Exception.new("Use #signed_value or #unsigned_value for Bitvec, not #value")
    end

    def signed_value : BigInt
      v = unsigned_value
      v >= (BigInt.new(1) << (size.to_i - 1)) ? v - (BigInt.new(1) << size.to_i) : v
    end

    # Z3 prints a Bitvec numeral as its unsigned value, so this is the one it gives us
    def unsigned_value : BigInt
      return BigInt.new(API.get_numeral_string(self)) if const?
      s = simplify
      return BigInt.new(API.get_numeral_string(s)) if s.const?
      raise Z3::Exception.new("Can't convert expression #{self} into Integer")
    end

    def inspect(io)
      io << "BitvecExpr(#{size})<"
      to_s(io)
      io << ">"
    end

    def to_unsafe
      @expr
    end
  end
end
