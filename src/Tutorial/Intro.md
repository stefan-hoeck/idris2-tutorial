# Introduction

Welcome to my Idris 2 tutorial. I'll try and treat as many aspects
of the Idris 2 programming language as possible here.
All `.md` files in here a literate Idris files: They consist of
Markdown (hence the `.md` ending), which is being pretty printed
by GitHub together with Idris code blocks, which can be
type checked and built by the Idris compiler (more on this later).
Note, however, that regular Idris source files use an `.idr` ending,
and that you go with that file type unless you end up writing
much more prose than code as I do at the moment. Later in this
tutorial, you'll have to solve some exercises, the solutions of
which can be found in the `src/Solutions` subfolder. There, I
use regular `.idr` files.

Before we begin, make sure to install the Idris compiler on your system.
Throughout this tutorial, I assume you installed the *pack* package
manager and setup a skeleton package as described
[here](../Appendices/Install.md). It is
certainly possible to follow along with just the Idris compiler installed
by other means, but some adjustments will be necessary
when starting REPL sessions or building executables.

Every Idris source file should typically start with a module
name plus some necessary imports, and this document is no
exception:

```idris
module Tutorial.Intro
```

A module name consists of a list of identifiers separated
by dots and must reflect the folder structure plus the module
file's name.

## About the Idris Programming Language

Idris is a *pure*, *dependently typed*, *total* *functional*
programming language. I'll quickly explain each of these adjectives
in this section.

### Functional Programming

In functional programming languages, functions are first-class
constructs, meaning that they can be assigned to variables,
passed as arguments to other functions, and returned as results
from functions. Unlike for instance in
object-oriented programming languages, in functional programming,
functions are the main form of abstraction. This means that whenever
we find a common pattern or (almost) identical code in several
parts of a project, we try to abstract over this in order to
have to write the corresponding code only once.
We do this by introducing one or more new functions
implementing this behavior. Doing so, we often try to be as general
as possible to make our functions as versatile to use as possible.

Functional programming languages are concerned with the evaluation
of functions, unlike classical imperative languages, which are
concerned with the execution of statements.

### Pure Functional Programming

Pure functional programming languages come with an additional
important guarantee: Functions don't have side effects like
writing to a file or mutating global state. They can only
compute a result from their arguments possibly by invoking other
pure functions, *and nothing else*. As a consequence, given
the same input, they will *always* generate the same output.
This property is known as
[referential transparency](https://en.wikipedia.org/wiki/Referential_transparency).

Pure functions have several advantages:

* They can easily be tested by specifying (possibly randomly generated)
  sets of input arguments together with the expected results.

* They are thread-safe, since the don't mutate global state, and
  as such can be freely used in several computations running
  in parallel.

There are, of course, also some disadvantages:

* Some algorithms are hard to implement efficiently using
  only pure functions.

* Writing programs that actually *do* something
  (have some observable effect) is a bit trickier but certainly
  possible.

### Dependent Types

Idris is a strongly, statically typed programming language. This
means, that every Idris expression is given a *type* (for instance:
integer, list of strings, boolean, function from integer to boolean, etc.)
and types are verified at compile time to rule out certain
common programming errors.

For instance, if a function expects an argument of type `String`
(a sequence of unicode characters, such as `"Hello123"`), it
is a *type error* to invoke this function with an argument of
type `Integer`, and the Idris compiler will refuse to
generate an executable from such an ill-typed program.

Being *statically typed* means that the Idris compiler will catch
type errors at *compile time*, that is, before it generates an executable
program that can be run. The opposite to this are *dynamically typed*
languages such as Python, which check for type errors at *runtime*, that is,
when a program is being executed. It is the philosophy of statically typed
languages to catch as many type errors as possible before there even is
a program that can be run.

Even more, Idris is *dependently typed*, which is one of its most
characteristic properties in the landscape of programming
languages. In Idris, types are *first class*: Types can be passed
as arguments to functions, and functions can return types as
their results. Even more, types can *depend* on other *values*.
What this means, and why this is incredibly useful, we'll explore
in due time.

### Total Functions

A *total* function is a pure function, that is guaranteed to return
a value of the expected return type for every possible input in
a finite number of computational steps. A total function will never fail with an
exception or loop infinitely, although it can still take arbitrarily
long to compute its result

Idris comes with a totality checker built in, which enables us to
verify the functions we write to be provably total. Totality
in Idris is opt-in, as in general, checking the totality of
an arbitrary computer program is undecidable
(see also the [halting problem](https://en.wikipedia.org/wiki/Halting_problem)).
However, if we annotate a function with the `total` keyword,
Idris will fail with a type error, if its totality checker
cannot verify that the function in question is indeed total.

## Using the REPL

Idris comes with a useful REPL (an acronym for *Read Evaluate
Print Loop*), which we will use for tinkering with small
ideas, and for quickly experimenting with the code we just wrote.
In order to start a REPL session, run the following command
in a terminal:

```repl
pack repl
```

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

Here `:t` is a command of the Idris REPL (it is not part of the
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
We will use many of these in due time.

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
pack -o hello exec src/Tutorial/Intro.md
```

This will create executable `hello` in directory `build/exec`,
which can be invoked from the command-line like so (without the
dollar prefix; this is used here to distinguish the terminal command
from its output):

```sh
$ build/exec/hello
Hello World!
```

The pack program requires an `.ipkg` to be in scope (in the current
directory or one of its parent directories) from which
it will get other settings like the source directory to use
(`src` in our case). The optional `-o` option gives the name of the
executable to be generated. Pack comes up with a name of its own
it this is missing. Type `pack help` for a list
of available command-line options and commands, and `pack help <cmd>`
for getting help for a specific command.

As an alternative, you can also load this source file in a REPL
session and invoke function `main` from there:

```sh
pack repl src/Tutorial/Intro.md
```

```repl
Tutorial.Intro> :exec main
Hello World!
```

Go ahead and try both ways of building and running function `main`
on your system!

## The Shape of an Idris Definition

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
function `maxBits8`. It is of type `Bits8`". This is
called the *function declaration*: We declare, that there
shall be a function of the given name and type. The second line
reads: "The result of invoking `maxBits8` should be `255`."
(As you can see, we can use integer literals for other integral
types than just `Integer`.) This is called the *function definition*:
Function `maxBits8` should behave as described here when being
evaluated.

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
then squared. If on the other hand we squared `maxBits8`
directly, the result would be truncated to still fit the
valid range of `Bits8`:

```repl
Tutorial.Intro> maxBits8 * maxBits8
1
```

## Where to get Help

There are several resources available online and in print, where
you can find help and documentation about the Idris programming
language. Here is a non-comprehensive list of them:

* [Type-Driven Development with Idris](https://www.manning.com/books/type-driven-development-with-idris)

  *The* Idris book! This describes in great detail
  the core concepts for using Idris and dependent types
  to write robust and concise code. It uses Idris 1 in
  its examples, so parts of it have to be slightly adjusted
  when using Idris 2. There is also a
  [list of required updates](https://idris2.readthedocs.io/en/latest/typedd/typedd.html).

* [A Crash Course in Idris 2](https://idris2.readthedocs.io/en/latest/tutorial/index.html)

  The official Idris 2 tutorial. A comprehensive but dense explanation of
  all features of Idris 2. I find this to be useful as a reference, and as such
  it is highly accessible. However, it is not an introduction to functional
  programming or type-driven development in general.

* [The Idris 2 GitHub Repository](https://github.com/idris-lang/Idris2)

  Look here for detailed installation instructions and some
  introductory material. There is also a [wiki](https://github.com/idris-lang/Idris2/wiki),
  where you can find a [list of editor plugins](https://github.com/idris-lang/Idris2/wiki/The-Idris-editor-experience),
  a [list of community libraries](https://github.com/idris-lang/Idris2/wiki/Libraries),
  a [list of external backends](https://github.com/idris-lang/Idris2/wiki/External-backends),
  and other useful information.

* [The Idris 2 Discord Channel](https://discord.gg/UX68fDs2jc)

  If you get stuck with a piece of code, want to ask about some
  obscure language feature, want to promote your new library,
  or want to just hang out with other Idris programmers, this
  is the place to go. The discord channel is pretty active and
  *very* friendly towards newcomers.

* The Idris REPL

  Finally, a lot of useful information can be provided by
  Idris itself. I tend to have at least one REPL session open all the
  time when programming in Idris. My editor (neovim) is set up
  to use the [language server for Idris 2](https://github.com/idris-community/idris2-lsp),
  which is incredibly useful. In the REPL,

  * use `:t` to inspect the type of an expression
    or meta variable (hole): `:t foldl`,
  * use `:ti` to inspect the type of a function
    including implicit arguments: `:ti foldl`,
  * use `:m` to list all meta variables (holes) in scope,
  * use `:doc` to access the documentation of a
    top level function (`:doc the`), a data type plus all its constructors
    and available hints (`:doc Bool`), a language feature (`:doc case`,
    `:doc let`, `:doc interface`, `:doc record`,
    or even `:doc ?`), or an interface (`:doc Uninhabited`),
  * use `:module` to import a module from one of the available
    packages: `:module Data.Vect`,
  * use `:browse` to list the names and types of all functions
    exported by a loaded module: `:browse Data.Vect`,
  * use `:help` to get a list of other commands plus a short
    description for each.

## Summary

In this introduction we learned about the most basic
features of the Idris programming language. We used
the REPL to tinker with our ideas and inspect the
types of things in our code, and we used the Idris
compiler to compile an Idris source file to an executable.

We also learned about the basic shape of a top level
definition in Idris, which always consists of an identifier
(its name), a type, and an implementation.

### What's next?

In the [next chapter](Functions1.md), we start programming
in Idris for real. We learn how to write our own pure
functions, how functions compose, and how we can treat
functions just like other values and pass them around
as arguments to other functions.
