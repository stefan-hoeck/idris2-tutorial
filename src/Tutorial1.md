# Part 1: Types and Functions

Welcome to my Idris2 tutorial. I'll try and treat as many aspects
of the Idris2 programming language as possible here.
All `.md` files in here a literate Idris2 files: They consist of
markdown (hence the `.md` ending), which is being pretty printed
by github together with Idris2 code blocks, which can be
typechecked and built by the Idris2 compiler (more on this later).

Every Idris2 source file should typically start with a module
name plus some necessary imports, and this document is no
exception:

```idris
module Tutorial1
```

A module name consists of a list of identifiers separated
by dots and must reflect the folder structure plus the module
file's name.

## The Types of Things

One of the most important aspects of programming in Idris
is the notion of a *type*. A type is a (sometimes pretty
detailed) description of the shape and or content of a value
in an Idris program. Start an Idris2 REPL (*REPL* is an acronym for
*read evaluate print loop*):

```sh
$ rlwrap idris2
```

(Using command line utility `rlwrap` is optional. It
leads to a somewhat nicer user experience, as it allows us
to use the up and down arrow keys to scroll through a history
of commands and expressions we entered. It should be available
for most Linux distributions.)

Idris should now be ready to accept you commands:

```repl
     ____    __     _         ___
    /  _/___/ /____(_)____   |__ \
    / // __  / ___/ / ___/   __/ /     Version 0.5.1-3c532ea35
  _/ // /_/ / /  / (__  )   / __/      https://www.idris-lang.org
 /___/\__,_/_/  /_/____/   /____/      Type :? for help

Welcome to Idris 2.  Enjoy yourself!
Main>
```

We can go ahead and enter some simple arithmetic expressions. Idris
will *evaluate* these and print the result:

```repl
Main> 2 * 4
8
Main> 3 * (7 + 100)
321
```

Since every expression in Idris has an associated *type*,
we might want to inspect these as well:

```repl
Main> :t 2
2 : Integer
```

Here `:t` is a command of the Idris REPL (it is not part of
Idris programming language), and it is used to inspect the type
of an expression.

```repl
Main> :t 2 * 4
2 * 4 : Integer
```

Whenever we perform calculations with integer literals without
being explicit about the types we want to use, Idris will
use `Integer` as a default. `Integer` is an arbitrary precision
signed integer type. It is one of the *primitive types* built
into the language. Other primitives include fixed precision
signed and unsigned integral types (`Bits8`, `Bits16`, `Bits32`
`Bits64`, `Int8`, `Int16`, `Int32`, and `Int64`), double
precision (64 bit) floating point numbers (`Double`), unicode
characters (`Char`) and strings of unicode characters (`String`).
We use many of these in due time.

## A First Idris2 Program

We will often start up a REPL for tinkering with small parts
of the Idris language, for reading some documentation, or
for inspecting the content of an Idris module, but now we will
write several small Idris programs and functions to get started with
the language. Fist, the mandatory *Hello World*:

```idris
main : IO ()
main = putStrLn "Hello World!"
```

We will inspect the code above in some detail in a moment,
but first we'd like to compile and run it. From this project's
root directory, run the following:

```sh
$ idris2 --find-ipkg -o hello src/Tutorial1.md
```

This will create executable `hello` in directory `build/exec`,
which can be invoked from the command line like so:

```sh
$ build/exec/hello
Hello World!
```

As an alternative, you can also load this source file in a REPL
session and invoke function `main` from there:

```sh
rlwrap idris2 --find-ipkg src/Tutorial1.md
```

```repl
Tutorial1> :exec main
Hello World!
```

Go ahead and try both ways to build and run function `main`
on your system!

## The Shape of an Idris Declaration

Now, that we executed our first Idris program, we will talk
some more about the code we had to write to define it.

A typical toplevel function in Idris consists of three things:
The function's name (`main` in our case), its type (`IO ()`)
plus its implementation (`putStrLn "Hello World"`). It is easier
to explain these things with a couple of simple examples. Below,
we define a toplevel constant for the largest unsigned 8 bit
integer:

```idris
maxBits8 : Bits8
maxBits8 = 255
```

The first line can be read as: "We'd like to declare  (nullary)
function `maxBits8`. It is of type `Bits8`". The second line
reads: "The result of invoking `maxBits8` should be `255`."
(As you can see, we can use integer literals for other integral
types than `Integer`.)
We can inspect this at the REPL. Load this source file into
an Idris REPL (as described above), and run the following tests.

```repl
Tutorial1> maxBits8
255
Tutorial1> :t maxBits8
Tutorial1.maxBits8 : Bits8
```

We can also use `maxBits8` as part of another expression:

```repl
Tutorial1> maxBits8 - 100
155
```

I called `maxBits8` a *nullary function*, which is just a fancy
word for *constant*. Let's write and test our first *real* function:

```idris
distanceToMax : Bits8 -> Bits8
distanceToMax n = maxBits8 - n
```

This introduces some new syntax and a new kind of type: Function
types. `distanceToMax : Bits8 -> Bits8` can be read as follows:
"`distanceToMax` is a function of one argument of type `Bits8`, which
returns a result of type `Bits8`". In the implementation, the argument
is given a local identifier `n`, which is then used in the
calculation on the right hand side. Again, go ahead and try this
function at the REPL:

```repl
Tutorial1> distanceToMax 12
243
Tutorial1> :t distanceToMax
Tutorial1.distanceToMax : Bits8 -> Bits8
Tutorial1> :t distanceToMax 12
distanceToMax 12 : Bits8
```

As a final example, let's implement a function to calculate
the square of an integer:

```idris
square : Integer -> Integer
square n = n * n
```

We now learn a very important aspect of Idris: It is
a *statically typed* programming language. We are not
allowed to freely mix types as we please. Doing so
will result in an error message from the type checker
(which is part of the compilation process of Idris).
For instance, if we try the following at the REPL,
we will get a type error:

```repl
Tutorial1> square maxBits8
Error: ...
```

The reason: `square` expects an argment of type `Integer`,
but `maxBits8` is of type `Bits8`. Many primitive types
are interconvertible (sometimes with the risk of loss
of precision) using function `cast` (more on the details
later):

```repl
Tutorial1> square (cast maxBits8)
65025
```

Note, that in the example above the result is much larger
that `maxBits8`. The reason is, that `maxBits8` is first
converted to an `Integer` of the same value, which is
then squared. If on the other hand we square `maxBits8`
directly, the result is truncated to still fit the
valid range of `Bits8`:

```repl
Tutorial1> maxBits8 * maxBits8
1
```

## Functions with more that one Argument

Let's implement a function, which checks if its three
`Integer` arguments form a pythagorean triple. We get to
use a new operator for this: `==`, the equality
operator.

```idris
isTriple : Integer -> Integer -> Integer -> Bool
isTriple x y z = x * x + y * y == z * z
```

Let's give this a spin at the REPL before we talk a bit
about the types:

```repl
Tutorial1> isTriple 1 2 3
False
Tutorial1> isTriple 3 4 5
True
```

As can be seen from this example, the type of a function
of several arguments consists just of a sequence
of argument types chained by function arrows (`->`), which
is terminated by a return type (`Bool` in this case).

Now, unlike `Integer` or `Bits8`, `Bool` is not a primitive
data type built into the Idris language but just a custom
data type that you could have written yourself. We will
learn more about declaring new data types in the second
part of this tutorial.

### Function Composition

Idris is a *functional* programming language. This means,
that functions are its main form of abstraction (unlike for
instance in an object oriented language like Java, where
*objects* and *classes* are the main form of abstraction). It also
means that we expect Idris to make it very easy for
us to compose and combine functions to create new
functions. In fact, in Idris, functions are *first class*:
Functions can take other functions as arguments and
can return functions as their results.

Functions can be combined in several way, the most direct
probably being the dot operator:

```idris
times2 : Integer -> Integer
times2 n = 2 * n

squareTimes2 : Integer -> Integer
squareTimes2 = times2 . square
```

Give this a try at the REPL! Does it do what you'd expect?

We could have implemented `squareTimes2` without using
the dot operator as follows:

```idris
squareTimes2' : Integer -> Integer
squareTimes2' n = times2 (square n)
```

It is important to note, that functions chained by the dot
operator are invoked from right to left: `times2 . square`
is the same as `\n => times2 (square n)` and not
`\n => square (times2 n)`.

We can conveniently chain several functions using the
dot operator to write more complex functions:

```idris
dotChain : Integer -> String
dotChain = reverse . show . square . square . times2 . times2
```

This will first multiply the argument by four, then square
it twice before converting it to a string (`show`) and
reversing the resulting `String` (functions `show` and
`reverse` are part of the Idris prelude and as such are
available in every Idris program).

### Higher Order Functions

Functions can take other functions as arguments. This is
an incredibly powerful concept and we can go crazy with
this very easily. But for sanity's sake, we'll start
slowly:

```idris
isEven : Integer -> Bool
isEven n = mod n 2 == 0

testSquare : (Integer -> Bool) -> Integer -> Bool
testSquare fun n = fun (square n)
```

First `isEven` uses the `mod` function to check, whether 
an integer is divisible by two. But the interesting function
is `testSquare`. It takes two arguments: The first argument
is of type *function from `Integer` to `Bool`*, and the second
of type `Integer`. This second argument is squared before
being passed to the first argument. Again, give this a go
at the REPL:

```repl
Tutorial1> testSquare isEven 12
True
```

We can use higher order functions (functions taking other
functions as their arguments) to build powerful abstractions.
Consider for instance the following example:

```idris
twice : (Integer -> Integer) -> Integer -> Integer
twice f n = f (f n)
```

And at the REPL:

```repl
Tutorial1> twice square 2
16
Tutorial1> (twice . twice) square 2
65536
Tutorial1> (twice . twice . twice . twice) square 2
*** huge number ***
```

You might be surprised about this behavior, so we'll try
and break it down. The following two expressions are identical
in their behavior:

```idris
expr1 : Integer -> Integer
expr1 = (twice . twice . twice . twice) square

expr2 : Integer -> Integer
expr2 = twice (twice (twice (twice square)))
```

So, `square` raises its argument to the 2nd power,
`twice square` raises it to its 4th power,
`twice (twice square)` raises it to its 16th power,
and so on, until `twice (twice (twice (twice square)))`
raises it to its 65536th power resulting in an impressively
huge result.

### Currying

Once we start using higher order functions, the concept
of partial function application (also called *currying*
after mathematician and logician Haskell Curry) becomes
very important.

Load this file in a REPL session and try the following:

```repl
Tutorial1> :t testSquare isEven
testSquare isEven : Integer -> Bool
Tutorial1> :t isTriple 1
isTriple 1 : Integer -> Integer -> Bool
Tutorial1> :t isTriple 1 2
isTriple 1 2 : Integer -> Bool
```

Note, how in Idris we can only partially apply a function
with more than one argument and as a result get a new function
back. For instance, `isTriple 1` applies argument `1` to function
`isTriple` and as a result returns a new function of
type `Integer -> Integer -> Bool`. We can even
use the result of such a partially applied function in
a new toplevel definition:

```idris
partialExample : Integer -> Bool
partialExample = isTriple 3 4
```

And at the REPL:

```repl
Tutorial1> partialExample 5
True
```

We already used partial function application in our `twice`
examples above to get some impressive results with very
little code.

## Exercises

0. Reimplement functions `testSquare` and `twice` by using the dot
operator and dropping the second arguments (have a look at the
implementation of `dotChain` to get an idea where this should
lead you). This highly concise
way of writing function implementations is sometimes called
*point-free style* and is often the preferred way of writing
small utility functions.

1. Declare and implement function `isOdd` by combining functions `isEven`
from above and `not` (from the Idris prelude). Use point-free style.

2. Declare and implement function `isSquareOf`, which checks whether
its first `Integer` argument is the square of the second argument.

3. Declare and implement function `isSmall`, which checks whether
its `Integer` argument is less than or equal to 100. Use one of the 
comparison operators `<=` or `>=` in your implementation.

4. Declare and implement function `absIsSmall`, which checks whether
the absolute value of its `Integer` argument is less than or equal to 100.
Use functions `isSmall` and `abs` (from the Idris prelude) in your implementation,
which should be in point-free style.

5. In this slightly extended exercise we are going to implement
some utilities for working with `Integer` predicates (functions
from `Integer` to `Bool`). Implement the following higher order
functions (use boolean operators `&&`, `||`, and function `not` in
your implementations):

```idris
-- return true, if and only if both predicates hold
and : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool

-- return true, if and only if at least one predicate holds
or : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool

-- return true, if the predicate does not hold
negate : (Integer -> Bool) -> Integer -> Bool
```

After solving exercise 5, give it a go in the REPL. In the
example below, we use binary function `and` in infix notation
by wrapping it in backticks. This is just a syntactic convenience
to make certain function applications more readable:

```repl
Tutorial1> negate (isSmall `and` isOdd) 73
False
```

<!-- vi: filetype=idris2
-->
