module Z3
  # Any expression, regardless of sort. This is what we can recover from a raw
  # AST pointer, since Z3 only tells us the sort kind at runtime.
  alias AnyExpr = BoolExpr | IntExpr | RealExpr | BitvecExpr

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
      get_algebraic_number_lower
      get_algebraic_number_upper
      get_ast_kind
      get_bool_value
      get_range
      is_algebraic_number
      is_eq_ast
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
      mk_sign_ext
      mk_solver
      mk_true
      mk_unary_minus
      mk_xor
      mk_zero_ext
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

    def model_to_string(model)
      String.new checked(LibZ3.model_to_string(Context, model))
    end

    def ast_to_string(ast)
      String.new checked(LibZ3.ast_to_string(Context, ast))
    end

    def get_numeral_string(ast)
      String.new checked(LibZ3.get_numeral_string(Context, ast))
    end

    def model_eval(model, ast, complete)
      result = LibZ3.model_eval(Context, model, ast, complete, out result_ast)
      check_error
      raise Z3::Exception.new("Cannot evaluate") unless result == true
      new_from_ast_pointer result_ast
    end

    def new_from_ast_pointer(_ast)
      _sort = checked LibZ3.get_sort(Context, _ast)
      sort_kind = checked LibZ3.get_sort_kind(Context, _sort)
      case sort_kind
      when LibZ3::SortKind::Bool
        BoolExpr.new(_ast)
      when LibZ3::SortKind::Int
        IntExpr.new(_ast)
      when LibZ3::SortKind::Real
        RealExpr.new(_ast)
      when LibZ3::SortKind::Bitvec
        size = checked LibZ3.get_bv_sort_size(Context, _sort)
        sort = BitvecSort.new(size)
        BitvecExpr.new(_ast, sort)
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

    def solver_to_string(solver)
      String.new checked(LibZ3.solver_to_string(Context, solver))
    end

    def solver_get_reason_unknown(solver)
      String.new checked(LibZ3.solver_get_reason_unknown(Context, solver))
    end

    def solver_get_assertions(solver)
      read_ast_vector checked(LibZ3.solver_get_assertions(Context, solver))
    end

    def solver_get_unsat_core(solver)
      read_ast_vector checked(LibZ3.solver_get_unsat_core(Context, solver))
    end

    def solver_get_statistics(solver)
      stats = checked LibZ3.solver_get_statistics(Context, solver)
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
      size = checked LibZ3.ast_vector_size(Context, vec)
      result = [] of AnyExpr
      size.times do |i|
        result << new_from_ast_pointer(checked LibZ3.ast_vector_get(Context, vec, i))
      end
      LibZ3.ast_vector_dec_ref(Context, vec)
      check_error
      result
    end
  end
end
