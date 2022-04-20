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

### Importing Modules

You often need to import functions and data type from other
modules when writing Idris code. This can be done with an
`import` statement. Here are several examples, how these might look like:

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
of the same source directory as the source file we are working on.

The third line imports module `Appendices.Neovim`, again from our
own source directory. Note, however, that this `import` statement comes
with an additional `public` keyword. This allows us to *re-export*
a module, so that it is available from within other modules in addition
the current module. So, if another module imports `Appendices.Projects`,
module `Appendices.Neovim` will be imported as well without the need
of an additional `import` statement. This is often useful when
we split some complex functionality across different modules and
want to import the lot via a single catch-all module.
An example of this can be seen in module `Control.Monad.State`
in the *base* library. This module only consists of two `import public`
statements, re-exporting modules `Control.Monad.State.Interface` and
`Control.Monad.State.State` (and two others).

The fourth line imports module `Data.Vect`, giving it a new name `V`, to
be used as a shorter prefix. If you often need to disambiguate identifiers
by prefixing them with a module's name, this can help making your code
more concise:

```idris
vectSum : Nat
vectSum = sum $ V.fromList [1..10]
```

Finally, on the fifth line we publicly import a module and give it
a new name. This name will then be the one seen when transitivelyk

<!-- vi: filetype=idris2
-->
