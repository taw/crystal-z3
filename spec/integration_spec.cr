describe "Integration Tests" do
  it "Sudoku" do
    actual = `./examples/sudoku.cr`
    expected = File.read("#{__DIR__}/integration/sudoku.txt")
    actual.should eq(expected)
  end

  it "SEND + MORE = MONEY" do
    actual = `./examples/send_more_money.cr`
    expected = File.read("#{__DIR__}/integration/send_more_money.txt")
    # Z3's model_to_string order is version-dependent (Ruby's insertion-ordered
    # hashes hid this), so compare the lines order-independently
    actual.lines.sort.should eq(expected.lines.sort)
  end
end
