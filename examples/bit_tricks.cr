#!/usr/bin/env crystal

require "../src/z3"

# Based on https://graphics.stanford.edu/~seander/bithacks.html

def c_boolean(expr)
  one = Z3::BitvecSort.new(32)[1]
  zero = Z3::BitvecSort.new(32)[0]
  expr.ite(one, zero)
end

# sign = v >> (sizeof(int) * CHAR_BIT - 1);
def validate_sign_by_shift!
  solver = Z3::Solver.new
  v = Z3.bitvec("v", 32)
  s = v.signed_rshift(31)
  puts "Validating sign trick:"
  solver.prove! (v.signed_lt(0) & (s == -1)) | (v.signed_ge(0) & (s == 0))
end

# int x, y;               // input values to compare signs
# bool f = ((x ^ y) < 0); // true iff x and y have opposite signs
def validate_opposite_sign_by_xor!
  solver = Z3::Solver.new
  x = Z3.bitvec("x", 32)
  y = Z3.bitvec("y", 32)
  f = (x ^ y).signed_lt(0)

  puts "Validating sign trick:"
  solver.prove!(
    Z3.or([
      Z3.and([x.signed_ge(0), y.signed_ge(0), f == false]),
      Z3.and([x.signed_lt(0), y.signed_lt(0), f == false]),
      Z3.and([x.signed_ge(0), y.signed_lt(0), f == true]),
      Z3.and([x.signed_lt(0), y.signed_ge(0), f == true]),
    ])
  )
end

# int v;           // we want to find the absolute value of v
# unsigned int r;  // the result goes here
# int const mask = v >> sizeof(int) * CHAR_BIT - 1;
# r = (v + mask) ^ mask;
def validate_abs_without_branching_1!
  solver = Z3::Solver.new
  v = Z3.bitvec("v", 32)
  mask = v.signed_rshift(31)
  r = (v + mask) ^ mask
  puts "Validating abs without branching, version 1"
  solver.prove!(
    v.signed_ge(0).ite(r == v, r == -v)
  )
end

# int v;           // we want to find the absolute value of v
# unsigned int r;  // the result goes here
# int const mask = v >> sizeof(int) * CHAR_BIT - 1;
# r = (v ^ mask) - mask;
def validate_abs_without_branching_2!
  solver = Z3::Solver.new
  v = Z3.bitvec("v", 32)
  mask = v.signed_rshift(31)
  r = (v ^ mask) - mask
  puts "Validating abs without branching, version 2"
  solver.prove!(
    v.signed_ge(0).ite(r == v, r == -v)
  )
end

# int x;  // we want to find the minimum of x and y
# int y;
# int r;  // the result goes here
# r = y ^ ((x ^ y) & -(x < y)); // min(x, y)
def validate_min_without_branching!
  solver = Z3::Solver.new
  x = Z3.bitvec("x", 32)
  y = Z3.bitvec("y", 32)
  r = y ^ ((x ^ y) & -c_boolean(x.signed_lt(y)))
  puts "Validating min without branching"
  solver.prove!(
    x.signed_le(y).ite(r == x, r == y)
  )
end

# int x;  // we want to find the minimum of x and y
# int y;
# int r;  // the result goes here
# r = x ^ ((x ^ y) & -(x < y)); // max(x, y)
def validate_max_without_branching!
  solver = Z3::Solver.new
  x = Z3.bitvec("x", 32)
  y = Z3.bitvec("y", 32)
  r = x ^ ((x ^ y) & -c_boolean(x.signed_lt(y)))
  puts "Validating max without branching"
  solver.prove!(
    x.signed_ge(y).ite(r == x, r == y)
  )
end

# unsigned int v; // we want to see if v is a power of 2
# bool f;         // the result goes here
#
# f = (v & (v - 1)) == 0;
def validate_is_power_of_two!
  solver = Z3::Solver.new
  v = Z3.bitvec("v", 32)
  f = (v & (v - 1)) == 0

  powers_of_two = (0..31).map { |i| 2i64 ** i }
  naive_is_f_power_of_two = Z3.or(powers_of_two.map { |k| v == k })

  puts "Validating is power of two"
  solver.prove!(
    Z3.or([
      f == naive_is_f_power_of_two,
      v == 0,
    ])
  )
end

validate_sign_by_shift!
validate_opposite_sign_by_xor!
validate_abs_without_branching_1!
validate_abs_without_branching_2!
validate_min_without_branching!
validate_max_without_branching!
validate_is_power_of_two!
