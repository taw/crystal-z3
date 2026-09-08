module Z3
  module API
    extend self

    # Z3's own error handler prints the message to stderr and lets the failed call
    # hand back a null pointer, so the program carries on with a null AST inside an
    # expression. This one does nothing at all, leaving the error code set for
    # `checked` to raise on - a Crystal exception can't be thrown out of a C callback
    # and back through Z3's own frames.
    Context = begin
      context = LibZ3.mk_context(LibZ3.mk_config)
      LibZ3.set_error_handler(context, ->(_context : LibZ3::Context, _code : LibZ3::ErrorCode) { })
      context
    end

    # Every call into Z3 goes through here, so a failed one raises instead of
    # answering null. Z3 remembers the code of the last failed call, and resets it at
    # the start of the next one - but a rescued exception would leave it set, so this
    # clears it itself.
    private def checked(result)
      check_error
      result
    end

    # Not every call has a result worth passing through - `model_eval` reads an out
    # parameter, and the void ones have nothing at all
    private def check_error
      code = LibZ3.get_error_code(Context)
      return if code == LibZ3::ErrorCode::Ok
      message = String.new LibZ3.get_error_msg(Context, code)
      LibZ3.set_error(Context, LibZ3::ErrorCode::Ok)
      raise Z3::Exception.new(message)
    end

    {% for name in %w[
                     func_entry_get_arg
                     func_entry_get_num_args
                     func_entry_get_value
                     func_interp_get_arity
                     func_interp_get_else
                     func_interp_get_entry
                     func_interp_get_num_entries
                     get_app_decl
                     get_arity
                     get_decl_kind
                     get_domain
                     get_algebraic_number_lower
                     get_algebraic_number_upper
                     get_ast_kind
                     get_bool_value
                     get_range
                     is_algebraic_number
                     is_eq_ast
                     is_string
                     mk_abs
                     mk_bit2bool
                     mk_bv2int
                     mk_bvadd
                     mk_bvadd_no_overflow
                     mk_bvadd_no_underflow
                     mk_bvand
                     mk_bvashr
                     mk_bvlshr
                     mk_bvmul
                     mk_bvmul_no_overflow
                     mk_bvmul_no_underflow
                     mk_bvnand
                     mk_bvneg
                     mk_bvneg_no_overflow
                     mk_bvnor
                     mk_bvnot
                     mk_bvor
                     mk_bvredand
                     mk_bvredor
                     mk_bvsdiv
                     mk_bvsdiv_no_overflow
                     mk_bvsge
                     mk_bvsgt
                     mk_bvshl
                     mk_bvsle
                     mk_bvslt
                     mk_bvsmod
                     mk_bvsrem
                     mk_bvsub
                     mk_bvsub_no_overflow
                     mk_bvsub_no_underflow
                     mk_bvudiv
                     mk_bvuge
                     mk_bvugt
                     mk_bvule
                     mk_bvult
                     mk_bvurem
                     mk_bvxnor
                     mk_bvxor
                     mk_char
                     mk_char_from_bv
                     mk_char_is_digit
                     mk_char_le
                     mk_char_to_bv
                     mk_char_to_int
                     mk_concat
                     mk_div
                     mk_divides
                     mk_eq
                     mk_ext_rotate_left
                     mk_ext_rotate_right
                     mk_extract
                     mk_false
                     mk_ge
                     mk_gt
                     mk_iff
                     mk_implies
                     mk_int2bv
                     mk_int2real
                     mk_int_to_str
                     mk_is_int
                     mk_ite
                     mk_le
                     mk_lt
                     mk_mod
                     mk_not
                     mk_power
                     mk_real2int
                     mk_rem
                     mk_repeat
                     mk_rotate_left
                     mk_rotate_right
                     mk_sbv_to_str
                     mk_seq_at
                     mk_seq_contains
                     mk_seq_empty
                     mk_seq_extract
                     mk_seq_index
                     mk_seq_last_index
                     mk_seq_length
                     mk_seq_nth
                     mk_seq_prefix
                     mk_seq_replace
                     mk_seq_replace_all
                     mk_seq_suffix
                     mk_seq_unit
                     mk_sign_ext
                     mk_solver
                     mk_str_le
                     mk_str_lt
                     mk_str_to_int
                     mk_string_from_code
                     mk_string_to_code
                     mk_true
                     mk_ubv_to_str
                     mk_unary_minus
                     mk_xor
                     mk_zero_ext
                     mk_optimize
                     mk_simple_solver
                     model_get_func_decl
                     model_get_num_funcs
                     model_has_interp
                     optimize_get_model
                     optimize_maximize
                     optimize_minimize
                     model_get_const_decl
                     model_get_num_consts
                     simplify
                     solver_check
                     solver_get_model
                     solver_get_num_scopes
                   ] %}
      def {{name.id}}(*args)
        checked LibZ3.{{name.id}}(Context, *args)
      end
    {% end %}

    # The same, for the calls which answer nothing - Crystal won't let a void lib
    # call be passed to `checked`, or assigned anywhere
    {% for name in %w[
                     func_entry_dec_ref
                     func_entry_inc_ref
                     func_interp_dec_ref
                     func_interp_inc_ref
                     optimize_assert
                     optimize_assert_and_track
                     optimize_from_file
                     optimize_from_string
                     optimize_inc_ref
                     optimize_pop
                     optimize_push
                     optimize_set_initial_value
                     solver_from_file
                     solver_from_string
                     solver_interrupt
                     solver_set_initial_value
                     model_inc_ref
                     solver_assert
                     solver_assert_and_track
                     solver_inc_ref
                     solver_pop
                     solver_push
                     solver_reset
                   ] %}
      def {{name.id}}(*args)
        LibZ3.{{name.id}}(Context, *args)
        check_error
      end
    {% end %}

    {% for name in %w[
                     mk_add
                     mk_and
                     mk_distinct
                     mk_mul
                     mk_or
                     mk_seq_concat
                     mk_sub
                   ] %}
      def {{name.id}}(asts)
        checked LibZ3.{{name.id}}(Context, asts.size, asts.map(&.to_unsafe))
      end
    {% end %}

    # The cardinality and pseudo-boolean constraints take a count and a bound in
    # addition to the asts, so they don't fit either of the loops above
    {% for name in %w[mk_atleast mk_atmost] %}
      def {{name.id}}(asts, k : UInt32)
        checked LibZ3.{{name.id}}(Context, asts.size, asts.map(&.to_unsafe), k)
      end
    {% end %}

    {% for name in %w[mk_pbeq mk_pbge mk_pble] %}
      def {{name.id}}(asts, coeffs : Array(Int32), k : Int32)
        checked LibZ3.{{name.id}}(Context, asts.size, asts.map(&.to_unsafe), coeffs, k)
      end
    {% end %}

    def mk_numeral(num : Int | BigRational | Float, sort)
      checked LibZ3.mk_numeral(Context, num.to_s, sort)
    end

    def mk_const(name, sort)
      name_sym = checked LibZ3.mk_string_symbol(Context, name)
      checked LibZ3.mk_const(Context, name_sym, sort)
    end

    # Not a real Z3 function
    def mk_ne(a, b)
      checked LibZ3.mk_distinct(Context, 2, [a.to_unsafe, b.to_unsafe])
    end

    # The calls which answer a C string. Z3 owns the buffer and reuses it, so each
    # one has to be copied into a Crystal String before the next call.
    {% for name in %w[
                     ast_to_string
                     get_numeral_string
                     model_to_string
                     optimize_get_help
                     optimize_get_reason_unknown
                     optimize_to_string
                     solver_get_help
                     solver_get_reason_unknown
                     solver_to_dimacs_string
                     solver_to_string
                   ] %}
      def {{name.id}}(*args)
        String.new checked(LibZ3.{{name.id}}(Context, *args))
      end
    {% end %}

    # The calls which answer an AST vector, which is Z3's array of terms
    {% for name in %w[
                     optimize_get_assertions
                     optimize_get_unsat_core
                     solver_get_assertions
                     solver_get_non_units
                     solver_get_trail
                     solver_get_unsat_core
                     solver_get_units
                   ] %}
      def {{name.id}}(*args)
        read_ast_vector checked(LibZ3.{{name.id}}(Context, *args))
      end
    {% end %}

    # A Z3 string is a sequence of code points, and these two are the only calls which
    # pass one either way without escaping it into ASCII first
    def mk_u32string(code_points : Array(UInt32))
      checked LibZ3.mk_u32string(Context, code_points.size, code_points)
    end

    def get_string(ast)
      size = checked LibZ3.get_string_length(Context, ast)
      return "" if size == 0
      code_points = Pointer(UInt32).malloc(size)
      LibZ3.get_string_contents(Context, ast, size, code_points)
      check_error
      String.build do |io|
        size.times { |i| io << code_points[i].to_i.chr }
      end
    end

    def model_eval(model, ast, complete)
      result = LibZ3.model_eval(Context, model, ast, complete, out result_ast)
      check_error
      raise Z3::Exception.new("Cannot evaluate") unless result == true
      new_from_ast_pointer result_ast
    end

    def new_from_ast_pointer(_ast) : AnyExpr
      sort_from_pointer(checked(LibZ3.get_sort(Context, _ast))).from_ast(_ast)
    end

    def sort_from_pointer(_sort) : AnySort
      sort_kind = checked LibZ3.get_sort_kind(Context, _sort)
      case sort_kind
      when LibZ3::SortKind::Bool
        BoolSort
      when LibZ3::SortKind::Int
        IntSort
      when LibZ3::SortKind::Real
        RealSort
      when LibZ3::SortKind::Char
        CharSort
      when LibZ3::SortKind::Bitvec
        BitvecSort.new(checked(LibZ3.get_bv_sort_size(Context, _sort)))
      when LibZ3::SortKind::Seq
        # Seq(Char) comes back as StringSort, which is what SeqSort.new says it is
        SeqSort.new(sort_from_pointer(checked(LibZ3.get_seq_sort_basis(Context, _sort))))
      else
        raise "Unsupported sort kind #{sort_kind}"
      end
    end

    # The arguments of an application, so a term like `a == 2` can be taken apart.
    # Anything which isn't an application has no arguments.
    # TODO: this becomes much less ad hoc once we have a real printer
    def app_args(ast)
      result = [] of AnyExpr
      return result unless get_ast_kind(ast) == LibZ3::AstKind::App
      app = checked LibZ3.to_app(Context, ast)
      checked(LibZ3.get_app_num_args(Context, app)).times do |i|
        result << new_from_ast_pointer(checked LibZ3.get_app_arg(Context, app, i))
      end
      result
    end

    def get_decl_name(decl)
      name = checked LibZ3.get_decl_name(Context, decl)
      String.new checked(LibZ3.get_symbol_string(Context, name))
    end

    def model_get_const_interp(model, decl)
      new_from_ast_pointer checked(LibZ3.model_get_const_interp(Context, model, decl))
    end

    {% for name in %w[optimize_get_statistics solver_get_statistics] %}
      def {{name.id}}(*args)
        unpack_statistics checked(LibZ3.{{name.id}}(Context, *args))
      end
    {% end %}

    private def unpack_statistics(stats)
      size = checked LibZ3.stats_size(Context, stats)
      result = {} of String => (UInt32 | Float64)
      size.times do |i|
        key = String.new checked(LibZ3.stats_get_key(Context, stats, i))
        if checked LibZ3.stats_is_uint(Context, stats, i)
          result[key] = checked LibZ3.stats_get_uint_value(Context, stats, i)
        else
          result[key] = checked LibZ3.stats_get_double_value(Context, stats, i)
        end
      end
      result
    end

    def read_ast_vector(vec)
      # Z3 hands back the vector at refcount 0, so hold a ref while we read it
      # or it gets reclaimed out from under us.
      LibZ3.ast_vector_inc_ref(Context, vec)
      check_error
      result = ast_vector_contents(vec)
      LibZ3.ast_vector_dec_ref(Context, vec)
      check_error
      result
    end

    # A vector we build ourselves, for the calls which take one. It comes back at
    # refcount 1 and the caller has to `release_ast_vector` it.
    def new_ast_vector(exprs)
      vec = checked LibZ3.mk_ast_vector(Context)
      LibZ3.ast_vector_inc_ref(Context, vec)
      check_error
      exprs.each do |expr|
        LibZ3.ast_vector_push(Context, vec, expr.to_unsafe)
        check_error
      end
      vec
    end

    def release_ast_vector(vec)
      LibZ3.ast_vector_dec_ref(Context, vec)
      check_error
    end

    private def ast_vector_contents(vec)
      size = checked LibZ3.ast_vector_size(Context, vec)
      result = [] of AnyExpr
      size.times do |i|
        result << new_from_ast_pointer(checked LibZ3.ast_vector_get(Context, vec, i))
      end
      result
    end

    def mk_symbol(name : String)
      checked LibZ3.mk_string_symbol(Context, name)
    end

    {% for name in %w[mk_func_decl mk_rec_func_decl] %}
      def {{name.id}}(name : String, domain : Array(LibZ3::Sort), range : LibZ3::Sort)
        checked LibZ3.{{name.id}}(Context, mk_symbol(name), domain.size, domain, range)
      end
    {% end %}

    def mk_fresh_func_decl(prefix : String, domain : Array(LibZ3::Sort), range : LibZ3::Sort)
      checked LibZ3.mk_fresh_func_decl(Context, prefix, domain.size, domain, range)
    end

    def mk_fresh_const(prefix : String, sort)
      checked LibZ3.mk_fresh_const(Context, prefix, sort)
    end

    def mk_app(decl, args)
      checked LibZ3.mk_app(Context, decl, args.size, args.map(&.to_unsafe))
    end

    def add_rec_def(decl, args, body)
      LibZ3.add_rec_def(Context, decl, args.size, args.map(&.to_unsafe), body)
      check_error
    end

    # The decl of a variable - `a` in `a + 1` - which is what Z3 wants wherever it
    # talks about one. Anything else is a term rather than a variable, and the two
    # calls which take one (`set_initial_value`, `model_has_interp`) both mean this.
    def const_decl(expr)
      unless get_ast_kind(expr) == LibZ3::AstKind::App
        raise Z3::Exception.new("Expected a variable, got #{expr}")
      end
      decl = checked LibZ3.get_app_decl(Context, checked(LibZ3.to_app(Context, expr)))
      unless get_arity(decl) == 0
        raise Z3::Exception.new("Expected a variable, got #{expr}")
      end
      decl
    end

    def mk_solver_for_logic(logic : String)
      checked LibZ3.mk_solver_for_logic(Context, mk_symbol(logic))
    end

    def optimize_assert_soft(optimize, expr, weight : String)
      # The third argument groups soft constraints, and wants a raw Z3 symbol nothing
      # here builds - a null one is Z3's own "no group"
      checked LibZ3.optimize_assert_soft(Context, optimize, expr, weight, Pointer(Void).null)
    end

    {% for name in %w[optimize_check solver_check_assumptions] %}
      def {{name.id}}(target, assumptions)
        checked LibZ3.{{name.id}}(Context, target, assumptions.size, assumptions.map(&.to_unsafe))
      end
    {% end %}

    # Answers the check result along with the consequences it found, since an
    # :unsat or :unknown means there are none to speak of
    def solver_get_consequences(solver, assumptions, variables)
      _assumptions = new_ast_vector(assumptions)
      _variables = new_ast_vector(variables)
      _consequences = new_ast_vector([] of AnyExpr)
      result = checked LibZ3.solver_get_consequences(Context, solver, _assumptions, _variables, _consequences)
      consequences = ast_vector_contents(_consequences)
      release_ast_vector(_assumptions)
      release_ast_vector(_variables)
      release_ast_vector(_consequences)
      {result, consequences}
    end

    def solver_cube(solver, variables, backtrack_level : UInt32)
      _variables = new_ast_vector(variables)
      result = read_ast_vector checked(LibZ3.solver_cube(Context, solver, _variables, backtrack_level))
      release_ast_vector(_variables)
      result
    end

    # What a model says a function does: the argument lists it had to pin down, and
    # the `else` branch which answers for every other one.
    def model_get_func_interp(model, decl)
      interp = checked LibZ3.model_get_func_interp(Context, model, decl)
      raise Z3::Exception.new("Model has no interpretation for this function") if interp.null?
      LibZ3.func_interp_inc_ref(Context, interp)
      check_error
      entries = [] of Tuple(Array(AnyExpr), AnyExpr)
      func_interp_get_num_entries(interp).times do |i|
        entry = func_interp_get_entry(interp, i)
        LibZ3.func_entry_inc_ref(Context, entry)
        check_error
        args = [] of AnyExpr
        func_entry_get_num_args(entry).times do |j|
          args << new_from_ast_pointer(func_entry_get_arg(entry, j))
        end
        entries << {args, new_from_ast_pointer(func_entry_get_value(entry))}
        LibZ3.func_entry_dec_ref(Context, entry)
        check_error
      end
      default = new_from_ast_pointer(func_interp_get_else(interp))
      LibZ3.func_interp_dec_ref(Context, interp)
      check_error
      {entries, default}
    end
  end
end
