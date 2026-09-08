#!/usr/bin/env crystal

require "../src/z3"

def check_if_true_is_true
  a = Z3::BoolSort[true]
  b = Z3::BoolSort[true]
  solver = Z3::Solver.new
  puts "Checking if true == true"
  solver.prove!(a == b)
end

def check_if_true_is_false
  a = Z3::BoolSort[true]
  b = Z3::BoolSort[false]
  solver = Z3::Solver.new
  puts "Checking if true == false"
  solver.prove!(a == b)
end

# We prove it by checking that negation is unsatisfiable
def check_de_morgan_law_1
  a = Z3.bool("a")
  b = Z3.bool("b")
  solver = Z3::Solver.new
  puts "Proving ~(a & b) == (~a | ~b)"
  solver.prove!(~(a & b) == (~a | ~b))
end

def check_de_morgan_law_2
  a = Z3.bool("a")
  b = Z3.bool("b")
  solver = Z3::Solver.new
  puts "Proving ~(a | b) == (~a & ~b)"
  solver.prove!(~(a | b) == (~a & ~b))
end

check_if_true_is_true
check_if_true_is_false
check_de_morgan_law_1
check_de_morgan_law_2
