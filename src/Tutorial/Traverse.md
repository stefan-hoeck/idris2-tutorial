# Effectful Traversals

In this chapter, we are going to bring our treatment
of the higher-kinded interfaces in the *Prelude* to an
end. In order to do so, we will continue developing the
CSV reader we started implementing in chapter
[Functor and Friends](Functor.md). I moved some of
the data types and interfaces from that chapter to
their own modules, so we can reimport them here without
the need to start from scratch.

Note, that unlike our original CSV-reader, we will use
`Validated` instead of `Either`, since this will allow
us to accumulate all errors when reading a CSV file.

```idris
module Tutorial.Traverse

import Data.Bits
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
in a CSV-file and decode it to a heterogeneous list.
As a reminder, here is how to use `hdecode` at the REPL:

```repl
Tutorial.Traverse> hdecode [Bool,String,Bits8] 1 "f,foo,12"
Valid [False, "foo", 12]
```

The next step will be to parse a whole CSV-table, represented
as a list of string, where each string corresponds to a line.
We will go about this stepwise as there are several aspects
to handle this properly. What we are looking for - eventually -
is a function of the following type (we are going to
implement several version of this function, hence the
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
wrapped in a `Validated CSVError`. The first step when abstracting
this should be to use generic types for the input and output:
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
as our effect type instead of `Validated CSVError`.
So, the next step should be to abstract over the *effect type*.
We note, that we used applicative syntax (idiom brackets and
`pure`) in our implementation, so we will need to write
an constrained function with an `Applicative` constraint
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

Let's give this a go at the REPL:

```repl
Tutorial.Traverse> hreadTable3 [Bool,Bits8] ["f,12","t,0"]
Valid [[False, 12], [True, 0]]
Tutorial.Traverse> hreadTable3 [Bool,Bits8] ["f,12","t,1000"]
Invalid (FieldError 0 2 "1000")
Tutorial.Traverse> hreadTable3 [Bool,Bits8] ["1,12","t,1000"]
Invalid (Append (FieldError 0 1 "1") (FieldError 0 2 "1000"))
```

This already work very well, but note how our error messages do
not yet print the correct line numbers. That's not surprising,
as we are using a dummy constant in our call to `hdecode`.
We will look at how we can come up with the line numbers on the
fly when we talk about stateful computations later in this chapters.
For now, we could just manually annotate lines with numbers:

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
`id`, which can be very useful when working with higher-order
functions.

While not perfect, this version at least allows us to verify at the REPL
that the line numbers are passed on to the error messages correctly:

```repl
Tutorial.Traverse> hreadTable4 [Bool,Bits8] [(1,"t,1000"),(2,"1,100")]
Invalid (Append (FieldError 1 2 "1000") (FieldError 2 1 "1"))
```

### Interface Traversable

Now, here is an interesting observation: We can implement a function
like `traverseList` for other container types. You might think that's
obvious, given that we can convert container types to lists via
function `toList` from interface `Foldable`. However, while going
via `List` might be feasible in some occasion, it is undesirable in
general, as we loose typing information. For instance, here
is such a function for `Vect`:

```idris
traverseVect' : Applicative f => (a -> f b) -> Vect n a -> f (List b)
traverseVect' fun = traverseList fun . toList
```

Note how we lost the information about the structure of the
original container type. What we are looking for is a function
like `traverseVect'`, keeping this information: The result should
be a vector of the same length as the input:

```idris
traverseVect : Applicative f => (a -> f b) -> Vect n a -> f (Vect n b)
traverseVect _   []        = pure []
traverseVect fun (x :: xs) = [| fun x :: traverseVect fun xs |]
```

That's much better! And as I wrote above, we can easily get the same
for other container types like `List1`, `SnocList`, `Maybe`, and so on.
As usual, some derived functions follow immediately from these.
For instance:

```idris
sequenceList : Applicative f => List (f a) -> f (List a)
sequenceList = traverseList id
```

All of this calls for a new interface, which is called
`Traversable` and exported from the *Prelude*. Here is
its definitions (with primes for disambiguation):

```idris
interface Functor t => Foldable t => Traversable' t where
  traverse' : Applicative f => (a -> f b) -> t a -> f (t b)
```

Function `traverse` is one of the most abstract and versatile
functions available from the *Prelude*. Just how powerful
it is, will only become clear once you start using it
over and over again in your code. However, it will be the
goal of the remainder of this chapter to show you several
diverse and interesting use cases.

For now, we will quickly focus on the degree of abstraction.
Function `traverse` is parameterized over no less than
four parameters: The container type `t` (`List`, `Vect n`,
`Maybe`, to just name a few), the effect type (`Validated e`,
`IO`, `Maybe`, and so on), the input element type `a`, and
the output element type `b`.

### Traversable Laws

TODO

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

3. To get some routine, implement `Traversable'` for
   `List1`, `Either e`, and Maybe`.

4. Implement `Traversable` for `List01 ne`:

   ```idris
   data List01 : (nonEmpty : Bool) -> Type -> Type where
     Nil  : List01 False a
     (::) : a -> List01 False a -> List01 ne a
   ```

5. Implement `Traversable` for rose trees:

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

8. Like `Applicative` and `Foldable`, `Traversable` is closed under
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
we might want to do the same things with trees, vectors,
non-empty lists and so on. And again, we are interested
in whether there is some form of abstraction we are
looking at.

### `IORef`

Let us for a moment think about how we'd do such a thing
in an imperative language. There, we'd probably define
a local (mutable) variable to keep track of the current
index, which is increased while iterating over the list
in a `for`- or `while`-loop.

In Idris, there is no such thing as mutable state.
Or is there? Remember, how we used a mutable reference
to simulate a data base connection in an earlier
exercise. There, we actually used some truly mutable
state. However, since accessing or modifying a mutable
variable is not a referential transparent operation,
such actions have to performed within `IO`.

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

Now, look at the type of `pairWithIndexIO ref`: `a -> IO (Nat,a)`.
We want to apply this effectful computation to each element
in a list, which will lead to a new list wrapped in `IO`,
since all of this is describes a computation with side
effects.

But this is *exactly* what function `traverse` does: Our
input type is `a`, our output type is `(Nat,a)`, our
container type is `List`, and the effect type is `IO`!

```idris
zipListWithIndexIO : IORef Nat -> List a -> IO (List (Nat,a))
zipListWithIndexIO ref = traverse (pairWithIndexIO ref)
```

Now *this* is really powerful: We could apply the same function
to *any* traversable data structure. It therefore makes
absolutely no sense to specialize `zipWithIndexIO` to
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

So, we solved the problem of tagging each element with its
index once and for all for all container types.

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
alternative on its own, and it can be hard to figure out
what's going on here, so I'll try to introduce this slowly.

We first need to ask ourselves what the essence of a
"stateful" but otherwise pure computation is. There
are two essential ingredients:

1. Access to the *current* state. In case of a pure
   function this means, that the function should take
   the current state as one of its arguments.
2. Ability to communicate the updated state to other
   stateful computations. In case of a pure function
   this means, that the function will return two
   values wrapped in a pair: The computation's result
   plus the updated state.

These two prerequisites lead to the following generic
type for a stateful computation operating on state
type `state` and producing values of type `a`:

```idris
Stateful : (state : Type) -> (a : Type) -> Type
Stateful state a = state -> (state, a)
```

In case of our use case of pairing elements with indices,
we can then arrive at the following pure (but stateful)
computation:

```idris
pairWithIndex' : a -> Stateful Nat (Nat,a)
pairWithIndex' v index = (S index, (index,v))
```

Note how we at the same time increment the index, returning
the incremented value as the new state, while pairing
the first argument with the current index.

Now, here is an important thing to note: While `Stateful` is
a useful type alias, Idris is not very good at resolving
interface implementations for function types. If we want to
write a small library of utility functions around such a type,
it is best to wrap it in single-constructor data type and
use this as our building block for writing more complex
computations. We therefore introduce record `State` as
a wrapper for pure, stateful computations:

```idris
record State state a where
  constructor ST
  runST : state -> (state,a)
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
get : State state state
get = ST $ \s => (s,s)
```

Here are two others, for overwriting the current state. These
corresponds to `writeIORef` and `modifyIORef`:

```idris
put : state -> State state ()
put v = ST $ \_ => (v,())

modify : (state -> state) -> State state ()
modify f = ST $ \v => (f v,())
```

Finally, we can define three functions in addition to `runST`
for running stateful computations

```idris
runState : state -> State state a -> (state, a)
runState = flip runST

evalState : state -> State state a -> a
evalState s = snd . runState s

execState : state -> State state a -> state
execState s = fst . runState s
```

All of these are useful on their own, but the real power of
`State s` comes from the observation that it is a monad.
Before you go on, please spend some time and try implementing
`Functor`, `Applicative`, and `Monad` for `State s` yourself.
Even if you don't succeed, you will have an easier time
understanding how the implementations below work.

```idris
Functor (State state) where
  map f (ST run) = ST $ \s => let (s2,va) = run s in (s2, f va)

Applicative (State state) where
  pure v = ST $ \s => (s,v)
  ST fun <*> ST val = ST $ \s =>
    let (s2, f)  = fun s
        (s3, va) = val s2
     in (s3, f va)

Monad (State state) where
  ST val >>= f = ST $ \s =>
    let (s2, va) = val s
     in runST (f va) s2
```

This may take some time to digest, so we come back to it in a
slightly advanced exercise. The most important thing to note is,
that we use every state value only ever once. We *must* make sure
that the updated state is passed to later computations, otherwise
the information about state updates is getting lost. This can
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
   rnd seed = (437799614237992725 * seed) `mod` 2305843009213693951
   ```

   The idea here is that the next pseudo-random number gets
   calculated from the last one. But once we think about
   how we can use these numbers as seeds for computing
   random values of other types, we realize that these are
   just stateful computations. We can therefore write
   down a type alias for random value generators and
   implement a primitive generator for 64-bit unsigned
   integers:

   ```idris
   Gen : Type -> Type
   Gen = State Bits64
   ```

   Before we begin, please note that `rnd` is not the strongest
   pseudo-random number generator. It will not generate values in
   the full 64bit range, nor is it safe to use in cryptographic
   applications. It is sufficient for our purposes in this chapter,
   however. Note also, that we could replace `rnd` with a stronger
   generator without any changes to the functions you will implement
   as part of this exercise.

   1. Implement `bits64` in terms of `rnd`. Make sure
      the state is properly updated, otherwise this won't behave
      as expected.

      ```idris
      bits64 : Gen Bits64
      ```

   2. Implement `range64` for generating random values in
      the range `[0,upper]`. Hint: Use `mod` in your implementation.

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
      the given interval but only such values with a representation
      in the the range `[0,18446744073709551615]`.

   3. Implement a generator for random boolean values.

   4. Implement a generator for `Fin n`. You'll have to think
      carefully about getting this one to typecheck and be
      accepted by the totality checker without cheating.

   5. Implement a generator for selecting a random element
      from a vector of values. Use the generator from
      exercise 4 in your implementation.

   6. Implement `vect` and `list`. In case of `list`, the
      first argument is used to randomly determine the length
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
      `[32,126]`. Hint: Use `chr` in your implementation.

   10. Implement a generator for strings. Hint: Use `pack`
       in your implementation.

       ```idris
       string : Gen Nat -> Gen Char -> Gen String
       ```

   11. We shouldn't forget about our ability to encode interesting
       things in the types in Idris, so, for a challenge,
       implement `hlist`:

       ```idris
       data HListF : (f : Type -> Type) -> (ts : List Type) -> Type where
         Nil  : HListF f []
         (::) : (x : f t) -> (xs : HLift f ts) -> HListF f (t :: ts)

       hlist : HListF f ts -> Gen (HList ts)
       ```

   12. Generalize `hlist` to work for any applicative functor, not just `Gen`.

   If you arrived here, please realize how we can generate pseudo-random
   values for most primitives, as well as regular sum- and product types.
   Here is an example REPL session:

   ```repl
   > testGen 100 $ hlist [bool, printableAscii, interval 0 127]
   [[True, '+', 113],
    [True, '!', 73],
    [False, '6', 18],
    [False, 't', 53],
    [True, 'Q', 117],
    [True, 'k', 74],
    [False, 'z', 64],
    [False, '[', 125],
    [False, '0', 70],
    [False, 'o', 78]]
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
   such as foreign function call or functions not publicly exported from
   other modules.

2. While `State s a` gives us a convenient way to talk about
   stateful computations, it only allows us to mutate the
   state's *value* but not its *type". For instance, the following
   function cannot be encapsulated in `State` because the type
   of the state changes:

   ```idris
   uncons : Vect (S n) a -> (Vect n a, a)
   ```

   Your task is to come up with a new state type allowing for
   such changes (sometimes referred to as an *indexed* state).
   The goal of this exercise is to also sharpen your skills in
   expressing things at the type level and derive function
   types and interfaces from there. Therefore, I give only little
   guidance how to go about this. If you get stuck, feel free to
   peek at the solutions but make sure to only look at the types
   at first.


   1. Come up with a parameterized data type for encapsulating
      stateful computations where the input and output state type can
      differ.

   2. Implement `Functor` for your state type.

   3. It is not possible to implement `Applicative` for this
      *indexed* state type (but see also exercise 2.1).
      Still, implement the necessary functions
      to use it with idom brackets.

   4. It is not possible to implement `Monad` for this
      indexed state type. Still, implement the necessary functions
      to use it in do blocks.

   5. Generalize the functions from exercises 3 and 4 in two new
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
   to these in later examples.

## The Power of Composition

After our excursion into the realms of stateful computations, we
will go back and combine mutable state with error accumulation
to tag and read CSV lines in a single traversal. We already
defined `pairWithIndex` for tagging lines with their indices.
We also have `uncurry $ hdecode ts` for decoding a single line.
We can combine the two effects in a single funcion:

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
(`Prelude.Applicative.Compose`), which we can use for this.
Remember, that we have to provide named implementations explicitly.
Since the type of `traverse` has the applicative functor as its
second implicit argument, we also need to provide the first
argument (the `Traversable` implementation) explicitly. But this
is an unnamed default implementation! To get our hands on such
a value, we can use the `%search` pragma:

```idris
readTable :  (0 ts : List Type)
          -> CSVLine (HList ts)
          => List String
          -> Validated CSVError (List $ HList ts)
readTable ts = evalState 1 . traverse @{%search} @{Compose} (tagAndDecode ts)
```

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

But I am not done yet demonstrating the power of composition. As you showed
in one of the exercises, `Traversable` is also closed under composition,
so a nesting of traversables is again a traversable. Consider the following
use case: When reading a CSV file, we'd like to allow lines to be
annotated with additional information. Such annotations could be
mere commets but also some formating instructions or other
custom data. Annotations are supposed to be separated from the rest of the
content by a hash (`#`).
We want to keep track of these optional annotations
so we come up with a new data type encapsulating this distinction:

```idris
data Line : Type -> Type where
  Annotated : String -> a -> Line a
  Content   : a -> Line a
```

This is just another container type and we can
easily implement `Traversable` for `Line` (do this yourself as
a quick exercise):

```idris
Functor Line where
  map f (Annotated s x) = Annotated s $ f x
  map f (Content x)     = Content $ f x

Foldable Line where
  foldr f acc (Annotated _ x) = f x acc
  foldr f acc (Content x)     = f x acc

Traversable Line where
  traverse f (Annotated s x) = Annotated s <$> f x
  traverse f (Content x)     = Content <$> f x
```

Below is a function for parsing a line and putting it in its
correct category. For simplicity, we just split the line on hashes:
If the result consists of exactly two strings, we treat the second
part as an annotation, otherwise we treat the whole line as CSV content.

```idris
readLine : String -> Line String
readLine s = case split ('#' ==) s of
  h ::: [t] => Annotated t h
  _         => Content s
```

We are now going to implement a function for reading whole
CSV tables, keeping track line annotations:

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
style, so we have to read it from right to left. First, we
split the whole string at line breaks, getting a list of strings
(function `Data.String.lines`). Next, we analyze each line,
keeping track of the presence of annotations (`map readLine`).
This gives us a value of type `List (Line String)`. Since
this is a nesting of traversables, we invoke `traverse`
with a named instance from the *Prelude*: `Prelude.Traversable.Compose`.
Idris can disambiguate this based on the types, so we can
drop the namespace prefix. But the effectful computation
we run over the list of lines results in a composition
of applicative functors, so we also need a named implementation for
the second constraint (again without need of an explicit
prefix, which would be `Prelude.Applicative` in this case).
Finally, we evaluate the stateful computation with `evalState 1`.

Honestly, I wrote all of this without verifying if it works,
so let's give it a go at the REPL. I'll provide two
example strings for this, a valid one without errors, and
an invalid one. I use *raw string literals* here, about which
I'll talk about in more detail in a later chapter. For the moment,
note that this allows us to conveniently enter strings literals
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
       Content [True, 100, 0.0017],
       Annotated "color: red" [True, 1, 100.8],
       Content [False, 255, 0.0],
       Content [False, 24, 1.12e17]]

Tutorial.Traverse> readCSV [Bool,Bits8,Double] invalidInput
Invalid (Append (FieldError 1 1 "o")
  (Append (FieldError 3 3 "abc") (FieldError 4 2 "256")))
```

## Conclusion

Interface `Traversable` and its main function `traverse` are incredibly
powerful forms of abstraction - even more so, because both `Applicative`
and `Traversable` are closed under composition. If you are interested
in additional use cases, I can highly recommend the publication, which
introduced `Traversable` to Haskell:
[The Essence of the Iterator Pattern](https://www.cs.ox.ac.uk/jeremy.gibbons/publications/iterator.pdf)

For now, this concludes our introduction of the *Prelude*'s
higher-kinded interfaces, which started with the introduction of
`Functor`, `Applicative`, and `Monad`, before moving on to `Foldable`,
and - last but definitely not least - `Traversable`.
For completeness, we might look at a few others, which come
up less often, in a later chapter. But first, we need to make
our brains smoke with some more type-level wizardry.

<!-- vi: filetype=idris2
-->
