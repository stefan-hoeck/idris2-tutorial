# IO: Programming with Side Effects

So far, all our examples and exercises dealt with pure, total functions.
We didn't read or write content from or to files, nor did
we write any messages to the standard output. It is time to change
that and learn, how we can write effectful programs in Idris.

```idris
module Tutorial.IO

import Data.List1
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
by each backend in order to be available there. At compile time (and at the REPL),
Idris knows nothing about the implementations of foreign functions
and therefore can't reduce foreign function calls, unless they are
built into the compiler itself. But even then, values of type `IO a`
(`a` being a type parameter) are typically not reduced.

It is important to understand that values of type `IO a` *describe*
a program, which, when being *executed*, will return a value of type `a`,
after performing arbitrary side effects along the way. For instance,
`putStrLn` has type `String -> IO ()`. Read this as: "`putStrLn` is a function,
which, when given a `String` argument, will return a description of
an effectful program with an output type of `()`".
(`()` is syntactic sugar for type `Unit`, the
empty tuple defined at the *Prelude*, which has only one value called `MkUnit`,
for which we can also use `()` in our code.)

Since values of type `IO a` are mere descriptions of effectful computations,
functions returning such values or taking such values as
arguments are still *pure* and thus referentially transparent.
It is, however, not possible to extract a value of type `a` from
a value of type `IO a`, that is, there is no generic function `IO a -> a`,
as such a function would inadvertently execute the side
effects when extracting the result from its argument,
thus breaking referential transparency.
(Actually, there *is* such a function called `unsafePerformIO`.
Do not ever use it in your code unless you know what you are doing.)

### Do Blocks

If you are new to pure functional programming, you might now - rightfully -
mumble something about how useless it is to
have descriptions of effectful programs without being able to run them.
So please, hear me out. While we are not able to run values of type
`IO a` when writing programs, that is, there is no function of
type `IO a -> a`, we are able to chain such computations and describe more
complex programs. Idris provides special syntax for this: *Do blocks*.
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
`IO` actions. This concept is powerful enough to let us encapsulate arbitrary
programs with side effects in a single value of type `IO`. Such a
description can then be returned by function `main`, the main entry point
to an Idris program, which is being executed when we run a compiled
Idris binary.

### The Difference between Program Description and Execution

In order to better understand the difference between *describing*
an effectful computation and *executing* or *running* it, here is a small
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

Before I explain what the code above does, please note function
`pure` used in the implementation of `runActions`. It is
a constrained function, about which we will learn in the next
chapter. Specialized to `IO`, it has generic type `a -> IO a`:
It allows us to wrap a value in an `IO` action. The resulting
`IO` program will just return the wrapped value without performing
any side effects. We can now look at the big picture of what's
going on in `readHellos`.

First, we define a friendlier version of `readHello`: When executed, this will
ask about our name explicitly. Since we will not use the result
of `putStrLn` any further, we can use an underscore as a catch-all
pattern here. Afterwards, `readHello` is invoked. We also define
`launchMissiles`, which, when being executed, will lead to the
destruction of planet earth.

Now, `runActions` is the function we use to
demonstrate that *describing* an `IO` action is not the
same as *running* it. It will drop the first action from
the non-empty vector it takes as its
argument and return a new `IO` action, which describes the
execution of the remaining `IO` actions in sequence. If this behaves
as expected, the first `IO` action passed to `runActions` should be
silently dropped together with all its potential side effects.

When we execute `readHellos` at the REPL, we will be asked for our
name twice, although `actions` also contains `launchMissiles` at the
beginning. Luckily, although we described how to destroy the planet, 
the action was not executed, and we are (probably) still here.

From this example we learn several things:

  * Values of type `IO a` are *pure descriptions* of programs, which,
    when being *executed*, perform arbitrary side effects before
    returning a value of type `a`.

  * Values of type `IO a` can be safely returned from functions and
    passed around as arguments or in data structures, without
    the risk of them being executed.

  * Values of type `IO a` can be safely combined in *do blocks* to
    *describe* new `IO` actions.

  * An `IO` action will only ever get executed when it's passed to
    `:exec` at the REPL, or when it is the `main` function of
    a compiled Idris program that is being executed.

  * It is not possible to ever break out of the `IO` context: There
    is no function of type `IO a -> a`, as such a function would
    need to execute its argument in order to extract the final
    result, and this would break referential transparency.

### Combining Pure Code with `IO` Actions

The title of this subsection is somewhat misleading. `IO` actions
*are* pure values, but what is typically meant here, is that we
combine non-`IO` functions with effectful computations.

As a demonstration, in this section we are going to write a small
program for evaluating arithmetic expressions. We are going to
keep things simple and allow only expressions with a single
operator and two arguments, both of which must be integers,
for instance `12 + 13`.

We are going to use function `split` from `Data.String` in
*base* to tokenize arithmetic expressions. We are then trying
to parse the two integer values and the operator. These operations
might fail, since user input can be invalid, so we also need an
error type. We could actually just use `String`, but I
consider it to be good practice to use custom sum types
for erroneous conditions.

```idris
data Error : Type where
  NotAnInteger    : (value : String) -> Error
  UnknownOperator : (value : String) -> Error
  ParseError      : (input : String) -> Error

dispError : Error -> String
dispError (NotAnInteger v)    = "Not an integer: " ++ v ++ "."
dispError (UnknownOperator v) = "Unknown operator: " ++ v ++ "."
dispError (ParseError v)      = "Invalid expression: " ++ v ++ "."
```

In order to parse integer literals, we use function `parseInteger`
from `Data.String`:

```idris
readInteger : String -> Either Error Integer
readInteger s = maybe (Left $ NotAnInteger s) Right $ parseInteger s
```

Likewise, we declare and implement a function for parsing
arithmetic operators:

```idris
readOperator : String -> Either Error (Integer -> Integer -> Integer)
readOperator "+" = Right (+)
readOperator "*" = Right (*)
readOperator s   = Left (UnknownOperator s)
```

We are now ready to parse and evaluate simple arithmetic
expressions. This consists of several steps (splitting the
input string, parsing each literal), each of which can fail.
Later, when we learn about monads, we will see that do
blocks can be used in such occasions just as well. However,
in this case we can use an alternative syntactic convenience:
Pattern matching in let bindings. Here is the code:

```idris
eval : String -> Either Error Integer
eval s =
  let [x,y,z]  := forget $ split isSpace s | _ => Left (ParseError s)
      Right v1 := readInteger x  | Left e => Left e
      Right op := readOperator y | Left e => Left e
      Right v2 := readInteger z  | Left e => Left e
   in Right $ op v1 v2
```

Let's break this down a bit. On the first line, we split
the input string at all white space occurrences. Since
`split` returns a `List1` (a type for non-empty lists
exported from `Data.List1` in *base*) but pattern matching
on `List` is more convenient, we convert the result using
`Data.List1.forget`. Note, how we use a pattern match
on the left hand side of the assignment operator `:=`.
This would be a non-covering pattern match, therefore we have
to deal with the other possibilities as well, which is
done after the vertical line. This can be read as follows:
"If the pattern match on the left hand side is successful,
and we get a list of exactly three tokens, continue with
the `let` expression, otherwise return a `ParseError` in
a `Left`".

The other three lines behave exactly the same: Each has
a partial pattern match on the left hand side with
instructions what to return in case of invalid input after
the vertical bar. We will later see, that this syntax is also
available in *do blocks*.

Note, how all of the functionality implemented so far is
*pure*, that is, it does not describe computations with
side effects. (One could argue that already the possibility
of failure is an observable *effect*, but even then, the code above
is still referentially transparent,
can be easily tested at the REPL, and evaluated at
compile time, which is the important thing here.)

Finally, we can wrap this functionality in an `IO`
action, which reads a string from standard input
and tries to evaluate the arithmetic expression:

```idris
exprProg : IO ()
exprProg = do
  s <- getLine
  case eval s of
    Left err  => do
      putStrLn "An error occured:"
      putStrLn (dispError err)
    Right res => putStrLn (s ++ " = " ++ show res)
```

Note, how in `exprProg` we were forced to deal with the
possibility of failure and handle both constructors
of `Either` differently in order to print a result.
Note also, that *do blocks* are ordinary expressions,
and we can, for instance, start a new *do block* on 
the right hand side of a case expression.

### Exercises

In these exercises, you are going to implement some
small command line applications. Some of these will potentially
run forever, as they will only stop when the user enters
a keyword for quitting the application. Such programs
are no longer provably total. If you added the
`%default total` pragma at the top of your source file,
you'll need to annotate these functions with `covering`,
meaning that you covered all cases in all pattern matches
but your program might still loop due to unrestricted
recursion.

1. Implement function `rep`, which will read a line
   of input from the terminal, evaluate it using the
   given function, and print the result to standard output:

   ```idris
   rep : (String -> String) -> IO ()
   ```

2. Implement function `repl`, which behaves just like `rep`
   but will keep repeating its behavior until being forcefully
   terminated:

   ```idris
   covering
   repl : (String -> String) -> IO ()
   ```

3. Implement function `replTill`, which behaves just like `repl`
   but will only continue looping if the given function returns
   a `Right`. If it returns a `Left`, `replTill` should print
   the final message wrapped in the `Left` and then stop.

   ```idris
   covering
   replTill : (String -> Either String String) -> IO ()
   ```

4. Write a program, which reads arithmetic
   expressions from standard input, evaluates them
   using `eval`, and prints the result to standard
   output. The program should loop until
   users stops it by entering "done", in which case
   the program should terminate with a friendly greeting.
   Use `replTill` in your implementation.

5. Implement function `replWith`, which behaves just like `repl`
   but uses some internal state to accumulate values.
   At each iteration (including the very first one!),
   the current state should be printed
   to standard output using function `dispState`, and
   the next state should be computed using function `next`.
   The loop should terminate in case of a `Left` and
   print a final message using `dispResult`:

   ```idris
   covering
   replWith :  (state      : s)
            -> (next       : s -> String -> Either res s)
            -> (dispState  : s -> String)
            -> (dispResult : res -> s -> String)
            -> IO ()
   ```

6. Use `replWith` from Exercise 5 to write a program
   for reading natural numbers from standard input and
   printing the accumulated sum of these numbers.
   The program should terminate in case of invalid input
   and if a user enters "done".

## Do Blocks, Desugared

Here's an important piece of information: There is nothing
special about *do blocks*. They are just syntactic sugar,
which is converted to a sequence of operator applications.
With [syntactic sugar](https://en.wikipedia.org/wiki/Syntactic_sugar),
we mean syntax in a programming language that makes it
easier to express certain things in that language without
making the language itself any more powerful or expressive.
Here, it means you could write all the `IO` programs
without using `do` notation, but the code you'll write
will sometimes be harder to read, so *do blocks* provide
nicer syntax for these occasions.

Consider the following example program:

```idris
sugared1 : IO ()
sugared1 = do
  str1 <- getLine
  str2 <- getLine
  str3 <- getLine
  putStrLn (str1 ++ str2 ++ str3)
```

The compiler will convert this to the following program
*before disambiguating function names and type checking*:

```idris
desugared1 : IO ()
desugared1 =
  getLine >>= (\str1 =>
    getLine >>= (\str2 =>
      getLine >>= (\str3 =>
        putStrLn (str1 ++ str2 ++ str3)
      )
    )
  )
```

There is a new operator (`(>>=)`) called *bind* in the
implementation of `desugared1`. If you look at its type
at the REPL, you'll see the following:

```repl
Main> :t (>>=)
Prelude.>>= : Monad m => m a -> (a -> m b) -> m b
```

This is a constrained function requiring an interface called `Monad`.
We will talk about `Monad` and some of its friends in the next
chapter. Specialized to `IO`, *bind* has the following type:

```repl
Main> :t (>>=) {m = IO}
>>= : IO a -> (a -> IO b) -> IO b
```

This describes a sequencing of `IO` actions. Upon execution,
the first `IO` action is being run and its result is
being passed as an argument to the function generating
the second `IO` action, which is then also being executed.

You might remember, that you already implemented something
similar in an earlier exercise: In [Algebraic Data Types](DataTypes.md),
you implemented *bind* for `Maybe` and `Either e`. We will
learn in the next chapter, that `Maybe` and `Either e` too come
with an implementation of `Monad`. For now, suffice to say
that `Monad` allows us to run computations with some kind
of effect in sequence by passing the *result* of the
first computation to the function returning the
second computation. In `desugared1` you can see, how
we first perform an `IO` action and pass its result
to the next `IO` action and so on. The code is somewhat
hard to read, since we use several layers of nested
anonymous function, that's why in such cases, *do blocks*
are a nice alternative to express the same functionality.

Since *do block* are always desugared to sequences of
applied *bind* operators, we can use them to chain
any monadic computation. For instance, we can rewrite
function `eval` by using a *do block* like so:

```idris
evalDo : String -> Either Error Integer
evalDo s = case forget $ split isSpace s of
  [x,y,z] => do
    v1 <- readInteger x
    op <- readOperator y
    v2 <- readInteger z
    Right $ op v1 v2
  _       => Left (ParseError s)
```

Don't worry, if this doesn't make too much sense yet. We will
see many more examples, and you'll get the hang of this
soon enough. The important thing to remember is how *do
blocks* are always converted to sequences of *bind*
operators as shown in `desugared1`.

### Do, Overloaded

Because Idris supports function and operator overloading, we
can write custom *bind* operators, which allows us to
use *do notation* for types without an implementation
of `Monad`. For instance, here is a custom implementation for
`(>>=)` for sequencing computations returning vectors.
Every value in the first vector (of length `m`)
will be converted to a vector of length `n`, and
the results will be concatenated leading to
a vector of length `m * n`:

```idris
flatten : Vect m (Vect n a) -> Vect (m * n) a
flatten []        = []
flatten (x :: xs) = x ++ flatten xs

(>>=) : Vect m a -> (a -> Vect n b) -> Vect (m * n) b
as >>= f = flatten (map f as)
```

It is not possible to write an implementation of `Monad`,
which encapsulates this behavior, as the types wouldn't
match: The monadic *bind* specialized to `Vect` has
type `Vect k a -> (a -> Vect k b) -> Vect k b`. As you
see, the sizes of all three occurrences of `Vect`
have to be the same, which is not what we expressed
in our custom version of *bind*. Here is an example to
see this in action:

```idris
modString : String -> Vect 4 String
modString s = [s, reverse s, toUpper s, toLower s]

testDo : Vect 24 String
testDo = IO.do
  s1 <- ["Hello", "World"]
  s2 <- [1, 2, 3]
  modString (s1 ++ show s2)
```

Try to figure out how `testDo` works by desugaring it
manually and then comparing its result with what you
expected at the REPL. Note, how we helped Idris disambiguate,
which version of the *bind* operator to use by prefixing
the `do` keyword with part of the operator's namespace.
In this case, this wasn't strictly necessary, although
`Vect k` does have an implementation of `Monad`, but it is
still good to know that it is possible to help
the compiler with disambiguating do blocks.

#### Modules and Namespaces

Every data type, function, and operator can be unambiguously
identified by prefixing it with its *namespace*. A function's
namespace typically is the same as the module where it was defined.
For instance, the fully qualified name of function `eval`
would be `Tutorial.IO.eval`. Function and operator names must
be unique in their namespace.

As we already learned, Idris can often disambiguate between
functions with the same name but defined in different namespaces
based on the types involved. If this is not possible, we can help
the compiler by *prefixing* the function or operator name with
a *suffix* of the full namespace. Let's demonstrate this in
a REPL session:

```repl
Tutorial.IO> :t (>>=)
Prelude.>>= : Monad m => m a -> (a -> m b) -> m b
Tutorial.IO.>>= : Vect m a -> (a -> Vect n b) -> Vect (m * n) b
```

As you can see, if we load this module in a REPL session and
inspect the type of `(>>=)`, we get two results as two
operators with this name are in scope. If we only want
the REPL to print the type of our custom *bind* operator,
is is sufficient to prefix it with `IO`, although we could
also prefix it with its full namespace:

```repl
Tutorial.IO> :t IO.(>>=)
Tutorial.IO.>>= : Vect m a -> (a -> Vect n b) -> Vect (m * n) b
Tutorial.IO> :t Tutorial.IO.(>>=)
Tutorial.IO.>>= : Vect m a -> (a -> Vect n b) -> Vect (m * n) b
```

Since function names must be unique in their namespace and
we still want to define two overloaded versions of a function
in an Idris module, Idris makes it possible to add
additional namespaces to modules. For instance, in order
to define another function called `eval`, we need to add
it to its own namespace:

```idris
namespace Foo
  export
  eval : Nat -> Nat -> Nat
  eval = (*)
```

Now, here is an important thing: For functions and data types to
be accessible from outside of their namespace, they need to
be *exported* by annotating them with the `export` or `public export`
keywords.

The difference between `export` and `public export` is the following:
A function annotated with `export` exports its type and can be
called from other namespaces. A data type annotated with `export`
exports its type constructor but not its data constructors.
A function annotated with `public export` also exports its
implementation. This is necessary to use the function in compile-time
computations. A data type annotated with `public export`
exports its data constructors as well.

In general, consider annotating data types with `public export`,
since otherwise you will not be able construct values of these
types or deconstruct them in pattern matches. Likewise, unless you
plan to use your functions in compile-time computations, annotate
them with `export`.

<!-- vi: filetype=idris2
-->
