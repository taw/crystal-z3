module Z3
  # A function symbol - what SMT-LIB's `declare-fun` declares, and what a model hands
  # back when it has decided what a function does.
  #
  # Applying one with `#[]` gives an expression of the declared range sort, which is
  # only known at runtime, so the result is an `AnyExpr` - a union - and has to be
  # narrowed before anything at all can be done with it, `==` included:
  #
  #     f = Z3.function("f", Z3::IntSort, Z3::IntSort)
  #     x = f[3].as(Z3::IntExpr)
  #     solver.assert x == 10
  #
  # This is the tax on there being no common `Z3::Expr` base class yet - see `_TODO.md`.
  class FuncDecl
    @@recursive_decl_kind : UInt32?

    def initialize(@decl : LibZ3::FuncDecl)
    end

    def name : String
      API.get_decl_name(self)
    end

    def arity
      API.get_arity(self)
    end

    def domain(i : Int) : AnySort
      if i < 0 || i >= arity
        raise Z3::Exception.new("Trying to access domain #{i} but function arity is #{arity}")
      end
      API.sort_from_pointer(API.get_domain(self, i.to_u32))
    end

    def range : AnySort
      API.sort_from_pointer(API.get_range(self))
    end

    # Applies the function. Arguments are cast into the declared domain sorts, so
    # `f[3]` works wherever `f[IntSort[3]]` does.
    def [](*args) : AnyExpr
      unless args.size == arity
        raise Z3::Exception.new("#{name} takes #{arity} arguments, got #{args.size}")
      end
      casted = [] of AnyExpr
      args.each_with_index { |arg, i| casted << domain(i).cast(arg) }
      range.from_ast(API.mk_app(self, casted))
    end

    def call(*args) : AnyExpr
      self[*args]
    end

    # Whether this was declared by `Z3.rec_function`, which is worth asking because Z3
    # hands those back in places nothing else shows up - see `Model#funcs`.
    def recursive?
      API.get_decl_kind(self) == FuncDecl.recursive_decl_kind
    end

    # Gives a recursive declaration its body - the `define-fun-rec` half of
    # `Z3.rec_function`. The block gets one fresh variable per domain sort, as an
    # Array because the arity is only known at runtime, and returns the body - which
    # may call this very function:
    #
    #     fact = Z3.rec_function("fact", Z3::IntSort, Z3::IntSort)
    #     fact.define do |args|
    #       n = args[0].as(Z3::IntExpr)
    #       (n <= 0).ite(1, n * fact[n - 1].as(Z3::IntExpr))
    #     end
    #
    # The Ruby gem takes the body as a block on `Z3.RecFunction` too. Here it's always
    # this second step, because Crystal has no way to pass a variable number of block
    # arguments and mutual recursion needs the two-step form anyway.
    #
    # Only a declaration made by `Z3.rec_function` can be defined; Z3 says so itself
    # for any other, which is a better error than anything we could check for here.
    def define(&) : self
      args = [] of AnyExpr
      arity.times do |i|
        sort = domain(i)
        args << sort.from_ast(API.mk_fresh_const(name, sort))
      end
      API.add_rec_def(self, args, range.cast(yield args))
      self
    end

    # Z3 hash-conses declarations, so two decls of the same name and signature are one
    # and the same pointer. Unlike an expression there's nothing for `==` to build - a
    # declaration is not a value - so this answers the question directly, and a
    # FuncDecl works as a Hash key.
    def ==(other : FuncDecl)
      @decl == other.to_unsafe
    end

    def hash(hasher)
      @decl.hash(hasher)
    end

    def to_s(io)
      io << name
    end

    def inspect(io)
      io << "Z3::FuncDecl<" << name << "/" << arity << ">"
    end

    def to_unsafe
      @decl
    end

    # Last sort is the range, the ones before it are the domain, the same order
    # SMT-LIB's `declare-fun` uses
    def self.declare(name : String, sorts : Array(AnySort)) : FuncDecl
      domain, range = split_signature(sorts)
      new API.mk_func_decl(name, domain, range)
    end

    def self.declare_rec(name : String, sorts : Array(AnySort)) : FuncDecl
      domain, range = split_signature(sorts)
      new API.mk_rec_func_decl(name, domain, range)
    end

    def self.declare_fresh(prefix : String, sorts : Array(AnySort)) : FuncDecl
      domain, range = split_signature(sorts)
      new API.mk_fresh_func_decl(prefix, domain, range)
    end

    # Z3's answer for `#recursive?` is the decl kind `Z3_OP_RECURSIVE`, whose numeric
    # value sits at the far end of an enum which grows between releases - so rather
    # than writing the number down, we make one recursive declaration and ask Z3 what
    # kind it came out as. Leaving it undefined is safe: nothing applies it, so no
    # solver ever has to unfold it and no model mentions it.
    def self.recursive_decl_kind : UInt32
      @@recursive_decl_kind ||= API.get_decl_kind(
        API.mk_rec_func_decl("z3.cr.recursive?", [BoolSort.to_unsafe], BoolSort.to_unsafe)
      )
    end

    private def self.split_signature(sorts : Array(AnySort))
      raise Z3::Exception.new("Function needs at least a range sort") if sorts.empty?
      {sorts[0...-1].map(&.to_unsafe), sorts[-1].to_unsafe}
    end
  end

  # An uninterpreted function - a symbol the solver decides the meaning of. The last
  # sort is the range and the ones before it the domain, so `Z3.function("f", Int,
  # Int, Bool)` is a two argument predicate. Apply it with `f[x, y]`.
  def Z3.function(name : String, *sorts : AnySort) : FuncDecl
    FuncDecl.declare(name, sorts_array(sorts))
  end

  # A function which *is* its body, rather than one the solver gets to interpret -
  # SMT-LIB's `define-fun-rec`. Declaring and defining are two steps so that the body
  # can mention the function it defines, and so that mutually recursive functions can
  # both be declared before either is defined:
  #
  #     even = Z3.rec_function("even", Z3::IntSort, Z3::BoolSort)
  #     odd = Z3.rec_function("odd", Z3::IntSort, Z3::BoolSort)
  #     even.define { |args| ... odd[...] ... }
  #     odd.define { |args| ... even[...] ... }
  #
  # A declaration never given a body is not an error and doesn't announce itself - it
  # simply behaves as an uninterpreted function. Z3 doesn't check that the recursion
  # terminates either, and one it can't finish unfolding comes back as `Unknown`.
  #
  # A definition belongs to the context rather than to any solver, exactly as it would
  # in an SMT-LIB script, so it is permanent and every solver made afterwards carries it.
  def Z3.rec_function(name : String, *sorts : AnySort) : FuncDecl
    FuncDecl.declare_rec(name, sorts_array(sorts))
  end

  # The same as `Z3.function` with a name Z3 picks, for helper functions which
  # mustn't collide with anything you've named
  def Z3.fresh_function(prefix : String, *sorts : AnySort) : FuncDecl
    FuncDecl.declare_fresh(prefix, sorts_array(sorts))
  end

  # A Tuple of sorts arrives with each element's own type, and Crystal's Arrays are
  # invariant, so the union has to be spelled out one element at a time
  private def self.sorts_array(sorts) : Array(AnySort)
    result = Array(AnySort).new(sorts.size)
    sorts.each { |sort| result << sort }
    result
  end
end
