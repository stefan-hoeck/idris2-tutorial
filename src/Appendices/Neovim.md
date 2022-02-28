# Interactive Editing in Neovim

Idris provides extensive capabilities to interactively
analyze the types of values and expressions in our programs
and fill out skeleton implementations and sometimes even whole
programs for us based on the types provided. These interactive
editing features are available via plugins in different editors.
Since I am a Neovim user, I explain the Idris related parts of
my own setup in detail here.

The main component required to get all these features to run
in Neovim is an executable provided by the
[idris2-lsp project](https://github.com/idris-community/idris2-lsp).
This executable makes use of the Idris compiler API (application
programming interface) internally, and can check the syntax and
types of the source code we are working on. It communicates with
Neovim via the language server protocol (LSP). This communication
is setup through the [idris2-nvim plugin](https://github.com/ShinKage/idris2-nvim).

As we will see in this tutorial, the `idris2-lsp` executable not only
supports syntax and type checking, but comes also with additional
interactive editing features. Finally, the Idris compiler API supports
semantic highlighting of Idris source code: Identifiers and keywords
are highlighted not only based on the language's syntax (that would
be *syntax highlighting*, a feature expected from all modern
programming environments and editors), but also based on their
*semantics*. For instance, a local variable in a function implementation
gets highlighted differently than the name of a top level function,
although syntactically these are both just identifiers.

```idris
module Appendices.Neovim

import Data.Vect

%default total
```

## Setup

In order to make full use of interactive Idris editing in
Neovim, at least the following tools need to be installed:

* A recent version of Neovim (version 0.5 or later).
* A recent version of the Idris compiler (at least version 0.5.1).
  Personally, I suggest you install Idris 2 from source, in order
  to get better control of the version to use, using the version
  specified in file `.idris-version` in this project.
* The Idris compiler API. This can be installed with command
  `make install-with-src-api` from the Idris project's root folder after
  installing the language itself. You might need to clean the project
  (`make clean`) before installing the API.
* The [idris2-lsp package](https://github.com/idris-community/idris2-lsp).

In addition, if you are new to Neovim and want to use the `init.vim`
file provided in the `resources` folder, you need to install
[vim-plug](https://github.com/junegunn/vim-plug). Afterwards,
copy all or parts of `resources/init.vim`  to your own `init.vim`
file. (Use `:help init.vim` from within Neovim in order to find
out where to look for this file.)

When you first use the `init.vim` from the `resources` folder,
you need to make sure to install all necessary plugins. From
within Neovim, run command `:PlugUpdate` when in normal mode.
Note also: If you make changes to your `init.vim` file, you have to
restart Neovim, or resource the file from a running Neovim
instance by running `source $MYVIMRC` when in normal mode.

## A Typical Workflow

In order to checkout the interactive editing features
available to us, we will reimplement some small utilities
from the *Prelude*. In order to follow along, you should have
already worked through the [Introduction](../Tutorial/Intro.md),
[Functions Part 1](../Tutorial/Functions1.md), and at least
parts of [Algebraic Data Types](../Tutorial/DataTypes.md).

Let's start with negation of a boolean value:

```idris
negate1 : Bool -> Bool
```

Typically, when writing Idris code we follow the mantra
"types first". Although you might already have an idea about
how to implement a certain piece of functionality, you still
need to provide an accurate type before you can start writing
your implementation. This means, when programming in Idris we have
to mentally keep track of the implementation of an algorithm
and the types involved at the same time, both of which can
become arbitrarily complex. Or do we? Remember that Idris knows
at least as much about the variables and their types available
in the current context of a function implementation as we do,
so we probably should ask it for guidance instead of trying
to do everything on our own.

So, in order to proceed, we ask Idris for a skeleton function
body: In normal mode, move your cursor on the line where
`negate1` is declared and enter `<LocalLeader>a` in quick
succession. `<LocalLeader>` is a special key that can specified
in the `init.vim` file. If you
use the `init.vim` from the `resources` folder, it is set to
the comma key, in which case the above command consists of a
comma quickly followed by the lowercase letter "a". See
also `:help leader` and `:help localleader`.

Idris will generate a skeleton implementation similar to the
following:

```idris
negate2 : Bool -> Bool
negate2 x = ?negate2_rhs
```

Note, that on the left hand side a new variable with name
`x` was introduced, while on the right hand side, Idris
added a *metavariable* (also called a *hole*). This is an
identifier prefixed with a question mark. It signals to Idris,
that we will implement this part of the function later.
The cool thing about holes is, that we can *hover* on them
and inspect their types and the types of values in the
surrounding context. You can do so by placing the cursor
on an identifier and entering `K` (an uppercase letter) in
normal mode. This will open a popup displaying the type of
the variable under the cursor plus the types and quantities of
the variables
in the surrounding context. You can also have this information
displayed in a separate window: Enter `<LocalLeader>so` to
open this window and repeat the hovering. The information will
appear in the new window and as an additional benefit, it will
be semantically highlighted. Enter `<LocalLeader>sc` to close
this window again. Go ahead and checkout the type and
context of `?negate2_rhs`.

Most functions in Idris are implemented by pattern matching
on one or more of the variables on the right hand side. Idris,
knowing the data constructors of all non-primitive data types
can write such pattern matches for us (a process also called
*case splitting*). To give this a try, move the cursor on the `x`
in the skeleton implementation of `negate2`, and enter
`<LocalLeader>c` in normal mode. The result will look as
follows:

```idris
negate3 : Bool -> Bool
negate3 False = ?negate3_rhs_0
negate3 True = ?negate3_rhs_1
```

As you can see, Idris inserted a hole for each of the cases on the
right hand side. We can inspect the types of these holes
and replace them with a proper implementation.

This concludes the introduction of the (in my opinion) core
features of interactive editing: Hovering on metavariables,
adding skeleton function implementations, and case splitting
(which also works in case blocks and for nested pattern
matches). You should start using these all the time *now*!

## Expression Search

Sometimes, Idris knows enough about the types involved, that
it can come up with an implementation on its own. For instance,
let us implement function `either` from the *Prelude*.
After giving its type, creating a skeleton implementation,
and case splitting on the `Either` argument, we arrive at
something similar to the following:

```idris
either2 : (a -> c) -> (b -> c) -> Either a b -> c
either2 f g (Left x) = ?either2_rhs_0
either2 f g (Right x) = ?either2_rhs_1
```

Idris can come up with expressions for the two metavariables
on its own, because the types are specific enough. Move
the cursor onto one of the metavariables and enter
`<LocalLeader>o` in normal mode. You will be given
a selection of possible expressions (only one in this case),
of which you can choose a fitting one (or abort with `q`).

Here is another example: A reimplementation of function `maybe`.
If you run an expression search on `?maybe2_rhs1`, you will
get a larger list of choices.

```idris
maybe2 : b -> (a -> b) -> Maybe a -> b
maybe2 x f Nothing = x
maybe2 x f (Just y) = ?maybe2_rhs_1
```

Idris is also capable of coming up with a complete function
implementation based on a functions type. For this to work well
in practice, the number of possible implementations satisfying
the type checker must be pretty small. As an example, here is
function `zipWith` for vectors. You might not yet have heard
about vectors: They will be introduced in the chapter about
[dependent types](../Tutorial/Dependent.md). You can still give
this a go. Just move the cursor on the line declaring `zipWithV`,
enter `<LocalLeader>gd` and select the first option. This will
automatically generate the whole function body including
case splits and implementations.

```idris
zipWithV : (a -> b -> c) -> Vect n a -> Vect n b -> Vect n c
```

Expression search only works well if the types are specific
enough. If you feel like that might be the case, go ahead
and give it a go, either by running `<LocalLeader>o` on
a metavariable, or by trying `<LocalLeader>gd` on a
function declaration.

## More Code Actions

There are other shortcuts for generating part of your code
available, two of which I'll explain here.

First, it is possible to add a new case block by entering
`<LocalLeader>mc` in normal mode when on a metavariable.
For instance, here is part of an implementation of `filterList`,
which appears in an exercise in the chapter about
algebraic data types. I arrived at this by letting Idris
generate a skeleton implementation followed by a case split
and an expression search on the first metavariable:

```idris
filterList : (a -> Bool) -> List a -> List a
filterList f [] = []
filterList f (x :: xs) = ?filterList_rhs_1
```

We will next have to pattern match on the result of applying
`x` to `f`. Idris can introduce a new case block for us,
if we move the cursor on metavariable `?filterList_rhs_1`
and enter `<LocalLeader>mc` in normal mode. We can then
continue with our implementation by first giving the
expression to use in the case block (`f x`) followed by a
pattern match on the new variable in the case block.
This will lead us to an implementation similar to the following
(I had to fix the indentation, though):

```idris
filterList2 : (a -> Bool) -> List a -> List a
filterList2 f [] = []
filterList2 f (x :: xs) = case f x of
  False => ?filterList2_rhs_2
  True => ?filterList2_rhs_3
```

Sometimes, we want to extract a utility function from
an implementation we are working on. This is also often
necessary when we write proofs about our code
(see chapters [Propositional Equality](../Tutorial/Eq.md)
and [Predicates](../Tutorial/Predicates.md) for instance).
In order to do so, we can move the cursor on a metavariable,
and enter `<LocalLeader>ml`. Give this a try with
`?whatNow` in the following example (this will work better
in a regular Idris source file instead of the literate
file I use for this tutorial):

```idris
traverseEither : (a -> Either e b) -> List a -> Either e (List b)
traverseEither f [] = Right []
traverseEither f (x :: xs) = ?whatNow x xs f (f x) (traverseEither f xs)
```

Idris will create a new function declaration with the
type and name of `?whatNow` and replace the hole in
`traverseEither` with a call to this new function:

```idris
whatNow2 : a -> List a -> (a -> Either e b) -> Either e b -> Either e (List b) -> Either e (List b)

traverseEither2 : (a -> Either e b) -> List a -> Either e (List b)
traverseEither2 f [] = Right []
traverseEither2 f (x :: xs) = whatNow2 x xs f (f x) (traverseEither f xs)
```

## Getting Information

The `idris2-lsp` executable and through it, the `idris2-nvim` plugin
not only supports the code actions described above. Here is a
non-comprehensive list of other possibilities. I suggest you try
out each of them from within this source file.

* Typing `K` on an identifier in normal mode shows its type
  and namespace (if any). In case of a metavariable, variables and
  types and quantities in the current context are displayed as well.
  Entering `<LocalLeader>so` opens a new window where this information
  is displayed and semantically highlighted.
* Typing `gd` on a function, operator, data constructor or type
  constructor in normal mode jumps to the function's definition.
  For external modules, this works only if the
  module in question has been installed together with its source code
  (by using the `idris2 --install-with-src` command).
* Typing `<LocalLeader>mm` opens a popup window listing all metavariables
  in the current module. You can place the cursor on an entry and
  jump to its location by pressing `<Enter>`.
* Typing `<LocalLeader>mn` (or `<LocalLeader>mp`) jumps to the next
  (or previous) metavariable in the current module.
* Typing `<LocalLeader>br` opens a popup where you can enter a
  namespace. Idris will then show all functions (plus their types)
  exported from that namespace in a popup window, and you can
  jump to a function's definition by pressing enter on one of the
  entries. Note: The module in question must be imported in the
  current module.
* Typing `<LocalLeader>x` opens a popup where you can enter
  a REPL command or Idris expression, and the plugin will reply
  with a response from the REPL.
* Typing `<LocalLeader><LocalLeader>e` will display the error message
  from the current line in a popup window. This can be highly useful,
  if error messages are too long to fit on a single line. Likewise,
  `<LocalLeader>el` will list all error messages from the current
  buffer in a new window. You can then select an error message and
  jump to its origin by pressing `<Enter>`.

Other use cases and examples are described on the GitHub page
of the `idris2-nvim` plugin and can be included as described there.

## The `%name` Pragma

When you ask Idris for a skeleton implementation with `<LocalLeader>a`
or a case split with `<LocalLeader>c`,
it has to decide on what names to use for the new variables it introduces.
If these variables already have predefined names (from the function's
signature or constructor fields), those names will be used, but
otherwise Idris will as a default use names `x`, `y`, and `z`, followed
by other letters. You can change this default behavior by for each
data type specifying a list of names to use for such occasions.

For instance:

```idris
data Element = H | He | C | N | O | F | Ne

%name Element e,f
```

Idris will then use these names (followed by these names postfixed
with a number), when it has to come up with variable names of this
type on its own. For instance, here is a test function and the
result of adding a skeleton definition to it:

```idris
test : Element -> Element -> Element -> Element -> Element
test e f e1 f1 = ?test_rhs
```

## Conclusion

Neovim, together with the `idris2-lsp` executable and the
`idris2-nvim` editor plugin, provides extensive utilities for
interactive editing when programming in Idris. Similar functionality
is available for some other editors, so feel free to ask what's
available for your editor of choice, for instance on the
Idris 2 discord channel.

<!-- vi: filetype=idris2
-->
