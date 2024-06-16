# Primitives

In the topics we covered so far, we hardly ever talked about primitive
types in Idris. They were around and we used them in some computations,
but I never really explained how they work and where they come from,
nor did I show in detail what we can and can't do with them.

```idris
module Tutorial.Prim

import Data.Bits
import Data.String

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
* Node.js (`node`): This converts an Idris program to JavaScript.
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
operator implementations from interfaces `Eq` and `Comp`.
On the other hand, they do not go via a conversion to `Bool`
and might therefore perform slightly better in performance
critical code (which you can only identify after some
serious profiling).

As with primitive types, the primitive functions are listed as
constructors in a data type (`Core.TT.PrimFn`) in the compiler
sources. We will look at most of these in the following sections.

### Consequences of being Primitive

Primitive functions and types are opaque to the compiler
in most regards: They have to be defined and implemented by each
backend individually, therefore, the compiler knows nothing about the inner
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

<!-- markdownlint-disable MD026 -->
### Believe Me!
<!-- markdownlint-enable MD026 -->

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

Here's what happens in the code above: The call to `doubleAddAssoc`
returns a proof that `One + (Tiny + Tiny)` is equal to
`(One + Tiny) + Tiny`. But `One + (Tiny + Tiny)` equals
`1.0000000000000002`, while `(One + Tiny) + Tiny` equals `1.0`.
We can therefore pass our (wrong) proof to `wrong`, because it
is of the correct type, and from this follows a proof of `Void`.

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
interpolation, but the opening curly brace has to be prefixed
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
allows us to indent the whole multiline literal. Whitespace used
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
* `x * (y + z) = x * y + x * z`: The distributive law holds.
* ``y * (x `div` y) + (x `mod` y) = x`` (for `y /= 0`).

Please note, that the officially supported backends use
*Euclidian modulus* for calculating `mod`:
For `y /= 0`, ``x `mod` y`` is always a non-negative value
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
modulo `2^bitsize`. For instance, for `Bits8`, all operations
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
modulo `2^bitsize` and subtracting `2^bitsize` if the result is still out of
range. For instance, for `Int8`, all operations calculate their results modulo
256, subtracting 256 if the result is still out of bounds:

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
and `y` have set, while `x .|. y` has all bits set that are either
set in `x` or `y` (or both), and ``x `xor` y`` has those bits
set that are set in exactly one of the two values:

```repl
23 in binary:          0  0  0  1    0  1  1  1
11 in binary:          0  0  0  0    1  0  1  1

23 .&. 11 in binary:   0  0  0  0    0  0  1  1
23 .|. 11 in binary:   0  0  0  1    1  1  1  1
23 `xor` 11 in binary: 0  0  0  1    1  1  0  0
```

And here are the examples at the REPL:

```repl
Tutorial.Prim> the Bits8 23 .&. 11
3
Tutorial.Prim> the Bits8 23 .|. 11
31
Tutorial.Prim> the Bits8 23 `xor` 11
28
```

Finally, it is possible to shift all bits to the right or left
by a certain number of steps by using functions `shiftR` and
`shiftL`, respectively (overflowing bits will just be dropped).
A left shift can therefore be viewed as a multiplication by a
power of two, while a right shift can be seen as a division
by a power of two:

```repl
22 in binary:            0  0  0  1    0  1  1  0

22 `shiftL` 2 in binary: 0  1  0  1    1  0  0  0
22 `shiftR` 1 in binary: 0  0  0  0    1  0  1  1
```

And at the REPL:

```repl
Tutorial.Prim> the Bits8 22 `shiftL` 2
88
Tutorial.Prim> the Bits8 22 `shiftR` 1
11
```

Bitwise operations are often used in specialized code or
certain high-performance applications. As programmers, we
have to know they exist and how they work.

### Integer Literals

So far, we always required an implementation of `Num` in order to
be able to use integer literals for a given type. However,
it is actually only necessary to implement a function `fromInteger`
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

#### Alternative Bases

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

   Hint: Use `shiftR` and `(.&. 15)` to access subsequent packages of
   four bits.

## Refined Primitives

We often do not want to allow all values of a type in a certain
context. For instance, `String` as an arbitrary sequence of
UTF-8 characters (several of which are not even printable), is
too general most of the time. Therefore, it is usually advisable
to rule out invalid values early on, by pairing a value with
an erased proof of validity.

We have learned how we can write elegant predicates, with
which we can proof our functions to be total, and from which we
can - in the ideal case - derive other, related predicates. However,
when we define predicates on primitives they are to a certain degree
doomed to live in isolation, unless we come up with a set of
primitive axioms (implemented most likely using `believe_me`), with
which we can manipulate our predicates.

### Use Case: ASCII Strings

String encodings is a difficult topic, so in many low level routines
it makes sense to rule out most characters from the beginning. Assume
therefore, we'd like to make sure the strings we accept in our
application only consist of ASCII characters:

```idris
isAsciiChar : Char -> Bool
isAsciiChar c = ord c <= 127

isAsciiString : String -> Bool
isAsciiString = all isAsciiChar . unpack
```

We can now *refine* a string value by pairing it with an erased
proof of validity:

```idris
record Ascii where
  constructor MkAscii
  value : String
  0 prf : isAsciiString value === True
```

It is now *impossible* to at runtime or compile time create
a value of type `Ascii` without first validating the wrapped
string. With this, it is already pretty easy to safely wrap strings at
compile time in a value of type `Ascii`:

```idris
hello : Ascii
hello = MkAscii "Hello World!" Refl
```

And yet, it would be much more convenient to still use string
literals for this, without having to sacrifice the comfort of
safety. To do so, we can't use interface `FromString`, as its
function `fromString` would force us to convert *any* string,
even an invalid one. However, we actually don't need an implementation of
`FromString` to support string literals, just like we didn't
require an implementation of `Num` to support integer literals.
What we really need is a function named `fromString`. Now, when
string literals are desugared, they are converted to invocations
of `fromString` with the given string value as its argument.
For instance, literal `"Hello"` gets desugared to `fromString "Hello"`.
This happens before type checking and filling in of (auto) implicit
values. It is therefore perfectly fine, to define a custom `fromString`
function with an erased auto implicit argument as a proof of
validity:

```idris
fromString : (s : String) -> {auto 0 prf : isAsciiString s === True} -> Ascii
fromString s = MkAscii s prf
```

With this, we can use (valid) string literals for coming up with
values of type `Ascii` directly:

```idris
hello2 : Ascii
hello2 = "Hello World!"
```

In order to at runtime create values of type `Ascii` from strings
of an unknown source, we can use a refinement function returning
some kind of failure type:

```idris
test : (b : Bool) -> Dec (b === True)
test True  = Yes Refl
test False = No absurd

ascii : String -> Maybe Ascii
ascii x = case test (isAsciiString x) of
  Yes prf   => Just $ MkAscii x prf
  No contra => Nothing
```

#### Disadvantages of Boolean Proofs

For many use cases, what we described above for ASCII strings can
take us very far. However, one drawback of this approach is that we
can't safely perform any computations with the proofs at hand.

For instance, we know it will be perfectly fine to concatenate
two ASCII strings, but in order to convince Idris of this, we
will have to use `believe_me`, because we will not be able to
proof the following lemma otherwise:

```idris
0 allAppend :  (f : Char -> Bool)
            -> (s1,s2 : String)
            -> (p1 : all f (unpack s1) === True)
            -> (p2 : all f (unpack s2) === True)
            -> all f (unpack (s1 ++ s2)) === True
allAppend f s1 s2 p1 p2 = believe_me $ Refl {x = True}

namespace Ascii
  export
  (++) : Ascii -> Ascii -> Ascii
  MkAscii s1 p1 ++ MkAscii s2 p2 =
    MkAscii (s1 ++ s2) (allAppend isAsciiChar s1 s2 p1 p2)
```

The same goes for all operations extracting a substring from
a given string: We will have to implement according rules using
`believe_me`. Finding a reasonable set of axioms to conveniently
deal with refined primitives can therefore be challenging at times,
and whether such axioms are even required very much depends
on the use case at hand.

### Use Case: Sanitized HTML

Assume you write a simple web application for scientific
discourse between registered users. To keep things simple, we
only consider unformatted text input here. Users can write arbitrary
text in a text field and upon hitting Enter, the message is
displayed to all other registered users.

Assume now a user decides to enter the following text:

```html
<script>alert("Hello World!")</script>
```

Well, it could have been (much) worse. Still, unless we take measures
to prevent this from happening, this might embed a JavaScript
program in our web page we never intended to have there!
What I described here, is a well known security vulnerability called
[cross-site scripting](https://en.wikipedia.org/wiki/Cross-site_scripting).
It allows users of web pages to enter malicious JavaScript code in
text fields, which will then be included in the page's HTML structure
and executed when it is being displayed to other users.

We want to make sure, that this cannot happen on our own web page.
In order to protect us from this attack, we could for instance disallow
certain characters like `'<'` or `'>'` completely (although this might not
be enough!), but if our chat service is targeted at programmers,
this will be overly restrictive. An alternative
is to escape certain characters before rendering them on the page.

```idris
escape : String -> String
escape = concat . map esc . unpack
  where esc : Char -> String
        esc '<'  = "&lt;"
        esc '>'  = "&gt;"
        esc '"'  = "&quot;"
        esc '&'  = "&amp;"
        esc '\'' = "&apos;"
        esc c    = singleton c
```

What we now want to do is to store a string together with
a proof that is was properly escaped. This is another form
of existential quantification: "Here is a string, and there
once existed another string, which we passed to `escape`
and arrived at the string we have now". Here's how to encode
this:

```idris
record Escaped where
  constructor MkEscaped
  value    : String
  0 origin : String
  0 prf    : escape origin === value
```

Whenever we now embed a string of unknown origin in our web page,
we can request a value of type `Escaped` and have the very
strong guarantee that we are no longer vulnerable to cross-site
scripting attacks. Even better, it is also possible to safely
embed string literals known at compile time without the need
to escape them first:

```idris
namespace Escaped
  export
  fromString : (s : String) -> {auto 0 prf : escape s === s} -> Escaped
  fromString s = MkEscaped s s prf

escaped : Escaped
escaped = "Hello World!"
```

### Exercises part 3

In this massive set of exercises, you are going to build
a small library for working with predicates on primitives.
We want to keep the following goals in mind:

* We want to use the usual operations of propositional logic to
  combine predicates: Negation, conjuction (logical *and*),
  and disjunction (logical *or*).
* All predicates should be erased at runtime. If we proof
  something about a primitive number, we want to make sure
  not to carry around a huge proof of validity.
* Calculations on predicates should make no appearance
  at runtime (with the exception of `decide`; see below).
* Recursive calculations on predicates should be tail recursive if
  they are used in implementations of `decide`. This might be tough
  to achieve. If you can't find a tail recursive
  solution for a given problem, use what feels most natural
  instead.

A note on efficiency: In order to be able to run
computations on our predicates, we try to convert primitive
values to algebraic data types as often and as soon as possible:
Unsigned integers will be converted to `Nat` using `cast`,
and strings will be converted to `List Char` using `unpack`.
This allows us to work with proofs on `Nat` and `List` most
of the time, and such proofs can be implemented without
resorting to `believe_me` or other cheats. However, the one
advantage of primitive types over algebraic data types is
that they often perform much better. This is especially
critical when comparing integral types with `Nat`: Operations
on natural numbers often run with `O(n)` time complexity,
where `n` is the size of one of the natural numbers involved,
while with `Bits64`, for instance, many operations run in fast constant
time (`O(1)`). Luckily, the Idris compiler optimizes many
functions on natural number to use the corresponding `Integer`
operations at runtime. This has the advantage that we can
still use proper induction to proof stuff about natural
numbers at compile time, while getting the benefit of fast
integer operations at runtime. However, operations on `Nat` do
run with `O(n)` time complexity and *compile time*. Proofs
working on large natural number will therefore drastically
slow down the compiler. A way out of this is discussed at
the end of this section of exercises.

Enough talk, let's begin!
To start with, you are given the following utilities:

```idris
-- Like `Dec` but with erased proofs. Constructors `Yes0`
-- and `No0` will be converted to constants `0` and `1` by
-- the compiler!
data Dec0 : (prop : Type) -> Type where
  Yes0 : (0 prf : prop) -> Dec0 prop
  No0  : (0 contra : prop -> Void) -> Dec0 prop

-- For interfaces with more than one parameter (`a` and `p`
-- in this example) sometimes one parameter can be determined
-- by knowing the other. For instance, if we know what `p` is,
-- we will most certainly also know what `a` is. We therefore
-- specify that proof search on `Decidable` should only be
-- based on `p` by listing `p` after a vertical bar: `| p`.
-- This is like specifing the search parameter(s) of
-- a data type with `[search p]` as was shown in the chapter
-- about predicates.
-- Specifying a single search parameter as shown here can
-- drastically help with type inference.
interface Decidable (0 a : Type) (0 p : a -> Type) | p where
  decide : (v : a) -> Dec0 (p v)

-- We often have to pass `p` explicitly in order to help Idris with
-- type inference. In such cases, it is more convenient to use
-- `decideOn pred` instead of `decide {p = pred}`.
decideOn : (0 p : a -> Type) -> Decidable a p => (v : a) -> Dec0 (p v)
decideOn _ = decide

-- Some primitive predicates can only be reasonably implemented
-- using boolean functions. This utility helps with decidability
-- on such proofs.
test0 : (b : Bool) -> Dec0 (b === True)
test0 True  = Yes0 Refl
test0 False = No0 absurd
```

We also want to run decidable computations at compile time. This
is often much more efficient than running a direct proof search on
an inductive type. We therefore come up with a predicate witnessing
that a `Dec0` value is actually a `Yes0` together with two
utility functions:

```idris
data IsYes0 : (d : Dec0 prop) -> Type where
  ItIsYes0 : {0 prf : _} -> IsYes0 (Yes0 prf)

0 fromYes0 : (d : Dec0 prop) -> (0 prf : IsYes0 d) => prop
fromYes0 (Yes0 x) = x
fromYes0 (No0 contra) impossible

0 safeDecideOn :  (0 p : a -> Type)
               -> Decidable a p
               => (v : a)
               -> (0 prf : IsYes0 (decideOn p v))
               => p v
safeDecideOn p v = fromYes0 $ decideOn p v
```

Finally, as we are planning to refine mostly primitives, we will
at times require some sledge hammer to convince Idris that
we know what we are doing:

```idris
-- only use this if you are sure that `decideOn p v`
-- will return a `Yes0`!
0 unsafeDecideOn : (0 p : a -> Type) -> Decidable a p => (v : a) -> p v
unsafeDecideOn p v = case decideOn p v of
  Yes0 prf => prf
  No0  _   =>
    assert_total $ idris_crash "Unexpected refinement failure in `unsafeRefineOn`"
```

1. We start with equality proofs. Implement `Decidable` for
   `Equal v`.

   Hint: Use `DecEq` from module `Decidable.Equality` as a constraint
         and make sure that `v` is available at runtime.

2. We want to be able to negate a predicate:

   ```idris
   data Neg : (p : a -> Type) -> a -> Type where
     IsNot : {0 p : a -> Type} -> (contra : p v -> Void) -> Neg p v
   ```

   Implement `Decidable` for `Neg p` using a suitable constraint.

3. We want to describe the conjunction of two predicates:

   ```idris
   data (&&) : (p,q : a -> Type) -> a -> Type where
     Both : {0 p,q : a -> Type} -> (prf1 : p v) -> (prf2 : q v) -> (&&) p q v
   ```

   Implement `Decidable` for `(p && q)` using suitable constraints.

4. Come up with a data type called `(||)` for the
   disjunction (logical *or*) of two predicates and implement
   `Decidable` using suitable constraints.

5. Proof [De Morgan's laws](https://en.wikipedia.org/wiki/De_Morgan%27s_laws)
   by implementing the following propositions:

   ```idris
   negOr : Neg (p || q) v -> (Neg p && Neg q) v

   andNeg : (Neg p && Neg q) v -> Neg (p || q) v

   orNeg : (Neg p || Neg q) v -> Neg (p && q) v
   ```

   The last of De Morgan's implications is harder to type and proof
   as we need a way to come up with values of type `p v` and `q v`
   and show that not both can exist. Here is a way to encode this
   (annotated with quantity 0 as we will need to access an erased
   contraposition):

   ```idris
   0 negAnd :  Decidable a p
            => Decidable a q
            => Neg (p && q) v
            -> (Neg p || Neg q) v
   ```

   When you implement `negAnd`, remember that you can freely access
   erased (implicit) arguments, because `negAnd` itself can only be
   used in an erased context.

So far, we implemented the tools to algebraically describe
and combine several predicate. It is now time to come up
with some examples. As a first use case, we will focus on
limiting the valid range of natural numbers. For this,
we use the following data type:

```idris
-- Proof that m <= n
data (<=) : (m,n : Nat) -> Type where
  ZLTE : 0 <= n
  SLTE : m <= n -> S m <= S n
```

This is similar to `Data.Nat.LTE` but I find operator
notation often to be clearer.
We also can define and use the following aliases:

```repl
(>=) : (m,n : Nat) -> Type
m >= n = n <= m

(<) : (m,n : Nat) -> Type
m < n = S m <= n

(>) : (m,n : Nat) -> Type
m > n = n < m

LessThan : (m,n : Nat) -> Type
LessThan m = (< m)

To : (m,n : Nat) -> Type
To m = (<= m)

GreaterThan : (m,n : Nat) -> Type
GreaterThan m = (> m)

From : (m,n : Nat) -> Type
From m = (>= m)

FromTo : (lower,upper : Nat) -> Nat -> Type
FromTo l u = From l && To u

Between : (lower,upper : Nat) -> Nat -> Type
Between l u = GreaterThan l && LessThan u
```

6. Coming up with a value of type `m <= n` by pattern
   matching on `m` and `n` is highly inefficient for
   large values of `m`, as it will require `m` iterations
   to do so. However, while in an erased context, we don't
   need to hold a value of type `m <= n`. We only need to
   show, that such a value follows from a more efficient
   computation. Such a computation is `compare` for natural
   numbers: Although this is implemented in the *Prelude* with
   a pattern match on its arguments, it is optimized
   by the compiler to a comparison of integers which runs
   in constant time even for very large numbers.
   Since `Prelude.(<=)` for natural numbers is implemented in terms of
   `compare`, it runs just as efficiently.

   We therefore need to proof the following two lemmas (make
   sure to not confuse `Prelude.(<=)` with `Prim.(<=)` in
   these declarations):

   ```idris
   0 fromLTE : (n1,n2 : Nat) -> (n1 <= n2) === True -> n1 <= n2

   0 toLTE : (n1,n2 : Nat) -> n1 <= n2 -> (n1 <= n2) === True
   ```

   They come with a quantity of 0, because they are just as inefficient
   as the other computations we discussed above. We therefore want
   to make absolutely sure that they will never be used at runtime!

   Now, implement `Decidable Nat (<= n)`, making use of `test0`,
   `fromLTE`, and `toLTE`.
   Likewise, implement `Decidable Nat (m <=)`, because we require
   both kinds of predicates.

   Note: You should by now figure out yourself that `n` must be
   available at runtime and how to make sure that this is the case.

7. Proof that `(<=)` is reflexive and transitive by declaring and
   implementing corresponding propositions. As we might require
   the proof of transitivity to chain several values of type `(<=)`,
   it makes sense to also define a short operator alias for this.

8. Proof that from `n > 0` follows `IsSucc n` and vise versa.

9. Declare and implement safe division and modulo functions
   for `Bits64`, by requesting an erased proof that
   the denominator is strictly positive when cast to a natural
   number. In case of the modulo function, return a refined
   value carrying an erased proof that the result is strictly
   smaller than the modulus:

   ```idris
   safeMod :  (x,y : Bits64)
           -> (0 prf : cast y > 0)
           => Subset Bits64 (\v => cast v < cast y)
   ```

10. We will use the predicates and utilities we defined so
    far to convert a value of type `Bits64` to a string
    of digits in base `b` with `2 <= b && b <= 16`.
    To do so, implement the following skeleton definitions:

    ```idris
    -- this will require some help from `assert_total`
    -- and `idris_crash`.
    digit : (v : Bits64) -> (0 prf : cast v < 16) => Char

    record Base where
      constructor MkBase
      value : Bits64
      0 prf : FromTo 2 16 (cast value)

    base : Bits64 -> Maybe Base

    namespace Base
      public export
      fromInteger : (v : Integer) -> {auto 0 _ : IsJust (base $ cast v)} -> Base
    ```

    Finally, implement `digits`, using `safeDiv` and `safeMod`
    in your implementation. This might be challenging, as you will
    have to manually transform some proofs to satisfy the type
    checker. You might also require `assert_smaller` in the
    recursive step.

    ```idris
    digits : Bits64 -> Base -> String
    ```

We will now turn our focus on strings. Two of the most
obvious ways in which we can restrict the strings we
accept are by limiting the set of characters and
limiting their lengths. More advanced refinements might
require strings to match a certain pattern or regular
expression. In such cases, we might either go for a
boolean check or use a custom data type representing the
different parts of the pattern, but we will not cover
these topics here.

11. Implement the following aliases for useful predicates on
    characters.

    Hint: Use `cast` to convert characters to natural numbers,
    use `(<=)` and `InRange` to specify regions of characters,
    and use `(||)` to combine regions of characters.

    ```idris
    -- Characters <= 127
    IsAscii : Char -> Type

    -- Characters <= 255
    IsLatin : Char -> Type

    -- Characters in the interval ['A','Z']
    IsUpper : Char -> Type

    -- Characters in the interval ['a','z']
    IsLower : Char -> Type

    -- Lower or upper case characters
    IsAlpha : Char -> Type

    -- Characters in the range ['0','9']
    IsDigit : Char -> Type

    -- Digits or characters from the alphabet
    IsAlphaNum : Char -> Type

    -- Characters in the ranges [0,31] or [127,159]
    IsControl : Char -> Type

    -- An ASCII character that is not a control character
    IsPlainAscii : Char -> Type

    -- A latin character that is not a control character
    IsPlainLatin : Char -> Type
    ```

12. The advantage of this more modular approach to predicates
    on primitives is that we can safely run calculations on
    our predicates and get the strong guarantees from the existing
    proofs on inductive types like `Nat` and `List`. Here are
    some examples of such calculations and conversions, all of which
    can be implemented without cheating:

    ```idris
    0 plainToAscii : IsPlainAscii c -> IsAscii c

    0 digitToAlphaNum : IsDigit c -> IsAlphaNum c

    0 alphaToAlphaNum : IsAlpha c -> IsAlphaNum c

    0 lowerToAlpha : IsLower c -> IsAlpha c

    0 upperToAlpha : IsUpper c -> IsAlpha c

    0 lowerToAlphaNum : IsLower c -> IsAlphaNum c

    0 upperToAlphaNum : IsUpper c -> IsAlphaNum c
    ```

    The following (`asciiToLatin`) is trickier. Remember that
    `(<=)` is transitive. However, in your invocation of the proof
    of transitivity, you will not be able to apply direct proof search using
    `%search` because the search depth is too small. You could
    increase the search depth, but it is much more efficient
    to use `safeDecideOn` instead.

    ```idris
    0 asciiToLatin : IsAscii c -> IsLatin c

    0 plainAsciiToPlainLatin : IsPlainAscii c -> IsPlainLatin c
    ```

Before we turn our full attention to predicates on strings,
we have to cover lists first, because we will often treat
strings as lists of characters.

13. Implement `Decidable` for `Head`:

    ```idris
    data Head : (p : a -> Type) -> List a -> Type where
      AtHead : {0 p : a -> Type} -> (0 prf : p v) -> Head p (v :: vs)
    ```

14. Implement `Decidable` for `Length`:

    ```idris
    data Length : (p : Nat -> Type) -> List a -> Type where
      HasLength :  {0 p : Nat -> Type}
                -> (0 prf : p (List.length vs))
                -> Length p vs
    ```

15. The following predicate is a proof that all values in a list
    of values fulfill the given predicate. We will use this to limit
    the valid set of characters in a string.

    ```idris
    data All : (p : a -> Type) -> (as : List a) -> Type where
      Nil  : All p []
      (::) :  {0 p : a -> Type}
           -> (0 h : p v)
           -> (0 t : All p vs)
           -> All p (v :: vs)
    ```

    Implement `Decidable` for `All`.

    For a real challenge, try to make your implementation of
    `decide` tail recursive. This will be important for real world
    applications on the JavaScript backends, where we might want to
    refine strings of thousands of characters without overflowing the
    stack at runtime. In order to come up with a tail recursive implementation,
    you will need an additional data type `AllSnoc` witnessing that a predicate
    holds for all elements in a `SnocList`.

16. It's time to come to an end here. An identifier in Idris is a sequence
    of alphanumeric characters, possibly separated by underscore characters
    (`_`). In addition, all identifiers must start with a letter.
    Given this specification, implement predicate `IdentChar`, from
    which we can define a new wrapper type for identifiers:

    ```idris
    0 IdentChars : List Char -> Type

    record Identifier where
      constructor MkIdentifier
      value : String
      0 prf : IdentChars (unpack value)
    ```

    Implement a factory method `identifier` for converting strings
    of unknown source at runtime:

    ```idris
    identifier : String -> Maybe Identifier
    ```

    In addition, implement `fromString` for `Identifier` and verify,
    that the following is a valid identifier:

    ```idris
    testIdent : Identifier
    testIdent = "fooBar_123"
    ```

Final remarks: Proofing stuff about the primitives can be challenging,
both when deciding on what axioms to use and when trying to make
things perform well at runtime and compile time. I'm experimenting
with a library, which deals with these issues. It is not yet finished,
but you can have a look at it [here](https://github.com/stefan-hoeck/idris2-prim).

<!-- vi: filetype=idris2:syntax=markdown
-->
