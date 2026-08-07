module Z3
  # `s[1..3]` on a String and on a Seq is the same arithmetic on an offset and a
  # length, so the two share it here rather than through a superclass - see SeqExpr
  # for why the Exprs have no common ancestor of their own.
  module RangeIndexing
    # An open ended Range runs to the end of the sequence, and an inclusive one takes
    # one more element than an exclusive one. Either end can be an IntExpr, so this
    # arithmetic may itself be symbolic.
    private def offset_and_length(range)
      offset = range.begin || 0
      last = range.end
      return {offset, length - offset} if last.nil?
      # An open beginning is offset 0, and subtracting it would only clutter the term
      len = (offset.is_a?(Int) && offset == 0) ? last : last - offset
      {offset, range.excludes_end? ? len : len + 1}
    end
  end
end
