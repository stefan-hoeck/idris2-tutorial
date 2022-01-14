# IO: Programming with Side Effects

So far, all examples and exercises dealt with pure, total functions.
We didn't read or write content from or to files, nor did
we write any messages to the standard output. It is time to change
that and learn, how we can write effectful programs in Idris.

```idris
module Tutorial.IO

import Data.String
import Data.Vect

%default total
```

## Pure Side Effects?

If we once again look at the *hello world* example from the
[introduction](Intro.md), it had the following type and implementation:

```idris
hello : IO ()
hello = putStrLn "Hello World!"
```

If you load this module in a REPL session and evaluate `hello`,
you'll get the following:

```repl
Tutorial.IO> hello
MkIO (prim__putStr "Hello World!")
```

This might not be what you expected, given that we'd actually wanted the
program to just print "Hello World!". In order to explain what's going
on here, we need to quickly look at how evaluation at the REPL works.

When we evaluate some expression at the REPL, Idris tries to
reduce it to a value until it gets stuck somewhere. In the above case,
Idris gets stuck at function `prim__putStr`. This is
a *foreign function* defined in the *Prelude*, which has to be implemented
by each backend in order to be available there. Idris knows nothing
about the implementation of foreign functions and therefore can't reduce
foreign function calls, unless they are built into the compiler itself.
But even then, values of type `IO a` (`a` being a type parameter) are
typically not reduced. We will quickly look at how `IO` is implemented
at the end of this tutorial, where we will also see, why these values
can't be reduced at the REPL.

For now, it is important to understand that values of type `IO a` *describe*
a program, which - when being *executed* - will return a value of type `a`,
while performing arbitrary side effects along the way. For instance,
`putStrLn` has type `String -> IO ()`. Read this as: "`putStrLn` is a function,
which, when given a `String` argument, will return a description of
a program, which - when being executed - performs arbitrary side effects
and eventually returns `()`". `()` is syntactic sugar for type `Unit`, the
empty tuple defined at the *Prelude*, which has only one value called `MkUnit`,
for which we can also use `()` in our code.

It is important to understand that values of type `IO a` *do not
perform any side effects*, they *describe* programs with side effects.
The side effects will only ever be performed, when these programs are being *executed*,
which happens, for instance, when we call `:exec hello` at the REPL.
Therefore, values of type `IO a` are *pure* descriptions of effectful
computations. It is therefore not possible to extract a value of type `a` from
a value of type `IO a`, as this would inadvertently execute the side
effects along the way, thus breaking referential transparency.

### Do Blocks

If you are new to pure functional programming, you might now - rightfully -
mumble something about how useless it is to
have descriptions of effectful programs without being able to run them.
So please, hear me out. While we are not able to run values of type
`IO a` when writing programs, that is, there is no function of
type `IO a -> a`, we are able to chain such computations and describe more
complex programs. Idris provides special syntax for this: Do blocks.
Here's an example:

```idris
readHello : IO ()
readHello = do
  name <- getLine
  putStrLn $ "Hello " ++ name ++ "!"
```

Before we talk about what's going on here, let's give this a go at
the REPL:

```repl
Tutorial.IO> :exec readHello
Stefan
Hello Stefan!
```

This is an interactive program, which will read a line from standard
input (`getLine`), assign the result to variable `name`, and then
use `name` to create a friendly greeting and write it to
standard output.

Note the `do` keyword at the beginning of the implementation of `readHello`:
It starts a *do block*, where we can chain `IO` computations and bind
intermediary results to variables using arrows pointing
to the left (`<-`), which can then be used in later
`IO` actions. This concept is powerful enough to let us describe arbitrary
programs with side effects in a single value of type `IO`. This whole
description is then returned by function `main`, the main entry point
to an Idris program. This describes the program being executed
when we run a compiled Idris binary.

### The Difference between Program Description and Execution

In order to better understand the difference between *describing*
an effectful computation and *executing* it, here is a small
program:

```idris
launchMissiles : IO ()
launchMissiles = putStrLn "Boom! You're dead."

friendlyReadHello : IO ()
friendlyReadHello = do
  _ <- putStrLn "Please enter your name."
  readHello

actions : Vect 3 (IO ())
actions = [launchMissiles, friendlyReadHello, friendlyReadHello]

runActions : Vect (S n) (IO ()) -> IO ()
runActions (_ :: xs) = go xs
  where go : Vect k (IO ()) -> IO ()
        go []        = pure ()
        go (y :: ys) = do
          _ <- y
          go ys

readHellos : IO ()
readHellos = runActions actions
```

First, we define a friendlier version of `readHello`: When executed, this will
ask about our name explicitly. Since we will not use the result
of `putStrLn` any further, we can use an underscore as a catch-all
pattern here. Afterwards, `readHello` is invoked. We also define
`launchMissiles`, which - when being executed - will lead to the
destruction of planet earth.

Now, `runActions` is the function we use to
test that *describing* an `IO` action is not the same as *executing* it.
It will drop the first action from the non-empty vector it takes as its
argument and return a new `IO` action, which - when being executed -
will execute the remaining `IO` actions in sequence. If this behaves
as expected, the first `IO` action passed to `runActions` should be
silently dropped together with all its potential side effects.

When we execute `readHellos` at the REPL, we will be asked for our
name twice, although `actions` contains also `launchMissiles` at the
beginning. Luckily, although we described how to destroy the planet, 
the action was not executed, and we are - probably - still here.

From this example we learn several things:

  * Values of type `IO a` are *pure descriptions* of programs, which
    - when being *executed* - perform arbitrary side effects before
    returning a value of type `a`.

  * Values of type `IO a` can be safely returned from functions and
    passed around in containers or other custom data types, without
    the risk of them being executed.

  * Values of type `IO a` can be safely combined in *do blocks* to
    *describe* new `IO` actions.

  * An `IO` action will only ever get executed when it's passed to
    `:exec` at the REPL, or when it is the `main` function of
    a compiled Idris program, which is then being executed.

  * It is not possible to ever break out of the `IO` context: There
    is no function of type `IO a -> a`, as such a function would
    need execute its argument in order to extract the final
    result, and this would break referential transparency.

### Combining Pure Code with `IO` Actions

The title of this subsection is somewhat misleading. `IO` actions
*are* pure values, but what is typically meant here, is that we
combine non-`IO` functions with effectful computations.

<!-- vi: filetype=idris2
-->
