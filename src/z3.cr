require "big"
require "./z3/*"

module Z3
  VERSION = "0.1.0"

  def Z3.distinct(args : Array(IntExpr))
    BoolExpr.new API.mk_distinct(args)
  end

  def Z3.distinct(args : Array(RealExpr))
    BoolExpr.new API.mk_distinct(args)
  end

  def Z3.distinct(args : Array(BoolExpr))
    BoolExpr.new API.mk_distinct(args)
  end

  def Z3.distinct(args : Array(BitvecExpr))
    BoolExpr.new API.mk_distinct(args)
  end

  def Z3.distinct(args : Array(CharExpr))
    BoolExpr.new API.mk_distinct(args)
  end

  def Z3.int(name : String)
    Z3::IntSort.var(name)
  end

  def Z3.bool(name : String)
    Z3::BoolSort.var(name)
  end

  def Z3.real(name : String)
    Z3::RealSort.var(name)
  end

  def Z3.bitvec(name : String, size : UInt32)
    Z3::BitvecSort.new(size).var(name)
  end

  def Z3.char(name : String)
    Z3::CharSort.var(name)
  end

  def Z3.version
    LibZ3.get_version(out v0, out v1, out v2, out v3)
    [v0, v1, v2, v3].join(".")
  end

  def Z3.add(args : Array(IntExpr | Int32))
    if args.empty?
      IntSort[0]
    else
      IntExpr.new API.mk_add(args.map{|a| IntSort[a]})
    end
  end

  def Z3.mul(args : Array(IntExpr | Int32))
    if args.empty?
      IntSort[1]
    else
      IntExpr.new API.mk_mul(args.map{|a| IntSort[a]})
    end
  end

  def Z3.add(args : Array(RealExpr))
    if args.empty?
      RealSort[0]
    else
      RealExpr.new API.mk_add(args)
    end
  end

  def Z3.mul(args : Array(RealExpr))
    if args.empty?
      RealSort[1]
    else
      RealExpr.new API.mk_mul(args)
    end
  end

  def Z3.and(args : Array(BoolExpr | Bool))
    BoolExpr.new API.mk_and(args.map{|a| BoolSort[a]})
  end

  def Z3.or(args : Array(BoolExpr | Bool))
    BoolExpr.new API.mk_or(args.map{|a| BoolSort[a]})
  end

  # Native cardinality constraint: at most k of the given Bool exprs are true.
  # An `{expr, weight}` pair list weighs them instead, so
  # `Z3.at_most([{a, 3}, {b, 2}], 4)` allows either one but not both.
  #
  # Ruby's z3 spells the weighted form as an `expr => weight` Hash. Exprs can't be
  # Hash keys here - see the Limitations section of the README.
  def Z3.at_most(args : Array(BoolExpr), k : Int32)
    BoolExpr.new API.mk_atmost(cardinality_args(args), cardinality_bound(k))
  end

  def Z3.at_most(args : Array(Tuple(BoolExpr, Int32)), k : Int32)
    exprs, weights = pseudo_boolean_args(args)
    BoolExpr.new API.mk_pble(exprs, weights, k)
  end

  # Native cardinality constraint: at least k of the given Bool exprs are true,
  # or at least k units of weight when given `{expr, weight}` pairs
  def Z3.at_least(args : Array(BoolExpr), k : Int32)
    BoolExpr.new API.mk_atleast(cardinality_args(args), cardinality_bound(k))
  end

  def Z3.at_least(args : Array(Tuple(BoolExpr, Int32)), k : Int32)
    exprs, weights = pseudo_boolean_args(args)
    BoolExpr.new API.mk_pbge(exprs, weights, k)
  end

  # Native cardinality constraint: exactly k of the given Bool exprs are true,
  # or exactly k units of weight when given `{expr, weight}` pairs
  def Z3.exactly(args : Array(BoolExpr), k : Int32)
    exprs = cardinality_args(args)
    cardinality_bound(k)
    # Z3 has no unweighted pbeq, so this is the one which has to make up the 1s.
    # It normalises all-1 weights back into the unweighted term anyway, so
    # `exactly([a, b], 1)` and `exactly([{a, 1}, {b, 1}], 1)` are the same AST.
    BoolExpr.new API.mk_pbeq(exprs, [1] * exprs.size, k)
  end

  def Z3.exactly(args : Array(Tuple(BoolExpr, Int32)), k : Int32)
    exprs, weights = pseudo_boolean_args(args)
    BoolExpr.new API.mk_pbeq(exprs, weights, k)
  end

  private def self.cardinality_args(args : Array(BoolExpr))
    raise Z3::Exception.new("Cardinality constraint requires at least one argument") if args.empty?
    args
  end

  # A count is between 0 and n, so a negative bound on one is a mistake. A weighted
  # total isn't - weights can be negative - so the same bound is allowed there.
  private def self.cardinality_bound(k : Int32)
    raise Z3::Exception.new("Cardinality bound must be a non-negative Integer") if k < 0
    k.to_u32
  end

  private def self.pseudo_boolean_args(args : Array(Tuple(BoolExpr, Int32)))
    raise Z3::Exception.new("Cardinality constraint requires at least one argument") if args.empty?
    {args.map(&.[0]), args.map(&.[1])}
  end

  # Bitvec has no n-ary and/or in Z3, so reduce with the bitwise operators.
  def Z3.and(args : Array(BitvecExpr))
    args.reduce { |a, b| a & b }
  end

  def Z3.or(args : Array(BitvecExpr))
    args.reduce { |a, b| a | b }
  end
end
