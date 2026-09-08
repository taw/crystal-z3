module Z3
  # What a model decided an uninterpreted function does: the argument lists it had to
  # pin down, plus the `else` branch which answers for every other one. Z3 picks one of
  # the values as that fallback, so the entries are only the exceptions to it.
  #
  # The Ruby gem is a Hash from argument lists to values, with Hash's own default
  # holding the `else` branch. Expressions can't be Hash keys here - see the
  # Limitations section of the README - so this is a list of `{args, value}` pairs and
  # `#[]` walks it.
  struct FuncInterp
    getter decl : FuncDecl
    getter entries : Array(Tuple(Array(AnyExpr), AnyExpr))
    getter default : AnyExpr

    def initialize(@decl, @entries, @default)
    end

    def arity
      decl.arity
    end

    # How many argument lists the model pinned down, not counting the `else` branch
    def size
      entries.size
    end

    # What the function answers for these arguments, which for anything the model
    # never had to decide is the `else` branch
    def [](*args) : AnyExpr
      unless args.size == arity
        raise Z3::Exception.new("#{decl.name} takes #{arity} arguments, got #{args.size}")
      end
      wanted = [] of AnyExpr
      args.each_with_index { |arg, i| wanted << decl.domain(i).cast(arg) }
      entries.each do |entry|
        entry_args, value = entry
        return value if entry_args.zip(wanted).all? { |a, b| a.same_term?(b) }
      end
      default
    end

    def to_s(io)
      io << "{"
      entries.each do |entry|
        entry_args, value = entry
        io << "(" << entry_args.join(", ") << ") => " << value << ", "
      end
      io << "else => " << default << "}"
    end

    def inspect(io)
      io << "Z3::FuncInterp<" << decl.name << "="
      to_s(io)
      io << ">"
    end
  end
end
