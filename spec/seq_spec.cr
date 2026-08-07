require "./spec_helper"

describe Z3::SeqExpr do
  int_seq = Z3::SeqSort.new(Z3::IntSort)
  a = Z3.seq("a", Z3::IntSort)
  b = Z3.seq("b", Z3::IntSort)
  i = Z3.int("i")
  x = Z3.bool("x")

  # Z3 has no String sort of its own, a String is just a Seq(Char)
  it "SeqSort.new(CharSort) is StringSort" do
    Z3::SeqSort.new(Z3::CharSort).should eq(Z3::StringSort)
    Z3::SeqSort.new(Z3::CharSort).var("s").should be_a(Z3::StringExpr)
    Z3.seq("s", Z3::CharSort).should be_a(Z3::StringExpr)
    Z3::SeqSort.new(Z3::CharSort)["abc"].value.should eq("abc")
  end

  it "SeqSort.new" do
    int_seq.element_sort.should eq(Z3::IntSort)
    int_seq.to_s.should eq("Seq(Int)")
    Z3::SeqSort.new(Z3::BitvecSort.new(8u32)).to_s.should eq("Seq(Bitvec(8))")
    Z3::SeqSort.new(Z3::SeqSort.new(Z3::IntSort)).to_s.should eq("Seq(Seq(Int))")
    Z3::SeqSort.new(Z3::StringSort).to_s.should eq("Seq(String)")
    # Z3 hash-conses its sorts, so two Seq(Int)s are one sort
    int_seq.should eq(Z3::SeqSort.new(Z3::IntSort))
    int_seq.should_not eq(Z3::SeqSort.new(Z3::RealSort))
  end

  # Z3 has no sequence literals, so a value is a concatenation of one element
  # sequences - and none of that shows up here
  it "SeqSort[]" do
    int_seq[[1, 2, 3]].elements.map(&.as(Z3::IntExpr).to_i).should eq([1, 2, 3])
    int_seq[[42]].elements.map(&.as(Z3::IntExpr).to_i).should eq([42])
    int_seq[[] of Int32].elements.should be_empty
    int_seq.empty.elements.should be_empty
    int_seq.unit(7).elements.map(&.as(Z3::IntExpr).to_i).should eq([7])
    Z3::SeqSort.new(Z3::BoolSort)[[true, false]].elements.map(&.as(Z3::BoolExpr).value).should eq([true, false])
  end

  it "SeqSort[] with elements of the wrong sort" do
    expect_raises(Z3::Exception) { int_seq[["a"]] }
    expect_raises(Z3::Exception) { int_seq.unit("a") }
  end

  it "SeqSort.var" do
    [a == [1, 2]].should have_solution(a == [1, 2])
  end

  it "==" do
    [a == [1, 2], b == [1, 2], x == (a == b)].should have_solution(x == true)
    [a == [1, 2], b == [1, 3], x == (a == b)].should have_solution(x == false)
  end

  it "!=" do
    [a == [1, 2], b == [1, 2], x == (a != b)].should have_solution(x == false)
    [a == [1, 2], b == [1, 3], x == (a != b)].should have_solution(x == true)
  end

  it "+" do
    [a == [1, 2], b == [3], a + b == [1, 2, 3]].should have_solution(a == [1, 2])
    (int_seq[[1, 2]] + [3]).elements.map(&.as(Z3::IntExpr).to_i).should eq([1, 2, 3])
  end

  it "*" do
    (int_seq[[1, 2]] * 3).elements.map(&.as(Z3::IntExpr).to_i).should eq([1, 2, 1, 2, 1, 2])
    (int_seq[[1, 2]] * 1).elements.map(&.as(Z3::IntExpr).to_i).should eq([1, 2])
    (int_seq[[1, 2]] * 0).elements.should be_empty
    expect_raises(Z3::Exception) { int_seq[[1, 2]] * -1 }
  end

  it "length" do
    [a == [1, 2, 3], i == a.length].should have_solution(i == 3)
    [a == [1, 2, 3], i == a.size].should have_solution(i == 3)
    [a == [] of Int32, x == a.empty?].should have_solution(x == true)
    [a == [1], x == a.empty?].should have_solution(x == false)
  end

  # An element is an AnyExpr, since a Seq only knows its element sort at runtime
  it "[index]" do
    [a == [1, 2, 3], i == a[1].as(Z3::IntExpr)].should have_solution(i == 2)
    [a == [1, 2, 3], i == a.at(1).as(Z3::IntExpr)].should have_solution(i == 2)
    [a == [1, 2, 3], i == a.first.as(Z3::IntExpr)].should have_solution(i == 1)
    [a == [1, 2, 3], i == a.last.as(Z3::IntExpr)].should have_solution(i == 3)
    int_seq[[1, 2, 3]][1].as(Z3::IntExpr).to_i.should eq(2)
  end

  it "[offset, length]" do
    [a == [1, 2, 3, 4], b == a[1, 2]].should have_solution(b == [2, 3])
    [a == [1, 2, 3, 4], b == a.first(2)].should have_solution(b == [1, 2])
    [a == [1, 2, 3, 4], b == a.last(2)].should have_solution(b == [3, 4])
  end

  it "[range]" do
    [a == [1, 2, 3, 4, 5], b == a[1..3]].should have_solution(b == [2, 3, 4])
    [a == [1, 2, 3, 4, 5], b == a[1...3]].should have_solution(b == [2, 3])
    [a == [1, 2, 3, 4, 5], b == a[2..]].should have_solution(b == [3, 4, 5])
    [a == [1, 2, 3, 4, 5], b == a[..2]].should have_solution(b == [1, 2, 3])
  end

  # Crystal's Array#includes? takes an element, so a bare one is wrapped into a one
  # element sequence, while a Seq or an Array is the subsequence it already is
  it "includes?" do
    [a == [1, 2, 3], x == a.includes?(2)].should have_solution(x == true)
    [a == [1, 2, 3], x == a.includes?(4)].should have_solution(x == false)
    [a == [1, 2, 3], x == a.includes?([2, 3])].should have_solution(x == true)
    [a == [1, 2, 3], x == a.includes?([1, 3])].should have_solution(x == false)
    [a == [1, 2, 3], b == [2, 3], x == a.includes?(b)].should have_solution(x == true)
  end

  it "starts_with? / ends_with?" do
    [a == [1, 2, 3], x == a.starts_with?(1)].should have_solution(x == true)
    [a == [1, 2, 3], x == a.starts_with?([1, 2])].should have_solution(x == true)
    [a == [1, 2, 3], x == a.starts_with?([2])].should have_solution(x == false)
    [a == [1, 2, 3], x == a.ends_with?(3)].should have_solution(x == true)
    [a == [1, 2, 3], x == a.ends_with?([2, 3])].should have_solution(x == true)
  end

  it "index" do
    [a == [1, 2, 1, 2], i == a.index(2)].should have_solution(i == 1)
    [a == [1, 2, 1, 2], i == a.index(2, 2)].should have_solution(i == 3)
    # There is no `nil` for these to be, so a missing element is -1
    [a == [1, 2, 1, 2], i == a.index(9)].should have_solution(i == -1)
  end

  # `seq.last_indexof` answers an out of range value for every sequence of
  # non-characters in Z3 4.16, so there is nothing about the result worth asserting
  it "rindex" do
    a.rindex(2).to_s.should eq("(seq.last_indexof a (seq.unit 2))")
  end

  it "sub / gsub" do
    [a == [1, 2, 1, 2], b == a.sub(2, 9)].should have_solution(b == [1, 9, 1, 2])
    [a == [1, 2, 1, 2], b == a.gsub(2, 9)].should have_solution(b == [1, 9, 1, 9])
    [a == [1, 2, 1, 2], b == a.sub([2, 1], [9])].should have_solution(b == [1, 9, 2])
  end

  it "elements" do
    int_seq[[1, 2, 3]].elements.map(&.as(Z3::IntExpr).value).should eq([1, 2, 3])
    expect_raises(Z3::Exception) { a.elements }
  end

  it "nested sequences" do
    seq_seq = Z3::SeqSort.new(int_seq)
    value = seq_seq[[[1, 2], [3]]]
    value.elements.map { |element| element.as(Z3::SeqExpr).elements.map(&.as(Z3::IntExpr).to_i) }.should eq([[1, 2], [3]])
  end

  it "sort mismatch" do
    real_seq = Z3::SeqSort.new(Z3::RealSort)
    expect_raises(Z3::Exception) { int_seq[real_seq.var("r")] }
    expect_raises(Z3::Exception) { a + real_seq.var("r") }
  end

  it "model" do
    solver = Z3::Solver.new
    solver.assert a.length == 2
    solver.assert a[0].as(Z3::IntExpr) == 5
    solver.assert a[1].as(Z3::IntExpr) == 6
    solver.satisfiable?.should be_true
    value = solver.model[a]
    value.should be_a(Z3::SeqExpr)
    value.elements.map(&.as(Z3::IntExpr).to_i).should eq([5, 6])
  end
end
