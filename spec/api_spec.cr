require "./spec_helper"

describe Z3::API do
  # Nothing the library builds is ever sort-incorrect, so the only way to reach Z3's
  # error handler is to wrap a raw AST by hand - here an Int term claiming to be a
  # Bitvec, which Z3 is the one to notice
  bogus_bitvec = Z3::BitvecExpr.new(Z3.int("a").to_unsafe, Z3::BitvecSort.new(8u32))

  it "raises instead of printing to stderr and answering null" do
    expect_raises(Z3::Exception, "operator is applied to arguments of the wrong sort") do
      bogus_bitvec + 1
    end
  end

  # Z3 remembers the code of the last failed call, so a rescued error has to leave
  # the context as good as it found it
  it "leaves the context usable after an error" do
    begin
      bogus_bitvec + 1
    rescue Z3::Exception
    end
    (Z3.int("a") + 1).simplify.to_s.should eq("(+ 1 a)")
    [Z3.int("b") == 7].should have_solution(Z3.int("b") == 7)
  end
end
