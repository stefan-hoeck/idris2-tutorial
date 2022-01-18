# Functor and Friends

Programming, like mathematics, is about abstraction. We
try to model parts of the real world, reusing reoccurring
patterns by abstracting over them.

In this chapter, we will learn about several related interfaces,
which are all about abstraction, and thus can be hard to
understand in the beginning. Especially figuring out
*why* they are useful and *when* to use them will take
time and experience. This chapter therefore comes
with tons of exercises, most of which can be solved
with less than three short lines of code. Don't skip them.
Come back to them several times until these things start
feeling natural to you. You will then realize that their
initial complexity has vanished.

```idris
module Tutorial.Functor

import Data.List1
import Data.String

%default total
```

## Functor

What do type constructors like `List`, `List1`, `Maybe`, or
`IO` have in common? First, all of them are of type
`Type -> Type`. Second, they all put values of a given type
in a certain *context*. With `List`,
the *context* is *non-determinism*: We know there to
be zero or more values, but we don't know the exact number
until we start taking the list apart by pattern matching
on it. Likewise for `List1`, though we know for sure that
there is at least one value. For `Maybe`, we are still not
sure about how many values there are, but the possibilities
are much smaller: Zero or one. With `IO`, the context is a different one:
Arbitrary side effects.

Although the type constructors discussed above are quite
different in how they behave and when they are useful,
there are certain operations that keep coming up
when working with them. The first such operation
is *mapping a pure function over the data type, without
affecting its underlying structure*.

For instance, given a list of numbers, we'd like to multiply
each number by two, without changing their order or removing
any values:

```idris
multBy2List : Num a => List a -> List a
multBy2List []        = []
multBy2List (x :: xs) = 2 * x :: multBy2List xs
```

But we might just as well convert every string in a
list of strings to upper case characters:

```idris
toUpperList : List String -> List String
toUpperList []        = []
toUpperList (x :: xs) = toUpper x :: toUpperList xs
```

Sometimes, the type of the stored value changes. In the
next example, we calculate the lengths of the strings stored
in a list:

```idris
toLengthList : List String -> List Nat
toLengthList []        = []
toLengthList (x :: xs) = length x :: toLengthList xs
```

I'd like you appreciate, just how boring these functions are. They
are almost identical, with the only interesting part being
the function we apply to each element. Surely, there must be
pattern to abstract over:

```idris
mapList : (a -> b) -> List a -> List b
mapList f []        = []
mapList f (x :: xs) = f x :: mapList f xs
```

This is often the first step of abstraction in functional
programming: Write a (possibly generic) higher-order function.
We can now concisely implement all examples shown above in
terms of `mapList`:

```idris
multBy2List' : Num a => List a -> List a
multBy2List' = mapList (2 *)

toUpperList' : List String -> List String
toUpperList' = mapList toUpper

toLengthList' : List String -> List Nat
toLengthList' = mapList length
```

But surely we'd like to do the same kind of thing with
`List1` and `Maybe`! After all, they are just container
types like `List`, the only difference being some detail
about the number of values they can or can't hold:

```idris
mapMaybe : (a -> b) -> Maybe a -> Maybe b
mapMaybe f Nothing  = Nothing
mapMaybe f (Just v) = Just (f v)
```

Even with `IO`, we'd like to be able to map pure functions
over effectful computations. The implementation is
a bit more involved, due to the nested layers of
data constructors, but if in doubt, the types will surely
guide us. Note, however, that `IO` is not publicly exported,
so its data constructor is unavailable to us. We can use
functions `toPrim` and `fromPrim`, however, for converting
`IO` from and to `PrimIO`, which we can freely dissect:

```idris
mapIO : (a -> b) -> IO a -> IO b
mapIO f io = fromPrim $ mapPrimIO (toPrim io)
  where mapPrimIO : PrimIO a -> PrimIO b
        mapPrimIO prim w =
          let MkIORes va w2 = prim w
           in MkIORes (f va) w2
```

From the concept of *mapping a pure function over
values in a context* follow some derived functions, which are
often useful. Here they are some of them for `IO`:

```idris
mapConstIO : b -> IO a -> IO b
mapConstIO = mapIO . const

forgetIO : IO a -> IO ()
forgetIO = mapConstIO ()
```

Of course, we'd want to implement `mapConst` and `forget` as well
for `List`, `List1`, and `Maybe` (and dozens of other type
constructors with some kind of mapping function), and they'd
all look the same and be equally boring.

When we come upon a recurring class of functions with
several useful derived functions, we should consider defining
an interface. But how should we go about this here?
When you look at the types of `mapList`, `mapMaybe`, and `mapIO`,
you'll see that it's the `List`, `List1`, and `IO` types we
need to get rid of. These are not of type `Type` but of type
`Type -> Type`. Luckily, there is nothing preventing us
from parametrizing an interface over something else than
a `Type`.

The interface we are looking for is called `Functor`.
Here is its definition and an example implementation (I appended
a tick at the end of the names for them not to overlap with
the interface and functions exported by the *Prelude*):

```idris
interface Functor' (0 f : Type -> Type) where
  map' : (a -> b) -> f a -> f b

implementation Functor' Maybe where
  map' _ Nothing  = Nothing
  map' f (Just v) = Just $ f v
```

Note, that we had to give the type of parameter `f` explicitly,
and in that case it needs to be annotated with quantity zero if
you want it to be erased at runtime (which you almost always want).

Now, reading type signatures consisting only of type parameters
like the one of `map'` can take some time to get used to, especially
when some type parameters are applied to other parameters as in
`f a`. It can be very helpful to inspect these signatures together
with all implicit arguments at the REPL:

```repl
Tutorial.Functor> :ti map'
Tutorial.Functor.map' : {0 b : Type} -> {0 a : Type} -> {0 f : Type -> Type} -> Functor' f => (a -> b) -> f a -> f b
```

### Derived Functions

There are several functions and operators directly derivable from interface 
`Functor`. Eventually, you should know and remember all of them as
they are highly useful. Here they are together with their types:

```repl
Tutorial.Functor> :t (<$>)
Prelude.<$> : Functor f => (a -> b) -> f a -> f b

Tutorial.Functor> :t (<&>)
Prelude.<&> : Functor f => f a -> (a -> b) -> f b

Tutorial.Functor> :t ($>)
Prelude.$> : Functor f => f a -> b -> f b

Tutorial.Functor> :t (<$)
Prelude.<$ : Functor f => b -> f a -> f b

Tutorial.Functor> :t ignore
Prelude.ignore : Functor f => f a -> f ()
```

`(<$>)` is an operator alias for `map` and allows you to sometimes
drop some parentheses. For instance:

```idris
tailShowReverse : Show a => List1 a -> List String
tailShowReverse xs = reverse . show <$> tail xs

tailShowReversNoOp : Show a => List1 a -> List String
tailShowReversNoOp xs = map (reverse . show) (tail xs)
```

`(<&>)` is an alias for `(<$>)` with the arguments flipped.
The other three (`ignore`, `($>)`, and `(<$)`) all are used
to map a constant over a data structure. They are often useful
when you don't care about the values stored in a context but
what to keep the underlying structure.

### Functors with more than one Type Parameter

The type constructors we looked at so far where all
of type `Type -> Type`. However, we can also implement `Functor`
for other type constructors. The only prerequisite is that
the type parameter we'd like to change with function `map` must
be the last in the argument list. For instance, here is the
`Functor` implementation for `Either e`:

```idris
implementation Functor' (Either e) where
  map' _ (Left ve)  = Left ve
  map' f (Right va) = Right $ f va
```

Here is another example, this time for a type constructor of
type `Bool -> Type -> Type`:

```idris
data List01 : (nonEmpty : Bool) -> Type -> Type where
  Nil  : List01 False a
  (::) : a -> List01 False a -> List01 ne a

implementation Functor (List01 ne) where
  map _ []        = []
  map f (x :: xs) = f x :: map f xs
```

### Functor Composition

The nice thing about `Functor`s is how they can be paired and
nested with other functors and the results are functors again:

```idris
record Product (f,g : Type -> Type) (a : Type) where
  constructor MkProduct
  pair  : (f a, g a)

implementation Functor f => Functor g => Functor (Product f g) where
  map f (MkProduct (l, r)) = MkProduct (map f l, map f r)
```

The above allows us to conveniently map over a pair of functors. Note,
however, that Idris needs some help with inferring the types involved:

```idris
productExample :  Show a
               => (Either e a, List a)
               -> (Either e String, List String)
productExample = pair . map show . MkProduct {f = Either e, g = List}
```

More often, we'd like to map over several layers of nested functors
at once. Here's how to do this with an example:

```idris
record Comp (f,g : Type -> Type) (a : Type) where
  constructor MkComp
  unComp  : f (g a)

implementation Functor f => Functor g => Functor (Comp f g) where
  map f (MkComp v) = MkComp $ map f <$> v

compExample :  Show a => List (Either e a) -> List (Either e String)
compExample = unComp . map show . MkComp {f = List, g = Either e}
```

#### Named Implementations

Sometimes, there are more ways to implement an interface for
a given type. For instance, for numeric types we can have
a `Monoid` representing addition and one representing multiplication.
Likewise, for nested functors, `map` can be interpreted as a mapping
over only the first layer of values, or a mapping over several layers
of values.

One way to go about this is to define single-field wrappers as
shown with data type `Comp` above. However, Idris also allows us
to define additional interface implementations, which must then
be given a name. For instance:

```idris
[Compose'] Functor f => Functor g => Functor (f . g) where
  map f = (map . map) f
```

Note, that this defines a new implementation of `Functor`, which will
*not* be considered during implicit search to avoid ambiguities. However,
it is possible to explicitly choose to use this implementation
by passing it as an explicit argument to `map`, prefixed with an `@`:

```idris
compExample2 :  Show a => List (Either e a) -> List (Either e String)
compExample2 = map @{Compose} show
```

In the example above, we used `Compose` instead of `Compose'`, since
the former is already exported by the *Prelude*.

### Functor Laws

Implementations of `Functor` are supposed to follow certain laws,
just like implementations of `Eq` or `Ord`. Again, these laws are
not verified by Idris, although it would be possible (and
often cumbersome) to so.

1. `map id = id`: Mapping the identity function over a functor
    must not have any visible effect like changing a container's
    structure or affecting the side effects perfomed when
    running an `IO` action.

2. `map (f . g) = map f . map g`: Sequencing two mappings must be identical
   to a single mapping using the composition of the two functions.

### Exercises

1. Write your own implementations of `Functor'` for `Maybe`, `List`,
   `List1`, `Vect n`, `Either e`, and `Pair a`.

2. Write a named implementation of `Functor` for pairs of functors
   (similar to the one implemented for `Product`).

3. Implement `Functor` for data type `Identity` (which is available
   from `Control.Monad.Identity` in *base*):

   ```idris
   record Identity a where
     constructor Id
     value : a
   ```

4. Here is a curious one: Implement `Functor` for `Const e` (which is also
   available from `Control.Applicative.Const` in *base*). You might be
   confused about the fact that the second type parameter has absolutely
   no relevance at runtime, as there is not value of that type. Such
   types are sometimes called *phantom types*. They can be quite useful
   for tagging values with additional typing information.

   Don't let the above confuse you: There is only one possible implementation.
   As usual, use holes and let the compiler guide you if you get lost.

   ```idris
   record Const e a where
     constructor MkConst
     value : e
   ```

5. Here is a sum type for describing CRUD operations
   (Create, Read, Update, and Delete) in a data store:

   ```idris
   data Crud : (i : Type) -> (a : Type) -> Type where
     Create : (value : a) -> Crud i a
     Update : (id : i) -> (value : a) -> Crud i a
     Read   : (id : i) -> Crud i a
     Delete : (id : i) -> Crud i a
   ```

   Implement `Functor` for `Crud i`.

6. Here is a sum type for describing responses from a data server:

   ```idris
   data Response : (e, i, a : Type) -> Type where
     Created : (id : i) -> (value : a) -> Response e i a
     Updated : (id : i) -> (value : a) -> Response e i a
     Found   : (values : List a) -> Response e i a
     Deleted : (id : i) -> Response e i a
     Error   : (err : e) -> Response e i a
   ```

   Implement `Functor` for `Repsonse e i`.

<!-- vi: filetype=idris2
-->
