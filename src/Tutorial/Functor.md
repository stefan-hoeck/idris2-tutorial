# Functor and Friends

Programming, like mathematics, is about abstraction. We
try to model parts of the real world, reusing reoccurring
patterns by abstracting over them.

In this chapter, we will learn about several related interfaces,
which are all about abstraction, and thus, can be hard to
understand at the beginning. Especially figuring out
*why* they are useful and *when* to use them will take
some time and experience. This chapter therefore comes
with tons of exercises, most of which can be solved
with less than three short lines of code. Don't skip them.
Come back to them several times until these things start
feeling natural to you. You will then realize that their
initial complexity has vanished.

```idris
module Tutorial.Functor

import Data.String

%default total
```

## Functor

What do type constructors like `List`, `List1`, `Maybe`, or
`IO` have in common? First, all of them are of type
`Type -> Type`. Second, they all store values of a given type
in a certain *context*. With list `List`,
the *context* is *non-determinism*: We know there to
be zero or more values, but we don't know the exact number
until we start taking the list apart by pattern matching
on it. Likewise for `List1`, though we know for sure that
there is at least one value. For `Maybe`, we are still not
sure about how many values there are, but the possibilities
are much smaller. With `IO`, the context is a different one:
Arbitrary side effects.

Although the type constructors discussed above are quite
different in how they behave and when they are useful,
there are certain operations that keep coming up time and
time again when working with them. The first such operation
is *mapping a pure function over the data type, without
affecting its underlying structure*.

For instance, given a list of numbers, we'd like to multiply
each number by two:

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

Do you realize, just how boring these functions are? They
are almost identical, with the only interesting part being
the function we apply to each element. Surely there's a
pattern, over which we can abstract:

```idris
mapList : (a -> b) -> List a -> List b
mapList f []        = []
mapList f (x :: xs) = f x :: mapList f xs
```

But surely we'd like to do the same kind of things with
`List1` and `Maybe`! After all, they are just container
types like `List`, the only difference being some detail
about the number of values they can or can't hold:

```idris
mapMaybe : (a -> b) -> Maybe a -> Maybe b
mapMaybe f Nothing  = Nothing
mapMaybe f (Just v) = Just (f v)
```

Even with `IO`, we'd like to be able to map a function
over an effectful computation. The implementation is
a bit more involved, what with the nested layers of
data constructors, but if in doubt, the types will surely
guide us. Note, however, that `IO` is not publicly exported,
so its data constructor is unavailable to us. We can use
functions `toPrim` and `fromPrim`, however, for converting
`IO` from and to `PrimIO`, which we can freely dissect as
we please:

```idris
mapIO : (a -> b) -> IO a -> IO b
mapIO f io = fromPrim $ mapPrimIO (toPrim io)
  where mapPrimIO : PrimIO a -> PrimIO b
        mapPrimIO prim w =
          let MkIORes va w2 = prim w
           in MkIORes (f va) w2
```

There are some low hanging derived functions, which are
often useful. Here they are for `IO`:

```idris
mapConstIO : b -> IO a -> IO b
mapConstIO = mapIO . const

forgetIO : IO a -> IO ()
forgetIO = mapConstIO ()
```

Of course, we could implement `mapConst` and `forget` as well
for `List`, `List1`, and `Maybe` (and dozens of other type
constructors with some kine of mapping function), and they'd
all look the same and be equally boring.

Often, when we come upon a recurring class of functions with
some useful derived functions, it is useful to abstract this
away in an interface. But how should we go about this here?
When you look at the types of `mapList`, `mapMaybe`, and `mapIO`,
you'll see that it's the `List`, `List1`, and `IO` types we
need to get rid of. These are not of type `Type` but of type
`Type -> Type`. Luckily, there is nothing preventing us
from parameterizing an interface over something else than
a `Type`:

```idris
interface Functor' (0 f : Type -> Type) where
  map' : (a -> b) -> f a -> f b

implementation Functor' Maybe where
  map' = mapMaybe
```

The interface we are looking for is called `Functor`.


<!-- vi: filetype=idris2
-->
