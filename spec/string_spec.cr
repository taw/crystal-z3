require "./spec_helper"

describe Z3::StringExpr do
  a = Z3.string("a")
  b = Z3.string("b")
  c = Z3.string("c")
  i = Z3.int("i")
  x = Z3.bool("x")

  it "StringSort[]" do
    Z3::StringSort["abc"].value.should eq("abc")
    Z3::StringSort[""].value.should eq("")
    # A Z3 string is a sequence of code points, so this is characters, not bytes
    Z3::StringSort["ząb 🦀"].value.should eq("ząb 🦀")
    Z3::StringSort["abc"].length.simplify.value.should eq(3)
    Z3::StringSort["ząb 🦀"].length.simplify.value.should eq(5)
  end

  it "StringSort[] outside Z3's alphabet" do
    expect_raises(Z3::Exception) { Z3::StringSort["\u{30000}"] }
  end

  it "StringSort.var" do
    [a == "xyz"].should have_solution(a == "xyz")
  end

  it "==" do
    [a == "xy", b == "xy", x == (a == b)].should have_solution(x == true)
    [a == "xy", b == "xz", x == (a == b)].should have_solution(x == false)
    ["xy" == a, a == b].should have_solution(b == "xy")
  end

  it "!=" do
    [a == "xy", b == "xy", x == (a != b)].should have_solution(x == false)
    [a == "xy", b == "xz", x == (a != b)].should have_solution(x == true)
  end

  it "+" do
    [a == "ab", b == "cd", c == a + b].should have_solution(c == "abcd")
    [a == "ab", c == a + "cd"].should have_solution(c == "abcd")
    [a == "ab", c == "cd" + a].should have_solution(c == "cdab")
    (Z3::StringSort["ab"] + "cd").simplify.value.should eq("abcd")
  end

  it "*" do
    [a == "ab", c == a * 3].should have_solution(c == "ababab")
    [a == "ab", c == a * 1].should have_solution(c == "ab")
    [a == "ab", c == a * 0].should have_solution(c == "")
    expect_raises(Z3::Exception) { Z3::StringSort["ab"] * -1 }
  end

  it "length" do
    [a == "abcd", i == a.length].should have_solution(i == 4)
    [a == "abcd", i == a.size].should have_solution(i == 4)
    [a == "", x == a.empty?].should have_solution(x == true)
    [a == "a", x == a.empty?].should have_solution(x == false)
  end

  # An index is an offset, and a negative one is out of range rather than counted
  # from the end - see StringExpr#[]
  it "[index]" do
    [a == "abcd", c == a[1]].should have_solution(c == "b")
    [a == "abcd", i == 2, c == a[i]].should have_solution(c == "c")
    [a == "abcd", c == a[4]].should have_solution(c == "")
    [a == "abcd", c == a[-1]].should have_solution(c == "")
    [a == "abcd", c == a[a.length - 1]].should have_solution(c == "d")
  end

  it "[offset, length]" do
    [a == "abcd", c == a[1, 2]].should have_solution(c == "bc")
    [a == "abcd", c == a[1, 100]].should have_solution(c == "bcd")
    [a == "abcd", i == 1, c == a[i, 2]].should have_solution(c == "bc")
  end

  it "[range]" do
    [a == "abcde", c == a[1..3]].should have_solution(c == "bcd")
    [a == "abcde", c == a[1...3]].should have_solution(c == "bc")
    [a == "abcde", c == a[2..]].should have_solution(c == "cde")
    [a == "abcde", c == a[..2]].should have_solution(c == "abc")
    [a == "abcde", i == 1, c == a[i..3]].should have_solution(c == "bcd")
  end

  it "includes?" do
    [a == "abcd", x == a.includes?("bc")].should have_solution(x == true)
    [a == "abcd", x == a.includes?("bd")].should have_solution(x == false)
    [a == "abcd", b == "cd", x == a.includes?(b)].should have_solution(x == true)
  end

  it "starts_with?" do
    [a == "abcd", x == a.starts_with?("ab")].should have_solution(x == true)
    [a == "abcd", x == a.starts_with?("bc")].should have_solution(x == false)
  end

  it "ends_with?" do
    [a == "abcd", x == a.ends_with?("cd")].should have_solution(x == true)
    [a == "abcd", x == a.ends_with?("bc")].should have_solution(x == false)
  end

  # There is no `nil` for these to be, so a missing substring is -1
  it "index" do
    [a == "abcab", i == a.index("ab")].should have_solution(i == 0)
    [a == "abcab", i == a.index("ab", 1)].should have_solution(i == 3)
    [a == "abcab", i == a.index("xy")].should have_solution(i == -1)
  end

  it "rindex" do
    [a == "abcab", i == a.rindex("ab")].should have_solution(i == 3)
    [a == "abcab", i == a.rindex("xy")].should have_solution(i == -1)
  end

  it "sub" do
    [a == "abcabc", c == a.sub("bc", "X")].should have_solution(c == "aXabc")
    [a == "abcabc", c == a.sub("xy", "X")].should have_solution(c == "abcabc")
  end

  it "gsub" do
    [a == "abcabc", c == a.gsub("bc", "X")].should have_solution(c == "aXaX")
    [a == "abcabc", c == a.gsub("xy", "X")].should have_solution(c == "abcabc")
  end

  # `str.to_int` is not quite Crystal's String#to_i - a string which isn't a run of
  # digits is -1 rather than an error
  it "to_i" do
    [a == "123", i == a.to_i].should have_solution(i == 123)
    [a == "12ab", i == a.to_i].should have_solution(i == -1)
    [a == "-12", i == a.to_i].should have_solution(i == -1)
  end

  it "to_code" do
    [a == "a", i == a.to_code].should have_solution(i == 97)
    [a == "ab", i == a.to_code].should have_solution(i == -1)
  end

  it "StringSort.from_int" do
    [i == 123, c == Z3::StringSort.from_int(i)].should have_solution(c == "123")
    # SMT-LIB says a negative number has no string form at all
    [i == -123, c == Z3::StringSort.from_int(i)].should have_solution(c == "")
    Z3::StringSort.from_int(123).simplify.value.should eq("123")
  end

  it "StringSort.from_code" do
    [i == 97, c == Z3::StringSort.from_code(i)].should have_solution(c == "a")
    Z3::StringSort.from_code(97).simplify.value.should eq("a")
  end

  # The same eight bits give "253" unsigned and "-3" signed
  it "StringSort.from_unsigned_bv / .from_signed_bv" do
    bv = Z3::BitvecSort.new(8u32)[253]
    [c == Z3::StringSort.from_unsigned_bv(bv)].should have_solution(c == "253")
    [c == Z3::StringSort.from_signed_bv(bv)].should have_solution(c == "-3")
  end

  it "<" do
    [a == "ab", b == "b", x == (a < b)].should have_solution(x == true)
    [a == "ab", b == "ab", x == (a < b)].should have_solution(x == false)
    [a == "b", b == "ab", x == (a < b)].should have_solution(x == false)
    [a == "b", x == ("ab" < a)].should have_solution(x == true)
  end

  it "<=" do
    [a == "ab", b == "b", x == (a <= b)].should have_solution(x == true)
    [a == "ab", b == "ab", x == (a <= b)].should have_solution(x == true)
    [a == "b", b == "ab", x == (a <= b)].should have_solution(x == false)
  end

  it ">" do
    [a == "ab", b == "b", x == (a > b)].should have_solution(x == false)
    [a == "ab", b == "ab", x == (a > b)].should have_solution(x == false)
    [a == "b", b == "ab", x == (a > b)].should have_solution(x == true)
  end

  it ">=" do
    [a == "ab", b == "b", x == (a >= b)].should have_solution(x == false)
    [a == "ab", b == "ab", x == (a >= b)].should have_solution(x == true)
    [a == "b", b == "ab", x == (a >= b)].should have_solution(x == true)
  end

  it "value" do
    Z3::StringSort["abc"].value.should eq("abc")
    (Z3::StringSort["ab"] + "cd").value.should eq("abcd")
    expect_raises(Z3::Exception) { a.value }
  end

  it "const?" do
    Z3::StringSort["abc"].const?.should be_true
    a.const?.should be_false
  end

  it "sort" do
    a.sort.should eq(Z3::StringSort)
    Z3::StringSort.element_sort.should eq(Z3::CharSort)
  end

  it "solving" do
    [a.length == 3, a.starts_with?("ab"), a.ends_with?("c")].should have_solution(a == "abc")
    [a.length == 2, a.starts_with?("abc")].should have_no_solution
  end

  it "model" do
    solver = Z3::Solver.new
    solver.assert a == "abc"
    solver.satisfiable?.should be_true
    solver.model[a].value.should eq("abc")
  end
end
