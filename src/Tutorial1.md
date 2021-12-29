# Part 1: All about Types

Welcome to my Idris2 tutorial. I'll try and treat as many aspects
of the Idris2 programming language as possible here.
All `.md` files in here a literate Idris2 files: They consist of
markdown (hence the `.md` ending), which is being pretty printed
by github together with Idris2 code blocks, which can be
typechecked and built by the Idris2 compiler (more on this later).

Every Idris2 source file should typicall start with a module
name plus some necessary imports, and this document is no
exception:

```idris
module Tutorial1
```

A module name consists of a list of identifiers seperated
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

(The use of command line utility `rlwrap` is optional. It
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

We can go ahead and enter some simple expressions. Idris
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
use `Integer` as default. `Integer` is an arbitrary precision
signed integer type. It is one of the *primitive types* built
into the language. Other primitives include fixed precision
signed and unsigned integral types (`Bits8`, `Bits16`, `Bits32`
`Bits64`, `Int8`, `Int16`, `Int32`, and `Int64`), double
precision (64 bit) floating point numbers (`Double`), unicode
characters (`Char`) and strings of unicode characters (`String`).
We will see several of these in action in a moment.

## A First Idris2 Program

We will often start up a REPL for tinkering with small parts
of the Idris language, for reading some documentation, or
for inspecting the content of an Idris module, but now we will
write several small Idris programs to get started with
the language. Fist, the mandatory *Hello World*:

```idris
main : IO ()
main = putStrLn "Hello World!"
```

We will inspect the code above in some detail in a moment,
but first we'd like to compile and run it. For this project's
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
to explain this things with a couple of simple examples. Below,
we define a toplevel constant for the largest unsigned 8 bit
integer:

```idris
maxBits8 : Bits8
maxBits8 = 255
```

The first line can be read as: "We'd like to declare  (nullary)
function `maxBits8`. It is of type `Bits8`". The second line
reads: "The result of invoking `maxBits8` should be `255`."
We can inspect this at the REPL. Load this source file into
an Idris REPL (as described above), and run the following tests:
As you can see, we can use integer literals for other integral
types than `Integer`.

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

This introduces some new syntax and a new kind of types: Function
types. `distanceToMax : Bits8 -> Bits8` can be read as follows:
`distanceToMax` is a function of one argument of type `Bits8`, which
returns a result of type `Bits8`. In the implementation, the argument
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

<!-- vi: filetype=idris2
-->
