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
both of which we stored on disk as tables together with their schemata
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
convinced. In fact, the following implementation of `Eq ColType`
would be perfectly fine as far as the type checker is concerned:

```repl
Eq ColType where
  _       == _       = True
```

So Idris is right in not trusting us. You might expect it to inspect the
implementation of `(==)` and figure out on its own, what the `True` result
means, but this is not how these things work in general, because most of the
time the number of computational paths to check would be far too large.
As a consequence, Idris is able to evaluate functions during
unification, but it will not trace back information about function
arguments from a function's result for us. We can do so manually, however,
as we will see later.

### A Type for equal Schemata

The problem described above is similar to what we saw when
we talked about the benefit of [singleton types](DPair.md#erased-existentials):
The types are not precise enough. What we are going to do now,
is something we'll repeat time again for different use cases:
We encode a contract between values in an indexed data type:

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
result of `sameSchema s1 s2`, is a *witness* that `s1` and `s2` are actually
identical, because this is what we specified in the definition of `Same`.

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
of type `SameSchema` for the nil and cons cases. Please note, how
the implementations are trivial. Still, we often have to quickly
write such small proofs (I'll explain in the next section, why I
call them *proofs*), which will then be used to convince the
type checker about some fact we already take for granted but Idris
does not.

```idris
sameNil : SameSchema [] []
sameNil = Same

sameCons :  SameColType c1 c2
         -> SameSchema s1 s2
         -> SameSchema (c1 :: s1) (c2 :: s2)
sameCons SameCT Same = Same
```

As usual, it can help understanding what's going on by replacing
the right hand side of `sameCons` with a hole an check out its
type and context at the REPL. The presence of values `SameCT`
and `Same` on the left hand side forces Idris to unify `c1` and `c2`
as well as `s1` and `s2`, from which the unification of
`c1 :: s1` and `c2 :: s2` immediately follows.
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

### Exercises part 1

In the following exercises, you are going to implement
some very basic properties of equality proofs. You'll
have to come up with the types of the functions yourself,
as the implementations will be incredibly simple.

Note: If you can't remember what the terms "reflexive",
"symmetric", and "transitive" means, quickly read about
equivalence relations [here](https://en.wikipedia.org/wiki/Equivalence_relation).

1. Show that `SameColType` is a reflexive relation.

2. Show that `SameColType` is a symmetric relation.

3. Show that `SameColType` is a transitive relation.

4. Show that for any function `f` from a value
   of type `SameColType c1 c2` follows that
   `f c1` and `f c2` are equal.

For `(=)` the above properties are available from the *Prelude*
as functions `sym`, `trans`, and `cong`. Reflexivity is comes
from the data constructor `Refl` itself.

5. Implement a function for verifying that two natural
   numbers are identical. Try using `cong` in your
   implementation.

6. Use the function from exercise 5 for zipping two
   `Table`s if they have the same number of rows.

   Hint: Use `Vect.zipWith`. You will need to implement
   custom function `appRows` for this, since Idris will
   not automatically figure out that the types unify when
   using `HList.(++)`:

   ```idris
   appRows : {ts1 : _} -> Row ts1 -> Row ts2 -> Row (ts1 ++ ts2)
   ```

We will later learn how to use *rewrite rules* to circumvent
the need of writing custom functions like `appRows` and use
`(++)` in `zipWith` directly.

## Programs as Proofs

A famous observation by mathematician *Haskell Curry* and
logician *William Alvin Howard* leads to the conclusion,
that we can view a *type* as a mathematical proposition
and a total program returning a *value* of this type as a
proof that the proposition holds. This is also known as the
[Curry-Howard isomorphism](https://en.wikipedia.org/wiki/Curry%E2%80%93Howard_correspondence).

For instance, here is a simple proof that one plus one
equals two:

```idris
onePlusOne : the Nat 1 + 1 = 2
onePlusOne = Refl
```

The above proof is trivial, as Idris solves this by unification.
But we already stated some more interesting things in the
exercises. For instance, the symmetry and transitivity of
`SameColType`:

```idris
sctSymmetric : SameColType c1 c2 -> SameColType c2 c1
sctSymmetric SameCT = SameCT

sctTransitive : SameColType c1 c2 -> SameColType c2 c3 -> SameColType c1 c3
sctTransitive SameCT SameCT = SameCT
```

Note, that a type alone is not a proof. For instance, we are free
to state that one plus one equals three:

```idris
onePlusOneWrong : the Nat 1 + 1 = 3
```

We will, however, have a hard time implementing this in a provably
total way.

### When Proofs replace Tests

We will see several different use cases for compile time proofs. A
very straight forward one being to show that our functions behave
as they should by proofing some properties about them. For instance,
here is a proposition that `map` on list does not change the number of
elements in the list:

```idris
mapListLength : (f : a -> b) -> (as : List a) -> length as = length (map f as)
```

Read this as a universally quantified statement: For all functions `f`
from `a` to `b` and for all lists `as` holding values of type `a`,
the length of `map f as` is the same the as the length of the original list.

We can implement `mapListLength` by pattern matching on `as`. The `Nil` case
will be trivial: Idris solves this by unification. It knows the value of the
input list (`Nil`), and since `map` is implemented by pattern matching on
the input as well, it follows immediately that the result will be `Nil` as
well:

```idris
mapListLength f []        = Refl
```

The `cons` case is more involved, and we will do this stepwise.
First, note that we can proof that the length of a map over the
tail will stay the same by means of recursion:


```repl
mapListLength f (x :: xs) = case mapListLength f xs of
  prf => ?mll1
```

Let's inspect the types and context we have here:

```repl
 0 b : Type
 0 a : Type
   xs : List a
   f : a -> b
   x : a
   prf : length xs = length (map f xs)
------------------------------
mll1 : S (length xs) = S (length (map f xs))
```

So, we have a proof of type `length xs = length (map f xs)`,
and from the implementation of `map` Idris concludes that what
we are actually looking for is a result of type
`S (length xs) = S (length (map f xs))`. This is exactly what
function `cong` from the *Prelude* is for (*cong* is an abbreviation
for *congruence*). We can thus implement the *cons* case
concisely like so:


```idris
mapListLength f (x :: xs) = cong S $ mapListLength f xs
```

Please take a moment to appreciate what we achieved here:
A *proof* in the mathematical sense that our function will not
affect the length of our list. There will be no need to verify
this in unit tests!

Before we continue, please note an important thing: In our
case expression, we used a *variable* for the result from the
recursive call:

```repl
mapListLength f (x :: xs) = case mapListLength f xs of
  prf => cong S prf
```

Here, we did not want the two lengths to unify, because we
needed the distinction in our call to `cong`. Therefore: If
you need a proof of type `x = y` in order for two variables
to unify, use the `Refl` data constructor in the pattern match.
If, on the other hand, you need to run further computations on
such a proof, use a variable for `x` and `y` to remain distinct.

Here is another example from the last chapter: We want to show
that parsing and printing column types behaves correctly.
Writing proofs about parser can be very hard in general, but
here it can be done with a mere pattern match:

```idris
showColType : ColType -> String
showColType I64      = "i64"
showColType Str      = "str"
showColType Boolean  = "boolean"
showColType Float    = "float"

readColType : String -> Maybe ColType
readColType "i64"      = Just I64
readColType "str"      = Just Str
readColType "boolean"  = Just Boolean
readColType "float"    = Just Float
readColType s          = Nothing

showReadColType : (c : ColType) -> readColType (showColType c) = Just c
showReadColType I64     = Refl
showReadColType Str     = Refl
showReadColType Boolean = Refl
showReadColType Float   = Refl
```

Such simple proofs give us a quick but strong guarantee
that we did not make any stupid mistakes.

The examples we saw so far were very easy to implement. In general,
this is not the case, and we will have to learn about several
additional techniques in order to proof interesting things about
our programs. However, when we use Idris as a general purpose
programming language and not as a proof assistant, we are free
to choose whether some aspect of our code needs such strong
guarantees or not.

### A Note of Caution: Lowercase Identifiers in Function Types

When writing down the types of proofs as we did above, one
has to be very careful not to fall into the following trap:
In general, Idris will treat lowercase identifiers in
function types as type parameters (erased implicit arguments).

For instance, here is a try at proofing the identity functor
law for `Maybe`:

```idris
mapMaybeId1 : (ma : Maybe a) -> map id ma = ma
mapMaybeId1 Nothing  = Refl
mapMaybeId1 (Just x) = ?mapMaybeId1_rhs
```

You will not be able to implement the `Just` case, because
Idris treats `id` as an implicit argument as can easily be
seen when inspecting the context of `mapMaybeId1_rhs`:

```repl
Tutorial.Relations> :t mapMaybeId1_rhs
 0 a : Type
 0 id : a -> a
   x : a
------------------------------
mapMaybeId1_rhs : Just (id x) = Just x
```

As you can see, `id` is an erased argument of type `a -> a`. And in
fact, when type-checking this module, Idris will issue a warning that
parameter `id` is shadowing an existing function:

```repl
Warning: We are about to implicitly bind the following lowercase names.
You may be unintentionally shadowing the associated global definitions:
  id is shadowing Prelude.Basics.id
```

The same is not true for `map`: Since we explicitly pass arguments
to `map`, Idris treats this as an existing function instead.

You have several options here. For instance, you could use an uppercase
identifier, as these will never be treated as implicit arguments:

```idris
Id : a -> a
Id = id

mapMaybeId2 : (ma : Maybe a) -> map Id ma = ma
mapMaybeId2 Nothing  = Refl
mapMaybeId2 (Just x) = Refl
```

As an alternative - and this is the preferred way to handle this case -
you can prefix `id` with part of its namespace, which will immediately
solve the issue:

```idris
mapMaybeId : (ma : Maybe a) -> map Prelude.id ma = ma
mapMaybeId Nothing  = Refl
mapMaybeId (Just x) = Refl
```

Note: If you have semantic highlighting turned on in your editor
(for instance, by using the [idris2-lsp plugin](https://github.com/idris-community/idris2-lsp)
for your editor), you will note that `map` and `id` in `mapMaybeId1` get
highlighted differently: `map` as a function name, `id` as a bound variable.

### Exercises part 2

In these exercises, you are going to proof several simple properties
of small functions. When writing proofs, it is even more important
to use holes to figure out what Idris expects from you next. Use
the tools given to you, instead of trying to find your way in the
dark!

1. Proof that `map id` on a `Either e` returns the value unmodified.

2. Proof that `map id` on a list returns the list unmodified.

3. Proof that complementing a strand of a nucleobase
   (see the [previous chapter](DPair.md#use-case-nucleic-acids))
   twice leads to the original strand.

   Hint: Proof this for single bases first, and use `cong2`
   from the *Prelude* in your implementation.

4. Implement function `replaceVect`:

   ```idris
   replaceVect : (ix : Fin n) -> a -> Vect n a -> Vect n a
   ```

   Now proof, that after replacing an element in a vector
   using `replaceAt` accessing the same element using
   `index` will return the value we just added.

5. Implement function `insertVect`:

   ```idris
   insertVect : (ix : Fin (S n)) -> a -> Vect n a -> Vect (S n) a
   ```

   Use a similar proof as in exercise 4 to show that this
   behaves correctly.

Note: Functions `replaceVect` and `insertVect` are available
from `Data.Vect` as `replaceAt` and `insertAt`.

## Into the Void

Remember function `onePlusOneWrong` from above? This was definitely
a wrong statement: One plus one does not equal three. Sometimes,
we want to express exactly this: That a certain statement is false
and does not hold. Consider for a moment what it means to proof
a statement in Idris: Such a statement (or proposition) is a
type, and a proof of the statement is a value or expression of
this type. If a statement is not true, there can be no value
of the given type. We say, the given type is *uninhabited*.
If we still manage to get our hands on a value of an uninhabited
type, that is a logical contradiction and from it, anything
follows (remember
[ex falso quodlibet](https://en.wikipedia.org/wiki/Principle_of_explosion)).

So this is how to express that a proposition does not hold: We
state that if it *would* hold, this would lead to a contradiction.
The most natural way to express a contradiction in Idris is
to return a value of type `Void`:

```idris
onePlusOneWrongProvably : the Nat 1 + 1 = 3 -> Void
onePlusOneWrongProvably Refl impossible
```

We can also use contradictory statements to proof other such
statements. For instance, here is a proof that if the lengths
of two lists are not the same, then the two list can't be
the same either:

```idris
notSameLength1 : (List.length as = length bs -> Void) -> as = bs -> Void
notSameLength1 f prf = f (cong length prf)
```

This is cumbersome to write and pretty hard to read, so there
is function `Not` in the prelude to express the same thing
more naturally:

```idris
notSameLength : Not (List.length as = length bs) -> Not (as = bs)
notSameLength f prf = f (cong length prf)
```

Actually, this is just a specialized version of the contraposition of
`cong`: If from `a = b` follows `f a = f b`, then from
`not (f a = f b)` follows `not (a = b)`:

```idris
contraCong : {0 f : _} -> Not (f a = f b) -> Not (a = b)
contraCong fun prf = fun (cong f prf)
```

### Interface `Uninhabited`

There is an interface in the *Prelude* for expressing this: `Uninhabited`,
with its sole function `uninhabited`. Have a look at its documentation at
the REPL. You will see, that there is already an impressive number
of implementations available, many of which involve data type
`Equal`.

We can use `Uninhabited`, to for instance express that
the empty schema is not equal to a non-empty schema:

```idris
Uninhabited (SameSchema [] (h :: t)) where
  uninhabited Same impossible
```

### Exercises part 3

1. Show that there can be no non-empty vector of `Void`
   by writing a corresponding implementation of uninhabited

2. Generalize exercise 1 for all uninhabited element types.

3. Show that if `a = b` cannot hold, then `b = a` cannot hold
   either.

4. Show that if `a = b` holds, and `b = c` cannot hold, then
   `a = c` cannot hold either.

5. Implement `Uninhabited` for `Crud i a`. Try to be
   as general as possible.

   ```idris
   data Crud : (i : Type) -> (a : Type) -> Type where
     Create : (value : a) -> Crud i a
     Update : (id : i) -> (value : a) -> Crud i a
     Read   : (id : i) -> Crud i a
     Delete : (id : i) -> Crud i a
   ```

<!-- vi: filetype=idris2
-->
