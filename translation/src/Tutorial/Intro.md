# 介绍

欢迎来到我的 Idris 2 教程。我将在这里尽可能多地处理 Idris 2 编程语言的各个方面。这里的所有 `.md` 文件都是一个识字的 Idris
文件：它们由 Markdown 组成（因此以 `.md` 结尾），由 GitHub 与 Idris 代码块一起打印出来，可以由 Idris
编译器进行类型检查和构建（稍后会详细介绍）。但是请注意，常规的 Idris 源文件使用 `.idr`
结尾，并且除非您最终编写的代码比我现在所做的更啰嗦，否则您将使用该文件类型。在本教程的后面，您将需要解决一些练习，这些练习的答案可以在
`src/Solutions` 子文件夹中找到。在那里，我使用常规的 `.idr` 文件。

每个 Idris 源文件通常应该以模块名称和一些必要的导入开头，本文档也不例外：

```idris module Tutorial.Intro ```

模块名称由以点分隔的标识符列表组成，并且必须反映文件夹结构加上模块文件的名称。

## 关于 Idris 编程语言

Idris 是一种*纯的*、*依赖类型*、具有*完全**函数* 的编程语言。我将在本节中快速解释这些形容词。

### 函数式编程

在函数式编程语言中，函数是一等结构，这意味着它们可以分配给变量，作为参数传递给其他函数，并作为函数的结果返回。与面向对象的编程语言不同，在函数式编程中，函数是抽象的主要形式。

函数式编程语言关注函数的求值，不像经典的命令式语言关注语句的执行。

### 纯函数式编程

纯函数式编程语言有一个额外的重要保证：函数不会产生像写入文件或改变全局状态这样的副作用。他们只能通过调用其他纯函数，给定参数来获取计算结果，*而没有其他获取数据的途径*。因此，给定相同的输入，它们将*总是*生成相同的输出。此属性称为
[引用透明](https://en.wikipedia.org/wiki/Referential_transparency)。

纯函数有几个优点：

* 它们可以通过指定（可能是随机生成的）输入参数集以及预期结果来轻松测试。

* 它们是线程安全的，因为不会改变全局状态，因此可以在并行运行的多个计算中自由使用。

当然，也有一些缺点：

* 仅使用纯函数很难有效地实现某些算法。

* 编写实际上*做*某些事情（具有一些可观察到的效果）的程序有点棘手，但肯定是可能的。

### 依赖类型

Idris 是一种强静态类型的编程语言。这意味着，给 Idris
表达式一个*类型*（例如：整数、字符串列表、布尔值、从整数到布尔值的函数等），并且在编译时验证类型以排除某些常见的编程错误。

例如，如果一个函数需要 `String` 类型的参数（Unicode 字符序列，例如 `"Hello123"`），使用 `Integer`
类型的参数调用此函数则它是*类型错误*的，Idris 编译器将拒绝从此类错误类型的程序生成可执行文件。

更重要的是，Idris 具有*依赖类型*，这是它在编程语言领域中最具特色的属性之一。在 Idris 中，类型是*
一等*的：类型可以作为参数传递给函数，函数可以返回类型作为结果。更重要的是，类型可以*依赖于*其他*值*。这意味着什么，以及为什么这非常有用，我们将在适当的时候进行探索。

### Total Functions

A *total* function is a pure function, that is guaranteed to return a value
of the expected return type for every possible input in a finite amount of
time. A total function will never fail with an exception or loop infinitely.

Idris comes with a totality checker built in, which enables us to verify the
functions we write to be provably total. Totality in Idris is opt-in, as in
general, checking the totality of an arbitrary computer program is
undecidable (see also the [halting
problem](https://en.wikipedia.org/wiki/Halting_problem)).  However, if we
annotate a function with the `total` keyword, Idris will fail with a type
error, if its totality checker cannot verify that the function in question
is indeed total.

## Using the REPL

Idris comes with a useful REPL (an acronym for *Read Evaluate Print Loop*),
which we will use for tinkering with small ideas, and for quickly
experimenting with the code we just wrote.  In order to start a REPL
session, run the following command in a terminal.

```repl rlwrap idris2 ```

(Using command-line utility `rlwrap` is optional. It leads to a somewhat
nicer user experience, as it allows us to use the up and down arrow keys to
scroll through a history of commands and expressions we entered. It should
be available for most Linux distributions.)

Idris should now be ready to accept you commands:

```repl
     ____    __     _         ___
    /  _/___/ /____(_)____   |__ \
    / // __  / ___/ / ___/   __/ /     Version 0.5.1-3c532ea35
  _/ // /_/ / /  / (__  )   / __/      https://www.idris-lang.org
 /___/\__,_/_/  /_/____/   /____/      Type :? for help

Welcome to Idris 2.  Enjoy yourself! Main> ```

We can go ahead and enter some simple arithmetic expressions. Idris will
*evaluate* these and print the result:

```repl Main> 2 * 4 8 Main> 3 * (7 + 100)  321 ```

Since every expression in Idris has an associated *type*, we might want to
inspect these as well:

```repl Main> :t 2 2 : Integer ```

Here `:t` is a command of the Idris REPL (it is not part of the Idris
programming language), and it is used to inspect the type of an expression.

```repl Main> :t 2 * 4 2 * 4 : Integer ```

Whenever we perform calculations with integer literals without being
explicit about the types we want to use, Idris will use `Integer` as a
default. `Integer` is an arbitrary precision signed integer type. It is one
of the *primitive types* built into the language. Other primitives include
fixed precision signed and unsigned integral types (`Bits8`, `Bits16`,
`Bits32` `Bits64`, `Int8`, `Int16`, `Int32`, and `Int64`), double precision
(64 bit) floating point numbers (`Double`), unicode characters (`Char`) and
strings of unicode characters (`String`).  We will use many of these in due
time.

## A First Idris Program

We will often start up a REPL for tinkering with small parts of the Idris
language, for reading some documentation, or for inspecting the content of
an Idris module, but now we will write a minimal Idris program to get
started with the language. Here comes the mandatory *Hello World*:

```idris main : IO ()  main = putStrLn "Hello World!" ```

We will inspect the code above in some detail in a moment, but first we'd
like to compile and run it. From this project's root directory, run the
following: ```sh idris2 --find-ipkg -o hello src/Tutorial/Intro.md ```

This will create executable `hello` in directory `build/exec`, which can be
invoked from the command-line like so (without the dollar prefix; this is
used here to distinguish the terminal command from its output):

```sh $ build/exec/hello Hello World! ```

The `--find-ipkg` option will look for an `.ipkg` file in the current
directory or one of its parent directories, from which it will get other
settings like the source directory to use (`src` in our case). The `-o`
option gives the name of the executable to be generated. Type `idris2
--help` for a list of available command-line options and environment
variables.

As an alternative, you can also load this source file in a REPL session and
invoke function `main` from there:

```sh rlwrap idris2 --find-ipkg src/Tutorial/Intro.md ```

```repl Tutorial.Intro> :exec main Hello World! ```

Go ahead and try both ways of building and running function `main` on your
system!

Note: It might be instructive to omit the `--find-ipkg` option.  You will
get an error message about the module name `Tutorial.Intro` not matching the
file path `src/Tutorial/Intro.md`. You can also use option `--source-dir
src` to silence this error.

## The Shape of an Idris Definition

Now that we executed our first Idris program, we will talk a bit more about
the code we had to write to define it.

A typical top level function in Idris consists of three things: The
function's name (`main` in our case), its type (`IO ()`)  plus its
implementation (`putStrLn "Hello World"`). It is easier to explain these
things with a couple of simple examples. Below, we define a top level
constant for the largest unsigned eight bit integer:

```idris maxBits8 : Bits8 maxBits8 = 255 ```

The first line can be read as: "We'd like to declare (nullary)  function
`maxBits8`. It is of type `Bits8`". This is called the *function
declaration*: We declare, that there shall be a function of the given name
and type. The second line reads: "The result of invoking `maxBits8` should
be `255`." (As you can see, we can use integer literals for other integral
types than just `Integer`.) This is called the *function definition*:
Function `maxBits8` should behave as described here when being evaluated.

We can inspect this at the REPL. Load this source file into an Idris REPL
(as described above), and run the following tests.

```repl Tutorial.Intro> maxBits8 255 Tutorial.Intro> :t maxBits8
Tutorial.Intro.maxBits8 : Bits8 ```

We can also use `maxBits8` as part of another expression:

```repl Tutorial.Intro> maxBits8 - 100 155 ```

I called `maxBits8` a *nullary function*, which is just a fancy word for
*constant*. Let's write and test our first *real* function:

```idris distanceToMax : Bits8 -> Bits8 distanceToMax n = maxBits8 - n ```

This introduces some new syntax and a new kind of type: Function
types. `distanceToMax : Bits8 -> Bits8` can be read as follows:
"`distanceToMax` is a function of one argument of type `Bits8`, which
returns a result of type `Bits8`". In the implementation, the argument is
given a local identifier `n`, which is then used in the calculation on the
right hand side. Again, go ahead and try this function at the REPL:

```repl Tutorial.Intro> distanceToMax 12 243 Tutorial.Intro> :t
distanceToMax Tutorial.Intro.distanceToMax : Bits8 -> Bits8 Tutorial.Intro>
:t distanceToMax 12 distanceToMax 12 : Bits8 ```

As a final example, let's implement a function to calculate the square of an
integer:

```idris square : Integer -> Integer square n = n * n ```

We now learn a very important aspect of programming in Idris: Idris is a
*statically typed* programming language. We are not allowed to freely mix
types as we please. Doing so will result in an error message from the type
checker (which is part of the compilation process of Idris).  For instance,
if we try the following at the REPL, we will get a type error:

```repl Tutorial.Intro> square maxBits8 Error: ...  ```

The reason: `square` expects an argument of type `Integer`, but `maxBits8`
is of type `Bits8`. Many primitive types are interconvertible (sometimes
with the risk of loss of precision) using function `cast` (more on the
details later):

```repl Tutorial.Intro> square (cast maxBits8)  65025 ```

Note, that in the example above the result is much larger that
`maxBits8`. The reason is, that `maxBits8` is first converted to an
`Integer` of the same value, which is then squared. If on the other hand we
squared `maxBits8` directly, the result would be truncated to still fit the
valid range of `Bits8`:

```repl Tutorial.Intro> maxBits8 * maxBits8 1 ```

## Where to get Help

There are several resources available online and in print, where you can
find help and documentation about the Idris programming language. Here is a
non-comprehensive list of them:

* [Type-Driven Development with
  Idris](https://www.manning.com/books/type-driven-development-with-idris)

  *The* Idris book! This describes in great detail
  the core concepts for using Idris and dependent types
  to write robust and concise code. It uses Idris 1 in
  its examples, so parts of it have to be slightly adjusted
  when using Idris 2. There is also a
  [list of required updates](https://idris2.readthedocs.io/en/latest/typedd/typedd.html).

* [A Crash Course in Idris
  2](https://idris2.readthedocs.io/en/latest/tutorial/index.html)

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

  * use `:t` to inspect the type of an expression or meta variable (hole):
    `:t foldl`,
  * use `:ti` to inspect the type of a function including implicit
    arguments: `:ti foldl`,
  * use `:m` to list all meta variables (holes) in scope,
  * use `:doc` to access the documentation of a top level function (`:doc
    the`), a data type plus all its constructors and available hints (`:doc
    Bool`), a language feature (`:doc case`, `:doc let`, `:doc interface`,
    `:doc record`, or even `:doc ?`), or an interface (`:doc Uninhabited`),
  * use `:module` to import a module from one of the available packages:
    `:module Data.Vect`,
  * use `:browse` to list the names and types of all functions exported by a
    loaded module: `:browse Data.Vect`,
  * use `:help` to get a list of other commands plus a short description for
    each.

## Summary

In this introduction we learned about the most basic features of the Idris
programming language. We used the REPL to tinker with our ideas and inspect
the types of things in our code, and we used the Idris compiler to compile
an Idris source file to an executable.

We also learned about the basic shape of a top level definition in Idris,
which always consists of an identifier (its name), a type, and an
implementation.

### 下一步是什么？

In the [next chapter](Functions1.md), we start programming in Idris for
real. We learn how to write our own pure functions, how functions compose,
and how we can treat functions just like other values and pass them around
as arguments to other functions.
