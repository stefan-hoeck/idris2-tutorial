# Recursion and Folds

In this chapter, we are going to have a closer look at the
computations we typically perform with *container types*:
Parameterized data types like `List`, `Maybe`, or
`Identity`, holding zero or more values of the parameter's
type. Many of these functions are recursive in nature,
so we start with a discourse about recursion in general,
and tail recursion as an important optimization technique
in particular. Most recursive functions in this part
will describe pure iterations over lists.

It is recursive functions, for which totality is hard
to determine, so we will next have a quick look at the
totality checker and learn, when it will refuse to
accept a function as being total and what to do about this.

Finally, we will start looking for common patterns in
the recursive functions from the first part and will
eventually introduce a new interface for consuming
container types: Interface `Foldable`.

```idris
module Tutorial.Folds

import Data.List1
import Data.Maybe
import Data.Vect
import Debug.Trace

%default total
```

## Recursion

In this section, we are going to have a closer look at
recursion in general and at tail recursion in particular.

Recursive functions are functions, which call themselves
to repeat a task or calculation until a certain aborting
condition (called the *base case*) holds.
Please note, that it is recursive functions, which
make it hard to verify totality: Non-recursive functions,
which are *covering* (they cover all possible cases in their
pattern matches) are automatically total if they only invoke
other total functions.

Here is an example of a recursive function: It generates
a list of the given length filling it with identical values:

```idris
replicateList : Nat -> a -> List a
replicateList 0     _ = []
replicateList (S k) x = x :: replicateList k x
```

As you can see (this module has the `%default total` pragma at the top),
this function is provably total. Idris verifies, that the `Nat` argument
gets *strictly smaller* in each recursive call, and that therefore, the
function *must* eventually come to an end. Of course, we can do the
same thing for `Vect`, where we can even show that the length of the
resulting vector matches the given natural number:

```idris
replicateVect : (n : Nat) -> a -> Vect n a
replicateVect 0     _ = []
replicateVect (S k) x = x :: replicateVect k x
```

While we often use recursion to *create* values of data types like
`List` or `Vect`, we also use recursion, when we *consume* such values.
For instance, here is a function for calculating the length of a list:

```idris
len : List a -> Nat
len []        = 0
len (_ :: xs) = 1 + len xs
```

Again, Idris can verify that `len` is total, as the list we pass in
the recursive case is strictly smaller than the original list argument.

But when is a recursive function non-total? Here is an example: The
following function creates a sequence of values until the given
generation function (`gen`) returns a `Nothing`. Note, how we use
a *state* value (of generic type `s`) and use `gen` to calculate
a value together with the next state:

```idris
covering
unfold : (gen : s -> Maybe (s,a)) -> s -> List a
unfold gen vs = case gen vs of
  Just (vs',va) => va :: unfold gen vs'
  Nothing       => []
```

With `unfold`, Idris can't verify that any of its arguments is
converging towards the base case. It therefore rightfully
refuses to accept that `unfold` is total. And indeed, the following
function produces an infinite list (so please, don't try to inspect
this at the REPL, as doing so will consume all your computer's
memory):

```idris
fiboHelper : (Nat,Nat) -> ((Nat,Nat),Nat)
fiboHelper (f0,f1) = ((f1, f0 + f1), f0)

covering
fibonacci : List Nat
fibonacci = unfold (Just . fiboHelper) (1,1)
```

In order to safely create a (finite) sequence of Fibonacci numbers,
we need to make sure the function generating the sequence will
stop after a finite number of steps, for instance by limiting
the length of the list:

```idris
unfoldTot : Nat -> (gen : s -> Maybe (s,a)) -> s -> List a
unfoldTot 0     _   _  = []
unfoldTot (S k) gen vs = case gen vs of
  Just (vs',va) => va :: unfoldTot k gen vs'
  Nothing       => []

fibonacciN : Nat -> List Nat
fibonacciN n = unfoldTot n (Just . fiboHelper) (1,1)
```

### The Call Stack

In order to demonstrate what tail recursion is about, we require
the following `main` function:

```idris
main : IO ()
main = printLn . len $ replicateList 10000 10
```

If you have [Node.js](https://nodejs.org/en/) installed on your system,
you might try the following experiment. Compile and run this
module using the *Node.js* backend of Idris instead of the default
*Chez Scheme* backend and run the resulting JavaScript source file
with the Node.js binary:

```sh
idris2 --cg node -o test.js --find-ipkg -src/Tutorial/Folds.md
node build/exec/test.js
```

Node.js will fail with the following error message and a lengthy
stack trace: `RangeError: Maximum call stack size exceeded`.
What's going on here? How can it be that `main` fails with an
exception although it is provably total?

First, remember that a function
being total means that it will eventually produce a value
of the given type in a finite amount of time, *given
enough resources like computer memory*. Here, `main` hasn't
been given enough resources as Node.js has a very small size
limit on its call stack. The *call stack* can be thought
of as a stack data structure (first in, last out), where
nested function calls are put. In case of recursive functions,
the stack size increases by one with every recursive function
call. In case of our `main` function, we create and consume
a list of length 10'000, so the call stack will hold
at least 10'000 function calls before they are being invoked
and the stack's size is reduced again. This exceeds Node.js's
stack size limit by far, hence the overflow error.

Now, before we look at a solution how to circumvent this issue,
please note that this is a very serious and limiting source of
bugs when using the JavaScript backends of Idris. In Idris, having no
access to control structures like `for` or `while` loops, we *always*
have to resort to recursion in order to describe iterative
computations. Luckily (or should I say "unfortunately", since otherwise
this issue would already have been addressed with all seriousness),
the Scheme backends don't have this issue, as their stack size
limit is much larger and they perform all kinds of optimizations
internally to prevent the call stack from overflowing.

### Tail Recursion

A recursive function is said to be *tail recursive*, if
all recursive calls occur at *tail position*: The last
function call in a (sub)expression. For instance, the following
version of `len` is tail recursive:

```idris
lenOnto : Nat -> List a -> Nat
lenOnto k []        = k
lenOnto k (_ :: xs) = lenOnto (k + 1) xs
```

Compare this to `len` as defined above: There, the last
function call is an invocation of operator `(+)`, and
the recursive call happens in one of its arguments:

```repl
len (_ :: xs) = 1 + len xs
```

We can use `lenOnto` as a utility to implement a tail recursive
version of `len` without the additional `Nat` argument:

```idris
lenTR : List a -> Nat
lenTR = lenOnto 0
```

This is a common pattern when writing tail recursive functions:
We typically add an additional function argument for accumulating
intermediary results, which is then passed on explicitly at each
recursive call. For instance, here is a tail recursive version
of `replicateList`:

```idris
replicateListTR : Nat -> a -> List a
replicateListTR n v = go Nil n
  where go : List a -> Nat -> List a
        go xs 0     = xs
        go xs (S k) = go (v :: xs) k
```

The big advantage of tail recursive functions is, that they
can be easily converted to efficient, imperative loops by the Idris
compiler, an are thus *stack safe*: Recursive function calls
are *not* added to the call stack, thus avoiding the dreaded
stack overflow errors.

```idris
main1 : IO ()
main1 = printLn . lenTR $ replicateListTR 10000 10
```

We can again run `main1` using the *Node.js* backend. This time,
we use slightly different syntax to execute a function other than
`main` (Remember: The dollar prefix is only there to distinghish
a terminal command from its output. It is not part of the
command you enter in a terminal sesssion.):

```sh
$ idris2 --cg node --exec main1 --find-ipkg src/Tutorial/Folds.md
10000
```

As you can see, this time the computation finished without
overflowing the call stack.

Tail recursive functions are allowed to consist of
(possibly nested) pattern matches, with recursive
calls at tail position in several of the branches.
Here is an example:

```idris
countTR : (a -> Bool) -> List a -> Nat
countTR p = go 0
  where go : Nat -> List a -> Nat
        go k []        = k
        go k (x :: xs) = case p x of
          True  => go (S k) xs
          False => go k xs
```

Note, how each invocation of `go` is in tail position in
its branch of the case expression.

### Mutual Recursion

It is sometimes convenient to implement several related
functions, which call each other recursively. In Idris,
unlike in many other programming languages,
a function must be declared in a source file
*before* it can be called by other functions, as in general
a function's implementation must
be available during type checking (because Idris has
dependent types). There are two ways around this, which
actually result in the same internal representation in the
compiler. Our first option is to write down the functions' declarations
first with the implementations following after. Here's a
silly example:

```idris
even : Nat -> Bool

odd : Nat -> Bool

even 0     = True
even (S k) = odd k

odd 0     = False
odd (S k) = even k
```

As you can see, function `even` is allowed to call function `odd` in
its implementation, since `odd` has already been declared (but not yet
implemented).

If you're like me and want to keep declarations and implementations
next to each other, you can introduce a `mutual` block, which has
the same effect. Like with other code blocks, functions in a `mutual`
block must all be indented by the same amount of whitespace:

```idris
mutual
  even' : Nat -> Bool
  even' 0     = True
  even' (S k) = odd' k

  odd' : Nat -> Bool
  odd' 0     = False
  odd' (S k) = even' k
```

Just like with single recursive functions, mutually recursive
functions can be optimized to imperative loops if all
recursive calls occur at tail position. This is the case
with functions `even` and `odd`, as can again be
verified at the *Node.js* backend:

```idris
main2 : IO ()
main2 =  printLn (even 100000)
      >> printLn (odd 100000)
```

```sh
$ idris2 --cg node --exec main2 --find-ipkg src/Tutorial/Folds.md
True
False
```

### Final Remarks

In this section, we learned about several important aspects
of recursion and totality checking, which are summarized here:

* In pure functional programming, recursion is the way to implement
  iterative procedures.

* Recursive functions pass the totality checker, if it can verify that one
  of the arguments is getting strictly smaller in every recursive function
  call.

* Arbitrary recursion can lead to stack overflow exceptions on backends with
  small stack size limits.

* The JavaScript backends of Idris perform mutual tail call optimization:
  Tail recursive functions are converted to stack safe, imperative loops.

Note, that not all Idris backends you will come across in the wild
will perform tail call optimization. Please check the corresponding
documentation.

Note also, that most recursive functions in the core libraries (*prelude*
and *base*) do not yet make use of tail recursion. There is an
important reason for this: In many cases, non-tail recursive
functions are easier to use in compile-time proofs, as they
unify more naturally than their tail recursive counterparts.
Compile-time proofs are an important aspect of programming
in Idris (as we will see in later chapters), so there is a
compromise to be made between what performs well at runtime
and what works well at compile time. Eventually, the way
to go might be to provide two implementations for most
recursive functions with a *transform rule* telling the
compiler to use the optimized version at runtime whenever
programmers use the non-optimized version in their code.
Such transform rules have - for instance - already been
written for functions `pack` and `unpack` (which use
`fastPack` and `fastUnpack` at runtime; see the corresponding
rules in [the following source file](https://github.com/idris-lang/Idris2/blob/main/libs/prelude/Prelude/Types.idr)).

### 练习第 1 部分

In these exercises you are going to implement several
recursive functions. Make sure to use tail recursion
whenever possible and quickly verify the correct
behavior of all functions at the REPL.

1. Implement functions `anyList` and `allList`, which return `True` if any
   element (or all elements in case of `allList`) in a list fulfills the
   given predicate:

   ```idris
   anyList : (a -> Bool) -> List a -> Bool

   allList : (a -> Bool) -> List a -> Bool
   ```

2. Implement function `findList`, which returns the first value (if any)
   fulfilling the given predicate:

   ```idris
   findList : (a -> Bool) -> List a -> Maybe a
   ```

3. Implement function `collectList`, which returns the first value (if any),
   for which the given function returns a `Just`:

   ```idris
   collectList : (a -> Maybe b) -> List a -> Maybe b
   ```

   Implement `lookupList` in terms of `collectList`:

   ```idris
   lookupList : Eq a => a -> List (a,b) -> Maybe b
   ```

4. For functions like `map` or `filter`, which must loop over a list without
   affecting the order of elements, it is harder to write a tail recursive
   implementation.  The safest way to do so is by using a `SnocList` (a
   *reverse* kind of list that's built from head to tail instead of from
   tail to head) to accumulate intermediate results. Its two constructors
   are `Lin` and `(:<)` (called the *snoc* operator).  Module
   `Data.SnocList` exports two tail recursive operators called *fish* and
   *chips* (`(<><)` and `(<>>)`) for going from `SnocList` to `List` and
   vice versa. Have a look at the types of all new data constructors and
   operators before continuing with the exercise.

   Implement a tail recursive version of `map` for `List`
   by using a `SnocList` to reassemble the mapped list. Use then
   the *chips* operator with a `Nil` argument to
   in the end convert the `SnocList` back to a `List`.

   ```idris
   mapTR : (a -> b) -> List a -> List b
   ```

5. Implement a tail recursive version of `filter`, which only keeps those
   values in a list, which fulfill the given predicate. Use the same
   technique as described in exercise 4.

   ```idris
   filterTR : (a -> Bool) -> List a -> List a
   ```

6. Implement a tail recursive version of `mapMaybe`, which only keeps those
   values in a list, for which the given function argument returns a `Just`:

   ```idris
   mapMaybeTR : (a -> Maybe b) -> List a -> List b
   ```

   Implement `catMaybesTR` in terms of `mapMaybeTR`:

   ```idris
   catMaybesTR : List (Maybe a) -> List a
   ```

7. Implement a tail recursive version of list concatenation:

   ```idris
   concatTR : List a -> List a -> List a
   ```

8. Implement tail recursive versions of *bind* and `join` for `List`:

   ```idris
   bindTR : List a -> (a -> List b) -> List b

   joinTR : List (List a) -> List a
   ```

## A few Notes on Totality Checking

The totality checker in Idris verifies, that at least one
(possibly erased!) argument in a recursive call converges towards
a base case. For instance, with natural numbers, if the base case
is zero (corresponding to data constructor `Z`), and we continue
with `k` after pattern matching on `S k`, Idris can derive from
`Nat`'s constructors, that `k` is strictly smaller than `S k`
and therefore the recursive call must converge towards a base case.
Exactly the same reasoning is used when pattern matching on a list
and continuing only with its tail in the recursive call.

While this works in many cases, it doesn't always go as expected.
Below, I'll show you a couple of examples where totality checking
fails, although *we* know, that the functions in question are definitely
total.

### Case 1: Recursion over a Primitive

Idris doesn't know anything about the internal structure of
primitive data types. So the following function, although
being obviously total, will not be accepted by the totality
checker:

```idris
covering
replicatePrim : Bits32 -> a -> List a
replicatePrim 0 v = []
replicatePrim x v = v :: replicatePrim (x - 1) v
```

Unlike with natural numbers (`Nat`), which are defined as an inductive
data type and are only converted to integer primitives during compilation,
Idris can't tell that `x - 1` is strictly smaller than `x`, and so it
fails to verify that this must converge towards the base case.
(The reason is, that `x - 1` is implemented in terms of primitive
function `prim__sub_Bits32`, which is built into the compiler and
must be implemented by each backend individually. The totality
checker knows about data types, constructors, and functions
defined in Idris, but not about (primitive) functions and foreign functions
implemented at the backends. While it is theoretically possible to
also define and use laws for primitive and foreign functions, this hasn't yet
been done for most of them.)

Since non-totality is highly contagious (all functions invoking a
partial function are themselves considered to be partial by the
totality checker), there is utility function `assert_smaller`, which
we can use to convince the totality checker and still annotate our
functions with the `total` keyword:

```idris
replicatePrim' : Bits32 -> a -> List a
replicatePrim' 0 v = []
replicatePrim' x v = v :: replicatePrim' (assert_smaller x $ x - 1) v
```

Please note, though, that whenever you use `assert_smaller` to
silence the totality checker, the burden of proving totality rests
on your shoulders. Failing to do so can lead to arbitrary and
unpredictable program behavior (which is the default with most
other programming languages).

#### Ex Falso Quodlibet

Below - as a demonstration - is a simple proof of `Void`.
`Void` is an *uninhabited type*: a type with no values.
*Proofing `Void`* means, that we implement a function accepted
by the totality checker, which returns a value of type `Void`,
although this is supposed to be impossible as there is no
such value. Doing so allows us to completely
disable the type system together with all the guarantees it provides.
Here's the code and its dire consequences:

```idris
-- In order to proof `Void`, we just loop forever, using
-- `assert_smaller` to silence the totality checker.
proofOfVoid : Bits8 -> Void
proofOfVoid n = proofOfVoid (assert_smaller n n)

-- From a value of type `Void`, anything follows!
-- This function is safe and total, as there is no
-- value of type `Void`!
exFalsoQuodlibet : Void -> a
exFalsoQuodlibet _ impossible

-- By passing our proof of void to `exFalsoQuodlibet`
-- (exported by the *Prelude* by the name of `void`), we
-- can coerce any value to a value of any other type.
-- This renders type checking completely useless, as
-- we can freely convert between values of different
-- types.
coerce : a -> b
coerce _ = exFalsoQuodlibet (proofOfVoid 0)

-- Finally, we invoke `putStrLn` with a number instead
-- of a string. `coerce` allows us to do just that.
pain : IO ()
pain = putStrLn $ coerce 0
```

Please take a moment to marvel at provably total function `coerce`:
It claims to convert *any* value to a value of *any* other type.
And it is completely safe, as it only uses total functions in its
implementation. The problem is - of course - that `proofOfVoid` should
never ever have been a total function.

In `pain` we use `coerce` to conjure a string from an integer.
In the end, we get what we deserve: The program crashes with an error.
While things could have been much worse, it can still be quite
time consuming and annoying to localize the source of such an error.

```sh
$ idris2 --cg node --exec pain --find-ipkg src/Tutorial/Folds.md
ERROR: No clauses
```

So, with a single thoughtless placement of `assert_smaller` we wrought
havoc within our pure and total codebase sacrificing totality and
type safety in one fell swoop. Therefore: Use at your own risk!

Note: I do not expect you to understand all the dark magic at
work in the code above. I'll explain the details in due time
in another chapter.

Second note: *Ex falso quodlibet*, also called
[the principle of explosion](https://en.wikipedia.org/wiki/Principle_of_explosion)
is a law in classical logic: From a contradiction, any statement can be proven.
In our case, the contradiction was our proof of `Void`: The claim that we wrote
a total function producing such a value, although `Void` is an uninhabited type.
You can verify this by inspecting `Void` at the REPL with `:doc Void`: It
has no data constructors.

### Case 2: Recursion via Function Calls

Below is an implementation of a [*rose tree*](https://en.wikipedia.org/wiki/Rose_tree).
Rose trees can represent search paths in computer algorithms,
for instance in graph theory.

```idris
record Tree a where
  constructor Node
  value  : a
  forest : List (Tree a)

Forest : Type -> Type
Forest = List . Tree
```

We could try and compute the size of such a tree as follows:

```idris
covering
size : Tree a -> Nat
size (Node _ forest) = S . sum $ map size forest
```

In the code above, the recursive call happens within `map`. *We* know that
we are using only subtrees in the recursive calls (since we know how `map`
is implemented for `List`), but Idris can't know this (teaching a totality
checker how to figure this out on its own seems to be an open research
question). So it will refuse to accept the function as being total.

There are two ways to handle the case above. If we don't mind writing
a bit of otherwise unneeded boilerplate code, we can use explicit recursion.
In fact, since we often also work with search *forests*, this is
the preferable way here.

```idris
mutual
  treeSize : Tree a -> Nat
  treeSize (Node _ forest) = S $ forestSize forest

  forestSize : Forest a -> Nat
  forestSize []        = 0
  forestSize (x :: xs) = treeSize x + forestSize xs
```

In the case above, Idris can verify that we don't blow up our trees behind
its back as we are explicit about what happens in each recursive step.
This is the safe, preferable way of going about this, especially if you are
new to the language and totality checking in general.

However, sometimes the solution presented above is just too cumbersome to
write. For instance, here is an implementation of `Show` for rose trees:

```idris
Show a => Show (Tree a) where
  showPrec p (Node v ts) =
    assert_total $ showCon p "Node" (showArg v ++ showArg ts)
```

In this case, we'd have to manually reimplement `Show` for lists of trees:
A tedious task - and error-prone on its own. Instead, we resort to using the
mighty sledgehammer of totality checking: `assert_total`. Needless to say
that this comes with the same risks as `assert_smaller`, so be very
careful.

### Exercises part 2

Implement the following functions in a provably total
way without "cheating". Note: It is not necessary to
implement these in a tail recursive way.

<!-- textlint-disable terminology -->
1. Implement function `depth` for rose trees. This
   should return the maximal number of `Node` constructors
   from the current node to the farthest child node.
   For instance, the current node should be at depth one,
   all its direct child nodes are at depth two, their
   immediate child nodes at depth three and so on.
<!-- textlint-enable -->

2. Implement interface `Eq` for rose trees.

3. Implement interface `Functor` for rose trees.

4. For the fun of it: Implement interface `Show` for rose trees.

5. In order not to forget how to program with dependent types, implement
   function `treeToVect` for converting a rose tree to a vector of the
   correct size.

   Hint: Make sure to follow the same recursion scheme as in
   the implementation of `treeSize`. Otherwise, this might be
   very hard to get to work.

## Interface Foldable

When looking back at all the exercises we solved
in the section about recursion, most tail recursive functions
on lists where of the following pattern: Iterate
over all list elements from head to tail while
passing along some state for accumulating intermediate
results. At the end of the list,
return the final state or convert it with an
additional function call.

### Left Folds

This is functional programming, and we'd like to abstract
over such reoccurring patterns. In order to tail recursively
iterate over a list, all we need is an accumulator function
and some initial state. But what should be the type of
the accumulator? Well, it combines the current state
with the list's next element and returns an updated
state: `state -> elem -> state`. Surely, we can come
up with a higher-order function to encapsulate this
behavior:

```idris
leftFold : (acc : state -> el -> state) -> (st : state) -> List el -> state
leftFold _   st []        = st
leftFold acc st (x :: xs) = leftFold acc (acc st x) xs
```

We call this function a *left fold*, as it iterates over
the list from left to right (head to tail), collapsing (or
*folding*) the list until just a single value remains.
This new value might still be a list or other container type,
but the original list has been consumed from head to tail.
Note how `leftFold` is tail recursive, and therefore all
functions implemented in terms of `leftFold` are
tail recursive (and thus, stack safe!) as well.

Here are a few examples:

```idris
sumLF : Num a => List a -> a
sumLF = leftFold (+) 0

reverseLF : List a -> List a
reverseLF = leftFold (flip (::)) Nil

-- this is more natural than `reverseLF`!
toSnocListLF : List a -> SnocList a
toSnocListLF = leftFold (:<) Lin
```

### Right Folds

The example functions we implemented in terms of `leftFold` had
to always completely traverse the whole list, as every single
element was required to compute the result. This is not always
necessary, however. For instance, if you look at `findList` from
the exercises, we could abort iterating over the list as soon
as our search was successful. It is *not* possible to implement
this more efficient behavior in terms of `leftFold`: There,
the result will only be returned when our pattern match reaches
the `Nil` case.

Interestingly, there is another, non-tail recursive fold, which
reflects the list structure more naturally, we can use for
breaking out early from an iteration. We call this a
*right fold*. Here is its implementation:

```idris
rightFold : (acc : el -> state -> state) -> state -> List el -> state
rightFold acc st []        = st
rightFold acc st (x :: xs) = acc x (rightFold acc st xs)
```

Now, it might not immediately be obvious how this differs from `leftFold`.
In order to see this, we will have to talk about lazy evaluation
first.

#### Lazy Evaluation in Idris

For some computations, it is not necessary to evaluate all function
arguments in order to return a result. For instance, consider
boolean operator `(&&)`: If the first argument evaluates to `False`,
we already know that the result is `False` without even looking at
the second argument. In such a case, we don't want to unnecessarily evaluate
the second argument, as this might include a lengthy computation.

Consider the following REPL session:

```repl
Tutorial.Folds> False && (length [1..10000000000] > 100)
False
```

If the second argument were evaluated, this computation would most
certainly blow up your computer's memory, or at least take a very long
time to run to completion. However, in this case, the result `False` is
printed immediately. If you look at the type of `(&&)`, you'll see
the following:

```repl
Tutorial.Folds> :t (&&)
Prelude.&& : Bool -> Lazy Bool -> Bool
```

As you can see, the second argument is wrapped in a `Lazy` type
constructor. This is a built-in type, and the details are handled
by Idris automatically most of the time. For instance, when passing
arguments to `(&&)`, we don't have to manually wrap the values in
some data constructor.
A lazy function argument will only be evaluated at the moment it
is *required* in the function's implementation, for instance,
because it is being pattern matched on, or it is being passed
as a strict argument to another function. In the implementation
of `(&&)`, the pattern match happens
on the first argument, so the second will only be evaluated if
the first argument is `True` and the second is returned as the function's
(strict) result.

There are two utility functions for working with lazy evaluation:
Function `delay` wraps a value in the `Lazy` data type. Note, that
the argument of `lazy` is strict, so the following might take
several seconds to print its result:

```repl
Tutorial.Folds> False && (delay $ length [1..10000] > 100)
False
```

In addition, there is function `force`, which forces evaluation
of a `Lazy` value.

#### Lazy Evaluation and Right Folds

We will now learn how to make use of `rightFold` and lazy evaluation
to implement folds, which can break out from iteration early.
Note, that in the implementation of `rightFold` the result of
folding over the remainder of the list is passed as an argument
to the accumulator (instead of the result of invoking the accumulator
being used in the recursive call):

```repl
rightFold acc st (x :: xs) = acc x (rightFold acc st xs)
```

If the second argument of `acc` were lazily evaluated, it would be possible
to abort the computation of `acc`'s result without having to iterate
till the end of the list:

```idris
foldHead : List a -> Maybe a
foldHead = force . rightFold first Nothing
  where first : a -> Lazy (Maybe a) -> Lazy (Maybe a)
        first v _ = Just v
```

Note, how Idris takes care of the bookkeeping of laziness most of the time. (It
doesn't handle the curried invocation of `rightFold` correctly, though, so we
either must pass on the list argument of `foldHead` explicitly, or compose
the curried function with `force` to get the types right.)

In order to verify that this works correctly, we need a debugging utility
called `trace` from module `Debug.Trace`. This "function" allows us to
print debugging messages to the console at certain points in our pure
code. Please note, that this is for debugging purposes only and should
never be left lying around in production code, as, strictly speaking,
printing stuff to the console breaks referential transparency.

Here is an adjusted version of `foldHead`, which prints "folded" to
standard output every time utility function `first` is being invoked:

```idris
foldHeadTraced : List a -> Maybe a
foldHeadTraced = force . rightFold first Nothing
  where first : a -> Lazy (Maybe a) -> Lazy (Maybe a)
        first v _ = trace "folded" (Just v)
```

In order to test this at the REPL, we need to know that `trace` uses `unsafePerformIO`
internally and therefore will not reduce during evaluation. We have to
resort to the `:exec` command to see this in action at the REPL:

```repl
Tutorial.Folds> :exec printLn $ foldHeadTraced [1..10]
folded
Just 1
```

As you can see, although the list holds ten elements, `first` is only called
once resulting in a considerable increase of efficiency.

Let's see what happens, if we change the implementation of `first` to
use strict evaluation:

```idris
foldHeadTracedStrict : List a -> Maybe a
foldHeadTracedStrict = rightFold first Nothing
  where first : a -> Maybe a -> Maybe a
        first v _ = trace "folded" (Just v)
```

Although we don't use the second argument in the implementation of `first`,
it is still being evaluated before evaluating the body of `first`, because
Idris - unlike Haskell! - defaults to use strict semantics. Here's how this
behaves at the REPL:

```repl
Tutorial.Folds> :exec printLn $ foldHeadTracedStrict [1..10]
folded
folded
folded
folded
folded
folded
folded
folded
folded
folded
Just 1
```

While this technique can sometimes lead to very elegant code, always
remember that `rightFold` is not stack safe in the general case. So,
unless your accumulator is not guaranteed to return a result after
not too many iterations, consider implementing your function
tail recursively with an explicit pattern match. Your code will be
slightly more verbose, but with the guaranteed benefit of stack safety.

### Folds and Monoids

Left and right folds share a common pattern: In both cases, we start
with an initial *state* value and use an accumulator function for
combining the current state with the current element. This principle
of *combining values* after starting from an *initial value* lies
at the heart of an interface we've already learned about: `Monoid`.
It therefore makes sense to fold a list over a monoid:

```idris
foldMapList : Monoid m => (a -> m) -> List a -> m
foldMapList f = leftFold (\vm,va => vm <+> f va) neutral
```

Note how, with `foldMapList`, we no longer need to pass an accumulator
function. All we need is a conversion from the element type to
a type with an implementation of `Monoid`. As we have already seen
in the chapter about [interfaces](Interfaces.md), there are *many*
monoids in functional programming, and therefore, `foldMapList` is
an incredibly useful function.

We could make this even shorter: If the elements in our list already
are of a type with a monoid implementation, we don't even need a
conversion function to collapse the list:

```idris
concatList : Monoid m => List m -> m
concatList = foldMapList id
```

### Stop Using `List` for Everything

And here we are, finally, looking at a large pile of utility functions
all dealing in some way with the concept of collapsing (or folding)
a list of values into a single result. But all of these folding functions
are just as useful when working with vectors, with non-empty lists, with
rose trees, even with single-value containers like `Maybe`, `Either e`,
or `Identity`. Heck, for the sake of completeness, they are even useful
when working with zero-value containers like `Control.Applicative.Const e`!
And since there are so many of these functions, we'd better look out for
an essential set of them in terms of which we can implement all
the others, and wrap up the whole bunch in an interface. This interface
is called `Foldable`, and is available from the `Prelude`. When you
look at its definition in the REPL (`:doc Foldable`), you'll see that
it consists of six essential functions:

* `foldr`, for folds from the right
* `foldl`, for folds from the left
* `null`, for testing if the container is empty or not
* `foldM`, for effectful folds in a monad
* `toList`, for converting the container to a list of values
* `foldMap`, for folding over a monoid

For a minimal implementation of `Foldable`, it is sufficient to only
implement `foldr`. However, consider implementing all six functions
manually, because folds over container types are often performance
critical operations, and each of them should be optimized accordingly.
For instance, implementing `toList` in terms of `foldr` for `List`
just makes no sense, as this is a non-tail recursive function
running in linear time complexity, while a hand-written implementation
can just return its argument without any modifications.

### Exercises part 3

In these exercises, you are going to implement `Foldable`
for different data types. Make sure to try and manually
implement all six functions of the interface.

1. Implement `Foldable` for `Crud i`:

   ```idris
   data Crud : (i : Type) -> (a : Type) -> Type where
     Create : (value : a) -> Crud i a
     Update : (id : i) -> (value : a) -> Crud i a
     Read   : (id : i) -> Crud i a
     Delete : (id : i) -> Crud i a
   ```

2. Implement `Foldable` for `Response e i`:

   ```idris
   data Response : (e, i, a : Type) -> Type where
     Created : (id : i) -> (value : a) -> Response e i a
     Updated : (id : i) -> (value : a) -> Response e i a
     Found   : (values : List a) -> Response e i a
     Deleted : (id : i) -> Response e i a
     Error   : (err : e) -> Response e i a
   ```

3. Implement `Foldable` for `List01`. Use tail recursion in the
   implementations of `toList`, `foldMap`, and `foldl`.

   ```idris
   data List01 : (nonEmpty : Bool) -> Type -> Type where
     Nil  : List01 False a
     (::) : a -> List01 False a -> List01 ne a
   ```

4. Implement `Foldable` for `Tree`. There is no need to use tail recursion
   in your implementations, but your functions must be accepted by the
   totality checker, and you are not allowed to cheat by using
   `assert_smaller` or `assert_total`.

   Hint: You can test the correct behavior of your implementations
   by running the same folds on the result of `treeToVect` and
   verify that the outcome is the same.

5. Like `Functor` and `Applicative`, `Foldable` composes: The product and
   composition of two foldable container types are again foldable container
   types. Proof this by implementing `Foldable` for `Comp` and `Product`:

   ```idris
   record Comp (f,g : Type -> Type) (a : Type) where
     constructor MkComp
     unComp  : f (g a)

   record Product (f,g : Type -> Type) (a : Type) where
     constructor MkProduct
     fst : f a
     snd : g a
   ```

## 结论

We learned a lot about recursion, totality checking, and folds
in this chapter, all of which are important concepts in pure
functional programming in general. Wrapping one's head
around recursion takes time and experience. Therefore - as
usual - try to solve as many exercises as you can.

In the next chapter, we are taking the concept of iterating
over container types one step further and look at
effectful data traversals.

<!-- vi: filetype=idris2
-->
