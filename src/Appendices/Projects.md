# Structuring Idris Projects

In this tutorial I'll show you how to organize, install, and depend on
larger Idris 2 projects. We will have a look at Idris packages,
the module system, visibility of types and functions, and writing
comments and doc strings.

This tutorial can be useful for all readers who have already
written a bit of Idris code. We will not do any fancy type level
wizardry in here, but I'll demonstrate several concepts using
`failing` code blocks. This rather new addition to the language
allows us to show code that is expected to fail during elaboration
(type checking). For instance:

```repl
failing "Can't find an implementation for FromString Bits8."
  ohno : Bits8
  ohno = "Oh no!"
```

As part of a failing block, we can give a substring of the compiler's
error message for documentation purposes and to make sure the block
fails with the expected error.

## Modules

Every Idris source file defines a *module*, typically starting with a
module header like the one below:

```idris
module Appendices.Projects
```

A module's name consists of several upper case identifiers separated
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
a new name. This name will then be the one seen when we transitively
import `Data.List1` via `Appendices.Projects`. To see this, start
a REPL session without loading a source file from this project's
root folder:

```sh
idris2 --find-ipkg
```

Now load module `Appendices.Projects` and checkout the type
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

### Namespaces

Sometimes we want to define several functions or data types
with the same name in a single module. Idris does not allow this,
because every name must be unique in its *namespace*, and the
namespace of a module is just the fully qualified module name.

However, it is possible to define additional namespaces within
a module by using the `namespace` keyword followed by the name
of the namespace. All functions, which should belong to this
namespace must be indented by the same amount of whitespace.

Here's an example:

```idris
data HList : List Type -> Type where
  Nil  : HList []
  (::) : (v : t) -> (vs : HList ts) -> HList (t :: ts)

head : HList (t :: ts) -> t
head (v :: _) = v

tail : HList (t :: ts) -> HList ts
tail (_ :: vs) = vs

namespace HVect
  public export
  data HVect : Vect n Type -> Type where
    Nil  : HVect []
    (::) : (v : t) -> (vs : HVect ts) -> HVect (t :: ts)

  public export
  head : HVect (t :: ts) -> t
  head (v :: _) = v

  public export
  tail : HVect (t :: ts) -> HVect ts
  tail (_ :: vs) = vs
```

Function names `HVect.head` and `HVect.tail` as well as constructors
`HVect.Nil` and `HVect.(::)` would clash with functions and constructors
of the same names from the outer namespace (`Appendices.Projects`), so
we had to put them in their own namespace. In order to be able to use
them from outside their namespace, they need to be exported (see the
section on visibility below). In case we need to disambiguate between
these names, we can prefix them with part of their namespace. For instance,
the following fails with a disambiguation error:

```idris
failing "Ambiguous elaboration."
  whatHead : Nat
  whatHead = head [12,"foo"]
```

By prefixing `head` with part of its namespace, we can resolve the
ambiguity:

```idris
thisHead : Nat
thisHead = HVect.head [12,"foo"]
```

In the following subsection I'll make use of namespaces to demonstrate
the principles of visibility.

### Visibility

In order to use functions and data types outside of the module
or namespace they were defined in, we need to change
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
OneHundred : Bits8
OneHundred = square 10
```

However, the *implementation* of `square` will not be exported,
so `square` will not reduce during elaboration:

```idris
failing "Can't solve constraint between: 100 and square 10."
  checkOneHundred : OneHundred === 100
  checkOneHundred = Refl
```

For this to work, we need to *publicly export* `square`:

```idris
namespace SquarePub
  public export
  squarePub : Num a => a -> a
  squarePub v = v * v

OneHundredAgain : Bits8
OneHundredAgain = squarePub 10

checkOneHundredAgain : OneHundredAgain === 100
checkOneHundredAgain = Refl
```

Therefore, if you need a function to reduce during elaboration
(type checking), annotate it with `public export` instead of `export`.
This is especially important if you use a function to compute
a type. Such function's *must* reduce during elaboration, otherwise they
are completely useless:

```idris
namespace Stupid
  export
  0 NatOrString : Type
  NatOrString = Either String Nat

failing "Can't solve constraint between: Either String ?b and NatOrString."
  natOrString : NatOrString
  natOrString = Left "foo"
```

If we publicly export our type alias, everything type checks fine:

```idris
namespace Better
  public export
  0 NatOrString : Type
  NatOrString = Either String Nat

natOrString : Better.NatOrString
natOrString = Left "bar"
```

### Visibility of Data Types

Visibility of data types behaves slightly differently. If set to
`private` (the default), neither the *type constructor* nor
the *data constructors* are visible outside of the namespace
they where defined in. If annotated with `export`,
the type constructor is exported but not the data constructors:

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
we cannot use the `Foo1` constructor to create a value
of type `Foo` directly:

```idris
failing "Export.Foo1 is private."
  foo : Export.Foo
  foo = Foo1 "foo"
```

This changes when we publicly export the data type:

```idris
namespace PublicExport
  public export
  data Foo : Type where
    Foo1 : String -> PublicExport.Foo
    Foo2 : Nat -> PublicExport.Foo

foo2 : PublicExport.Foo
foo2 = Foo2 12
```

The same goes for interfaces: If they are publicly exported, the
interface (a type constructor) plus all its functions are exported
and you can write implementations outside the namespace where
they where defined:

```idris
namespace PEI
  public export
  interface Sized a where
    size : a -> Nat

Sized Nat where size = id

sumSizes : Foldable t => Sized a => t a -> Nat
sumSizes = foldl (\n,e => n + size e) 0
```

If they are not publicly exported, you will not be able to write
implementations outside the namespace they were defined in
(but you can still use the type and its functions in your code):

```idris
namespace EI
  export
  interface Empty a where
    empty : a -> Bool

  export
  Empty (List a) where
    empty [] = True
    empty _  = False

failing
  Empty Nat where
    empty Z = True
    empty (S _) = False

nonEmpty : Empty a => a -> Bool
nonEmpty = not . empty
```

### Child Namespaces

Sometimes, it is necessary to access a private function
in another module or namespace. This is possible from within child namespaces
(for want of a better name): Modules and namespaces sharing the
parent module's or namespace's prefix. For instance:

```idris
namespace Inner
  testEmpty : Bool
  testEmpty = nonEmpty (the (List Nat) [12])
```

As you can see, we can access function `nonEmpty` from
within namespace `Appendices.Projects.Inner`, although it is a
private function of module `Appendices.Projects`. This is
even possible for modules: If you were to write a module
`Data.List.Magic`, you'd have access to private utility functions
defined in module `Data.List` in *base*. Actually, I did just that
and added module `Data.List.Magic` demonstrating this quirk
of the Idris module system (go have a look!).
Typically, this is a rather hacky way to work around visibility
constraints, but it can be useful at times.

<!-- vi: filetype=idris2
-->
