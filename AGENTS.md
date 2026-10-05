# AGENTS.md

Crystal bindings for the Z3 theorem prover. A port of the Ruby z3 gem
(<https://github.com/taw/z3>, cloned locally at `~/github/z3`), which is the reference
for both behaviour and API design.

## Layout

* `src/z3.cr` - entry point, `AnyExpr` / `AnySort` unions, `Z3.*` module functions
* `src/z3/libz3.cr` - hand-written `lib LibZ3` bindings; add a call here before using it
* `src/z3/api.cr` - `Z3::API`, the only layer that calls `LibZ3`. Holds the global
  `Context` and wraps every call in `checked`, so Z3 errors raise `Z3::Exception`
  instead of returning null. New calls go into the macro name lists by signature shape.
* `src/z3/*_sort.cr` / `*_expr.cr` - one pair per sort (Bool, Int, Real, Bitvec, Char,
  String, Seq, Float, RoundingMode). Every sort answers `to_unsafe`, `var`, `[]`,
  `cast` and `from_ast`. Sorts with no parameters are singletons, so they are the class
  itself (`IntSort`), not an instance.
* `src/z3/core_ext.cr` - reversed operators (`2 + expr`, `1 < expr`), since Crystal has
  no `coerce`. Each new sort needs its block here.
* `src/z3/solver.cr`, `optimize.cr`, `checkable.cr`, `model.cr`, `func_decl.cr`,
  `func_interp.cr`, `check_result.cr` - everything above single expressions
* `spec/*_spec.cr` - unit specs; `spec/spec_helper.cr` has `have_solution` matchers that
  check constraints against the model rather than comparing strings
* `examples/*.cr` - executable puzzle solvers (`#!/usr/bin/env crystal`, mode +x)
* `spec/integration_spec.cr` + `spec/integration/*.txt` - runs each example and compares
  its output (trailing whitespace ignored) to the saved answer
* `_TODO.md` - parity status with the Ruby gem and the planned order of work. Read it
  before starting anything new, and update it when an item lands.

## Commands

```sh
crystal spec                    # everything, including integration (slow-ish)
crystal spec spec/int_spec.cr   # one file
crystal tool format             # code is kept in standard Crystal formatting
```

Requires libz3 **4.16.0 or newer**; older versions fail at link time. CI
(`.semaphore/semaphore.yml`) installs Z3 4.16.0 and Crystal 1.21 on Ubuntu 24.04 and
uses `CRYSTAL_LIBRARY_PATH` to outrank the image's ancient system libz3.

## Conventions

* Before designing a feature, read the gem's `lib/z3/sort/*.rb`, `lib/z3/expr/*.rb`
  and their comments - they record design decisions and Z3 misbehaviours. Mirror its
  structure, but let Crystal idiom win: `includes?` not `include?`, lowercase
  `Z3.distinct` not `Z3.Distinct`, `String` not `Symbol` for runtime names, compile-time
  type errors instead of runtime raises.
* `==` on an expression builds a `BoolExpr`, which is always truthy. Never put
  expressions in `Hash`/`Set` keys or use `includes?`/`index`/`uniq` on them; use
  arrays of tuples (`Z3.at_most([{a, 3}], 4)`) and `#same_term?` for identity.
* `!` isn't overloadable: negation is `~a`, "not this model" is `Model#negate`.
* Anything returning an element of runtime-known sort (`SeqExpr#[]`, `FuncDecl#[]`)
  returns `AnyExpr`; callers narrow with `.as(Z3::IntExpr)`.
* Comments explain *why* (Z3 quirks, divergence from the gem), in full sentences.
  Match the existing density.
* Ported examples get a saved answer in `spec/integration/` and an entry in
  `integration_spec.cr`. Examples with several valid answers are left out.
* Known gaps: no reference counting yet (`Solver`/`Model`/`Optimize` leak), output is
  Z3's S-expression `to_s` rather than the gem's infix printer.

## Environment rules

* Never install, upgrade, or symlink anything outside the repo (`brew install`,
  `/opt/homebrew` links, global config) without asking. If the toolchain is broken,
  say what's wrong and what would fix it, then stop.
