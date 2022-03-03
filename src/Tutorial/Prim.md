# Primitives

In the topics we covered so far, we hardly ever talked about primitive
types in Idris. They where around and we used them in some computations,
but I never really explained how they work and where they come from,
nor did I show in detail what we can and can't do with them.

```idris
module Tutorial.Prim

import Data.Bits

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
code can be found in folder `src` of the [Idris project](https://github.com/idris-lang/Idris2)
and the primitive types are the constant constructors of
data type `Core.TT.Constant`.

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

For instance, the primitive function for adding two eight bit
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

As with primitive types, the primitive functions are listed as
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
Needless to say, this is only safe if we *really* know what we are doing:

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

## Working with Strings

Module `Data.String` in *base* offers a rich set of functions
for working with strings. All these are based on the following
primitive operations built into the compiler:

* `prim__strLength`: Returns the length of a string.
* `prim__strHead`: Extracts the first character from a string.
* `prim__strTail`: Removes the first character from a string.
* `prim__strCons`: Prepends a character to a string.
* `prim__strAppend`: Appends two strings.
* `prim__strIndex`: Extracts a character at the given position from a string.
* `prim__strSubstr`: Extracts the substring between the given positions.

Needless to say, not all of these functions are total. Therefore, Idris
must make sure that invalid calls do not reduce during compile time, as
otherwise the compiler would crash. If, however we force the evaluation
of a partial primitive function by compiling and running the corresponding
program, this program will crash with an error:

```repl
Tutorial.Prim> prim__strTail ""
prim__strTail ""
Tutorial.Prim> :exec putStrLn (prim__strTail "")
Exception in substring: 1 and 0 are not valid start/end indices for ""
```

Note, how `prim__strTail ""` is not reduced at the REPL and how the
same expression leads to a runtime exception if we compile and
execute the program. Valid calls to `prim__strTail` are reduced
just fine, however:

```idris
tailExample : prim__strTail "foo" = "oo"
tailExample = Refl
```

### Pack and Unpack

Two of the most important functions for working with strings
are `unpack` and `pack`, which convert a string to a list
of characters and vice versa. This allows us to conveniently
implement many string operations by iterating or folding
over the list of characters instead. This might not always
be the most efficient thing to do, but unless you plan to
handle very large amounts of text, they work and perform
reasonably well.

### String Interpolation

Idris allows us to include arbitrary string expressions in
a string literal by wrapping them in curly braces, the first
of which has to be escaped with a backslash. For instance:

```idris
interpEx1 : Bits64 -> Bits64 -> String
interpEx1 x y = "\{show x} + \{show y} = \{show $ x + y}"
```

This is a very convenient way to assemble complex strings
from values of different types.
In addition, there is interface `Interpolation`, which
allows us to use values in interpolated strings without
having to convert them to strings first:

```idris
data Element = H | He | C | N | O | F | Ne

Formula : Type
Formula = List (Element,Nat)

Interpolation Element where
  interpolate H  = "H"
  interpolate He = "He"
  interpolate C  = "C"
  interpolate N  = "N"
  interpolate O  = "O"
  interpolate F  = "F"
  interpolate Ne = "Ne"

Interpolation (Element,Nat) where
  interpolate (_, 0) = ""
  interpolate (x, 1) = "\{x}"
  interpolate (x, k) = "\{x}\{show k}"

Interpolation Formula where
  interpolate = foldMap interpolate

ethanol : String
ethanol = "The formulat of ethanol is: \{[(C,2),(H,6),(O, the Nat 1)]}"
```

### Raw and Multiline String Literals

In string literals, we have to escape certain characters
like quotes, backslashes or new line characters. For instance:

```idris
escapeExample : String
escapeExample = "A quote: \". \nThis is on a new line.\nA backslash: \\"
```

Idris allows us to enter raw string literals, where there
is no need to escape quotes and backslashes, by pre- and
postfixing the wrapping quote characters with the same number
of hash characters. For instance:

```idris
rawExample : String
rawExample = #"A quote: ". A blackslash: \"#

rawExample2 : String
rawExample2 = ##"A quote: ". A blackslash: \"##
```

With raw string literals, it is still possible to use string
interpolation, but the opening curly brace as to be prefixed
with a backslash and the same number of hashes as are being used
for opening and closing the string literal:

```idris
rawInterpolExample : String
rawInterpolExample = ##"An interpolated "string": \##{rawExample}"##
```

Finally, Idris also allows us to conveniently write multiline
strings. These can be pre- and postfixed with hashes if we want
raw multiline string literals, and they also can be combined with
string interpolation. Multiline literals are opened and closed with
triple quote characters. Indenting the closing triple quotes
allows us to indent the whole multiline literal. White space used
for indentation will not appear in the resulting string. For instance:

```idris
multiline1 : String
multiline1 = """
  And I raise my head and stare
  Into the eyes of a stranger
  I've always known that the mirror never lies
  People always turn away
  From the eyes of a stranger
  Afraid to see what hides behind the stare
  """

multiline2 : String
multiline2 = #"""
  An example for a simple expression:
  "foo" ++ "bar".
  This is reduced to "\#{"foo" ++ "bar"}".
  """#
```

Make sure to look at the example strings at the
REPL to see the effect of interpolation and raw string
literals and compare it with the syntax we used.

### Exercises part 1

In these exercises, you are supposed to implement a bunch
of utility functions for consuming and converting strings.
I don't give the expected types here, because you are
supposed to come up with those yourself.

1. Implement functions similar to `map`, `filter`, and
   `mapMaybe` for strings. The output type of these
   should always be a string.

2. Implement functions similar to `foldl` and `foldMap`
   for strings.

3. Implement a function similar to `traverse`
   for strings. The output type should be a wrapped string.

4. Implement the bind operator for strings. The output type
   should again be a string.

## Integers

As listed at the beginning of this chapter, Idris provides different
fixed-precision signed and unsigned integer types as well as `Integer`,
an arbitrary precision signed integer type.
All of them come with the following primitive functions (given
here for `Bits8` as an example):

* `prim__add_Bits8`: Integer addition.
* `prim__sub_Bits8`: Integer subtraction.
* `prim__mul_Bits8`: Integer multiplication.
* `prim__div_Bits8`: Integer division.
* `prim__mod_Bits8`: Modulo function.
* `prim__shl_Bits8`: Bitwise left shift.
* `prim__shr_Bits8`: Bitwise right shift.
* `prim__and_Bits8`: Bitwise *and*.
* `prim__or_Bits8`: Bitwise *or*.
* `prim__xor_Bits8`: Bitwise *xor*.

Typically, you use the functions for addition and multiplication
through the operators from interface `Num`, the function
for subtraction through interface `Neg`, and the functions
for division (`div` and `mod`) through interface `Integral`.
The bitwise operations are available through interfaces
`Data.Bits.Bits` and `Data.Bits.FiniteBits`.

For all integral types, the following laws are assumed to
hold for numeric operations (`x`, `y`, and `z` are
arbitrary value of the same primitive integral type):

* `x + y = y + x`: Addition is commutative.
* `x + (y + z) = (x + y) + z`: Addition is associative.
* `x + 0 = x`: Zero is the neutral element of addition.
* `x - x = x + (-x) = 0`: `-x` is the additive inverse of `x`.
* `x * y = y * x`: Multiplication is commutative.
* `x * (y * z) = (x * y) * z`: Multiplication is associative.
* `x * 1 = x`: One is the neutral element of multiplication.
* `x * 0 = 0`: Multiplication with zero equals zero.
* `x * (y + z) = x * y + x * z`: The distributive law holds.
* ``y * (x `div` y) + (x `mod` y) = x`` (for `y /= 0`).

Please note, that the officially supported backends use
*Euclidian modulus* for calculating `mod`:
For `y /= 0`, `x `mod` y` is always a non-negative value
strictly smaller than `abs y`, so that the law given above
does hold. If `x` or `y` are negative numbers, this is different
to what many other languages do but for good reasons as explained
in the following [article](https://www.microsoft.com/en-us/research/publication/division-and-modulus-for-computer-scientists/).

### Unsigned Integers

The unsigned fixed precision integer types (`Bits8`, `Bits16`,
`Bits32`, and `Bits64`) come with implementations of all
integral interfaces (`Num`, `Neg`, and `Integral`) and
the two interfaces for bitwise operations (`Bits` and `FiniteBits`).
All functions with the exception of `div` and `mod` are
total. Overflows are handled by calculating the remainder
module `2^bitsize`. For instance, for `Bits8`, all operations
calculate their results modulo 256:

```repl
Main> the Bits8 255 + 1
0
Main> the Bits8 255 + 255
254
Main> the Bits8 128 * 2 + 7
7
Main> the Bits8 12 - 13
255
```

### Signed Integers

Like the unsigned integer types, the signed fixed precision
integer types (`Int8`, `Int16`, `Int32`, and `Int64`) come with
implementations of all integral interfaces and
the two interfaces for bitwise operations (`Bits` and `FiniteBits`).
Overflows are handled by calculating the remainder
module `2^bitsize` and adding the lower bound (a negative number)
if the result is still out of range. For instance, for `Int8`, all operations
calculate their results modulo 256, subtracting 128 if the
result is still out of bounds:

```repl
Main> the Int8 2 * 127
-2
Main> the Int8 3 * 127
125
```

### Bitwise Operations

Module `Data.Bits` exports interfaces for performing bitwise
operations on integral types. I'm going to show a couple of
examples on unsigned 8-bit numbers (`Bits8`) to explain the concept
to readers new to bitwise arithmetics. Note, that this is much easier
to grasp for unsigned integer types than for the signed versions.
Those have to include information about the *sign* of numbers in their
bit pattern, and it is assumed that signed integers in Idris use
a [two's complement representation](https://en.wikipedia.org/wiki/Two%27s_complement),
about which I will not go into the details here.

An unsigned 8-bit binary number is represented internally as
a sequence of eight bits (with values 0 or 1), each of which
corresponds to a power of 2. For instance,
the number 23 (= 16 + 4 + 2 + 1) is represented as `0001 0111`:

```repl
23 in binary:    0  0  0  1    0  1  1  1

Bit number:      7  6  5  4    3  2  1  0
Decimal value: 128 64 32 16    8  4  2  1
```

We can use function `testBit` to check if the bit at the given
position is set or not:

```repl
Tutorial.Prim> testBit (the Bits8 23) 0
True
Tutorial.Prim> testBit (the Bits8 23) 1
True
Tutorial.Prim> testBit (the Bits8 23) 3
False
```

Likewise, we can use functions `setBit` and `clearBit` to
set or unset a bit at a certain position:

```repl
Tutorial.Prim> setBit (the Bits8 23) 3
31
Tutorial.Prim> clearBit (the Bits8 23) 2
19
```

There are also operators `(.&.)` (bitwise *and*) and `(.|.)`
(bitwise *or*) as well as function `xor` (bitwise *exclusive or*)
for performing boolean operations on integral values.
For instance `x .&. y` has exactly those bits set, which both `x`
and `y` have set:

```repl
Tutorial.Prim> the Bits8 23 .&. 11
3
Tutorial.Prim> the Bits8 23 .&. 15
7
```

Finally, it is possible to shift all bits to the right or left
by a certain number of steps by using functions `shiftR` and
`shiftL`, respectively (overflowing bits will just be dropped).
A left shift can therefore be viewed as a multiplication by a
power of two, while a right shift can be seen as a division
by power of two:

```repl
Tutorial.Prim> the Bits8 22 `shiftL` 2
88
Tutorial.Prim> the Bits8 22 `shiftR` 1
11
```

### Integer Literals

So far, we only require an implementation of `Num` in order to
be able to use integer literals for a given type. However,
actually it is only necessary to implement a function `fromInteger`
converting an `Integer` to the type in question. As we will
see in the last section, such a function can even restrict
the values allowed as valid literals.

For instance, assume we'd like to define a data type for
representing the charge of a chemical molecule. Such a value
can be positive or negative and (theoretically) of almost
arbitrary magnitude:

```idris
record Charge where
  constructor MkCharge
  value : Integer
```

It makes sense to be able to sum up charges, but not to
multiply them. They should therefore have an implementation
of `Monoid` but not of `Num`. Still, we'd like to have
the convenience of integer literals when using constant
charges at compile time. Here's how to do this:

```idris
fromInteger : Integer -> Charge
fromInteger = MkCharge

Semigroup Charge where
  x <+> y = MkCharge $ x.value + y.value

Monoid Charge where
  neutral = 0
```

In addition to the well known decimal literals, it is also
possible to use integer literals in binary, octal, or
hexadecimal representation. These have to be prefixed
with a zero following by a `b`, `o`, or `x` for
binary, octal, and hexadecimal, respectively:

```repl
Tutorial.Prim> 0b1101
13
Tutorial.Prim> 0o773
507
Tutorial.Prim> 0xffa2
65442
```

### Exercises part 2

1. Define a wrapper record for integral values and implement
   `Monoid` so that `(<+>)` corresponds to `(.&.)`.

   Hint: Have a look at the functions available from interface
   `Bits` to find a value suitable as the neutral element.

2. Define a wrapper record for integral values and implement
   `Monoid` so that `(<+>)` corresponds to `(.|.)`.

3. Use bitwise operations to implement a function, which tests if
   a given value of type `Bits64` is even or not.

4. Convert a value of type `Bits64` to a string in binary representation.

5. Convert a value of type `Bits64` to a string in hexadecimal representation.

   Hint: Use `shiftR` and `(.|. 15)` to access subsequent packages of
   four bits.

## Refined Primitives


<!-- vi: filetype=idris2
-->
