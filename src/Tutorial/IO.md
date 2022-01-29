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

import System.File

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
the input string at all whitespace occurrences. Since
`split` returns a `List1` (a type for non-empty lists
exported from `Data.List1` in *base*) but pattern matching
on `List` is more convenient, we convert the result using
`Data.List1.forget`. Note, how we use a pattern match
on the left hand side of the assignment operator `:=`.
This is a partial pattern match (*partial* meaning,
that it doesn't cover all possible cases), therefore we have
to deal with the other possibilities as well, which is
done after the vertical line. This can be read as follows:
"If the pattern match on the left hand side is successful,
and we get a list of exactly three tokens, continue with
the `let` expression, otherwise return a `ParseError` in
a `Left` immediately".

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

### Exercises part 1

In these exercises, you are going to implement some
small command-line applications. Some of these will potentially
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
   but will repeat itself forever (or until being forcefully
   terminated):

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
we first perform an `IO` action and use its result
to compute the next `IO` action and so on. The code is somewhat
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

### Binding Unit

Remember our implementation of `friendlyReadHello`? Here it is again:

```idris
friendlyReadHello' : IO ()
friendlyReadHello' = do
  _ <- putStrLn "Please enter your name."
  readHello
```

The underscore in there is a bit ugly and unnecessary. In fact,
a common use case is to just chain effectful computations with
result type `Unit` (`()`), merely for the side
effects they perform. For instance, we could repeat `friendlyReadHello`
three times, like so:

```idris
friendly3 : IO ()
friendly3 = do
  _ <- friendlyReadHello
  _ <- friendlyReadHello
  friendlyReadHello
```

This is such a common thing to do, that Idris allows us to
drop the bound underscores altogether:

```idris
friendly4 : IO ()
friendly4 = do
  friendlyReadHello
  friendlyReadHello
  friendlyReadHello
  friendlyReadHello
```

Note, however, that the above gets desugared slightly differently:

```idris
friendly4Desugared : IO ()
friendly4Desugared =
  friendlyReadHello >>
  friendlyReadHello >>
  friendlyReadHello >>
  friendlyReadHello
```

Operator `(>>)` has the following type:

```repl
Main> :t (>>)
Prelude.>> : Monad m => m () -> Lazy (m b) -> m b
```

Note the `Lazy` keyword in the type signature. This means,
that the wrapped argument will be *lazily evaluated*. This
makes sense in many occasions. For instance, if the `Monad`
in question is `Maybe` the result will be `Nothing` if
the first argument is `Nothing`, in which case there is no
need to even evaluate the second argument.

### Do, Overloaded

Because Idris supports function and operator overloading, we
can write custom *bind* operators, which allows us to
use *do notation* for types without an implementation
of `Monad`. For instance, here is a custom implementation of
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
match: Monadic *bind* specialized to `Vect` has
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

Of course, we can (and should!) overload `(>>)` in the
same manner as `(>>=)`, if we want to overload the
behavior of *do blocks*.

#### Modules and Namespaces

Every data type, function, or operator can be unambiguously
identified by prefixing it with its *namespace*. A function's
namespace typically is the same as the module where it was defined.
For instance, the fully qualified name of function `eval`
would be `Tutorial.IO.eval`. Function and operator names must
be unique in their namespace.

As we already learned, Idris can often disambiguate between
functions with the same name but defined in different namespaces
based on the types involved. If this is not possible, we can help
the compiler by *prefixing* the function or operator name with
a *suffix* of the full namespace. Let's demonstrate this at the REPL:

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
we still may want to define two overloaded versions of a function
in an Idris module, Idris makes it possible to add
additional namespaces to modules. For instance, in order
to define another function called `eval`, we need to add
it to its own namespace (note, that all definitions in a
namespace must be indented by the same amount of
white space):

```idris
namespace Foo
  export
  eval : Nat -> Nat -> Nat
  eval = (*)

-- prefixing `eval` with its namespace is not strictly necessary here
testFooEval : Nat
testFooEval = Foo.eval 12 100
```

Now, here is an important thing: For functions and data types to
be accessible from outside their namespace or module, they need to
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
since otherwise you will not be able to create values of these
types or deconstruct them in pattern matches. Likewise, unless you
plan to use your functions in compile-time computations, annotate
them with `export`.

### Bind, with a Bang

Sometimes, even *do blocks* are too noisy to express a
combination of effectful computations. In this case, we
can prefix the effectful parts with an exclamation mark
(wrapping them in parentheses if they contain additional
white space), while leaving pure expressions unmodified:

```idris
getHello : IO ()
getHello = putStrLn $ "Hello " ++ !getLine ++ "!"
```

The above gets desugared to the following *do block*:

```idris
getHello' : IO ()
getHello' = do
  s <- getLine
  putStrLn $ "Hello " ++ s ++ "!"
```

Here is another example:

```idris
bangExpr : String -> String -> String -> Maybe Integer
bangExpr s1 s2 s3 =
  Just $ !(parseInteger s1) + !(parseInteger s2) * !(parseInteger s3)
```

And here is the desugared *do block*:

```idris
bangExpr' : String -> String -> String -> Maybe Integer
bangExpr' s1 s2 s3 = do
  x1 <- parseInteger s1
  x2 <- parseInteger s2
  x3 <- parseInteger s3
  Just $ x1 + x2 * x3
```

Please remember the following: Syntactic sugar has been introduced
to make code more readable or more convenient to write. If
it is abused just to show how clever you are, you make things
harder for other people (including your future self!)
reading and trying to understand your code.

### Exercises part 2

1. Reimplement the following *do blocks*, once by using
   *bang notation*, and once by writing them in their
   desugared form with nested *bind*s:

   ```idris
   ex1a : IO String
   ex1a = do
     s1 <- getLine
     s2 <- getLine
     s3 <- getLine
     pure $ s1 ++ reverse s2 ++ s3

   ex1b : Maybe Integer
   ex1b = do
     n1 <- parseInteger "12"
     n2 <- parseInteger "300"
     Just $ n1 + n2 * 100
   ```

2. Below is the definition of an indexed family of types,
   the index of which keeps track of whether the value in
   question is possibly empty or provably non-empty:

   ```idris
   data List01 : (nonEmpty : Bool) -> Type -> Type where
     Nil  : List01 False a
     (::) : a -> List01 False a -> List01 ne a
   ```

   Please note, that the `Nil` case *must* have the `nonEmpty`
   tag set to `False`, while with the *cons* case, this is
   optional. So, a `List01 False a` can be empty or non-empty,
   and we'll only find out, which is the case, by pattern
   matching on it. A `List01 True a` on the other hand *must*
   be a *cons*, as for the `Nil` case the `nonEmpty` tag is
   always set to `False`.

   1. Declare and implement function `head` for non-empty lists:

      ```idris
      head : List01 True a -> a
      ```

   2. Declare and implement function `weaken` for converting any `List01 ne a`
      to a `List01 False a` of the same length and order
      of values.

   3. Declare and implement function `tail` for extracting the possibly
      empty tail from a non-empty list.

   4. Implement function `(++)` for concatenating two
      values of type `List01`. Note, how we use a type-level computation
      to make sure the result is non-empty if and only if
      at least one of the two arguments is non-empty:

      ```idris
      (++) : List01 b1 a -> List01 b2 a -> List01 (b1 || b2) a
      ```

   5. Implement utility function `concat'` and use it in
      the implementation of `concat`. Note, that in `concat` the
      two boolean tags are passed as unrestricted implicits,
      since you will need to pattern match on these to determine
      whether the result is provably non-empty or not:

      ```idris
      concat' : List01 ne1 (List01 ne2 a) -> List01 False a

      concat :  {ne1, ne2 : _}
             -> List01 ne1 (List01 ne2 a)
             -> List01 (ne1 && ne2) a
      ```

   6. Implement `map01`:

      ```idris
      map01 : (a -> b) -> List01 ne a -> List01 ne b
      ```

   7. Implement a custom *bind* operator in namespace `List01`
      for sequencing computations returning `List01`s.

      Hint: Use `map01` and `concat` in your implementation and
      make sure to use unrestricted implicits where necessary.

      You can use the following examples to test your
      custom *bind* operator:

      ```idris
      -- this and lf are necessary to make sure, which tag to use
      -- when using list literals
      lt : List01 True a -> List01 True a
      lt = id

      lf : List01 False a -> List01 False a
      lf = id

      test : List01 True Integer
      test = List01.do
        x  <- lt [1,2,3]
        y  <- lt [4,5,6,7]
        op <- lt [(*), (+), (-)]
        [op x y]

      test2 : List01 False Integer
      test2 = List01.do
        x  <- lt [1,2,3]
        y  <- Nil {a = Integer}
        op <- lt [(*), (+), (-)]
        lt [op x y]
      ```

Some notes on Exercise 2: Here, we combined the capabilities
of `List` and `Data.List1` in a single indexed type family.
This allowed us to treat list concatenation correctly: If
at least one of the arguments is provably non-empty, the
result is also non-empty. To tackle this correctly with
`List` and `List1`, a total of four concatenation functions
would have to be written. So, while it is often possible to
define distinct data types instead of indexed families,
the latter allow us to perform type-level computations to
be more precise about the pre- and postconditions of the functions
we write, at the cost of more-complex type signatures.
In addition, sometimes it's not possible to derive the
values of the indices from pattern matching on the data
values alone, so they have to be passed as unerased
(possibly implicit) arguments.

Please remember, that *do blocks* are first desugared, before
type-checking, disambiguating which *bind* operator to use,
and filling in implicit arguments. It is therefore perfectly fine
to define *bind* operators with arbitrary constraints or
implicit arguments as was shown above. Idris will handle
all the details, *after* desugaring the *do blocks*.

## Working with Files

Module `System.File` from the *base* library exports utilities necessary
to work with file handles and read and write from and to files. When
you have a file path (for instance "/home/hock/idris/tutorial/tutorial.ipkg"),
the first thing we will typically do is to try and create a file handle
(of type `System.File.File` by calling `fileOpen`).

Here is a program for counting all empty lines in a Unix/Linux-file:

```idris
covering
countEmpty : (path : String) -> IO (Either FileError Nat)
countEmpty path = openFile path Read >>= either (pure . Left) (go 0)
  where covering go : Nat -> File -> IO (Either FileError Nat)
        go k file = do
          False <- fEOF file | True => closeFile file $> Right k
          Right "\n" <- fGetLine file
            | Right _  => go k file
            | Left err => closeFile file $> Left err
          go (k + 1) file
```

In the example above, I invoked `(>>=)` without starting a *do block*.
Make sure you understand what's going on here. Reading concise functional
code is important in order to understand other people's code.
Have a look at function `either` at the REPL, try figuring out what
`(pure . Left)` does, and note how we use a curried version of `go`
as the second argument to `either`.

Function `go` calls for some additional explanations. First, note how
we used the same syntax for pattern matching intermediary results
as we also saw for `let` bindings. As you can see, we can use several
vertical bars to handle more than one additional pattern. In order to
read a single line from a file, we use function `fGetLine`. As with
most operations working with the file system, this function might fail
with a `FileError`, which we have to handle correctly. Note also, that
`fGetLine` will return the line including its trailing newline character
`'\n'`, so in order to check for empty lines, we have to match against
`"\n"` instead of the empty string `""`.

Finally, `go` is not provably total and rightfully so.
Files like `/dev/urandom` or `/dev/zero` provide infinite
streams of data, so `countEmpty` will never
terminate when invoked with such a file path.

### Safe Resource Handling

Note, how we had to manually open and close the file handle in
`countEmpty`. This is error-prone and tedious. Resource handling
is a big topic, and we definitely won't be going into the
details here, but there is a convenient function exported
from `System.File`: `withFile`, which handles the opening,
closing and handling of file errors for us.

```idris
covering
countEmpty' : (path : String) -> IO (Either FileError Nat)
countEmpty' path = withFile path Read pure (go 0)
  where covering go : Nat -> File -> IO (Either FileError Nat)
        go k file = do
          False <- fEOF file | True => pure (Right k)
          Right "\n" <- fGetLine file
            | Right _  => go k file
            | Left err => pure (Left err)
          go (k + 1) file
```

Go ahead, and have a look at the type of `withFile`, then
have a look how we use it to simplify the implementation of
`countEmpty'`. Reading and understanding slightly more complex
function types is important when learning to program in Idris.

#### Interface `HasIO`

When you look at the `IO` functions we used so far, you'll
notice that most if not all of them actually don't work
with `IO` itself but with a type parameter `io` with a
constraint of `HasIO`. This interface allows us to *lift*
a value of type `IO a` into another context. We will see
use cases for this in later chapters, especially when we
talk about monad transformers. For now, you can treat these
`io` parameters as being specialized to `IO`.

### Exercises part 3

1. As we have seen in the examples above, `IO` actions
   working with file handles often come with the risk
   of failure. We can therefore simplify things by
   writing some utility functions and a custom *bind*
   operator to work with these nested effects. In
   a new namespace `IOErr`, implement the following
   utility functions and use these to further cleanup
   the implementation of `countEmpty'`:

   ```idris
   pure : a -> IO (Either e a)

   fail : e -> IO (Either e a)

   lift : IO a -> IO (Either e a)

   catch : IO (Either e1 a) -> (e1 -> IO (Either e2 a)) -> IO (Either e2 a)

   (>>=) : IO (Either e a) -> (a -> IO (Either e b)) -> IO (Either e b)

   (>>) : IO (Either e ()) -> Lazy (IO (Either e a)) -> IO (Either e a)
   ```

2. Write a function `countWords` for counting the words in a file.
   Consider using `Data.String.words` and the utilities from
   exercise 1 in your implementation.

3. We can generalize the functionality used in `countEmpty`
   and `countWords`, by implementing a helper function for
   iterating over the lines in a file and accumulating some
   state along the way. Implement `withLines` and use it to
   reimplement `countEmpty` and `countWords`:

   ```idris
   covering
   withLines :  (path : String)
             -> (accum : s -> String -> s)
             -> (initialState : s)
             -> IO (Either FileError s)
   ```

4. We often use a `Monoid` for accumulating values.
   It is therefore convenient to specialize `withLines`
   for this case. Use `withLines` to implement
   `foldLines` according to the type given below:

   ```idris
   covering
   foldLines :  Monoid s
             => (path : String)
             -> (f    : String -> s)
             -> IO (Either FileError s)
   ```

5. Implement function `wordCount` for counting
   the number of lines, words, and characters in
   a text document. Define a custom record type
   together with an implementation of `Monoid`
   for storing and accumulating these values
   and use `foldLines` in your implementation of
   `wordCount`.

## How `IO` is Implemented

In this final section of an already lengthy chapter, we will risk
a glance at how `IO` is implemented in Idris. It is interesting
to note, that `IO` is not a built-in type but a regular data type
with only one minor speciality. Let's learn about it at the REPL:

```repl
Tutorial.IO> :doc IO
data PrimIO.IO : Type -> Type
  Totality: total
  Constructor: MkIO : (1 _ : PrimIO a) -> IO a
  Hints:
    Applicative IO
    Functor IO
    HasLinearIO IO
    Monad IO
```

Here, we learn that `IO` has a single data constructor
called `MkIO`, which takes a single argument of type
`PrimIO a` with quantity *1*. We are not going to
talk about the quantities here, as in fact they are not
important to understand how `IO` works.

Now, `PrimIO a` is a type alias for the following function:

```repl
Tutorial.IO> :printdef PrimIO
PrimIO.PrimIO : Type -> Type
PrimIO a = (1 _ : %World) -> IORes a
```

Again, don't mind the quantities. There is only
one piece of the puzzle missing: `IORes a`, which is
a publicly exported record type:

```repl
Solutions.IO> :doc IORes
data PrimIO.IORes : Type -> Type
  Totality: total
  Constructor: MkIORes : a -> (1 _ : %World) -> IORes a
```

So, to put this all together, `IO` is a wrapper around
something similar to the following function type:

```repl
%World -> (a, %World)
```

You can think of type `%World` as a placeholder for the
state of the outside world of a program (file system,
memory, network connections, and so on). Conceptually,
to execute an `IO a` action, we pass it the current state
of the world, and in return get an updated world state
plus a result of type `a`. The world state being updated
represents all the side effects describable in a computer
program.

Now, it is important to understand that there is no such
thing as the *state of the world*. The `%World` type is
just a placeholder, which is converted to some kind of
constant that's passed around and never inspected at
runtime. So, if we had a value of type `%World`, we could
pass it to an `IO a` action and execute it, and this is
exactly what happens at runtime: A single value of
type `%World` (an uninteresting placeholder like `null`,
`0`, or - in case of the JavaScript backends - `undefined`)
is passed to the `main` function, thus
setting the whole program in motion. However, it
is impossible to programmatically create a value of
type `%World` (it is an abstract, primitive type), and
therefore we cannot ever extract a value of type `a`
from an `IO a` action (modulo `unsafePerformIO`).

Once we will talk about monad transformers and the state
monad, you will see that `IO` is nothing else but
a state monad in disguise but with an abstract state
type, which makes it impossible for us to run the
stateful computation.

## Conclusion

* Values of type `IO a` describe programs with side effects,
  which will eventually result in a value of type `a`.

* While we cannot safely extract a value of type `a`
  from an `IO a`, we can use several combinators and
  syntactic constructs to combine `IO` actions and
  build more-complex programs.

* *Do blocks* offer a convenient way to run and combine
  `IO` actions sequentially.

* *Do blocks* are desugared to nested applications of
  *bind* operators (`(>>=)`).

* *Bind* operators, and thus *do blocks*, can be overloaded
  to achieve custom behavior instead of the default
  (monadic) *bind*.

* Under the hood, `IO` actions are stateful computations
  operating on a symbolic `%World` state.

### What's next

Now, that we had a glimpse at *monads* and the *bind* operator,
it is time to in the [next chapter](Functor.md) introduce `Monad` and some
related interfaces for real.

<!-- vi: filetype=idris2
-->
