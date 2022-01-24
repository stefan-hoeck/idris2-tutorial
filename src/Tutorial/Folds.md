# Folds and Traversals

In this chapter, we are going to have a closer look at the
computations we typically perform with *container types*:
Parameterized data types like `List`, `Maybe`, or
`Identity`, holding zero or more values of the parameter's
type.

We start with concrete, pure functions like "calculating
the sum of the numeric values stored in a container", but will
soon begin to experiment with generalizations,
eventually arriving at two highly versatile functions
for accumulating the values stored in a container: `foldl`,
and `foldMap`.

We will then look at running effectful conversions over the
elements stored in a container, while reassembling and
preserving the container's structure. This will eventually
lead us to one of the most powerful function exported by
the *Prelude*: `traverse`.

```idris
module Tutorial.Folds

import Data.List1
import Data.Maybe

%default total
```

## Interface Foldable

We already learned about several *container types*: Parameterized
data structures holding zero or more values of their parameter's
type. Some of these are of a fixed size and structure, some pair their
values with additional informations, but all of them allow us to
pattern match on them and extract the values they potentially hold.
Here is a (possibly non-comprehensive) list of the ones we met so far:

* `Prelude.List`
* `Prelude.Maybe`
* `Prelude.Either e`
* `Prelude.Pair e`
* `Data.List1.List1`
* `Data.Vect.Vect n`
* `Control.Applicative.Const e`
* `Control.Monad.Identity`

One common thing to do with container types is to try and
extract all elements they hold. Sometimes, the data type itself
tells us the exact number of elements (this is, for instance,
the case with `Pair e`, `Vect n`, `Const e`, and `Identity`),
sometimes we can't know the number of elements without inspecting
a value of the given type by pattern matching on it. Yet,
the general idea of *collecting all elements* can be applied
to them all:

```idris
maybeToList : Maybe a -> List a
maybeToList = maybe Nil pure

eitherToList : Either e a -> List a
eitherToList = either (const Nil) pure

list1ToList : List1 a -> List a
list1ToList = forget

pairToList : (e,a) -> List a
pairToList (_,v) = [v]
```

But there are more things we could think of doing. We could, for instance,
build the sum or product over all numeric values in a container type:

```idris
maybeSum : Num a => Maybe a -> a
maybeSum = fromMaybe 0

listSum : Num a => List a -> a
listSum []        = 0
listSum (x :: xs) = x + listSum xs
```

Note, that there is a common pattern here: In the empty case, we
return a *neutral* value, while in the non-empty case, while in the
non-empty case we combine the current element with the result of
accumulating the rest of the data structure using an associative
operation. There is an interface encapsulating these two concepts: `Monoid`.
And indeed, `maybeSum` and `listSum` but also the `toList` operations
shown above can be *generalized* as an accumulation of values over
a `Monoid`:

```idris
maybeFold : Monoid m => Maybe m -> m
maybeFold = fromMaybe neutral

listFold : Monoid m => List m -> m
listFold []        = neutral
listFold (x :: xs) = x <+> listFold xs

record Plus a where
  constructor MkPlus
  value : a

Num a => Semigroup (Plus a) where
  MkPlus x <+> MkPlus y = MkPlus $ x + y

Num a => Monoid (Plus a) where
  neutral = MkPlus 0

maybeSum' : Num a => Maybe a -> a
maybeSum' = value . maybeFold . map MkPlus

maybeToList' : Maybe a -> List a
maybeToList' = maybeFold . map pure
```

From the implementations of `maybeSum'` and `maybeToList'` we see,
that this *folding over a monoid* is quite a powerful concept.
However, we can make this even more convenient to use:
In both implementations we had to first *map* over the list to
get a list of values with an implementation of `Monoid`. Surely,
we can abstract over this in a new function:

```idris
maybeFoldMap : Monoid m => (a -> m) -> Maybe a -> m
maybeFoldMap f = maybe neutral f

listFoldMap : Monoid m => (a -> m) -> List a -> m
listFoldMap f []        = neutral
listFoldMap f (x :: xs) = f x <+> listFoldMap f xs

maybeSum'' : Num a => Maybe a -> a
maybeSum'' = value . maybeFoldMap MkPlus
```

But what, if our result type doesn't have an implementation of `Monoid`,
and writing one would be just too cumbersome to bother? Well, the
only two things `Monoid` gives us, is a value to start with (`neutral`),
and a binary function for accumulating values. So, instead of taking
a `Monoid` constraint, we could just as well take these two things
as explicit arguments:

```idris
maybeFoldWith : (acc : a -> a -> a) -> (ini : a) -> Maybe a -> a
maybeFoldWith acc ini = maybe ini (acc ini)

listFoldWith : (acc : a -> a -> a) -> (ini : a) -> List a -> a
listFoldWith acc ini []        = ini
listFoldWith acc ini (x :: xs) = listFoldWith acc (acc ini x) xs

maybeFold' : Monoid m => Maybe m -> m
maybeFold' = maybeFoldWith (<+>) neutral

listFold' : Monoid m => List m -> m
listFold' = listFoldWith (<+>) neutral
```

We can take one step further, and make `acc` a heterogeneous
binary function:

```idris
maybeFoldH : (acc : b -> a -> b) -> (ini : b) -> Maybe a -> b
maybeFoldH acc ini = maybe ini (acc ini)

listFoldH : (acc : b -> a -> b) -> (ini : b) -> List a -> b
listFoldH acc ini []        = ini
listFoldH acc ini (x :: xs) = listFoldH acc (acc ini x) xs

maybeFoldMap' : Monoid m => (a -> m) -> Maybe a -> m
maybeFoldMap' f = maybeFoldH (\x,y => x <+> f y) neutral

listFoldMap' : Monoid m => (a -> m) -> List a -> m
listFoldMap' f = listFoldH (\x,y => x <+> f y) neutral
```

<!-- vi: filetype=idris2
-->
