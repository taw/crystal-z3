# Ruby gets `2 + expr` from Integer#coerce. Crystal has no such protocol, so every
# reversed operator has to be spelled out - one per Crystal type which can be cast
# into the sort on the other side.
abstract struct Int
  def +(other : Z3::IntExpr)
    Z3::IntSort[self] + other
  end

  def *(other : Z3::IntExpr)
    Z3::IntSort[self] * other
  end

  def /(other : Z3::IntExpr)
    Z3::IntSort[self] / other
  end

  def -(other : Z3::IntExpr)
    Z3::IntSort[self] - other
  end

  def ==(other : Z3::IntExpr)
    Z3::IntSort[self] == other
  end

  def !=(other : Z3::IntExpr)
    Z3::IntSort[self] != other
  end

  def >=(other : Z3::IntExpr)
    Z3::IntSort[self] >= other
  end

  def >(other : Z3::IntExpr)
    Z3::IntSort[self] > other
  end

  def <=(other : Z3::IntExpr)
    Z3::IntSort[self] <= other
  end

  def <(other : Z3::IntExpr)
    Z3::IntSort[self] < other
  end

  def +(other : Z3::RealExpr)
    Z3::RealSort[self] + other
  end

  def *(other : Z3::RealExpr)
    Z3::RealSort[self] * other
  end

  def /(other : Z3::RealExpr)
    Z3::RealSort[self] / other
  end

  def -(other : Z3::RealExpr)
    Z3::RealSort[self] - other
  end

  def ==(other : Z3::RealExpr)
    Z3::RealSort[self] == other
  end

  def !=(other : Z3::RealExpr)
    Z3::RealSort[self] != other
  end

  def >=(other : Z3::RealExpr)
    Z3::RealSort[self] >= other
  end

  def >(other : Z3::RealExpr)
    Z3::RealSort[self] > other
  end

  def <=(other : Z3::RealExpr)
    Z3::RealSort[self] <= other
  end

  def <(other : Z3::RealExpr)
    Z3::RealSort[self] < other
  end

  # A Bitvec literal takes its size from the expression it's paired with, and the
  # comparisons are all sign-dependent, so they're #signed_lt and friends only
  def +(other : Z3::BitvecExpr)
    other.sort[self] + other
  end

  def *(other : Z3::BitvecExpr)
    other.sort[self] * other
  end

  def -(other : Z3::BitvecExpr)
    other.sort[self] - other
  end

  def ==(other : Z3::BitvecExpr)
    other.sort[self] == other
  end

  def !=(other : Z3::BitvecExpr)
    other.sort[self] != other
  end

  def &(other : Z3::BitvecExpr)
    other.sort[self] & other
  end

  def |(other : Z3::BitvecExpr)
    other.sort[self] | other
  end

  def ^(other : Z3::BitvecExpr)
    other.sort[self] ^ other
  end
end

struct Float64
  def +(other : Z3::RealExpr)
    Z3::RealSort[self] + other
  end

  def *(other : Z3::RealExpr)
    Z3::RealSort[self] * other
  end

  def /(other : Z3::RealExpr)
    Z3::RealSort[self] / other
  end

  def -(other : Z3::RealExpr)
    Z3::RealSort[self] - other
  end

  def ==(other : Z3::RealExpr)
    Z3::RealSort[self] == other
  end

  def !=(other : Z3::RealExpr)
    Z3::RealSort[self] != other
  end

  def >=(other : Z3::RealExpr)
    Z3::RealSort[self] >= other
  end

  def >(other : Z3::RealExpr)
    Z3::RealSort[self] > other
  end

  def <=(other : Z3::RealExpr)
    Z3::RealSort[self] <= other
  end

  def <(other : Z3::RealExpr)
    Z3::RealSort[self] < other
  end
end

struct BigRational
  def +(other : Z3::RealExpr)
    Z3::RealSort[self] + other
  end

  def *(other : Z3::RealExpr)
    Z3::RealSort[self] * other
  end

  def /(other : Z3::RealExpr)
    Z3::RealSort[self] / other
  end

  def -(other : Z3::RealExpr)
    Z3::RealSort[self] - other
  end

  def ==(other : Z3::RealExpr)
    Z3::RealSort[self] == other
  end

  def !=(other : Z3::RealExpr)
    Z3::RealSort[self] != other
  end

  def >=(other : Z3::RealExpr)
    Z3::RealSort[self] >= other
  end

  def >(other : Z3::RealExpr)
    Z3::RealSort[self] > other
  end

  def <=(other : Z3::RealExpr)
    Z3::RealSort[self] <= other
  end

  def <(other : Z3::RealExpr)
    Z3::RealSort[self] < other
  end
end

struct Char
  def ==(other : Z3::CharExpr)
    Z3::CharSort[self] == other
  end

  def !=(other : Z3::CharExpr)
    Z3::CharSort[self] != other
  end

  def >=(other : Z3::CharExpr)
    Z3::CharSort[self] >= other
  end

  def >(other : Z3::CharExpr)
    Z3::CharSort[self] > other
  end

  def <=(other : Z3::CharExpr)
    Z3::CharSort[self] <= other
  end

  def <(other : Z3::CharExpr)
    Z3::CharSort[self] < other
  end
end
