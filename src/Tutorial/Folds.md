# Folds and Traversals

In this chapter, we are going to have a closer look at the
computations we typically perform with *container types*:
Parameterized data types like `List`, `Maybe`, or
`Identity`, holding zero or more values of the parameter's
type.

We start with concrete, pure functions like "calculating
the sum of the numeric values stored in a container", but will
soon begin to experiment with generalizations,
eventually arriving at three highly versatile functions
for accumulating the values stored in a container: `foldl`,
`foldr`, and `foldMap`.

We will then look at running effectful conversions over the
elements stored in a container, while reassembling and
preserving the container's structure. This will eventually
lead us to one of the most powerful functions exported by
the *Prelude*: `traverse`.

```idris
module Tutorial.Folds

import Data.List1
import Data.Maybe
import Data.Vect

%default total
```

## Recursion

In this section, we are going to have a closer look at
recursion in general and at tail recursion in particular.

Recursive functions are functions, which call themselves,
to repeat a task or calculation until a certain aborting
condition (called the *base case*) holds. We will look
at totality in more detail in a later chapter, but right
now, please note that it is recursive functions, which
make it hard to verify totality: Non-recursive functions,
which are *covering* (they cover all possible cases in their
pattern matches) are automatically total (if they only invoke
other total functions).

Here is an example: The following function generates
a list of a given length filling it with the given argument:

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
a value and the next state:

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

In order to demonstrate what tail recursion is about, we will need
the following `main` function:

```idris
main : IO ()
main = printLn . len $ replicateList 10000 10
```

If you have [NodeJS](https://nodejs.org/en/) installed on your system,
you might try the following experiment. Compile and run this
module using the *node* backend of Idris instead of the default
*Chez Scheme* backend:

```sh
$> idris2 --cg node -o test.js --find-ipkg -src/Tutorial/Folds.md
$> node build/exec/test.js
```

Node will fail with the following error message and a lengthy
stack trace: `RangeError: Maximum call stack size exceeded`.
What's going on here? How can it be that `main` fails with an
exception although it is provably total? First, a function
being total means that it will eventually produce a value
of the given type in a finite amount of time, *given
enough resources like computer memory*. Here, `main` hasn't
been given enough resources as NodeJS has a very small size
limit on its call stack. The *call stack* can be thought
of as a stack data structure (first in, last out), where
nested function calls are put. In case of recursive functions,
the stack size increases by one with every recursive function
call. In case of our `main` function, we create and consume
a list of length 10'000, so the call stack will hold
at least 10'000 function calls before they are being invoked
and the stack size is reduced again. This exceeds *node*'s
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
intermediary results, which is then handed explicitly at the
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
can be easily converted to an imperative loop by the Idris
compiler, an are thus *stack safe*: Recursive function calls
are *not* added to the call stack, thus avoiding the dreaded
stack overflow errors.

```idris
main1 : IO ()
main1 = printLn . lenTR $ replicateListTR 10000 10
```

We can again run `main1` using the *node* backend. This time,
we use slightly different syntax to execute a function other than
`main`:

```sh
$> idris2 --cg node --exec main1 --find-ipkg src/Tutorial/Folds.md
10000
```

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

### Mutual Recursion

It is sometimes convenient, to implement several related
functions, which call each other recursively. In Idris,
unlike in many other programming languages,
a function must be declared before it can be called by other
functions, as in general, a function's implementation must
be available during type checking (because Idris has
dependent types). There are two ways around this, which
actually result in the same internal representation in the
compiler. One thing to do, is write down the functions' declarations
first, with the implementations following after. Here's a
silly example:

```idris
even : Nat -> Bool

odd : Nat -> Bool

even 0     = True
even (S k) = odd k

odd 0     = False
odd (S k) = even k
```

If you're like me and want to keep declarations and implementations
next to each other, you can introduce a `mutual` block, which has
the same effect:

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
with our functions `even` and `odd`, as can again be
verified on the *node* backend:

```idris
main2 : IO ()
main2 =  printLn (even 100000)
      >> printLn (odd 100000)
```

```sh
$> idris2 --cg node --exec main2 --find-ipkg src/Tutorial/Folds.md
True
False
```

### Final Remarks

In this section, we learned about several important aspects
of recursion, which are summarized here:

* In pure functional programming, recursion is the
  way to implement iterative expressions.

* Recursive functions pass the totality checker, if it can
  verify that one of the arguments is getting strictly smaller
  in every recursive function call.

* Arbitrary recursion can lead to stack overflow exceptions on
  backends small stack size limits.

* The JavaScript backends of Idris perform mutual tail call
  optimization: Tail recursive functions are converted to
  stack-safe, imperative loops.

Note, that not all backends you will come across in the wild
will perform tail call optimization.

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
recursive function with a *transform rule* telling the
compiler to use the optimized version at runtime whenever
programmers use the non-optimized version in their code.
Such transform rules have - for instance - already been
written for functions `pack` and `unpack` (which use
`fastPack` and `fastUnpack` at runtime; see the corresponding
rules in [the following source file](https://github.com/idris-lang/Idris2/blob/main/libs/prelude/Prelude/Types.idr)).

### Exercises

In these exercises you are going to implement several
recursive functions. Make sure to use tail recursion
whenever possible and quickly verify the correct
behavior of all functions at the REPL.

1. Implement functions `anyList` and `allList`, which return
   `True` if any element (or all elements in case of `allList`) in
   a list fulfills the given predicate:

   ```idris
   anyList : (a -> Bool) -> List a -> Bool

   allList : (a -> Bool) -> List a -> Bool
   ```

2. Implement function `findList`, which returns the first value
   (if any) fulfilling the given predicate:

   ```idris
   findList : (a -> Bool) -> List a -> Maybe a
   ```

3. Implement function `collectList`, which returns the first value
   (if any), for which the given function returns a `Just`:

   ```idris
   collectList : (a -> Maybe b) -> List a -> Maybe b
   ```

   Implement `lookupList` in terms of `collectList`:

   ```idris
   lookupList : Eq a => a List (a,b) -> Maybe b
   ```

4. For functions like `map` or `filter`, which must
   loop over a list without affecting the order of elements,
   it is harder to write a tail recursive implementation.
   The safest way to do so is by using a `SnocList` (a
   *reverse* kind of list that's built from head to tail
   instead of from tail to head) to accumulate intermediate
   results. Its two constructors
   are `Lin` and `(:<)` (called the *snoc* operator).
   Module `Data.SnocList` exports two tail recursive operators
   called *fish* and *chips* (`(<><)` and `(<>>)`) for going
   from `SnocList` to `List` and vice versa. Have a look
   at the types of all new data constructors and operators 
   before continuing with the exercise.

   Implement a tail recursive version of `map` for `List`
   by using a `SnocList` to reassemble the mapped list. Use then
   the *chips* operator with a `Nil` argument to
   in the end convert the `SnocList` back to a `List`.

   ```idris
   mapTR : (a -> b) -> List a -> List b
   ```

5. Implement a tail recursive version of `filter`, which
   only keeps those values in a list, which fulfill the
   given predicate. Use the same technique as described in
   exercise 4.

   ```idris
   filterTR : (a -> Bool) -> List a -> List a
   ```

6. Implement a tail recursive version of `mapMaybe`, which
   only keeps those values in a list, for which the given
   function argument returns a `Just`:

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

8. Implement a tail recursive version of *bind* and `join`
   for `List`:

   ```idris
   bindTR : List a -> (a -> List b) -> List b

   joinTR : List (List a) -> List a
   ```

## Interface Foldable

When looking back at all the exercises we solved
in the last section, most tail recursive functions
on lists where of the following pattern: Iterate
over all list elements from head to tail, while
passing along some state for accumulating intermediate
results. At the end of the list,
return the final state or convert it with an
additional function call.

This is functional programming, and we'd like to abstract
over such reoccurring patterns. In order to tail recursively
iterate over a list, all we need is an accumulator function
and some initial state. But what would be the type of
the accumulator? Well, it combines the current state
with the list's next element and returns an updated
state: `state -> elem -> state`. Surely, we can come
up with a higher order function to encapsulate this
behavior:

```idris
leftFold : (state -> el -> state) -> state -> List el -> state
leftFold _   st []        = st
leftFold acc st (x :: xs) = leftFold acc (acc st x) xs
```

We call this function a *left fold*, as it iterates over
the list from left to right (head to tail), collapsing (or
*folding*) the list until just a single value remains.
This new value might still be a list or other container type,
but the original list has be consumed from head to tail.
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

<!-- vi: filetype=idris2
-->
