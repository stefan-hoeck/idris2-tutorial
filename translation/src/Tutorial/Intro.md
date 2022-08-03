# 介绍

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

Every Idris source file should typically start with a module
name plus some necessary imports, and this document is no
exception:

```idris
module Tutorial.Intro
```

A module name consists of a list of identifiers separated
by dots and must reflect the folder structure plus the module
file's name.

## 关于 Idris 编程语言

Idris is a *pure*, *dependently typed*, *total* *functional*
programming language. I'll quickly explain each of these adjectives
in this section.

### 函数式编程

In functional programming languages, functions are first-class
constructs, meaning that they can be assigned to variables,
passed as arguments to other functions, and returned as results
from functions. Unlike for instance in
object-oriented programming languages, in functional programming,
functions are the main form of abstraction.

Functional programming languages are concerned with the evaluation
of functions, unlike classical imperative languages, which are
concerned with the execution of statements.

### 纯函数式编程

Pure functional programming languages come with an additional
important guarantee: Functions don't have side effects like
writing to a file or mutating global state. They can only
compute a result from their arguments possibly by invoking other
pure functions, *and nothing else*. As a consequence, given
the same input, they will *always* generate the same output.
This property is known as
[referential transparency](https://en.wikipedia.org/wiki/Referential_transparency).

Pure functions have several advantages:

* 它们可以通过指定（可能是随机生成的）输入参数集以及预期结果来轻松测试。

* 它们是线程安全的，因为不会改变全局状态，因此可以在并行运行的多个计算中自由使用。

There are, of course, also some disadvantages:

* 仅使用纯函数很难有效地实现某些算法。

* 编写实际上*做*某些事情（具有一些可观察到的效果）的程序有点棘手，但肯定是可能的。

### 依赖类型

Idris is a strongly, statically typed programming language. This
means, that ever Idris expression is given a *type* (for instance:
integer, list of strings, boolean, function from integer to boolean, etc.)
and types are verified at compile time to rule out certain
common programming errors.

For instance, if a function expects an argument of type `String`
(a sequence of unicode characters, such as `"Hello123"`), it
is a *type error* to invoke this function with an argument of
type `Integer`, and the Idris compiler will refuse to
generate an executable from such an ill-typed program.

Even more, Idris is *dependently typed*, which is one of its most
characteristic properties in the landscape of programming
languages. In Idris, types are *first class*: Types can be passed
as arguments to functions, and functions can return types as
their results. Even more, types can *depend* on other *values*.
What this means, and why this is incredibly useful, we'll explore
in due time.

### 完全函数

A *total* function is a pure function, that is guaranteed to return
a value of the expected return type for every possible input in
a finite amount of time. A total function will never fail with an
exception or loop infinitely.

Idris comes with a totality checker built in, which enables us to
verify the functions we write to be provably total. Totality
in Idris is opt-in, as in general, checking the totality of
an arbitrary computer program is undecidable
(see also the [halting problem](https://en.wikipedia.org/wiki/Halting_problem)).
However, if we annotate a function with the `total` keyword,
Idris will fail with a type error, if its totality checker
cannot verify that the function in question is indeed total.

## 使用 REPL

Idris comes with a useful REPL (an acronym for *Read Evaluate
Print Loop*), which we will use for tinkering with small
ideas, and for quickly experimenting with the code we just wrote.
In order to start a REPL session, run the following command
in a terminal.

```repl
rlwrap idris2
```

(Using command-line utility `rlwrap` is optional. It
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

## 第一个 Idris 程序

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
idris2 --find-ipkg -o hello src/Tutorial/Intro.md
```

This will create executable `hello` in directory `build/exec`,
which can be invoked from the command-line like so (without the
dollar prefix; this is used here to distinguish the terminal command
from its output):

```sh
$ build/exec/hello
Hello World!
```

The `--find-ipkg` option will look for an `.ipkg` file in the
current directory or one of its parent directories, from which
it will get other settings like the source directory to use
(`src` in our case). The `-o` option gives the name of the
executable to be generated. Type `idris2 --help` for a list
of available command-line options and environment variables.

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

Note: It might be instructive to omit the `--find-ipkg` option.
You will get an error message about the module name `Tutorial.Intro`
not matching the file path `src/Tutorial/Intro.md`. You can
also use option `--source-dir src` to silence this error.

## 一个 Idris 定义包含什么

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
distanceToMax：Bits8 -> Bits8
distanceToMax n = maxBits8 - n
```

这引入了一些新语法和一种新类型：函数类型。 `distanceToMax : Bits8 -> Bits8` 可以这样读：“`distanceToMax` 是 具有一个`Bits8` 类型参数的函数，它返回 `Bits8`" 类型的结果。在实现中，参数给定一个本地标识符 `n`，然后在右侧计算。再次继续尝试 REPL 的功能：

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

## 在哪里可以获得帮助

There are several resources available online and in print, where
you can find help and documentation about the Idris programming
language. Here is a non-comprehensive list of them:

* [使用 Idris
  进行类型驱动开发](https://www.manning.com/books/type-driven-development-with-idris)

  *专门*讲 Idris 的书！这描述得很详细。使用 Idris 和依赖类型的核心概念编写健壮和简洁的代码。它使用 Idris 1 实现书中的例子，所以使用 Idris 2 时它的一部分必须稍微调整，有一个[所需更新列表](https://idris2.readthedocs.io/en/latest/typedd/typedd.html)。

* [Idris 2
  速成课程](https://idris2.readthedocs.io/en/latest/tutorial/index.html)

  Idris 2 官方教程。全面而密集的解释 Idris 2 的所有功能。我发现这作为参考很有用，因此它是高度可访问的。但是，它不是函数式编程或类型驱动开发的入门介绍

* [Idris 2 GitHub 存储库](https://github.com/idris-lang/Idris2)

  在这里查看详细的安装说明和一些介绍材料。还有一个[wiki](https://github.com/idris-lang/Idris2/wiki)，
  在这里你可以找到[编辑器插件列表](https://github.com/idris-lang/Idris2/wiki/The-Idris-editor-experience)，
  [社区库列表](https://github.com/idris-lang/Idris2/wiki/Libraries),
  [外部后端列表](https://github.com/idris-lang/Idris2/wiki/External-backends),
和其他有用的信息。

* [Idris 2 Discord 频道](https://discord.gg/UX68fDs2jc)

  如果你被一段代码卡住了，想问一些晦涩的语言功能，想推广你的新库，或者想和其他 Idris 程序员一起出去玩，可以来这个地方。Discord 频道非常活跃且对新人*非常*友好。

* The Idris REPL

  最后，Idris 本身可以提供很多有用的信息。在 Idris 编程的时间我倾向于至少打开一个 REPL 会话。我的编辑器（neovim）已设置使用 [Idris 2 的语言服务器](https://github.com/idris-community/idris2-lsp)，在 REPL 中这非常有用。

  * 使用 `:t` 检查表达式或元变量（孔）的类型：`:t foldl`,
  * 使用 `:ti` 检查包含隐式参数的函数类型：`:ti foldl`,
  * 使用 `:m` 列出范围内的所有元变量（孔），
  * 使用 `:doc` 访问顶级函数 (`:doc the`) 的文档，一种数据类型及其所有构造函数和可用提示 (`:doc Bool`
    )，语言特征（`:doc case`, `:doc let`, `:doc interface`, `:doc record`，甚至 `:doc
    ?`)，或者一个接口（`:doc Uninhabited`），
  * 使用 `:module` 从可用包之一导入模块：`:module Data.Vect`,
  * 使用 `:browse` 列出加载模块导出的所有函数的名称和类型： `:browse Data.Vect`,
  * 使用 `:help` 获取其他命令的列表以及每个命令的简短描述。

## 概括

In this introduction we learned about the most basic
features of the Idris programming language. We used
the REPL to tinker with our ideas and inspect the
types of things in our code, and we used the Idris
compiler to compile an Idris source file to an executable.

We also learned about the basic shape of a top level
definition in Idris, which always consists of an identifier
(its name), a type, and an implementation.

### 下一步是什么？

In the [next chapter](Functions1.md), we start programming
in Idris for real. We learn how to write our own pure
functions, how functions compose, and how we can treat
functions just like other values and pass them around
as arguments to other functions.
