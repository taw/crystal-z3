#!/usr/bin/env crystal

require "../src/z3"

# http://faculty.uml.edu/jpropp/srat-Q.txt
#
# SELF-REFERENTIAL APTITUDE TEST, by Jim Propp (jimpropp at gmaildotcom)
#
# The solution to the following puzzle is unique; in some cases the
# knowledge that the solution is unique may actually give you a short-cut
# to finding the answer to a particular question.
class SelfRefPuzzleSolver
  ANSWERS = " ABCDE"

  getter q : Hash(Int32, Z3::IntExpr)
  getter a : Hash(Int32, Hash(Int32, Z3::IntExpr))
  getter a_answers : Z3::IntExpr
  getter b_answers : Z3::IntExpr
  getter c_answers : Z3::IntExpr
  getter d_answers : Z3::IntExpr
  getter e_answers : Z3::IntExpr
  getter cons_answers : Z3::IntExpr

  def initialize
    @solver = Z3::Solver.new
    @q = {} of Int32 => Z3::IntExpr
    @a = {} of Int32 => Hash(Int32, Z3::IntExpr)
    (1..20).each do |i|
      @q[i] = Z3.int("q#{i}")
      assert @q[i] >= 1
      assert @q[i] <= 5
      answers = {} of Int32 => Z3::IntExpr
      (1..5).each do |j|
        answers[j] = Z3.int("a#{i},#{ANSWERS[j]}")
        assert (answers[j] == 0) == (@q[i] != j)
        assert (answers[j] == 1) == (@q[i] == j)
      end
      @a[i] = answers
    end

    @a_answers = Z3.add((1..20).map { |i| @a[i][1] })
    @b_answers = Z3.add((1..20).map { |i| @a[i][2] })
    @c_answers = Z3.add((1..20).map { |i| @a[i][3] })
    @d_answers = Z3.add((1..20).map { |i| @a[i][4] })
    @e_answers = Z3.add((1..20).map { |i| @a[i][5] })
    @cons_answers = @b_answers + @c_answers + @d_answers
  end

  def assert(ast)
    @solver.assert(ast)
  end

  def cons_in(*ary : Int32)
    Z3.or(ary.to_a.map { |i| cons_answers == i })
  end

  def call
    # Question 1
    assert (q[1] == 1) == (q[1] == 2)
    assert (q[1] == 2) == Z3.and([q[1] != 2, q[2] == 2])
    assert (q[1] == 3) == Z3.and([q[1] != 2, q[2] != 2, q[3] == 2])
    assert (q[1] == 4) == Z3.and([q[1] != 2, q[2] != 2, q[3] != 2, q[4] == 2])
    assert (q[1] == 5) == Z3.and([q[1] != 2, q[2] != 2, q[3] != 2, q[4] != 2, q[5] == 2])

    # Question 2
    assert q[1] != q[2]
    assert q[2] != q[3]
    assert q[3] != q[4]
    assert q[4] != q[5]
    assert q[5] != q[6]
    assert (q[6] == q[7]) == (q[2] == 1)
    assert (q[7] == q[8]) == (q[2] == 2)
    assert (q[8] == q[9]) == (q[2] == 3)
    assert (q[9] == q[10]) == (q[2] == 4)
    assert (q[10] == q[11]) == (q[2] == 5)
    assert q[11] != q[12]
    assert q[12] != q[13]
    assert q[13] != q[14]
    assert q[14] != q[15]
    assert q[15] != q[16]
    assert q[16] != q[17]
    assert q[17] != q[18]
    assert q[18] != q[19]
    assert q[19] != q[20]

    # Question 3
    assert (e_answers == 0) == (q[3] == 1)
    assert (e_answers == 1) == (q[3] == 2)
    assert (e_answers == 2) == (q[3] == 3)
    assert (e_answers == 3) == (q[3] == 4)
    assert (e_answers == 4) == (q[3] == 5)

    # Question 4
    assert (a_answers == 4) == (q[4] == 1)
    assert (a_answers == 5) == (q[4] == 2)
    assert (a_answers == 6) == (q[4] == 3)
    assert (a_answers == 7) == (q[4] == 4)
    assert (a_answers == 8) == (q[4] == 5)

    # Question 5
    assert (q[5] == 1).implies(q[5] == q[1])
    assert (q[5] == 2).implies(q[5] == q[2])
    assert (q[5] == 3).implies(q[5] == q[3])
    assert (q[5] == 4).implies(q[5] == q[4])
    assert (q[5] == 5).implies(q[5] == q[5])

    # Question 6
    assert (q[17] == 3) == (q[6] == 1)
    assert (q[17] == 4) == (q[6] == 2)
    assert (q[17] == 5) == (q[6] == 3)
    assert Z3.or([q[17] == 1, q[17] == 2]) == (q[6] == 4)
    assert q[6] != 5

    # Question 7
    assert Z3.or([q[7] - q[8] == 4, q[8] - q[7] == 4]) == (q[7] == 1)
    assert Z3.or([q[7] - q[8] == 3, q[8] - q[7] == 3]) == (q[7] == 2)
    assert Z3.or([q[7] - q[8] == 2, q[8] - q[7] == 2]) == (q[7] == 3)
    assert Z3.or([q[7] - q[8] == 1, q[8] - q[7] == 1]) == (q[7] == 4)
    assert Z3.or([q[7] - q[8] == 0, q[8] - q[7] == 0]) == (q[7] == 5)

    # Question 8
    assert (a_answers + e_answers == 4) == (q[8] == 1)
    assert (a_answers + e_answers == 5) == (q[8] == 2)
    assert (a_answers + e_answers == 6) == (q[8] == 3)
    assert (a_answers + e_answers == 7) == (q[8] == 4)
    assert (a_answers + e_answers == 8) == (q[8] == 5)

    # Question 9
    assert (q[10] == q[9]) == (q[9] == 1)
    assert Z3.and([q[10] != q[9], q[11] == q[9]]) == (q[9] == 2)
    assert Z3.and([q[10] != q[9], q[11] != q[9], q[12] == q[9]]) == (q[9] == 3)
    assert Z3.and([q[10] != q[9], q[11] != q[9], q[12] != q[9], q[13] == q[9]]) == (q[9] == 4)
    assert Z3.and([q[10] != q[9], q[11] != q[9], q[12] != q[9], q[13] != q[9], q[14] == q[9]]) == (q[9] == 5)

    # Question 10
    assert (q[16] == 4) == (q[10] == 1)
    assert (q[16] == 1) == (q[10] == 2)
    assert (q[16] == 5) == (q[10] == 3)
    assert (q[16] == 2) == (q[10] == 4)
    assert (q[16] == 3) == (q[10] == 5)

    # Question 11
    prec_b_answers = Z3.add((1..10).map { |i| @a[i][2] })
    assert (prec_b_answers == 0) == (q[11] == 1)
    assert (prec_b_answers == 1) == (q[11] == 2)
    assert (prec_b_answers == 2) == (q[11] == 3)
    assert (prec_b_answers == 3) == (q[11] == 4)
    assert (prec_b_answers == 4) == (q[11] == 5)

    # Question 12
    assert (q[12] == 1).implies(cons_in(2, 4, 6, 8, 10, 12, 14, 16, 18, 20))
    assert (q[12] == 2).implies(cons_in(1, 3, 5, 7, 9, 11, 13, 15, 17, 19))
    assert (q[12] == 3).implies(cons_in(1, 4, 9, 16))
    assert (q[12] == 4).implies(cons_in(2, 3, 5, 7, 11, 13, 17, 19))
    assert (q[12] == 5).implies(cons_in(5, 10, 15, 20))

    # Question 13
    assert q[1] != 1
    assert q[3] != 1
    assert q[5] != 1
    assert q[7] != 1
    assert (q[9] == 1) == (q[13] == 1)
    assert (q[11] == 1) == (q[13] == 2)
    assert (q[13] == 1) == (q[13] == 3)
    assert (q[15] == 1) == (q[13] == 4)
    assert (q[17] == 1) == (q[13] == 5)
    assert q[19] != 1

    # Question 14
    assert (d_answers == 6) == (q[4] == 1)
    assert (d_answers == 7) == (q[4] == 2)
    assert (d_answers == 8) == (q[4] == 3)
    assert (d_answers == 9) == (q[4] == 4)
    assert (d_answers == 10) == (q[4] == 5)

    # Question 15
    assert q[15] == q[12]

    # Question 16
    assert (q[10] == 4) == (q[16] == 1)
    assert (q[10] == 3) == (q[16] == 2)
    assert (q[10] == 2) == (q[16] == 3)
    assert (q[10] == 1) == (q[16] == 4)
    assert (q[10] == 5) == (q[16] == 5)

    # Question 17
    assert (q[6] == 3) == (q[17] == 1)
    assert (q[6] == 4) == (q[17] == 2)
    assert (q[6] == 5) == (q[17] == 3)
    assert Z3.and([q[6] != 3, q[6] != 4, q[6] != 5]) == (q[17] == 4)
    assert q[17] != 5

    # Question 18
    assert (a_answers == b_answers) == (q[18] == 1)
    assert (a_answers == c_answers) == (q[18] == 2)
    assert (a_answers == d_answers) == (q[18] == 3)
    assert (a_answers == e_answers) == (q[18] == 4)
    assert Z3.and([
      a_answers != b_answers,
      a_answers != c_answers,
      a_answers != d_answers,
      a_answers != e_answers,
    ]) == (q[18] == 5)

    # Question 19
    assert q[19] == q[19]

    # Question 20
    assert q[20] == 5

    # Print solutions
    if @solver.satisfiable?
      model = @solver.model
      (1..20).each do |i|
        a = model[q[i]].to_i
        puts "Q%2d: %s" % [i, ANSWERS[a]]
      end
    else
      puts "failed to solve"
    end
  end
end

SelfRefPuzzleSolver.new.call
