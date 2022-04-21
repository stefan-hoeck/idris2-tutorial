# Structuring Idris Projects

In this tutorial I'll show you how to organize, install, and depend on
larger Idris 2 projects. We will have a look at Idris packages,
the module system, visibility of types and functions, and writing
comments and doc strings.

## Modules

Every Idris source file defines a *module*, typically starting with a
module header like the one below:

```idris
module Appendices.Projects
```

A module's name consists of several upper case identifier separated
by dots, which must reflect the path of the `.idr` file where the
module is stored. For instance, this module is stored in file
`Appendices/Projects.md`, so the module's name is `Appendices.Projects`.

"But wait!", I hear you say, "What about the parent folder(s) of `Appendices`?
Why aren't those part of the module's name?" In order to understand this,
we must talk about the concept of the *source directory*. The source directory
is where Idris is looking for source files. It defaults to the
directory, from which the Idris executable is run. For instance, when
in folder `src` of this project, you can open this source file like so:

```sh
idris2 Appendices/Projects.md
```

This will not work, however, if you try the same thing from this
project's root folder:

```sh
$ idris2 src/Appendices/Projects.md
...
Error: Module name Appendices.Projects does not match file name "src/Appendices/Projects.md"
...
```

So, which folder names to include in a module name depends on the
parent folder we consider to be our source directory. It is common
practice to name the source directory `src`, although this is not
mandatory (as I said above, the default is actually the directory,
from which we run Idris). It is possible to change the source directory
with the `--source-dir` command line option. The following works from
within this project's root directory:

```sh
idris2 --source-dir src src/Appendices/Projects.md
```

And the following would work from a parent directory
(assuming this tutorial is stored in folder `tutorial`):

```sh
idris2 --source-dir tutorial/src tutorial/src/Appendices/Projects.md
```

Most of the time, however, you will specify an `.ipkg` file for
your project (see later in this tutorial) and define the source
directory there.

### Module Imports

You often need to import functions and data types from other
modules when writing Idris code. This can be done with an
`import` statement. Here are several examples showing
how these might look like:

```idris
import Data.List
import Text.CSV
import public Appendices.Neovim
import Data.Vect as V
import public Data.List1 as L
```

The first line imports a module from another *package* (we will learn
about packages below): The *base* package, which will be installed
as part of your Idris installation.

The second line imports module `Text.CSV` from within our own source
directory. It is always possible to import modules, which are part
of the same source directory as the file we are working on.

The third line imports module `Appendices.Neovim`, again from our
own source directory. Note, however, that this `import` statement comes
with an additional `public` keyword. This allows us to *re-export*
a module, so that it is available from within other modules in addition
to the current module: If another module imports `Appendices.Projects`,
module `Appendices.Neovim` will be imported as well without the need
of an additional `import` statement. This is useful when
we split some complex functionality across different modules and
want to import the lot via a single catch-all module
(for an example, see module `Control.Monad.State` in *base*). It also
often happens that in order to make use of functions from a module
`A` we also require utilities from a module `B`, so `A` should
re-export `B`. For instance, `Data.Vect` in *base* re-exports `Data.Fin`.

The fourth line imports module `Data.Vect`, giving it a new name `V`, to
be used as a shorter prefix. If you often need to disambiguate identifiers
by prefixing them with a module's name, this can help making your code
more concise:

```idris
vectSum : Nat
vectSum = sum $ V.fromList [1..10]
```

Finally, on the fifth line we publicly import a module and give it
a new name. This name will then be the one seen we transitively
import `Data.List1` via `Appendices.Projects`. To see this, start
a REPL session without loading a source file from this project's
root folder:

```sh
idris2 --find-ipkg
```

Now load module `Appendices.Projects` a checkout the type
of `singleton`:

```repl
Main> :module Appendices.Projects
Imported module Appendices.Projects
Main> :t singleton
Data.String.singleton : Char -> String
Data.List.singleton : a -> List a
L.singleton : a -> List1 a
```

As you can see, the `List1` version of `singleton` is now prefixed
with `L` instead of `Data.List1`. It is still possible to use the
"official" prefix, though:

```repl
Main> List1.singleton 12
12 ::: []
Main> L.singleton 12
12 ::: []
```

### Visibility

In order to use functions and data types outside of the module
(or namespace) where they were define, we need to change
their *visibility*. The default visibility is `private`:
Such a function or data type is not visible from outside
its module or namespace:

```idris
namespace Foo
  foo : Nat
  foo = 12

failing "Name Appendices.Projects.Foo.foo is private."
  bar : Nat
  bar = 2 * foo
```

In the example above, I used a `failing` block to demonstrate
that `bar` will fail to elaborate.

To make a function visible, annotate it with the `export`
keyword:

```idris
namespace Square
  export
  square : Num a => a -> a
  square v = v * v
```

This will allow us to invoke function `square` from within
other modules or namespaces (after importing `Appendices.Projects`):

```idris
oneHundred : Bits8
oneHundred = square 10
```

However, the *implementation* of `square` will not be exported,
so `square` will not reduce during elaboration:

```idris
failing "Can't solve constraint between: 100 and square 10."
  checkOneHundred : Projects.oneHundred === 100
  checkOneHundred = Refl
```

For this to work, we need to *publicly export* `square`:

```idris
namespace SquarePub
  public export
  squarePub : Num a => a -> a
  squarePub v = v * v

oneHundredAgain : Bits8
oneHundredAgain = squarePub 10

checkOneHundredAgain : Projects.oneHundredAgain === 100
checkOneHundredAgain = Refl
```

Therefore, if you expect to require a function during elaboration
(type checking), annotate it with `public export` instead of `export`.
This is especially important if you use a function to compute
a type. Such function's must reduce during elaboration, otherwise they
are completely useless:

```idris
namespace Stupid
  export
  0 Foo : Type
  Foo = Either String Nat

failing "Can't solve constraint between: Either String ?b and Foo."
  foo : Foo
  foo = Left "foo"
```

If we publicly export our type alias, everything type checks fine:

```idris
namespace Better
  public export
  0 Bar : Type
  Bar = Either String Nat

bar : Bar
bar = Left "bar"
```

### Visibility of Data Types

Visibility of data types behaves slightly different. If they are
`private`, neither the *type* nor the *data constructors* are visible
outside of the namespace they where defined in. If they
are annotated with `export`, the type (constructor) is exported
but not the data constructors:

```idris
namespace Export
  export
  data Foo : Type where
    Foo1 : String -> Foo
    Foo2 : Nat -> Foo

  export
  mkFoo1 : String -> Export.Foo
  mkFoo1 = Foo1

foo1 : Export.Foo
foo1 = mkFoo1 "foo"
```

As you can see, we can use the type `Foo` as well as
function `mkFoo1` outside of namespace `Export`. However,
we cannot use the `MkFoo` constructor to create a value
of type `Foo` directly:

```idris
failing "Export.Foo1 is private."
  foo : Export.Foo
  foo = Foo1 "foo"
```

<!-- vi: filetype=idris2
-->
