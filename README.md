# z3

Crystal API for Z3 Theorem Prover.

## Requirements

Z3 4.16.0 or newer. Older versions are missing API functions the bindings call, so
linking against them fails with `undefined reference to Z3_mk_seq_replace_all` and
friends. Note that distributions often package something much older - Ubuntu 24.04
ships 4.8.12 - so check `z3 --version` rather than assuming.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     z3:
       github: taw/crystal-z3
   ```

2. Run `shards install`

## Usage

```crystal
require "z3"
```

See `examples` folder for some examples.

## Limitations

Every Z3 expression defines `==` to build a `Z3::BoolExpr` instead of answering a
Crystal `Bool`, and a `Z3::BoolExpr` is always truthy. That makes expressions unsafe
to look up in any collection which compares elements with `==` - as `Hash` keys or
`Set` members, and with `Array#includes?`, `#index`, `#uniq` and `#-`:

```crystal
h = {a => 1, b => 2}
h[b]                 # => 1, not 2
[a, b].includes?(z)  # => true, for any z
```

Building such a collection is fine, only reading back is wrong.

The [Ruby z3 gem](https://github.com/taw/z3) has no such limitation, as Ruby's `Hash`
uses `#eql?` rather than `#==`, which leaves `==` free to build expressions. Crystal
has no `eql?` - a single `==` serves both roles.

A `Z3::SeqExpr` only knows its element sort at runtime, so everything which hands back
an element - `xs[0]`, `#first`, `#last`, `#elements` - answers a `Z3::AnyExpr` union
rather than the element's own class:

```crystal
xs = Z3.seq("xs", Z3::IntSort)
xs[0].as(Z3::IntExpr) == 5   # `xs[0] == 5` does not compile
```

That's the price of `Z3::SeqSort.new(Z3::CharSort)` handing back `Z3::StringSort`, the
way Z3 itself has only the one sort for both: a generic `SeqSort(IntSort)` could type
its elements, but then Seq(Char) could not be turned into something else.

## Contributing

1. Fork it (<https://github.com/taw/crystal-z3/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Tomasz Wegrzanowski](https://github.com/taw) - creator and maintainer
