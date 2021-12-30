# Introduction

Welcome to my Idris2 tutorial. I'll try and treat as many aspects
of the Idris2 programming language as possible here.
All `.md` files in here a literate Idris2 files: They consist of
markdown (hence the `.md` ending), which is being pretty printed
by github together with Idris2 code blocks, which can be
type checked and built by the Idris2 compiler (more on this later).
Note, however, that regular Idris source files use an `.idr` ending,
and that you go with that file type unless you end up writing
much more prose than code as I do at the moment. Later in this
tutorial, you'll have to solve some exercises, the solutions of
which can be found in the `src/Solutions` subfolder. There, I
use regular `.idr` files.

Every Idris source file should typically start with a module
name plus some necessary imports, and this document is no
exception:

```idris
module Tutorial.Intro
```

A module name consists of a list of identifiers separated
by dots and must reflect the folder structure plus the module
file's name.

## Using the REPL

Idris comes with a useful REPL (an acronym for *Read Evaluate
Print Loop*), which we will use for tinkering with small
ideas, and for quickly experimenting with the code we just wrote.
In order to start a REPL session, run the following command
from a terminal.

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

## A First Idris Program

We will often start up a REPL for tinkering with small parts
of the Idris language, for reading some documentation, or
for inspecting the content of an Idris module, but now we will
write a minimal Idris program to get started with
the language. Here comes the mandatory *Hello World*:

```idris
main : IO ()
main = putStrLn "Hello World!"
```

We will inspect the code above in some detail in a moment,
but first we'd like to compile and run it. From this project's
root directory, run the following:

```sh
$ idris2 --find-ipkg -o hello src/Tutorial/Intro.md
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
rlwrap idris2 --find-ipkg src/Tutorial/Intro.md
```

```repl
Tutorial.Intro> :exec main
Hello World!
```

Go ahead and try both ways of building and running function `main`
on your system!

## The Shape of an Idris Declaration

Now that we executed our first Idris program, we will talk
a bit more about the code we had to write to define it.

A typical top level function in Idris consists of three things:
The function's name (`main` in our case), its type (`IO ()`)
plus its implementation (`putStrLn "Hello World"`). It is easier
to explain these things with a couple of simple examples. Below,
we define a top level constant for the largest unsigned eight bit
integer:

```idris
maxBits8 : Bits8
maxBits8 = 255
```

The first line can be read as: "We'd like to declare  (nullary)
function `maxBits8`. It is of type `Bits8`". The second line
reads: "The result of invoking `maxBits8` should be `255`."
(As you can see, we can use integer literals for other integral
types than just `Integer`.)
We can inspect this at the REPL. Load this source file into
an Idris REPL (as described above), and run the following tests.

```repl
Tutorial.Intro> maxBits8
255
Tutorial.Intro> :t maxBits8
Tutorial.Intro.maxBits8 : Bits8
```

We can also use `maxBits8` as part of another expression:

```repl
Tutorial.Intro> maxBits8 - 100
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
Tutorial.Intro> distanceToMax 12
243
Tutorial.Intro> :t distanceToMax
Tutorial.Intro.distanceToMax : Bits8 -> Bits8
Tutorial.Intro> :t distanceToMax 12
distanceToMax 12 : Bits8
```

As a final example, let's implement a function to calculate
the square of an integer:

```idris
square : Integer -> Integer
square n = n * n
```

We now learn a very important aspect of programming
in Idris: Idris is
a *statically typed* programming language. We are not
allowed to freely mix types as we please. Doing so
will result in an error message from the type checker
(which is part of the compilation process of Idris).
For instance, if we try the following at the REPL,
we will get a type error:

```repl
Tutorial.Intro> square maxBits8
Error: ...
```

The reason: `square` expects an argument of type `Integer`,
but `maxBits8` is of type `Bits8`. Many primitive types
are interconvertible (sometimes with the risk of loss
of precision) using function `cast` (more on the details
later):

```repl
Tutorial.Intro> square (cast maxBits8)
65025
```

Note, that in the example above the result is much larger
that `maxBits8`. The reason is, that `maxBits8` is first
converted to an `Integer` of the same value, which is
then squared. If on the other hand we square `maxBits8`
directly, the result is truncated to still fit the
valid range of `Bits8`:

```repl
Tutorial.Intro> maxBits8 * maxBits8
1
```

## Summary

In this introduction we learned about the most basic
features of the Idris programming language. We use
the REPL to tinker with our ideas and inspect the
types of things in our code, and we used the Idris
compiler to compile an Idris source file to an executable.

We also learned about the basic shape of a top level
declaration in Idris, which always consists of an identifier
(its name), a type, and an implementation.
