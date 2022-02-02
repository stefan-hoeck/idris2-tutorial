# Effectful Traversals

In this chapter, we are going to bring our treatment
of the higher-kinded interfaces in the *Prelude* to an
end. In order to do so, we will continue developing the
CSV reader we started implementing in chapter
[Functor and Friends](Functor.md). I moved some of
the data types and interfaces from that chapter to
their own modules, so we can import them here without
the need to start from scratch.

Note that unlike in our original CSV reader, we will use
`Validated` instead of `Either` for handling exceptions,
since this will allow us to accumulate all errors
when reading a CSV file.

```idris
module Tutorial.Traverse

import Data.HList
import Data.IORef
import Data.List1
import Data.String
import Data.Validated
import Data.Vect
import Text.CSV

%default total
```

## Reading CSV Tables

We stopped developing our CSV reader with function
`hdecode`, which allows us to read a single line
in a CSV file and decode it to a heterogeneous list.
As a reminder, here is how to use `hdecode` at the REPL:

```repl
Tutorial.Traverse> hdecode [Bool,String,Bits8] 1 "f,foo,12"
Valid [False, "foo", 12]
```

The next step will be to parse a whole CSV table, represented
as a list of strings, where each string corresponds to one
of the table's rows.
We will go about this stepwise as there are several aspects
about doing this properly. What we are looking for - eventually -
is a function of the following type (we are going to
implement several versions of this function, hence the
numbering):

```idris
hreadTable1 :  (0 ts : List Type)
            -> CSVLine (HList ts)
            => List String
            -> Validated CSVError (List $ HList ts)
```

In our first implementation, we are not going to care
about line numbers:

```idris
hreadTable1 _  []        = pure []
hreadTable1 ts (s :: ss) = [| hdecode ts 0 s :: hreadTable1 ts ss |]
```

Note, how we can just use applicative syntax in the implementation
of `hreadTable1`. To make this clearer, I used `pure []` on the first
line instead of the more specific `Valid []`. In fact, if we used
`Either` or `Maybe` instead of `Validated` for error handling,
the implementation of `hreadTable1` would look exactly the same.

The question is: Can we extract a pattern to abstract over
from this observation? What we do in `hreadTable1` is running
an effectful computation of type `String -> Validated CSVError (HList ts)`
over a list of strings, so that the result is a list of `HList ts`
wrapped in a `Validated CSVError`. The first step of abstraction
should be to use type parameters for the input and output:
Run a computation of type `a -> Validated CSVError b` over a
list `List a`:

```idris
traverseValidatedList :  (a -> Validated CSVError b)
                      -> List a
                      -> Validated CSVError (List b)
traverseValidatedList _ []        = pure []
traverseValidatedList f (x :: xs) = [| f x :: traverseValidatedList f xs |]

hreadTable2 :  (0 ts : List Type)
            -> CSVLine (HList ts)
            => List String
            -> Validated CSVError (List $ HList ts)
hreadTable2 ts = traverseValidatedList (hdecode ts 0)
```

But our observation was, that the implementation of `hreadTable1`
would be exactly the same if we used `Either CSVError` or `Maybe`
as our effect types instead of `Validated CSVError`.
So, the next step should be to abstract over the *effect type*.
We note, that we used applicative syntax (idiom brackets and
`pure`) in our implementation, so we will need to write
a function with an `Applicative` constraint
on the effect type:

```idris
traverseList :  Applicative f => (a -> f b) -> List a -> f (List b)
traverseList _ []        = pure []
traverseList f (x :: xs) = [| f x :: traverseList f xs |]

hreadTable3 :  (0 ts : List Type)
            -> CSVLine (HList ts)
            => List String
            -> Validated CSVError (List $ HList ts)
hreadTable3 ts = traverseList (hdecode ts 0)
```

Note, how the implementation of `traverseList` is exactly the same
as the one of `traverseValidatedList`, but the types are more general
and therefore, `traverseList` is much more powerful.

Let's give this a go at the REPL:

```repl
Tutorial.Traverse> hreadTable3 [Bool,Bits8] ["f,12","t,0"]
Valid [[False, 12], [True, 0]]
Tutorial.Traverse> hreadTable3 [Bool,Bits8] ["f,12","t,1000"]
Invalid (FieldError 0 2 "1000")
Tutorial.Traverse> hreadTable3 [Bool,Bits8] ["1,12","t,1000"]
Invalid (Append (FieldError 0 1 "1") (FieldError 0 2 "1000"))
```

This works very well already, but note how our error messages do
not yet print the correct line numbers. That's not surprising,
as we are using a dummy constant in our call to `hdecode`.
We will look at how we can come up with the line numbers on the
fly when we talk about stateful computations later in this chapter.
For now, we could just manually annotate the lines with their
numbers and pass a list of pairs to `hreadTable`:

```idris
hreadTable4 :  (0 ts : List Type)
            -> CSVLine (HList ts)
            => List (Nat, String)
            -> Validated CSVError (List $ HList ts)
hreadTable4 ts = traverseList (uncurry $ hdecode ts)
```

If this is the first time you came across function `uncurry`,
make sure you have a look at its type and try to figure out why it is
used here. There are several utility functions like this
in the *Prelude*, such as `curry`, `uncurry`, `flip`, or even
`id`, all of which can be very useful when working with higher-order
functions.

While not perfect, this version at least allows us to verify at the REPL
that the line numbers are passed to the error messages correctly:

```repl
Tutorial.Traverse> hreadTable4 [Bool,Bits8] [(1,"t,1000"),(2,"1,100")]
Invalid (Append (FieldError 1 2 "1000") (FieldError 2 1 "1"))
```

### Interface Traversable

Now, here is an interesting observation: We can implement a function
like `traverseList` for other container types as well. You might think that's
obvious, given that we can convert container types to lists via
function `toList` from interface `Foldable`. However, while going
via `List` might be feasible in some occasions, it is undesirable in
general, as we loose typing information. For instance, here
is such a function for `Vect`:

```idris
traverseVect' : Applicative f => (a -> f b) -> Vect n a -> f (List b)
traverseVect' fun = traverseList fun . toList
```

Note how we lost all information about the structure of the
original container type. What we are looking for is a function
like `traverseVect'`, which keeps this type level information:
The result should be a vector of the same length as the input.

```idris
traverseVect : Applicative f => (a -> f b) -> Vect n a -> f (Vect n b)
traverseVect _   []        = pure []
traverseVect fun (x :: xs) = [| fun x :: traverseVect fun xs |]
```

That's much better! And as I wrote above, we can easily get the same
for other container types like `List1`, `SnocList`, `Maybe`, and so on.
As usual, some derived functions will follow immediately from `traverseXY`.
For instance:

```idris
sequenceList : Applicative f => List (f a) -> f (List a)
sequenceList = traverseList id
```

All of this calls for a new interface, which is called
`Traversable` and is exported from the *Prelude*. Here is
its definition (with primes for disambiguation):

```idris
interface Functor t => Foldable t => Traversable' t where
  traverse' : Applicative f => (a -> f b) -> t a -> f (t b)
```

Function `traverse` is one of the most abstract and versatile
functions available from the *Prelude*. Just how powerful
it is will only become clear once you start using it
over and over again in your code. However, it will be the
goal of the remainder of this chapter to show you several
diverse and interesting use cases.

For now, we will quickly focus on the degree of abstraction.
Function `traverse` is parameterized over no less than
four parameters: The container type `t` (`List`, `Vect n`,
`Maybe`, to just name a few), the effect type (`Validated e`,
`IO`, `Maybe`, and so on), the input element type `a`, and
the output element type `b`. Considering that the libraries
bundled with the Idris project export more than 30 data types
with an implementation of `Applicative` and more than ten
traversable container types, there are literally hundreds
of combinations for traversing a container with an effectful
computation. This number gets even larger once we realize
that traversable containers - like applicative functors -
are closed under composition (see the exercises and
the final section in this chapter).

### Traversable Laws

There are two laws function `traverse` must obey:

* `traverse (Id . f) = Id . map f`: Traversing over
  the `Identity` monad is just functor `map`.
* `traverse (MkComp . map f . g) = MkComp . map (traverse f) . traverse g`:
  Traversing with a composition of effects
  must be the same when being done in a single traversal
  (left hand side) or a sequence of two traversals (right
  hand side).

Since `map id = id` (functor's identity law), we can derive
from the first law that `traverse Id = Id`. This means, that
`traverse` must not change the size or shape of the container
type, nor is it allowed to change the order of elements.

### Exercises part 1

1. It is interesting that `Traversable` has a `Functor`
   constraint. Proof that every `Traversable` is
   automatically a `Functor` by implementing `map`
   in terms of `traverse`.

   Hint: Remember `Control.Monad.Identity`.

2. Likewise, proof that every `Traversable` is
   a `Foldable` by implementing `foldMap` in
   terms of `Traverse`.

   Hint: Remember `Control.Applicative.Const`.

3. To gain some routine, implement `Traversable'` for
   `List1`, `Either e`, and `Maybe`.

4. Implement `Traversable` for `List01 ne`:

   ```idris
   data List01 : (nonEmpty : Bool) -> Type -> Type where
     Nil  : List01 False a
     (::) : a -> List01 False a -> List01 ne a
   ```

5. Implement `Traversable` for rose trees. Try to satisfy
   the totality checker without cheating.

   ```idris
   record Tree a where
     constructor Node
     value  : a
     forest : List (Tree a)
   ```

6. Implement `Traversable` for `Crud i`:

   ```idris
   data Crud : (i : Type) -> (a : Type) -> Type where
     Create : (value : a) -> Crud i a
     Update : (id : i) -> (value : a) -> Crud i a
     Read   : (id : i) -> Crud i a
     Delete : (id : i) -> Crud i a
   ```

7. Implement `Traversable` for `Response e i`:

   ```idris
   data Response : (e, i, a : Type) -> Type where
     Created : (id : i) -> (value : a) -> Response e i a
     Updated : (id : i) -> (value : a) -> Response e i a
     Found   : (values : List a) -> Response e i a
     Deleted : (id : i) -> Response e i a
     Error   : (err : e) -> Response e i a
   ```

8. Like `Functor`, `Applicative` and `Foldable`, `Traversable` is closed under
   composition. Proof this by implementing `Traversable` for `Comp`
   and `Product`:

   ```idris
   record Comp (f,g : Type -> Type) (a : Type) where
     constructor MkComp
     unComp  : f (g a)

   record Product (f,g : Type -> Type) (a : Type) where
     constructor MkProduct
     fst : f a
     snd : g a
   ```

## Programming with State

Let's go back to our CSV reader. In order to get reasonable
error messages, we'd like to tag each line with its
index:

```idris
zipWithIndex : List a -> List (Nat, a)
```

It is, of course, very easy to come up with an ad hoc
implementation for this:

```idris
zipWithIndex = go 1
  where go : Nat -> List a -> List (Nat,a)
        go _ []        = []
        go n (x :: xs) = (n,x) :: go (S n) xs
```

While this is perfectly fine, we should still note that
we might want to do the same thing with the elements of
trees, vectors, non-empty lists and so on.
And again, we are interested in whether there is some
form of abstraction we can use to describe such computations.

### Mutable References in Idris

Let us for a moment think about how we'd do such a thing
in an imperative language. There, we'd probably define
a local (mutable) variable to keep track of the current
index, which would then be increased while iterating over the list
in a `for`- or `while`-loop.

In Idris, there is no such thing as mutable state.
Or is there? Remember, how we used a mutable reference
to simulate a data base connection in an earlier
exercise. There, we actually used some truly mutable
state. However, since accessing or modifying a mutable
variable is not a referential transparent operation,
such actions have to be performed within `IO`.
Other than that, nothing keeps us from using mutable
variables in our code. The necessary functionality is
available from module `Data.IORef` from the *base* library.

As a quick exercise, try to implement a function, which -
given an `IORef Nat` - pairs a value with the current
index and increases the index afterwards.

Here's how I would do this:

```idris
pairWithIndexIO : IORef Nat -> a -> IO (Nat,a)
pairWithIndexIO ref va = do
  ix <- readIORef ref
  writeIORef ref (S ix)
  pure (ix,va)
```

Note, that every time we *run* `pairWithIndexIO ref`, the
natural number stored in `ref` is incremented by one.
Also, look at the type of `pairWithIndexIO ref`: `a -> IO (Nat,a)`.
We want to apply this effectful computation to each element
in a list, which should lead to a new list wrapped in `IO`,
since all of this describes a single computation with side
effects. But this is *exactly* what function `traverse` does: Our
input type is `a`, our output type is `(Nat,a)`, our
container type is `List`, and the effect type is `IO`!

```idris
zipListWithIndexIO : IORef Nat -> List a -> IO (List (Nat,a))
zipListWithIndexIO ref = traverse (pairWithIndexIO ref)
```

Now *this* is really powerful: We could apply the same function
to *any* traversable data structure. It therefore makes
absolutely no sense to specialize `zipListWithIndexIO` to
lists only:

```idris
zipWithIndexIO : Traversable t => IORef Nat -> t a -> IO (t (Nat,a))
zipWithIndexIO ref = traverse (pairWithIndexIO ref)
```

To please our intellectual minds even more, here is the
same function in point-free style:

```idris
zipWithIndexIO' : Traversable t => IORef Nat -> t a -> IO (t (Nat,a))
zipWithIndexIO' = traverse . pairWithIndexIO
```

All that's left to do now is to initialize a new mutable variable
before passing it to `zipWithIndexIO`:

```idris
zipFromZeroIO : Traversable t => t a -> IO (t (Nat,a))
zipFromZeroIO ta = newIORef 0 >>= (`zipWithIndexIO` ta)
```

Quickly, let's give this a go at the REPL:

```repl
> :exec zipFromZeroIO {t = List} ["hello", "world"] >>= printLn
[(0, "hello"), (1, "world")]
> :exec zipFromZeroIO (Just 12) >>= printLn
Just (0, 12)
> :exec zipFromZeroIO {t = Vect 2} ["hello", "world"] >>= printLn
[(0, "hello"), (1, "world")]
```

Thus, we solved the problem of tagging each element with its
index once and for all for all traversable container types.

### The State Monad

Alas, while the solution presented above is elegant and
performs very well, it still carries its `IO` stain, which
is fine if we are already in `IO` land, but unacceptable
otherwise. We do not want to make our otherwise pure functions
much harder to test and reason about just for a simple
case of stateful element tagging.

Luckily, there is an alternative to using a mutable reference,
which allows us to keep our computations pure and
untainted. However, it is not easy to come upon this
alternative on one's own, and it can be hard to figure out
what's going on here, so I'll try to introduce this slowly.
We first need to ask ourselves what the essence of a
"stateful" but otherwise pure computation is. There
are two essential ingredients:

1. Access to the *current* state. In case of a pure
   function, this means that the function should take
   the current state as one of its arguments.
2. Ability to communicate the updated state to later
   stateful computations. In case of a pure function
   this means, that the function will return a pair
   of values: The computation's result plus the updated state.

These two prerequisites lead to the following generic
type for a pure, stateful computation operating on state
type `st` and producing values of type `a`:

```idris
Stateful : (st : Type) -> (a : Type) -> Type
Stateful st a = st -> (st, a)
```

Our use case is pairing elements with indices, which
can be implemented as a pure, stateful computation like so:

```idris
pairWithIndex' : a -> Stateful Nat (Nat,a)
pairWithIndex' v index = (S index, (index,v))
```

Note, how we at the same time increment the index, returning
the incremented value as the new state, while pairing
the first argument with the original index.

Now, here is an important thing to note: While `Stateful` is
a useful type alias, Idris in general does *not* resolve
interface implementations for function types. If we want to
write a small library of utility functions around such a type,
it is therefore best to wrap it in a single-constructor data type and
use this as our building block for writing more complex
computations. We therefore introduce record `State` as
a wrapper for pure, stateful computations:

```idris
record State st a where
  constructor ST
  runST : st -> (st,a)
```

We can now implement `pairWithIndex` in terms of `State` like so:

```idris
pairWithIndex : a -> State Nat (Nat,a)
pairWithIndex v = ST $ \index => (S index, (index, v))
```

In addition, we can define some more utility functions. Here's
one for getting the current state without modifying it
(this corresponds to `readIORef`):

```idris
get : State st st
get = ST $ \s => (s,s)
```

Here are two others, for overwriting the current state. These
corresponds to `writeIORef` and `modifyIORef`:

```idris
put : st -> State st ()
put v = ST $ \_ => (v,())

modify : (st -> st) -> State st ()
modify f = ST $ \v => (f v,())
```

Finally, we can define three functions in addition to `runST`
for running stateful computations

```idris
runState : st -> State st a -> (st, a)
runState = flip runST

evalState : st -> State st a -> a
evalState s = snd . runState s

execState : st -> State st a -> st
execState s = fst . runState s
```

All of these are useful on their own, but the real power of
`State s` comes from the observation that it is a monad.
Before you go on, please spend some time and try implementing
`Functor`, `Applicative`, and `Monad` for `State s` yourself.
Even if you don't succeed, you will have an easier time
understanding how the implementations below work.

```idris
Functor (State st) where
  map f (ST run) = ST $ \s => let (s2,va) = run s in (s2, f va)

Applicative (State st) where
  pure v = ST $ \s => (s,v)

  ST fun <*> ST val = ST $ \s =>
    let (s2, f)  = fun s
        (s3, va) = val s2
     in (s3, f va)

Monad (State st) where
  ST val >>= f = ST $ \s =>
    let (s2, va) = val s
     in runST (f va) s2
```

This may take some time to digest, so we come back to it in a
slightly advanced exercise. The most important thing to note is,
that we use every state value only ever once. We *must* make sure
that the updated state is passed to later computations, otherwise
the information about state updates is being lost. This can
best be seen in the implementation of `Applicative`: The initial
state, `s`, is used in the computation of the function value,
which will also return an updated state, `s2`, which is then
used in the computation of the function argument. This will
again return an updated state, `s3`, which is passed on to
later stateful computations together with the result of
applying `f` to `va`.

### Exercises part 2

This sections consists of two extended exercise, the aim
of which is to increase your understanding of the state monad.
In the first exercise, we will look at random value generation,
a classical application of stateful computations.
In the second exercise, we will look at an indexed version of
a state monad, which allows us to not only change the
state's value but also its *type* during computations.

1. Below is the implementation of a simple pseudo-random number
   generator. We call this a *pseudo-random* number generator,
   because the numbers look pretty random but are generated
   predictably. If we initialize a series of such computations
   with a truly random seed, most users of our library will not
   be able to predict the outcome of our computations.

   ```idris
   rnd : Bits64 -> Bits64
   rnd seed = fromInteger
            $ (437799614237992725 * cast seed) `mod` 2305843009213693951
   ```

   The idea here is that the next pseudo-random number gets
   calculated from the previous one. But once we think about
   how we can use these numbers as seeds for computing
   random values of other types, we realize that these are
   just stateful computations. We can therefore write
   down an alias for random value generators as stateful
   computations:

   ```idris
   Gen : Type -> Type
   Gen = State Bits64
   ```

   Before we begin, please note that `rnd` is not a very strong
   pseudo-random number generator. It will not generate values in
   the full 64bit range, nor is it safe to use in cryptographic
   applications. It is sufficient for our purposes in this chapter,
   however. Note also, that we could replace `rnd` with a stronger
   generator without any changes to the functions you will implement
   as part of this exercise.

   1. Implement `bits64` in terms of `rnd`. This should return
      the current state, updating it afterwards by invoking
      function `rnd`. Make sure the state is properly updated,
      otherwise this won't behave as expected.

      ```idris
      bits64 : Gen Bits64
      ```

      This will be our *only* primitive generator, from which
      we will derived all the others. Therefore,
      before you continue, quickly test your implementation of
      `bits64` at the REPL:

      ```repl
      Solutions.Traverse> runState 100 bits64
      (2274787257952781382, 100)
      ```

   2. Implement `range64` for generating random values in
      the range `[0,upper]`. Hint: Use `bits64` and `mod`
      in your implementation but make sure to deal with
      the fact that `mod x upper` produces values in the
      range `[0,upper)`.

      ```idris
      range64 : (upper : Bits64) -> Gen Bits64
      ```

      Likewise, implement `interval64` for generating values
      in the range `[min a b, max a b]`:

      ```idris
      interval64 : (a,b : Bits64) -> Gen Bits64
      ```

      Finally, implement `interval` for arbitrary integral types.

      ```idris
      interval : Num n => Cast n Bits64 => (a,b : n) -> Gen n
      ```

      Note, that `interval` will not generate all possible values in
      the given interval but only such values with a `Bits64`
      representation in the the range `[0,2305843009213693950]`.

   3. Implement a generator for random boolean values.

   4. Implement a generator for `Fin n`. You'll have to think
      carefully about getting this one to typecheck and be
      accepted by the totality checker without cheating.
      Note: Have a look at function `Data.Fin.natToFin`.

   5. Implement a generator for selecting a random element
      from a vector of values. Use the generator from
      exercise 4 in your implementation.

   6. Implement `vect` and `list`. In case of `list`, the
      first argument should be used to randomly determine the length
      of the list.

      ```idris
      vect : {n : _} -> Gen a -> Gen (Vect n a)

      list : Gen Nat -> Gen a -> Gen (List a)
      ```

      Use `vect` to implement utility function `testGen` for
      testing your generators at the REPL:

      ```idris
      testGen : Bits64 -> Gen a -> Vect 10 a
      ```

   7. Implement `choice`.

      ```idris
      choice : {n : _} -> Vect (S n) (Gen a) -> Gen a
      ```

   8. Implement `either`.

      ```idris
      either : Gen a -> Gen b -> Gen (Either a b)
      ```

   9. Implement a generator for printable ASCII characters.
      These are characters with ASCII codes in the interval
      `[32,126]`. Hint: Function `chr` from the *Prelude*
      will be useful here.

   10. Implement a generator for strings. Hint: Function `pack`
       from the *Prelude* might be useful for this.

       ```idris
       string : Gen Nat -> Gen Char -> Gen String
       ```

   11. We shouldn't forget about our ability to encode interesting
       things in the types in Idris, so, for a challenge and without
       further ado, implement `hlist` (note the distinction between
       `HListF` and `HList`). If you are rather new to dependent types,
       this might take a moment to digest, so don't forget to
       use holes.

       ```idris
       data HListF : (f : Type -> Type) -> (ts : List Type) -> Type where
         Nil  : HListF f []
         (::) : (x : f t) -> (xs : HLift f ts) -> HListF f (t :: ts)

       hlist : HListF Gen ts -> Gen (HList ts)
       ```

   12. Generalize `hlist` to work with any applicative functor, not just `Gen`.

   If you arrived here, please realize how we can now generate pseudo-random
   values for most primitives, as well as regular sum- and product types.
   Here is an example REPL session:

   ```repl
   > testGen 100 $ hlist [bool, printableAscii, interval 0 127]
   [[True, ';', 5],
    [True, '^', 39],
    [False, 'o', 106],
    [True, 'k', 127],
    [False, ' ', 11],
    [False, '~', 76],
    [True, 'M', 11],
    [False, 'P', 107],
    [True, '5', 67],
    [False, '8', 9]]
   ```

   Final remarks: Pseudo-random value generators play an important role
   in property based testing libraries like [QuickCheck](https://hackage.haskell.org/package/QuickCheck)
   or [Hedgehog](https://github.com/stefan-hoeck/idris2-hedgehog).
   The idea of property based testing is to test predefined *properties* of
   pure functions against a large number of randomly generated arguments,
   to get strong guarantees about these properties to hold for *all*
   possible arguments. One example would be a test for verifying
   that the result of reversing a list twice equals the original list.
   While it is possible to proof many of the simpler properties in Idris
   directly without the need for tests, this is no longer possible
   as soon as functions are involved, which don't reduce during unification
   such as foreign function calls or functions not publicly exported from
   other modules.

2. While `State s a` gives us a convenient way to talk about
   stateful computations, it only allows us to mutate the
   state's *value* but not its *type*. For instance, the following
   function cannot be encapsulated in `State` because the type
   of the state changes:

   ```idris
   uncons : Vect (S n) a -> (Vect n a, a)
   uncons (x :: xs) = (xs, x)
   ```

   Your task is to come up with a new state type allowing for
   such changes (sometimes referred to as an *indexed* state data type).
   The goal of this exercise is to also sharpen your skills in
   expressing things at the type level including derived function
   types and interfaces. Therefore, I will give only little
   guidance on how to go about this. If you get stuck, feel free to
   peek at the solutions but make sure to only look at the types
   at first.


   1. Come up with a parameterized data type for encapsulating
      stateful computations where the input and output state type can
      differ. It must be possible to wrap `uncons` in a value of
      this type.

   2. Implement `Functor` for your indexed state type.

   3. It is not possible to implement `Applicative` for this
      *indexed* state type (but see also exercise 2.vii).
      Still, implement the necessary functions
      to use it with idom brackets.

   4. It is not possible to implement `Monad` for this
      indexed state type. Still, implement the necessary functions
      to use it in do blocks.

   5. Generalize the functions from exercises 3 and 4 with two new
      interfaces `IxApplicative` and `IxMonad` and provide implementations
      of these for your indexed state data type.

   6. Implement functions `get`, `put`, `modify`, `runState`,
      `evalState`, and `execState` for the indexed state data type. Make
      sure to adjust the type parameters where necessary.

   7. Show that your indexed state type is strictly more powerful than
      `State` by implementing `Applicative` and `Monad` for it.

      Hint: Keep the input and output state identical. Note also,
      that you might need to implement `join` manually if Idris
      has trouble inferring the types correctly.

   Indexed state types can be useful when we want to make sure that
   stateful computations are combined in the correct sequence, or
   that scarce resources get cleaned up properly. We might get back
   to such use cases in later examples.

## The Power of Composition

After our excursion into the realms of stateful computations, we
will go back and combine mutable state with error accumulation
to tag and read CSV lines in a single traversal. We already
defined `pairWithIndex` for tagging lines with their indices.
We also have `uncurry $ hdecode ts` for decoding single tagged lines.
We can now combine the two effects in a single computation:

```idris
tagAndDecode :  (0 ts : List Type)
             -> CSVLine (HList ts)
             => String
             -> State Nat (Validated CSVError (HList ts))
tagAndDecode ts s = uncurry (hdecode ts) <$> pairWithIndex s
```

Now, as we learned before, applicative functors are closed under
composition, and the result of `tagAndDecode` is a nesting
of two applicatives: `State Nat` and `Validated CSVError`.
The *Prelude* exports a corresponding named interface implementation
(`Prelude.Applicative.Compose`), which we can use for traversing
a list of strings with `tagAndDecode`.
Remember, that we have to provide named implementations explicitly.
Since `traverse` has the applicative functor as its
second constraint, we also need to provide the first
constraint (`Traversable`) explicitly. But this
is going to be the unnamed default implementation! To get our hands on such
a value, we can use the `%search` pragma:

```idris
readTable :  (0 ts : List Type)
          -> CSVLine (HList ts)
          => List String
          -> Validated CSVError (List $ HList ts)
readTable ts = evalState 1 . traverse @{%search} @{Compose} (tagAndDecode ts)
```

This tells Idris to use the default implementation for the
`Traversable` constraint, and `Prelude.Applicatie.Compose` for the
`Applicative` constraint.
While this syntax is not very nice, it doesn't come up too often, and
if it does, we can improve things by providing custom functions
for better readability:

```idris
traverseComp : Traversable t
             => Applicative f
             => Applicative g
             => (a -> f (g b))
             -> t a
             -> f (g (t b))
traverseComp = traverse @{%search} @{Compose}

readTable' :  (0 ts : List Type)
           -> CSVLine (HList ts)
           => List String
           -> Validated CSVError (List $ HList ts)
readTable' ts = evalState 1 . traverseComp (tagAndDecode ts)
```

Note, how this allows us to combine two computational effects
(mutable state and error accumulation) in a single list traversal.

But I am not yet done demonstrating the power of composition. As you showed
in one of the exercises, `Traversable` is also closed under composition,
so a nesting of traversables is again a traversable. Consider the following
use case: When reading a CSV file, we'd like to allow lines to be
annotated with additional information. Such annotations could be
mere comments but also some formatting instructions or other
custom data tags might be feasible.
Annotations are supposed to be separated from the rest of the
content by a single hash character (`#`).
We want to keep track of these optional annotations
so we come up with a custom data type encapsulating
this distinction:

```idris
data Line : Type -> Type where
  Annotated : String -> a -> Line a
  Clean     : a -> Line a
```

This is just another container type and we can
easily implement `Traversable` for `Line` (do this yourself as
a quick exercise):

```idris
Functor Line where
  map f (Annotated s x) = Annotated s $ f x
  map f (Clean x)       = Clean $ f x

Foldable Line where
  foldr f acc (Annotated _ x) = f x acc
  foldr f acc (Clean x)       = f x acc

Traversable Line where
  traverse f (Annotated s x) = Annotated s <$> f x
  traverse f (Clean x)       = Clean <$> f x
```

Below is a function for parsing a line and putting it in its
correct category. For simplicity, we just split the line on hashes:
If the result consists of exactly two strings, we treat the second
part as an annotation, otherwise we treat the whole line as untagged
CSV content.

```idris
readLine : String -> Line String
readLine s = case split ('#' ==) s of
  h ::: [t] => Annotated t h
  _         => Clean s
```

We are now going to implement a function for reading whole
CSV tables, keeping track of line annotations:

```idris
readCSV :  (0 ts : List Type)
        -> CSVLine (HList ts)
        => String
        -> Validated CSVError (List $ Line $ HList ts)
readCSV ts = evalState 1
           . traverse @{Compose} @{Compose} (tagAndDecode ts)
           . map readLine
           . lines
```

Let's digest this monstrosity. This is written in point-free
style, so we have to read it from end to beginning. First, we
split the whole string at line breaks, getting a list of strings
(function `Data.String.lines`). Next, we analyze each line,
keeping track of optional annotations (`map readLine`).
This gives us a value of type `List (Line String)`. Since
this is a nesting of traversables, we invoke `traverse`
with a named instance from the *Prelude*: `Prelude.Traversable.Compose`.
Idris can disambiguate this based on the types, so we can
drop the namespace prefix. But the effectful computation
we run over the list of lines results in a composition
of applicative functors, so we also need the named implementation
for compositions of applicatives in the second
constraint (again without need of an explicit
prefix, which would be `Prelude.Applicative` here).
Finally, we evaluate the stateful computation with `evalState 1`.

Honestly, I wrote all of this without verifying if it works,
so let's give it a go at the REPL. I'll provide two
example strings for this, a valid one without errors, and
an invalid one. I use *multiline string literals* here, about which
I'll talk in more detail in a later chapter. For the moment,
note that these allow us to conveniently enter string literals
with line breaks:

```idris
validInput : String
validInput = """
  f,12,-13.01#this is a comment
  t,100,0.0017
  t,1,100.8#color: red
  f,255,0.0
  f,24,1.12e17
  """

invalidInput : String
invalidInput = """
  o,12,-13.01#another comment
  t,100,0.0017
  t,1,abc
  f,256,0.0
  f,24,1.12e17
  """
```

And here's how it goes at the REPL:

```repl
Tutorial.Traverse> readCSV [Bool,Bits8,Double] validInput
Valid [Annotated "this is a comment" [False, 12, -13.01],
       Clean [True, 100, 0.0017],
       Annotated "color: red" [True, 1, 100.8],
       Clean [False, 255, 0.0],
       Clean [False, 24, 1.12e17]]

Tutorial.Traverse> readCSV [Bool,Bits8,Double] invalidInput
Invalid (Append (FieldError 1 1 "o")
  (Append (FieldError 3 3 "abc") (FieldError 4 2 "256")))
```

It is pretty amazing how we wrote dozens of lines of
code, always being guided by the type- and totality
checkers, arriving eventually at a function for parsing
properly typed CSV tables with automatic line numbering and
error accumulation, all of which just worked on first try.

### Exercises part 3

The *Prelude* provides three additional interfaces for
container types parameterized over *two* type parameters
such as `Either` or `Pair`: `Bifunctor`, `Bifoldable`,
and `Bitraversable`. In the following exercises we get
some hands-one experience working with these. You are
supposed to look up what functions they provide
and how to implement and use them yourself.

1. Assume we'd like to not only interpret CSV content
   but also the optional comment tags in our CSV files.
   For this, we could use a data type such as `Tagged`:

   ```idris
   data Tagged : (tag, value : Type) -> Type where
     Tag  : tag -> value -> Tagged tag value
     Pure : value -> Tagged tag value
   ```

   Implement interfaces `Functor`, `Foldable`, and `Traversable`
   but also `Bifunctor`, `Bifoldable`, and `Bitraversable`
   for `Tagged`.

2. Show that the composition of a bifunctor with two functors
   such as `Either (List a) (Maybe b)` is again a bifunctor
   by defining a dedicated wrapper type for such compositions
   and writing a corresponding implementation of `Bifunctor`.
   Likewise for `Bifoldable`/`Foldable` and `Bitraversable`/`Traversable`.

3. Show that the composition of a functor with a bifunctor
   such as `List (Either a b)` is again a bifunctor
   by defining a dedicated wrapper type for such compositions
   and writing a corresponding implementation of `Bifunctor`.
   Likewise for `Bifoldable`/`Foldable` and `Bitraversable`/`Traversable`.

4. We are now going to adjust `readCSV` in such a way that it
   decodes comment tags and CSV content in a single traversal.
   We need a new error type to include invalid tags for this:

   ```idris
   data TagError : Type where
     CE         : CSVError -> TagError
     InvalidTag : (line : Nat) -> (tag : String) -> TagError
     Append     : TagError -> TagError -> TagError

   Semigroup TagError where (<+>) = Append
   ```

   For testing, we also define a simple data type for color tags:

   ```idris
   data Color = Red | Green | Blue
   ```

   You should now implement the following functions, but
   please note that while `readColor` will need to
   access the current line number in case of an error,
   it must *not* increase it, as otherwise line numbers
   will be wrong in the invocation of `tagAndDecodeTE`.

   ```idris
   readColor : String -> State Nat (Validated TagError Color)

   readTaggedLine : String -> Tagged String String

   tagAndDecodeTE :  (0 ts : List Type)
                  -> CSVLine (HList ts)
                  => String
                  -> State Nat (Validated TagError (HList ts))
   ```

   Finally, implement `readTagged` by using the wrapper type
   from exercise 3 as well as `readColor` and `tagAndDecodeTE`
   in a call to `bitraverse`.
   The implementation will look very similar to `readCSV` but
   with some additional wrapping and unwrapping at the right
   places.

   ```idris
   readTagged :  (0 ts : List Type)
              -> CSVLine (HList ts)
              => String
              -> Validated TagError (List $ Tagged Color $ HList ts)
   ```

   Test your implementation with some example strings at the REPL.


You can find more examples for functor/bifunctor compositions
in Haskell's [bifunctors](https://hackage.haskell.org/package/bifunctors)
package.

## Conclusion

Interface `Traversable` and its main function `traverse` are incredibly
powerful forms of abstraction - even more so, because both `Applicative`
and `Traversable` are closed under composition. If you are interested
in additional use cases, the publication, which
introduced `Traversable` to Haskell, is a highly recommended read:
[The Essence of the Iterator Pattern](https://www.cs.ox.ac.uk/jeremy.gibbons/publications/iterator.pdf)

The *base* library provides an extended version of the
state monad in module `Control.Monad.State`. We will look
at this in more detail when we talk about monad transformers.
Please note also, that `IO` itself is implemented as a
[simple state monad](IO.md#how-io-is-implemented)
over an abstract, primitive state type: `%World`.

Here's a short summary of what we learned in this chapter:

* Function `traverse` is used to run effectful computations
  over container types without affecting their size or shape.
* We can use `IORef` as mutable references in stateful
  computations running in `IO`.
* For referentially transparent computations with "mutable"
  state, the `State` monad is extremely useful.
* Applicative functors are closed under composition,
  so we can run several effectful computations in a single
  traversal.
* Traversables are also closed under composition, so we can
  use `traverse` to operate on a nesting of containers.

For now, this concludes our introduction of the *Prelude*'s
higher-kinded interfaces, which started with the introduction of
`Functor`, `Applicative`, and `Monad`, before moving on to `Foldable`,
and - last but definitely not least - `Traversable`.
There's one still missing - `Alternative` - but this will
have to wait a bit longer, because we need to first make
our brains smoke with some more type-level wizardry.

<!-- vi: filetype=idris2
-->
