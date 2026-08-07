module Z3
  # This reads like Crystal's String - see SeqExpr for why the two don't share a
  # hierarchy even though Z3 models a String as a Seq(Char).
  #
  # Where Crystal and SMT-LIB disagree, Crystal wins: `#includes?` rather than
  # `contains?`, `#sub` / `#gsub` rather than `replace` / `replace_all`, and the
  # receiver back in front of `#starts_with?`.
  #
  # Where Crystal answers `nil` there's nothing to answer with, because every one of
  # these is a subexpression - `s[i]` can appear as `s[i] + "!"`, or under an `==`, or
  # buried in a term a model hands back - so it has to denote a String, and no String
  # is `nil`. Those return whatever Z3 returns, and the method comments say what it is.
  class StringExpr
    include RangeIndexing

    def initialize(@expr : LibZ3::Ast)
    end

    def sort
      StringSort
    end

    def ==(other)
      BoolExpr.new API.mk_eq(self, sort[other])
    end

    def !=(other)
      BoolExpr.new API.mk_ne(self, sort[other])
    end

    # `str.len` and `seq.len` are one Z3 operation, so SeqExpr#length is the same call
    def length
      IntExpr.new API.mk_seq_length(self)
    end

    def size
      length
    end

    def empty?
      length == 0
    end

    # Crystal String#+ is concatenation, and so is `str.++`
    def +(other)
      StringExpr.new API.mk_seq_concat([self, sort[other]])
    end

    # Crystal String#* repeats. Z3 has no repetition operator, so it's Crystal side
    # concatenation, and the count has to be a Crystal Integer rather than an IntExpr.
    def *(count : Int)
      raise Z3::Exception.new("Can only repeat a String a non-negative Integer number of times") unless count >= 0
      return sort[""] if count == 0
      return self if count == 1
      StringExpr.new API.mk_seq_concat([self] * count)
    end

    # Crystal String#[]. `s[i]` is a one character String (`str.at`), `s[i, len]` and
    # `s[range]` are substrings (`str.substr`).
    #
    # An index is an offset, and that's the whole of it - a negative one is not counted
    # from the end the way Crystal's is. Only a literal could ever be recognized as
    # negative, and `s[-1]` meaning the last character while `s[i]` with `i == -1` means
    # something else is worse than not emulating it at all: an index has to mean the
    # same thing however it's spelled. So a negative index is simply out of range, and
    # out of range is whatever Z3 says, which is `""`. Counting from the end is
    # `s[s.length - 1]`, which works for a symbolic offset too.
    def [](index : IntExpr | Int)
      StringExpr.new API.mk_seq_at(self, IntSort[index])
    end

    def [](offset : IntExpr | Int, len : IntExpr | Int)
      substr(offset, len)
    end

    def [](range : Range)
      substr(*offset_and_length(range))
    end

    # Crystal String#includes? - a substring, not a character
    def includes?(substring : StringExpr | String)
      BoolExpr.new API.mk_seq_contains(self, sort[substring])
    end

    # Z3's `str.prefixof` takes the prefix first and the string second, the opposite
    # way round from Crystal's String#starts_with?
    def starts_with?(prefix : StringExpr | String)
      BoolExpr.new API.mk_seq_prefix(sort[prefix], self)
    end

    def ends_with?(suffix : StringExpr | String)
      BoolExpr.new API.mk_seq_suffix(sort[suffix], self)
    end

    # Crystal String#index. This denotes an Int, so there's no `nil` available for it to
    # be when there's no match - `str.indexof` answers -1, and that's what comes back.
    def index(substring : StringExpr | String, offset : IntExpr | Int = 0)
      IntExpr.new API.mk_seq_index(self, sort[substring], IntSort[offset])
    end

    # Crystal String#rindex. Z3's `seq.last_indexof` takes no offset, so neither does this.
    def rindex(substring : StringExpr | String)
      IntExpr.new API.mk_seq_last_index(self, sort[substring])
    end

    # Crystal String#sub and #gsub, split the same way: `str.replace` replaces the first
    # occurrence, `str.replace_all` every one. We have no regular expressions yet, so
    # the pattern is a String, matched unanchored exactly as Crystal's String one is.
    def sub(pattern : StringExpr | String, replacement : StringExpr | String)
      StringExpr.new API.mk_seq_replace(self, sort[pattern], sort[replacement])
    end

    def gsub(pattern : StringExpr | String, replacement : StringExpr | String)
      StringExpr.new API.mk_seq_replace_all(self, sort[pattern], sort[replacement])
    end

    # Crystal String#to_i, so this is the symbolic `str.to_int` - not IntExpr#to_i,
    # which goes the other way and gives a Crystal Int32. #value is the one that gives
    # a Crystal object back.
    #
    # `str.to_int` isn't quite Crystal's String#to_i, though: it takes a non-negative
    # run of digits and answers -1 for anything else, where Crystal takes a sign, parses
    # a digit prefix and raises on failure. This returns what Z3 returns.
    def to_i
      IntExpr.new API.mk_str_to_int(self)
    end

    # The code point of a one character string, as a Z3 Int, or -1 for a string of any
    # other length. StringSort.from_code is this backwards.
    def to_code
      IntExpr.new API.mk_string_to_code(self)
    end

    # `str.<` / `str.<=` are lexicographic, and have nothing to do with `==`
    def <(other)
      BoolExpr.new API.mk_str_lt(self, sort[other])
    end

    def <=(other)
      BoolExpr.new API.mk_str_le(self, sort[other])
    end

    def >(other)
      BoolExpr.new API.mk_str_lt(sort[other], self)
    end

    def >=(other)
      BoolExpr.new API.mk_str_le(sort[other], self)
    end

    def simplify
      StringExpr.new API.simplify(self)
    end

    def const?
      API.is_string(self)
    end

    # Every sort which can hand back a Crystal object spells it #value. Deliberately
    # not #to_s - that's the printed form of any AST, and it has to work on all of them.
    def value : String
      return API.get_string(self) if const?
      s = simplify
      return API.get_string(s) if s.const?
      raise Z3::Exception.new("Can't convert expression #{self} into String")
    end

    def to_s(io)
      io << API.ast_to_string(self)
    end

    def inspect(io)
      io << "StringExpr<"
      to_s(io)
      io << ">"
    end

    # Whether this is the same term as `other`. Z3 hash-conses its expressions, so
    # this is structural equality - `Z3.int("a") + 1` built twice is one term. It is
    # a named method rather than `==` because `==` builds a Z3 expression instead of
    # answering a Crystal Bool - see the Limitations section of the README.
    def same_term?(other : AnyExpr)
      API.is_eq_ast(self, other)
    end

    def to_unsafe
      @expr
    end

    # `str.substr`, with `s[offset, len]` the only spelling exposed
    private def substr(offset, len)
      StringExpr.new API.mk_seq_extract(self, IntSort[offset], IntSort[len])
    end
  end
end
