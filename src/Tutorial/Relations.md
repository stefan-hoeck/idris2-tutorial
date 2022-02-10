# Relations

Note: This is still work in progress. Please come back later.

In the [last chapter](DPair.md) we learned, how dependent pairs
and records can be used to calculate *types* from values only known
at runtime by pattern matching on these values. We will now look
at how we can describe relations - or *contracts* - between
values as types, and how we can use values of these types as
proofs that the contracts hold.

```idris
module Tutorial.Relations

import Data.Either
import Data.HList
import Data.Vect
import Data.String

%default total
```

## Equality as a Type

Imagine, we'd like to concatenate the contents of two CSV files,
both of which we store as tables together with their schemata
as shown in our discussion about dependent pairs:

```idris
data ColType = I64 | Str | Boolean | Float

Schema : Type
Schema = List ColType

IdrisType : ColType -> Type
IdrisType I64     = Int64
IdrisType Str     = String
IdrisType Boolean = Bool
IdrisType Float   = Double

Row : Schema -> Type
Row = HList . map IdrisType

record Table where
  constructor MkTable
  schema : Schema
  size   : Nat
  rows   : Vect size (Row schema)

concatTables1 : Table -> Table -> Maybe Table
```

We will not be able to implement `concatTables` by appending the
two row vectors, unless we can somehow verify that the two schemata
are identical. "Well," I hear you say, "that shouldn't be a big issue!
Just implement `Eq` for `ColType`". Let's give this a try:

```idris
Eq ColType where
  I64     == I64     = True
  Str     == Str     = True
  Boolean == Boolean = True
  Float   == Float   = True
  _       == _       = False

concatTables1 (MkTable s1 m rs1) (MkTable s2 n rs2) = case s1 == s2 of
  True  => ?what_now
  False => Nothing
```

Somehow, this doesn't seem to work. If we inspect the context of hole
`what_now`, Idris still thinks that `s1` and `s2` are different, and
if we go ahead and invoke `Vect.(++)` anyway in the `True` case,
Idris will respond with a type error.

```repl
Tutorial.Relations> :t what_now
   m : Nat
   s1 : List ColType
   rs1 : Vect m (HList (map IdrisType s1))
   n : Nat
   s2 : List ColType
   rs2 : Vect n (HList (map IdrisType s2))
------------------------------
what_now : Maybe Table
```

The problem is, that there is no reason for Idris to unify the two
values, even though `(==)` returned `True` because the result of `(==)`
holds no other information than the type being a `Bool`. *We* think,
if this is `True` the two values should be identical, but Idris is not
convinced. In fact, the following implementation would be perfectly fine
as far as the type checker is concerned:

```repl
Eq ColType where
  _       == _       = True
```

So Idris is right in not trusting us. You might expect it to inspect the
implementation of `(==)` and figure out on its own, what the `True` result
means, but this is not how these things work in general, because most of the
time the number of computational paths to check would be far too large.

### A Type for equal Schemata

The problem described above is similar to what we saw when
we talked about the benefit of singleton types: The types
are not precise enough. What we are going to do now, is something we'll repeat
time again for different use cases: We encode a contract between values in
an indexed data type:

```idris
data SameSchema : (s1 : Schema) -> (s2 : Schema) -> Type where
  Same : SameSchema s s
```

First, note how `SameSchema` is a family of types indexed over two
values of type `Schema`. But note also that the constructors
restrict the values we allow for `s1` and `s2`: The two indices
*must* be identical.

Why is this useful? Well, imagine we had a function for checking
the equality of two schemata, which would try and return a value
of type `SameSchema s1 s2`:

```idris
sameSchema : (s1, s2 : Schema) -> Maybe (SameSchema s1 s2)
```

We could then use this function to implement `concatTables`:

```idris
concatTables : Table -> Table -> Maybe Table
concatTables (MkTable s1 m rs1) (MkTable s2 n rs2) = case sameSchema s1 s2 of
  Just Same => Just $ MkTable s1 _ (rs1 ++ rs2)
  Nothing   => Nothing
```

It worked! What's going on here? Well, let's inspect the types involved:

```idris
concatTables2 : Table -> Table -> Maybe Table
concatTables2 (MkTable s1 m rs1) (MkTable s2 n rs2) = case sameSchema s1 s2 of
  Just Same => ?almost_there
  Nothing   => Nothing
```

At the REPL, we get the following context for `almost_there`:

```repl
Tutorial.Relations> :t almost_there
   m : Nat
   s2 : List ColType
   rs1 : Vect m (HList (map IdrisType s2))
   n : Nat
   rs2 : Vect n (HList (map IdrisType s2))
   s1 : List ColType
------------------------------
almost_there : Maybe Table
```

See, how the types of `rs1` and `rs2` unify? Value `Same`, coming as the
result of `sameSchema s1 s2`, is a witness that `s1` and `s2` are actually
identical, because this is what we specified in our definition of `Same`.

All that remains to do is to implement `sameSchema`. For this, we will write
another data type for specifying when two values of type `ColType` are
identical:

```idris
data SameColType : (c1, c2 : ColType) -> Type where
  SameCT : SameColType c1 c1
```

We can now define several utility functions. First, one for figuring out
if two column types are identical:

```idris
sameColType : (c1, c2 : ColType) -> Maybe (SameColType c1 c2)
sameColType I64     I64     = Just SameCT
sameColType Str     Str     = Just SameCT
sameColType Boolean Boolean = Just SameCT
sameColType Float   Float   = Just SameCT
sameColType _ _             = Nothing
```

This will convince Idris, because in each pattern match, the return
type will be adjusted according to the values we matched on. For instance,
on the first line, the output type is `Maybe (SameColType I64 I64)` as
you can easily verify yourself by inserting a hole and checking its
type at the REPL.

We will need two additional utilities: Functions for creating values
of type `SameSchema` for the nil and cons cases:

```idris
sameNil : SameSchema [] []
sameNil = Same

sameCons :  SameColType c1 c2
         -> SameSchema s1 s2
         -> SameSchema (c1 :: s1) (c2 :: s2)
sameCons SameCT Same = Same
```

With these, we can finally implement `sameSchema`:

```idris
sameSchema []        []        = Just sameNil
sameSchema (x :: xs) (y :: ys) =
  [| sameCons (sameColType x y) (sameSchema xs ys) |]
sameSchema (x :: xs) []        = Nothing
sameSchema []        (x :: xs) = Nothing
```

What we described here is a far stronger form of equality
than what is provided by interface `Eq` and the `(==)`
operator: Equality of values that is accepted by the
type checker when trying to unify type level indices.

### Type `Equal`

Type level equality is such a fundamental concept, that the *Prelude*
exports a general data type for this already: `Equal`, with its only
data constructor `Refl`. In addition, there is a built-in operator
for expressing type level equality, which gets desugared to `Equal`:
`(=)`. Here is another implementation of `concatTables`:

```idris
eqColType : (c1,c2 : ColType) -> Maybe (c1 = c2)
eqColType I64     I64     = Just Refl
eqColType Str     Str     = Just Refl
eqColType Boolean Boolean = Just Refl
eqColType Float   Float   = Just Refl
eqColType _ _             = Nothing

eqCons :  {0 c1,c2 : a}
       -> {0 s1,s2 : List a}
       -> c1 = c2 -> s1 = s2 ->  c1 :: s1 = c2 :: s2
eqCons Refl Refl = Refl

eqSchema : (s1,s2 : Schema) -> Maybe (s1 = s2)
eqSchema []        []        = Just Refl
eqSchema (x :: xs) (y :: ys) = [| eqCons (eqColType x y) (eqSchema xs ys) |]
eqSchema (x :: xs) []        = Nothing
eqSchema []        (x :: xs) = Nothing

concatTables3 : Table -> Table -> Maybe Table
concatTables3 (MkTable s1 m rs1) (MkTable s2 n rs2) = case eqSchema s1 s2 of
  Just Refl => Just $ MkTable _ _ (rs1 ++ rs2)
  Nothing   => Nothing
```

## Programs as Proofs

<!-- vi: filetype=idris2
-->
