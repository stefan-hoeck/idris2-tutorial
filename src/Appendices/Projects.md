# Structuring Idris Projects

In this section I'll show you how to organize, install, and depend on
larger Idris projects. We will have a look at Idris packages,
the module system, visibility of types and functions, writing
comments and doc strings, and using pack for managing our libraries.

This section can be useful for all readers who have already
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
with the `--source-dir` command-line option. The following works from
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
your project (see later in this section) and define the source
directory there. Afterwards, you can use pack (instead of the `idris2`
executable) to start REPL sessions and load your source files.

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
about packages below): `Data.List` from the *base* package, which
will be installed as part of your Idris installation.

The second line imports module `Text.CSV` from within our own source
directory `src`. It is always possible to import modules that are part
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
(for an example, see module `Control.Monad.State` in *base*; really,
you should go to the [Idris2 project page](https://github.com/idris-lang/Idris2)
and actually *look at the code*!). The base library can be found
in the `libs` subfolder.

It often happens that in order to make use of functions from some module
`A` we also require utilities from another module `B`, so `A` should
re-export `B`. For instance, `Data.Vect` in *base* re-exports `Data.Fin`,
because the latter is often required when working with vectors.

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
a REPL after session (after type checking the tutorial)
without loading a source file from this project's root folder:

```sh
pack typecheck tutorial
pack repl
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

Sometimes, we want to define several functions or data types
with the same name in a single module. Idris does not allow this,
because every name must be unique in its *namespace*, and the
namespace of a module is just the fully qualified module name.

However, it is possible to define additional namespaces within
a module by using the `namespace` keyword followed by the name
of the namespace. All functions, which should belong to this
namespace must then be indented by the same amount of whitespace.

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
the following fails with a disambiguation error, because there
are several functions called `head` in scope and it is not clear
from `head`'s argument (some data type supporting list syntax,
of which again several are in scope), which version we want:

```idris
failing "Ambiguous elaboration."
  whatHead : Nat
  whatHead = head [12,"foo"]
```

By prefixing `head` with part of its namespace, we can resolve both
ambiguities. It is now immediately clear, that `[12,"foo"]` must be
an `HVect`, because that's the type of `HVect.head`'s argument:

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
In general, this is a rather hacky way to work around visibility
constraints, but it can be useful at times.

## Packages

Idris packages allow us to assemble several modules into
a logical unit and make them available to other Idris projects
by *installing* the package. In this section we will learn
about the structure of an Idris package and how to depend on
other packages.

### The `.ipkg` File

At the heart of an Idris package lies the package's `.ipkg` file,
which is usually but not necessarily stored at a project's root directory.
For instance, for this Idris tutorial, there is file
`tutorial.ipkg` in the root directory. An `.ipkg` file consists
of several key-value pairs (most of them optional), the
most important of which I'll describe here. By far the easiest
way to setup a new Idris package is by letting pack (or Idris itself)
do it for you. Just run `pack new lib pkgname` to create the skeleton
of a new library or `pack new bin appname` to setup a new application.

### Dependencies

One of the most important fields in an `.ipkg` file is
the `depends` fields, where dependencies on other
packages are listed. Here is an example from the
[*hedgehog* package](https://github.com/stefan-hoeck/idris2-hedgehog)
a framework for writing property tests in Idris:

```ipkg
depends    = base         >= 0.5.1
           , contrib      >= 0.5.1
           , elab-util    >= 0.5.0
           , pretty-show  >= 0.5.0
           , sop          >= 0.5.0
```

As you can see, *hedgehog* depends on *base* and *contrib*,
both of which are part of every Idris installation, but
also on
[*elab-util*](https://github.com/stefan-hoeck/idris2-elab-util),
a library of utilities for writing elaborator scripts (a
powerful technique for creating Idris declarations by
writing Idris code; it comes with its own lengthy tutorial
if you are interested),
[*sop*](https://github.com/stefan-hoeck/idris2-sop), a library
for generically deriving interface implementations via a
*sum of products* representation (this is a useful thing
you might want to check out some day), and
[*pretty-show*](https://github.com/stefan-hoeck/idris2-pretty-show),
a library for pretty printing Idris values (*hedgehog* makes
use of this in case a test fails).

So, before you actually can use *hedgehog* to write some
property tests for your own project, you will need to
install the packages it depends on before installing
*hedgehog* itself. Since this can be a cumbersome thing to do manually,
it is best to let a package manager like pack handle this tedious task
for you.

#### Dependency Versions

You might want to specify a certain version (or a range)
Idris should use for your dependencies. This might be useful
if you have several versions of the same package installed
and not all of them are compatible with your project.
Here are several examples:

```ipkg
depends    = base         == 0.5.1
           , contrib      == 0.5.1
           , elab-util    >= 0.5.0
           , pretty-show
           , sop          >= 0.5.0 && < 0.6.0
```

This will look for packages *base* and *contrib* of
exactly the given version, package *elab-util* of a version
greater than or equal to `0.5.0`, package *pretty-show* of
any version, and package *sop* of a version in the given
range. In all cases, if several installed versions of a
package match the specified range, the latest version will
be used.

In order to make use of this for your own packages, every
`.ipkg` file should give the package's name and current
version:

```ipkg
package tutorial

version    = 0.1.0
```

### Library Modules

Many if not most Idris packages available on GitHub are
programming *libraries*: They implement some piece of
functionality and make it available to all projects importing
the given package. This is unlike Idris *applications*, which
are supposed to be compiled to an executable, which can then
be run on your computer. The Idris project itself provides
both: The Idris compiler application, which we use to
type check and build other Idris libraries and applications,
and several libraries like *prelude*, *base*, and *contrib*,
which provide basic data types and functions useful in
most Idris projects.

In order to type check and install the modules you wrote in a
library, you must list them in the `modules` field. Here is
an excerpt from the *sop* package:

```ipkg
modules = Data.Lazy
        , Data.SOP
        , Data.SOP.Interfaces
        , Data.SOP.NP
        , Data.SOP.NS
        , Data.SOP.POP
        , Data.SOP.SOP
        , Data.SOP.Utils
```

Modules missing from this list will *not* be installed and hence
will not be available for other modules depending on the sop library.

### Pack and its curated Collection of Packages

When the dependency graph of your project is large and complex, that is,
when your project depends on many libraries that themselves depend on yet
other libraries, it can happen that two packages depend both on different
(maybe incompatible) versions of a third package. This situation can be nigh to
impossible to resolve, and can lead to a lot of frustration when working
with conflicting libraries.

It is therefore the philosophy of the pack project to avoid such a situation
from the very beginning by making use of *curated package collections*. A pack
collections consists of a specific GitHub commit of the Idris compiler and a set
of packages, again each at a specific GitHub commit, all of which have been
tested to work well and without issues together. You can see a list of
packages available to pack [here](https://github.com/stefan-hoeck/idris2-pack-db/blob/main/STATUS.md).

Whenever a project you are working on depends on one of the libraries listed
in pack's package collection, pack will automatically install it and all of its
dependencies for you. However, you might also want to depend on a library that
is not yet part of pack's collection. In that case, you must specify the
library in question in one of your `pack.toml` files - the global
one found at `$HOME/.pack/user/pack.toml`, or the one local to your
current project (if any). There, you can either specify a dependency local
to your system or a remote project on GitHub. An example for each is
shown below:

```toml
[custom.all.foo]
type = "local"
path = "/path/to/foo"
ipkg = "foo.ipkg

[custom.all.bar]
type   = "github"
url    = "//https://github.com/me/bar"
commit = "latest:main"
ipkg   = "bar.ipkg"
```

As you can see, in both cases you have to specify where the project can be
found as well as the name and location of its `.ipkg` file. In case of
a GitHub project, you also need to tell pack the commit it should use.
In the example above, we want to use the latest commit from the `main`
branch. We can use `pack fetch` to fetch and store the currently latest
commit hash.

Entries like the ones given above are all that is needed to add support to
custom libraries to pack. You can now list these libraries as dependencies
in your project's `.ipkg` file(s) and pack will automatically install them
for you.

<!-- vi: filetype=idris2
-->
