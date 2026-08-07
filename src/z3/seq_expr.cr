module Z3
  # Z3 has no String sort of its own - a String is a Seq(Char), and `str.++` is the
  # same operation as `seq.++`. The Exprs still don't share a hierarchy, because the
  # Crystal side of them doesn't: a SeqExpr should read like a Crystal Array and a
  # StringExpr like a Crystal String, and those two have no common ancestor either.
  # Where a seq and a string operation really are one Z3 operation, they share the
  # API call, not a superclass.
  #
  # That split is what settles the element-versus-subsequence question. Every Z3 seq
  # operation takes a subsequence, but Crystal's Array#includes? / #index take an
  # element, and Crystal wins - as it does everywhere the two disagree: a bare element
  # is wrapped into a one element sequence, while a SeqExpr of this very sort or a
  # Crystal Array is taken as the subsequence it already is.
  #
  # A Seq only knows its element sort at runtime, so everything which hands back an
  # element hands back an `AnyExpr` - `xs[0].as(IntExpr)` is how you get back to a
  # sort Crystal can typecheck.
  class SeqExpr
    include RangeIndexing

    def initialize(@expr : LibZ3::Ast, @sort : SeqSort)
    end

    def sort
      @sort
    end

    def element_sort
      @sort.element_sort
    end

    def ==(other)
      BoolExpr.new API.mk_eq(self, sort.cast(other))
    end

    def !=(other)
      BoolExpr.new API.mk_ne(self, sort.cast(other))
    end

    # Crystal Array has both #size and #length, so this has both too
    def length
      IntExpr.new API.mk_seq_length(self)
    end

    def size
      length
    end

    def empty?
      length == 0
    end

    # Crystal Array#+ is concatenation, and so is `seq.++`
    def +(other)
      SeqExpr.new API.mk_seq_concat([self, sort.cast(other)]), sort
    end

    # Crystal Array#* repeats. Only the Integer form - Array#*(String) is #join, and
    # there's no joining a sequence of arbitrary element sort into a String.
    def *(count : Int)
      raise Z3::Exception.new("Can only repeat a Seq a non-negative Integer number of times") unless count >= 0
      return sort.empty if count == 0
      return self if count == 1
      SeqExpr.new API.mk_seq_concat([self] * count), sort
    end

    # Crystal Array#[]. `xs[i]` is the element (`seq.nth`), `xs[i, len]` and `xs[range]`
    # are subsequences (`seq.extract`).
    #
    # An index is an offset, and a negative one is not counted from the end the way
    # Crystal's is - see StringExpr#[] for why. Counting from the end is
    # `xs[xs.length - 1]`, which is what #last does. Out of range is whatever Z3 says: a
    # subsequence is empty, and an element is left *unspecified*, so an out of range
    # `xs[i]` is a term the solver may pick any value for. It denotes an element, and no
    # element is `nil`.
    def [](index : IntExpr | Int) : AnyExpr
      element_sort.from_ast API.mk_seq_nth(self, IntSort[index])
    end

    def [](offset : IntExpr | Int, len : IntExpr | Int)
      subseq(offset, len)
    end

    def [](range : Range)
      subseq(*offset_and_length(range))
    end

    # Crystal Array#at - the element, same as `xs[i]`
    def at(index : IntExpr | Int)
      self[index]
    end

    def first
      self[0]
    end

    def first(n : IntExpr | Int)
      subseq(0, n)
    end

    def last
      self[length - 1]
    end

    def last(n : IntExpr | Int)
      subseq(length - n, n)
    end

    # Crystal Array#includes? takes an element, so that's what this expects - pass a
    # SeqExpr of this sort, or a Crystal Array, to ask about a subsequence instead
    def includes?(element_or_subsequence)
      BoolExpr.new API.mk_seq_contains(self, cast_to_seq(element_or_subsequence))
    end

    # Z3's `seq.prefixof` takes the prefix first and the sequence second. Crystal's Array
    # has no #starts_with?, so String's spelling is reused.
    def starts_with?(element_or_subsequence)
      BoolExpr.new API.mk_seq_prefix(cast_to_seq(element_or_subsequence), self)
    end

    def ends_with?(element_or_subsequence)
      BoolExpr.new API.mk_seq_suffix(cast_to_seq(element_or_subsequence), self)
    end

    # Crystal Array#index. This denotes an Int, so there's no `nil` available for it to
    # be when there's no match - `seq.indexof` answers -1, and that's what comes back. It
    # also takes a starting offset, which Crystal's Array#index doesn't.
    def index(element_or_subsequence, offset : IntExpr | Int = 0)
      IntExpr.new API.mk_seq_index(self, cast_to_seq(element_or_subsequence), IntSort[offset])
    end

    # Crystal Array#rindex. Z3's `seq.last_indexof` takes no offset, so neither does
    # this - and as of Z3 4.16 it builds fine but answers an out of range value for
    # every sequence of non-characters, so only StringExpr#rindex is any use yet.
    def rindex(element_or_subsequence)
      IntExpr.new API.mk_seq_last_index(self, cast_to_seq(element_or_subsequence))
    end

    # Crystal's Array has nothing like these, so they keep String's names along with
    # String's first-one versus every-one split
    def sub(pattern, replacement)
      SeqExpr.new API.mk_seq_replace(self, cast_to_seq(pattern), cast_to_seq(replacement)), sort
    end

    def gsub(pattern, replacement)
      SeqExpr.new API.mk_seq_replace_all(self, cast_to_seq(pattern), cast_to_seq(replacement)), sort
    end

    def simplify
      SeqExpr.new API.simplify(self), sort
    end

    # The elements of a sequence value, each an expression of the element sort. There is
    # no #value, the way every other sort has one: the element sort is only known at
    # runtime, so the best a Crystal Array could be is an Array of unions - call #value
    # on the elements you want instead, as in `xs.elements.map(&.as(IntExpr).value)`.
    def elements : Array(AnyExpr)
      count = IntExpr.new API.simplify(API.mk_seq_length(self))
      raise Z3::Exception.new("Can't take the elements of expression #{self}") unless count.const?
      (0...count.to_i).map do |i|
        element_sort.from_ast API.simplify(API.mk_seq_nth(self, IntSort[i]))
      end
    end

    def to_s(io)
      io << API.ast_to_string(self)
    end

    def inspect(io)
      io << "SeqExpr<"
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

    # `seq.extract`, with `xs[offset, len]` the only spelling exposed
    private def subseq(offset, len)
      SeqExpr.new API.mk_seq_extract(self, IntSort[offset], IntSort[len]), sort
    end

    # A sequence of this very sort, or a Crystal Array, is already the subsequence it
    # looks like. Anything else is an element, and becomes a one element sequence -
    # which is also the only reading available when the element sort is itself a Seq.
    private def cast_to_seq(other) : SeqExpr
      case other
      when SeqExpr, Array
        sort.cast(other)
      else
        sort.unit(other)
      end
    end
  end
end
