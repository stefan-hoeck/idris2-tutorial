# Primitives

In the topics we covered so far, we hardly ever talked about primitive
types in Idris. They where around and we used them in some computations,
but I never really explained how they work and where they come from,
nor did I show in detail what we can and can't do with them.

```idris
module Tutorial.Prim

%default total
```

## How Primitives are Implemented

### A Short Note on Backends

According to [Wikipedia](https://en.wikipedia.org/wiki/Compiler),
a compiler is "a computer program that translates computer code
written in one programming language (the source language) into
another language (the target language)". The Idris compiler is
exactly that: A program translating programs written in Idris
into programs written in Chez Scheme. This scheme code is then
parsed and interpreted by a Chez Scheme interpreter, which must
be installed on the computers we use to run compiled Idris
programs.

But that's only part of the story. Idris 2 was from the beginning
designed to support different code generators (so called *backends*),
which allows us to write Idris code to target different platforms,
and your Idris installation comes with several additional
backends available. You can specify the backend to use with the `--cg` command
line argument (`cg` stands for *code generator*). For instance:

```sh
idris2 --cg racket
```

Here is a non-comprehensive list of the backends available with a
standard Idris installation (the name to be used in the command line
argument is given in parentheses):

* Racket Scheme (`racket`): This is a different flavour of the scheme
  programming language, which can be useful to use when Chez Scheme
  is not available on your operating system.
* NodeJS (`node`): This converts an Idris program to JavaScript.
* Browser (`javascript`): Another JavaScript backend which allows you to
  write web applications which run in the browser in Idris.
* RefC (`refc`): A backend compiling Idris to C code, which is then
  further compiled by a C compiler.

I plan to at least cover the JavaScript backends in some more detail
in another part of this Idris guide, as I use them pretty often myself.

There are also several external backends not officially supported by
the Idris project, amongst which are backends for compiling Idris code
to Java and Python. You can find a list of external backends on
the [Idris Wiki](https://github.com/idris-lang/Idris2/wiki/1-%5BLanguage%5D-External-backends).

### The Idris Primitives

A *primitive data type* is a type that is built into the Idris compiler
together with a set of *primitive functions*, which are used to perform
calculations on the primitives. You will therefore not find a definition
of a primitive type or function in the source code of the *Prelude*.

Here is again the list of primitive types in Idris:

* Signed, fixed precision integers:
  * `Int8`: Integer in the range [-128,127]
  * `Int16`: Integer in the range [-32768,32767]
  * `Int32`: Integer in the range [-2147483648,2147483647]
  * `Int64`: Integer in the range [-9223372036854775808,9223372036854775807]
* Unsigned, fixed precision integers:
  * `Bits8`: Integer in the range [0,255]
  * `Bits16`: Integer in the range [0,65535]
  * `Bits32`: Integer in the range [0,4294967295]
  * `Bits64`: Integer in the range [0,18446744073709551615]
* `Integer`: A signed, arbitrary precision integer.
* `Double`: A double precision (64 bit) floating point number.
* `Char`: A unicode character.
* `String`: A sequence of unicode characters.
* `%World`: A symbolic representation of the current world state.
  We learned about this when I showed you how `IO` is implemented.
  Most of the time, you will not handle values of this type in your own
  code.
* `Int`: This one is special. It is a fixed precision, signed integer,
   but the bit size is somewhat dependent on the backend and
   (maybe) platform we use.
   For instance, if you use the default Chez Scheme backend, `Int` is
   a 64 bit signed integer, while on the JavaScript backends it is a
   32 bit signed integer for performance reasons. Therefore, `Int` comes
   with very few guarantees, and you should use one of the well
   specified integer types listed above whenever possible.

It can be instructive to learn, where in the compiler's source
code the primitive types and functions are defined. This source
code can be found in folder `src` of the [Idris project](?TODO),
and the primitive types are the constant constructors of
`Core.TT.Constant`.

### Primitive Functions

All calculations operating on primitives are based on two
kinds of primitive functions: The ones built into the compiler
(see below) and the ones defined by programmers via the
foreign function interface (FFI), about which I'll talk in
another chapter.

Built-in primitive functions are functions known to the compiler
the definition of which can not be found in the *Prelude*. They
define the core functionality available for the primitive
types. Typically, you do not invoke these directly (although
it is perfectly fine to do so in most cases) but via functions
and interfaces exported by the *Prelude* or the *base* library.

For instance, the primitive function for adding two 8 bit
unsigned integers is `prim__add_Bits8`. You can inspect its
type and behavior at the REPL:

```repl
Tutorial.Prim> :t prim__add_Bits8
prim__add_Bits8 : Bits8 -> Bits8 -> Bits8
Tutorial.Prim> prim__add_Bits8 12 100
112
```

If you look at the source code implementing interface `Num`
for `Bits8`, you will see that the plus operator just invokes
`prim__add_Bits8` internally. The same goes for most of the other
functions in primitive interface implementations.
For instance, every primitive type with the exception of
`%World` comes with primitive comparison functions.
For `Bits8`, these are:
`prim__eq_Bits8`, `prim__gt_Bits8`, `prim__lt_Bits8`,
`prim__gte_Bits8`, and `prim__lte_Bits8`.
Note, that these functions do not return a `Bool` (which
is *not* a primitive type in Idris), but an `Int`. They are
therefore not as safe or convenient to use as the corresponding
operator implementations form interfaces `Eq` and `Comp`.
On the other hand, they do not go via a conversion to `Bool`
and might therefore perform slightly better in performance
critical code (which you can only identify after some
serious profiling).

Like with primitive types, the primitive functions are listed as
constructors in a data type (`Core.TT.PrimFn`) in the compiler
sources. We will look at most of these in the following sections.

### Consequences of being Primitive

Primitive functions and types are opaque to the compiler
in most regards: The compiler does not know about the internal
structure of a primitive value nor about the inner workings
of primitive functions. For instance, in the following recursive
function, *we* know that the argument in the recursive call
must be converging towards the base case (unless there is a bug
in the backend we use), but the compiler does not:

```idris
covering
replicateBits8' : Bits8 -> a -> List a
replicateBits8' 0 _ = []
replicateBits8' n v = v :: replicateBits8' (n - 1) v
```

In these cases, we either must be content with just a
*covering* function, or we use `assert_smaller` to
convince the totality checker (the preferred way):

```idris
replicateBits8 : Bits8 -> a -> List a
replicateBits8 0 _ = []
replicateBits8 n v = v :: replicateBits8 (assert_smaller n $ n - 1) v
```

I have shown you the risks of using `assert_smaller` before, so we
must be extra careful in making sure that the new function argument
is indeed smaller with relation to the base case.

While Idris knows nothing about the internal workings of primitives
and related functions, most of these functions still reduce during
evaluation when fed with values known at compile time. For instance,
we can trivially proof that for `Bits8` the following equation holds:

```idris
zeroBits8 : the Bits8 0 = 255 + 1
zeroBits8 = Refl
```

Having no clue about the internal structure of a primitive
nor about the implementations of primitive functions,
Idris can't help us proofing any *general* properties of such functions
and values. Here is an example to demonstrate this. Assume we'd
like to wrap a list in a data type indexed by the list's length:

```idris
data LenList : (n : Nat) -> Type -> Type where
  MkLenList : (as : List a) -> LenList (length as) a
```

When we concatenate two `LenList`s, the length indices
should be added. That's how list concatenation affects the
length of lists. We can safely teach Idris that this is true:

```idris
0 concatLen : (xs,ys : List a) -> length xs + length ys = length (xs ++ ys)
concatLen []        ys = Refl
concatLen (x :: xs) ys = cong S $ concatLen xs ys
```

With the above lemma, we can implement concatenation of `LenList`:

```idris
(++) : LenList m a -> LenList n a -> LenList (m + n) a
MkLenList xs ++ MkLenList ys =
  rewrite concatLen xs ys in MkLenList (xs ++ ys)
```

The same is not possible for strings. There are applications where
pairing a string with its length would be useful (for instance, if we
wanted to make sure that strings are getting strictly shorter
during parsing and will therefore eventually be wholly
consumed), but Idris cannot help us getting these things right.
There is no way to implement and thus proof the following
lemma in a safe way:

```idris
0 concatLenStr : (a,b : String) -> length a + length b = length (a ++ b)
```

### Believe Me!

In order to implement `concatLenStr`, we have to abandon all
safety and use the ten ton wrecking ball of type coercion:
`believe_me`. This primitive function allows us to freely
coerce a value of any type into a value of any other type.
Needless to say, this is only safe if we *really* know that we are doing:

```idris
concatLenStr a b = believe_me $ Refl {x = length a + length b}
```

The explicit assignment of variable `x` in `{x = length a + length b}`
is necessary, because otherwise Idris will complain about an *unsolved
hole*: It can't infer the type of parameter `x` in the `Refl`
constructor. We could assign any type to `x` here, because we
are passing the result to `believe_me` anyway, but I consider it
to be good practice to assign one of the two sides of the equality
to make our intention clear.

The higher the complexity of a primitive type, the riskier
it is to assume even the most basic properties for it to hold.
For instance, we might act under the delusion that floating
point addition is associative:

```idris
0 doubleAddAssoc : (x,y,z : Double) -> x + (y + z) = (x + y) + z
doubleAddAssoc x y z = believe_me $ Refl {x = x + (y + z)}
```

Well, guess what: That's a lie. And lies lead us straight
into the `Void`:

```idris
Tiny : Double
Tiny = 0.0000000000000001

One : Double
One = 1.0

wrong : (0 _ : 1.0000000000000002 = 1.0) -> Void
wrong Refl impossible

boom : Void
boom = wrong (doubleAddAssoc One Tiny Tiny)
```

<!-- vi: filetype=idris2
-->
