# Functions Part 1

Idris is a *functional* programming language. This means,
that functions are its main form of abstraction (unlike for
instance in an object oriented language like Java, where
*objects* and *classes* are the main form of abstraction). It also
means that we expect Idris to make it very easy for
us to compose and combine functions to create new
functions. In fact, in Idris functions are *first class*:
Functions can take other functions as arguments and
can return functions as their results.

We already learned about the basic shape of top level
function declarations in Idris in the [introduction](Intro.md),
so we will continue from what we learned there.

```idris
module Tutorial.Functions1
```

## Functions with more than one Argument

Let's implement a function, which checks if its three
`Integer` arguments form a
[Pythagorean triple](https://en.wikipedia.org/wiki/Pythagorean_triple).
We get to use a new operator for this: `==`, the equality
operator.

```idris
isTriple : Integer -> Integer -> Integer -> Bool
isTriple x y z = x * x + y * y == z * z
```

Let's give this a spin at the REPL before we talk a bit
about the types:

```repl
Tutorial.Functions1> isTriple 1 2 3
False
Tutorial.Functions1> isTriple 3 4 5
True
```

As can be seen from this example, the type of a function
of several arguments consists just of a sequence
of argument types (also called *input types*)
chained by function arrows (`->`), which
is terminated by an output type (`Bool` in this case).

The implementation looks a bit like a mathematical equation:
We list the arguments on the left hand side of `=` and describe the
computation(s) to perform with them on the right hand
side. Function implementations in functional programming
languages often have this more mathematical look compared
to implementations in imperative  languages, which often
describe not *what* to compute, but *how* to
compute it by describing an algorithm as a sequence of
imperative statements. We will later see that this
imperative style is also available in Idris, but whenever
possible we prefer the declarative style.

As can be seen in the REPL example, functions can be invoked
by passing the arguments separated by whitespace. No parentheses
are necessary unless one of the expressions we pass as the
function's arguments contains itself additional whitespace.
This comes in very handy when we apply functions
only partially (see later in this chapter).

Note that, unlike `Integer` or `Bits8`, `Bool` is not a primitive
data type built into the Idris language but just a custom
data type that you could have written yourself. We will
learn more about declaring new data types in the
next chapter.

## Function Composition

Functions can be combined in several ways, the most direct
probably being the dot operator:

```idris
square : Integer -> Integer
square n = n * n

times2 : Integer -> Integer
times2 n = 2 * n

squareTimes2 : Integer -> Integer
squareTimes2 = times2 . square
```

Give this a try at the REPL! Does it do what you'd expect?

We could have implemented `squareTimes2` without using
the dot operator as follows:

```idris
squareTimes2' : Integer -> Integer
squareTimes2' n = times2 (square n)
```

It is important to note, that functions chained by the dot
operator are invoked from right to left: `times2 . square`
is the same as `\n => times2 (square n)` and not
`\n => square (times2 n)`.

We can conveniently chain several functions using the
dot operator to write more complex functions:

```idris
dotChain : Integer -> String
dotChain = reverse . show . square . square . times2 . times2
```

This will first multiply the argument by four, then square
it twice before converting it to a string (`show`) and
reversing the resulting `String` (functions `show` and
`reverse` are part of the Idris *Prelude* and as such are
available in every Idris program).

## Higher-order Functions

Functions can take other functions as arguments. This is
an incredibly powerful concept and we can go crazy with
this very easily. But for sanity's sake, we'll start
slowly:

```idris
isEven : Integer -> Bool
isEven n = mod n 2 == 0

testSquare : (Integer -> Bool) -> Integer -> Bool
testSquare fun n = fun (square n)
```

First `isEven` uses the `mod` function to check, whether
an integer is divisible by two. But the interesting function
is `testSquare`. It takes two arguments: The first argument
is of type *function from `Integer` to `Bool`*, and the second
of type `Integer`. This second argument is squared before
being passed to the first argument. Again, give this a go
at the REPL:

```repl
Tutorial.Functions1> testSquare isEven 12
True
```

Take your time to understand what's going on here. We pass
function `isEven` as an argument to `testSquare`. The
second argument is an integer, which will first be squared
and then passed to `isEven`. While this is not very interesting,
we will see lots of use cases for passing functions as
arguments to other functions.

I said above, we could go crazy pretty easily.
Consider for instance the following example:

```idris
twice : (Integer -> Integer) -> Integer -> Integer
twice f n = f (f n)
```

And at the REPL:

```repl
Tutorial.Functions1> twice square 2
16
Tutorial.Functions1> (twice . twice) square 2
65536
Tutorial.Functions1> (twice . twice . twice . twice) square 2
*** huge number ***
```

You might be surprised about this behavior, so we'll try
and break it down. The following two expressions are identical
in their behavior:

```idris
expr1 : Integer -> Integer
expr1 = (twice . twice . twice . twice) square

expr2 : Integer -> Integer
expr2 = twice (twice (twice (twice square)))
```

So, `square` raises its argument to the 2nd power,
`twice square` raises it to its 4th power (by invoking
`square` twice in succession),
`twice (twice square)` raises it to its 16th power
(by invoking `twice square` twice in succession),
and so on, until `twice (twice (twice (twice square)))`
raises it to its 65536th power resulting in an impressively
huge result.

## Currying

Once we start using higher-order functions, the concept
of partial function application (also called *currying*
after mathematician and logician Haskell Curry) becomes
very important.

Load this file in a REPL session and try the following:

```repl
Tutorial.Functions1> :t testSquare isEven
testSquare isEven : Integer -> Bool
Tutorial.Functions1> :t isTriple 1
isTriple 1 : Integer -> Integer -> Bool
Tutorial.Functions1> :t isTriple 1 2
isTriple 1 2 : Integer -> Bool
```

Note, how in Idris we can partially apply a function
with more than one argument and as a result get a new function
back. For instance, `isTriple 1` applies argument `1` to function
`isTriple` and as a result returns a new function of
type `Integer -> Integer -> Bool`. We can even
use the result of such a partially applied function in
a new top level definition:

```idris
partialExample : Integer -> Bool
partialExample = isTriple 3 4
```

And at the REPL:

```repl
Tutorial.Functions1> partialExample 5
True
```

We already used partial function application in our `twice`
examples above to get some impressive results with very
little code.

## Anonymous Functions

Sometimes we'd like to pass a small custom function to
a higher-order function without bothering to write a
top level definition. For instance, in the following example,
function `someTest` is very specific and probably not
very useful in general, but we'd still like to pass it
to higher-order function `testSquare`:

```idris
someTest : Integer -> Bool
someTest n = n >= 3 || n <= 10
```

Here's, how to pass it to `testSquare`:

```repl
Tutorial.Functions1> testSquare someTest 100
True
```

Instead of defining and using `someTest`, we can use an
anonymous function:

```repl
Tutorial.Functions1> testSquare (\n => n >= 3 || n <= 10) 100
True
```

Anonymous functions are sometimes also called *lambdas* (from
[lambda calculus](https://en.wikipedia.org/wiki/Lambda_calculus)),
and the backslash is chosen since it resembles the Greek
letter *lambda*. The `\n =>` syntax introduces a new anonymous
function of one argument called `n`, the implementation of
which is on the right hand side of the function arrow.
Like other top level functions, lambdas can have more
than one arguments, separated by commas: `\x,y => x * x + y`.
When we pass lambdas as arguments to higher-order functions,
they typically need to be wrapped in parentheses or separated
by the dollar operator `($)` (see the next section about this).

Note that, in a lambda, arguments are not annotated with types,
so Idris has to be able to infer them from the current context.

## Operators

In Idris, infix operators like `.`, `*` or `+` are not built into
the language, but are just regular Idris function with
some special support for using them in infix notation.
When we don't use operators in infix notation, we have
to wrap them in parentheses.

As an example, let us define a custom operator for sequencing
functions of type `Bits8 -> Bits8`:

```idris
infixr 4 >>>

(>>>) : (Bits8 -> Bits8) -> (Bits8 -> Bits8) -> Bits8 -> Bits8
f1 >>> f2 = f2 . f1

foo : Bits8 -> Bits8
foo n = 2 * n + 3

test : Bits8 -> Bits8
test = foo >>> foo >>> foo >>> foo
```

In addition to declaring and defining the operator
itself, we also have to specify its fixity: `infixr 4 >>>` means,
that `(>>>)` associates to the right (meaning, that
`f >>> g >>> h` is to be interpreted as `f >>> (g >>> h)`)
with a priority of `4`. You can also have a look at the fixity
of operators exported by the *Prelude* in the REPL:

```repl
Tutorial.Functions1> :doc (.)
Prelude.. : (b -> c) -> (a -> b) -> a -> c
  Function composition.
  Totality: total
  Fixity Declaration: infixr operator, level 9
```

When you mix infix operators in an expression, those with
a higher priority bind more tightly. For instance, `(+)`
is left associated with a priority of 8, while `(*)`
is left associated with a priority of 9. Hence,
`a * b + c` is the same as `(a * b) + c` instead of `a * (b + c)`.

### Operator Sections

Operators can be partially applied just like regular
functions. In this case, the whole expression has to
be wrapped in parentheses and is called an *operator
section*. Here are two examples:

```repl
Tutorial.Functions1> testSquare (< 10) 5
False
Tutorial.Functions1> testSquare (10 <) 5
True
```

As you can see, there is a difference between `(< 10)`
and `(10 <)`. The first tests, whether its argument is
less than 10, the second, whether 10 is less than its
argument.

One exception where operator sections will not work is
with the *minus* operator `(-)`. Here is an example to
demonstrate this:

```idris
applyToTen : (Integer -> Integer) -> Integer
applyToTen f = f 10
```

This is just a higher-order function applying the number ten
to its function argument. This works very well in the following
example:

```repl
Tutorial.Functions1> applyToTen (* 2)
20
```

However, if we want to subtract five from ten, the following
will fail:

```repl
Tutorial.Functions1> applyToTen (- 5)
Error: Can't find an implementation for Num (Integer -> Integer).

(Interactive):1:12--1:17
 1 | applyToTen (- 5)
```

The problem here is, that Idris treats `- 5` as an integer literal
instead of an operator section. In this special case, we therefore
have to use an anonymous function instead:

```repl
Tutorial.Functions1> applyToTen (\x => x - 5)
5
```

### Infix Notation for Non-Operators

In Idris, it is possible to use infix notation for
regular binary functions, by wrapping them in backticks.
It is even possible to define a precedence (fixity) for
these and use them in operator sections, just like regular
operators:

```idris
infixl 8 `plus`

infixl 9 `mult`

plus : Integer -> Integer -> Integer
plus = (+)

mult : Integer -> Integer -> Integer
mult = (*)

arithTest : Integer
arithTest = 5 `plus` 10 `mult` 12

arithTest' : Integer
arithTest' = 5 + 10 * 12
```

### Operators exported by the *Prelude*

Here is a list of important operators exported by the *Prelude*.
Most of these are *constrained*, that is they work only
for types implementing a certain *interface*. Don't worry
about this right now. We will learn about interfaces in due
time, and the operators behave as they intuitively should.
For instance, addition and multiplication work for all
numeric types, comparison operators work for almost all
types in the *Prelude* with the exception of functions.

* `(.)`: Function composition
* `(+)`: Addition
* `(*)`: Multiplication
* `(-)`: Subtraction
* `(/)`: Division
* `(==)` : True, if two values are equal
* `(/=)` : True, if two values are not equal
* `(<=)`, `(>=)`, `(<)`, and `(>)` : Comparison operators
* `($)`: Function application

The most special of the above is the last one. It has a
priority of 0, so all other operators bind more tightly.
In addition, function application binds more tightly, so
this can be used to reduce the number of parentheses
required. For instance, instead of writing
`isTriple 3 4 (2 + 3 * 1)` we can write
`isTriple 3 4 $ 2 + 3 * 1`,
which is exactly the same. Sometimes, this helps readability,
sometimes, it doesn't. The important thing to remember is
that `fun $ x y` is just the same as `fun (x y)`.

## Exercises

1. Reimplement functions `testSquare` and `twice` by using the dot
   operator and dropping the second arguments (have a look at the
   implementation of `squareTimes2` to get an idea where this should
   lead you). This highly concise
   way of writing function implementations is sometimes called
   *point-free style* and is often the preferred way of writing
   small utility functions.

2. Declare and implement function `isOdd` by combining functions `isEven`
   from above and `not` (from the Idris *Prelude*). Use point-free style.

3. Declare and implement function `isSquareOf`, which checks whether
   its first `Integer` argument is the square of the second argument.

4. Declare and implement function `isSmall`, which checks whether
   its `Integer` argument is less than or equal to 100. Use one of the
   comparison operators `<=` or `>=` in your implementation.

5. Declare and implement function `absIsSmall`, which checks whether
   the absolute value of its `Integer` argument is less than or equal to 100.
   Use functions `isSmall` and `abs` (from the Idris *Prelude*) in your implementation,
   which should be in point-free style.

6. In this slightly extended exercise we are going to implement
   some utilities for working with `Integer` predicates (functions
   from `Integer` to `Bool`). Implement the following higher-order
   functions (use boolean operators `&&`, `||`, and function `not` in
   your implementations):

   ```idris
   -- return true, if and only if both predicates hold
   and : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool

   -- return true, if and only if at least one predicate holds
   or : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool

   -- return true, if the predicate does not hold
   negate : (Integer -> Bool) -> Integer -> Bool
   ```

   After solving this exercise, give it a go in the REPL. In the
   example below, we use binary function `and` in infix notation
   by wrapping it in backticks. This is just a syntactic convenience
   to make certain function applications more readable:

   ```repl
   Tutorial.Functions1> negate (isSmall `and` isOdd) 73
   False
   ```

7. As explained above, Idris allows us to define our own infix operators.
   Even better, Idris supports *overloading* of function names,
   that is, two functions or operators can have the same
   name, but different types and implementations.
   Idris will make use of the
   types to distinguish between equally named operators and
   functions.

   This allows us, to reimplement functions `and`, `or`, and `negate`
   from Exercise 6 by using the existing operator and function
   names from boolean algebra:

   ```idris
   -- return true, if and only if both predicates hold
   (&&) : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool
   x && y = and x y

   -- return true, if and only if at least one predicate holds
   (||) : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool

   -- return true, if the predicate does not hold
   not : (Integer -> Bool) -> Integer -> Bool
   ```

   Implement the other two functions and test them at the REPL:

   ```repl
   Tutorial.Functions1> not (isSmall && isOdd) 73
   False
   ```

## Conclusion

What we learned in this chapter:

* A function in Idris can take an arbitrary number of arguments,
separated by `->` in the function's type.

* Functions can be combined
sequentially using the dot operator, which leads to highly
concise code.

* Functions can be partially applied by passing them fewer
arguments than they expect. The result is a new function
expecting the remaining arguments. This technique is called
*currying*.

* Functions can be passed as arguments to other functions, which
allows us to easily combine small coding units to create
more complex behavior.

* We can pass anonymous functions (*lambdas*) to higher-order
functions, if writing a corresponding top level
function would be too cumbersome.

* Idris allows us to define our own infix operators. These
have to be written in parentheses unless they are being used
in infix notation.

* Infix operators can also be partially applied. These *operator sections*
have to be wrapped in parentheses, and the position of the
argument determines, whether it is used as the operator's first
or second argument.

* Idris supports name overloading: Functions can have the same
names but different implementations. Idris will decide, which function
to used based to the types involved.

Please note, that function and operator names in a module
must be unique. In order to define two functions with the same
name, they have to be declared in distinct modules. If Idris
is not able to decide, which of the two functions to use, we
can help name resolution by prefixing a function with
(a part of) its *namespace*:

```repl
Tutorial.Functions1> :t Prelude.not
Prelude.not : Bool -> Bool
Tutorial.Functions1> :t Functions1.not
Tutorial.Functions1.not : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool
```

### What's next

In the [next section](DataTypes.md), we will learn how to define
our own data types and how to construct and deconstruct
values of these new types. We will also learn about
generic types and functions.

<!-- vi: filetype=idris2:syntax=markdown
-->
