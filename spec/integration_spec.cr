require "./spec_helper"

# Each example is run as a program and its output compared to a saved answer, the
# way the Ruby gem's integration specs do. Only the examples with one right answer
# are here - the ones whose puzzle has several solutions would be testing which one
# this version of Z3 happens to pick.
private def output_of(example)
  `./examples/#{example}.cr`
end

private def saved_answer(example)
  File.read("#{__DIR__}/integration/#{example}.txt")
end

# The gem's matcher ignores trailing spaces on both sides, and the examples which
# draw grids leave plenty of them
private def normalize(text)
  text.lines.map(&.rstrip).join("\n").rstrip + "\n"
end

private def strip_colors(text)
  text.gsub(/\e\[[0-9;]*m/, "")
end

describe "Integration Tests" do
  {
    "algebra_problems"    => "Algebra Problems",
    "aquarium"            => "Aquarium",
    "basic_int_math"      => "Basic Int Math",
    "basic_logic"         => "Basic Logic",
    "bit_tricks"          => "Bit Tricks",
    "bridges"             => "Bridges",
    "circuit_problems"    => "Circuit Problems",
    "color_nonogram"      => "Color Nonogram",
    "crossflip"           => "Crossflip",
    "dominion"            => "Dominion",
    "dominosa"            => "Dominosa",
    "eulero"              => "Eulero",
    "four_hackers_puzzle" => "Four Hackers Puzzle",
    "kakurasu"            => "Kakurasu",
    "kakuro"              => "Kakuro",
    "killer_sudoku"       => "Killer Sudoku",
    "kropki"              => "Kropki",
    "letter_connections"  => "Letter Connections",
    "light_up"            => "Light Up",
    "minisudoku"          => "Mini Sudoku",
    "miracle_sudoku"      => "Miracle Sudoku",
    "nanro"               => "Nanro",
    "nine_clocks"         => "Nine Clocks",
    "nonogram"            => "Nonogram",
    "pyramid_nonogram"    => "Pyramid Nonogram",
    "renzoku"             => "Renzoku",
    "sandwich_sudoku"     => "Sandwich Sudoku",
    "selfref"             => "Self-Referential Aptitude Test",
    "skyscrapers"         => "Skyscrapers",
    "star_battle"         => "Star Battle",
    "sudoku"              => "Sudoku",
    "suguru"              => "Suguru",
    "verbal_arithmetic"   => "Verbal Arithmetic",
    "yajilin"             => "Yajilin",
  }.each do |example, title|
    it title do
      normalize(output_of(example)).should eq(normalize(saved_answer(example)))
    end
  end

  # Stitches paints each group in a colour it picks at random, so only the stitching
  # is compared - which is what the gem's have_output_no_color matcher does
  it "Stitches" do
    normalize(strip_colors(output_of("stitches"))).should eq(normalize(strip_colors(saved_answer("stitches"))))
  end

  it "SEND + MORE = MONEY" do
    # Z3's model_to_string order is version-dependent (Ruby's insertion-ordered
    # hashes hid this), so compare the lines order-independently
    output_of("send_more_money").lines.sort.should eq(saved_answer("send_more_money").lines.sort)
  end
end
