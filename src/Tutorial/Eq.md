# Propositional Equality

In the [last chapter](DPair.md) we learned, how dependent pairs
and records can be used to calculate *types* from values only known
at runtime by pattern matching on these values. We will now look
at how we can describe relations - or *contracts* - between
values as types, and how we can use values of these types as
proofs that the contracts hold.

```idris
module Tutorial.Eq

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

We will not be able to implement `concatTables1` by appending the
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
values of type `Schema`. But note also that the sole constructor
restricts the values we allow for `s1` and `s2`: The two indices
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
This is also called *propositional equality*: We will see
below, that we can view types as mathematical *propositions*,
and values of these types a *proofs* that these propositions
hold.

### Type `Equal`

Propositional equality is such a fundamental concept, that the *Prelude*
exports a general data type for this already: `Equal`, with its only
data constructor `Refl`. In addition, there is a built-in operator
for expressing propositional equality, which gets desugared to `Equal`:
`(=)`. This can sometimes lead to some confusion, because the equals
symbol is also used for *definitional equality*: Describing in function
implementations that the left-hand side and right-hand side are
defined to be equal. If you want to disambiguate propositional from
definitional equality, you can also use operator `(===)` for the
former.

Here is another implementation of `concatTables`:

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
"symmetric", and "transitive" mean, quickly read about
equivalence relations [here](https://en.wikipedia.org/wiki/Equivalence_relation).

1. Show that `SameColType` is a reflexive relation.

2. Show that `SameColType` is a symmetric relation.

3. Show that `SameColType` is a transitive relation.

4. Let `f` be a function of type `ColType -> a` for an
   arbitrary type `a`. Show that from a value of type
   `SameColType c1 c2` follows that `f c1` and `f c2` are equal.

For `(=)` the above properties are available from the *Prelude*
as functions `sym`, `trans`, and `cong`. Reflexivity comes
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
that we can view a *type* in a programming language with
a sufficiently rich type system as a mathematical proposition
and a total program calculating a *value* of this type as a
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
total way. We say: "The type `the Nat 1 + 1 = 3` is *uninhabited*",
meaning, that there is no value of this type.

### When Proofs replace Tests

We will see several different use cases for compile time proofs, a
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
function `cong` from the *Prelude* is for ("cong" is an abbreviation
for *congruence*). We can thus implement the *cons* case
concisely like so:

```idris
mapListLength f (x :: xs) = cong S $ mapListLength f xs
```

Please take a moment to appreciate what we achieved here:
A *proof* in the mathematical sense that our function will not
affect the length of our list. We no longer need a unit test
or similar program to verify this.

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
such a proof, use a variable and the left and right-hand sides
will remain distinct.

Here is another example from the last chapter: We want to show
that parsing and printing column types behaves correctly.
Writing proofs about parsers can be very hard in general, but
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

Such simple proofs give us quick but strong guarantees
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
to `map`, Idris treats this as a function name and not as an
implicit argument.

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
resolve the issue:

```idris
mapMaybeId : (ma : Maybe a) -> map Prelude.id ma = ma
mapMaybeId Nothing  = Refl
mapMaybeId (Just x) = Refl
```

Note: If you have semantic highlighting turned on in your editor
(for instance, by using the [idris2-lsp plugin](https://github.com/idris-community/idris2-lsp)),
you will note that `map` and `id` in `mapMaybeId1` get
highlighted differently: `map` as a function name, `id` as a bound variable.

### Exercises part 2

In these exercises, you are going to proof several simple properties
of small functions. When writing proofs, it is even more important
to use holes to figure out what Idris expects from you next. Use
the tools given to you, instead of trying to find your way in the
dark!

1. Proof that `map id` on an `Either e` returns the value unmodified.

2. Proof that `map id` on a list returns the list unmodified.

3. Proof that complementing a strand of a nucleobase
   (see the [previous chapter](DPair.md#use-case-nucleic-acids))
   twice leads to the original strand.

   Hint: Proof this for single bases first, and use `cong2`
   from the *Prelude* in your implementation for sequences
   of nucleic acids.

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
this type: The type is said to be *inhabited*.
If a statement is not true, there can be no value
of the given type. We say, the given type is *uninhabited*.
If we still manage to get our hands on a value of an uninhabited
type, that is a logical contradiction and from this, anything
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

See how this is a provably total implementation of the
given type: A function from `1 + 1 = 3` to `Void`. We
implement this by pattern matching, and there is only
one constructor to match on, which leads to an impossible
case.

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
contraCong fun x = fun $ cong f x
```

### Interface `Uninhabited`

There is an interface in the *Prelude* for uninhabited types: `Uninhabited`
with its sole function `uninhabited`. Have a look at its documentation at
the REPL. You will see, that there is already an impressive number
of implementations available, many of which involve data type
`Equal`.

We can use `Uninhabited`, to for instance express that
the empty schema is not equal to a non-empty schema:

```idris
Uninhabited (SameSchema [] (h :: t)) where
  uninhabited Same impossible

Uninhabited (SameSchema (h :: t) []) where
  uninhabited Same impossible
```

There is a related function you need to know about: `absurd`, which
combines `uninhabited` with `void`:

```repl
Tutorial.Eq> :printdef absurd
Prelude.absurd : Uninhabited t => t -> a
absurd h = void (uninhabited h)
```

### Decidable Equality

When we implemented `sameColType`, we got a proof that two
column types are indeed the same, from which we could figure out,
whether two schemata are identical. The types guarantee
we do not generate any false positives: If we generate a value
of type `SameSchema s1 s2`, we have a proof that `s1` and `s2`
are indeed identical.
However, `sameColType` and thus `sameSchema` could theoretically
still produce false negatives by returning `Nothing`
although the two values are identical. For instance,
we could implement `sameColType` in such a way that it
always returns `Nothing`. This would be in agreement with
the types, but definitely not what we want. So, here is
what we'd like to do in order to get yet stronger guarantees:
We'd either want to return a proof that the two schemata
are the same, or return a proof that the two schemata
are not the same. (Remember that `Not a` is an alias for `a -> Void`).

We call a property, which either holds or leads to a
contradiction a *decidable property*, and the *Prelude*
exports data type `Dec prop`, which encapsulates this
distinction.

Here is a way to encode this for `ColType`:

```idris
decSameColType :  (c1,c2 : ColType) -> Dec (SameColType c1 c2)
decSameColType I64 I64         = Yes SameCT
decSameColType I64 Str         = No $ \case SameCT impossible
decSameColType I64 Boolean     = No $ \case SameCT impossible
decSameColType I64 Float       = No $ \case SameCT impossible

decSameColType Str I64         = No $ \case SameCT impossible
decSameColType Str Str         = Yes SameCT
decSameColType Str Boolean     = No $ \case SameCT impossible
decSameColType Str Float       = No $ \case SameCT impossible

decSameColType Boolean I64     = No $ \case SameCT impossible
decSameColType Boolean Str     = No $ \case SameCT impossible
decSameColType Boolean Boolean = Yes SameCT
decSameColType Boolean Float   = No $ \case SameCT impossible

decSameColType Float I64       = No $ \case SameCT impossible
decSameColType Float Str       = No $ \case SameCT impossible
decSameColType Float Boolean   = No $ \case SameCT impossible
decSameColType Float Float     = Yes SameCT
```

First, note how we could use a pattern match in a single
argument lambda directly. This is sometimes called the
*lambda case* style, named after an extension of the Haskell
programming language. If we use the `SameCT` constructor
in the pattern match, Idris is forced to try and unify for instance
`Float` with `I64`. This is not possible, so the case as
a whole is impossible.

Yet, this was pretty cumbersome to implement. In order to
convince Idris we did not miss a case,
there is no way around treating every possible pairing
of constructors explicitly.
However, we get *much* stronger guarantees out of this: We
can no longer create false positives *or* false negatives, and
therefore, `decSameColType` is provably correct.

Doing the same thing for schemata requires some utility functions,
the types of which we can figure out by placing some holes:

```idris
decSameSchema' :  (s1, s2 : Schema) -> Dec (SameSchema s1 s2)
decSameSchema' []        []        = Yes Same
decSameSchema' []        (y :: ys) = No ?decss1
decSameSchema' (x :: xs) []        = No ?decss2
decSameSchema' (x :: xs) (y :: ys) = case decSameColType x y of
  Yes SameCT => case decSameSchema' xs ys of
    Yes Same => Yes Same
    No  contra => No $ \prf => ?decss3
  No  contra => No $ \prf => ?decss4
```

The first two cases are not too hard. The type of `decss1` is
`SameSchema [] (y :: ys) -> Void`, which you can easily verify
at the REPL. But that's just `uninhabited`, specialized to
`SameSchema [] (y :: ys)`, and this we already implemented
further above. The same goes for `decss2`.

The other two cases are harder, so I already filled in as much stuff
as possible. We know that we want to return a `No`, if either the
heads or tails are provably distinct. The `No` holds a
function, so I already added a lambda, leaving a hole only for
the return value. Here are the type and - more important -
context of `decss3`:

```repl
Tutorial.Relations> :t decss3
   y : ColType
   xs : List ColType
   ys : List ColType
   x : ColType
   contra : SameSchema xs ys -> Void
   prf : SameSchema (y :: xs) (y :: ys)
------------------------------
decss3 : Void
```

The types of `contra` and `prf` are what we need here:
If `xs` and `ys` are distinct, then `y :: xs` and `y :: ys`
must be distinct as well. This is the contraposition of the
following statement: If `x :: xs` is the same as `y :: ys`,
then `xs` and `ys` are the same as well. We must therefore
implement a lemma, which proves that the *cons* constructor
is [*injective*](https://en.wikipedia.org/wiki/Injective_function):

```idris
consInjective :  SameSchema (c1 :: cs1) (c2 :: cs2)
              -> (SameColType c1 c2, SameSchema cs1 cs2)
consInjective Same = (SameCT, Same)
```

We can now pass `prf` to `consInjective` to extract a value of
type `SameSchema xs ys`, which we then pass to `contra` in
order to get the desired value of type `Void`.
With these observations and utilities, we can now implement
`decSameSchema`:

```idris
decSameSchema :  (s1, s2 : Schema) -> Dec (SameSchema s1 s2)
decSameSchema []        []        = Yes Same
decSameSchema []        (y :: ys) = No absurd
decSameSchema (x :: xs) []        = No absurd
decSameSchema (x :: xs) (y :: ys) = case decSameColType x y of
  Yes SameCT => case decSameSchema xs ys of
    Yes Same   => Yes Same
    No  contra => No $ contra . snd . consInjective
  No  contra => No $ contra . fst . consInjective
```

There is an interface called `DecEq` exported by module `Decidable.Equality`
for types for which we can implement a decision procedure for propositional
equality. We can implement this to figure out if two values are equal or not.

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

6. Implement `DecEq` for `ColType`.

7. Implementations such as the one from exercise 6 are cumbersome
   to write as they require a quadratic number of pattern matches
   with relation to the number of data constructors. Here is a
   trick how to make this more bearable.

   1. Implement a function `ctNat`, which assigns every value
      of type `ColType` a unique natural number.

   2. Proof that `ctNat` is injective.
      Hint: You will need to pattern match on the `ColType`
      values, but four matches should be enough to satisfy the
      coverage checker.

   3. In your implementation of `DecEq` for `ColType`,
      use `decEq` on the result of applying both column
      types to `ctNat`, thus reducing it to only two lines of
      code.

   We will later talk about `with` rules: Special forms of
   dependent pattern matches, that allow us to learn something
   about the shape of function arguments by performing
   computations on them. These will allow us to use
   a similar technique as shown here to implement `DecEq`
   requiring only `n` pattern matches
   for arbitrary sum types with `n` data constructors.

## Rewrite Rules

One of the most important use cases of propositional equality
is to replace or *rewrite* existing types, which Idris can't
unify automatically otherwise. For instance,
the following is no problem:
Idris know that `0 + n` equals `n`, because `plus` on
natural numbers is implemented by pattern matching on the
first argument. The two vector lengths therefore unify
just fine.

```idris
leftZero :  List (Vect n Nat)
         -> List (Vect (0 + n) Nat)
         -> List (Vect n Nat)
leftZero = (++)
```

However, the example below can't be implemented as easily
(try id!), because Idris can't figure out on its own
that the two lengths unify.

```idris
rightZero' :  List (Vect n Nat)
           -> List (Vect (n + 0) Nat)
           -> List (Vect n Nat)
```

Probably for the first time we realize, just how little
Idris knows about the laws of arithmetics. Idris is able
to unify values when

* all values in a computation are known at compile time
* one expression follows directly from the other due
  to the pattern matches used in a function's implementation.

In expression `n + 0`,  not all values are known (`n` is a variable),
and `(+)` is implemented by pattern matching on the first
argument, about which we know nothing here.

However, we can teach Idris. If we can proof that the two
expressions are equivalent, we can replace one expression
for the other, so that the two unify again. Here is a lemma
and its proof, that `n + 0` equals `n`, for all natural
numbers `n`.

```idris
addZeroRight : (n : Nat) -> n + 0 = n
addZeroRight 0     = Refl
addZeroRight (S k) = cong S $ addZeroRight k
```

Note, how the base case is trivial: Since there are no
variables left, Idris can immediately figure out that
`0 + 0 = 0`. In the recursive case, it can be instructive
to replace `cong S` with a hole and look at its type
and context to figure out how to proceed.

The *Prelude* exports function `replace` for substituting one
variable in a term by another, based on a proof of equality.
Make sure to inspect its type first before looking at the
example below:

```idris
replaceVect : Vect (n + 0) a -> Vect n a
replaceVect as = replace {p = \k => Vect k a} (addZeroRight n) as
```

As you can see, we *replace* a value of type `p x` with a value
of type `p y` based on a proof that `x = y`,
where `p` is a function from some type `t` to
`Type`, and `x` and `y` are values of type `t`. In our
`replaceVect` example, `t` equals `Nat`, `x` equals `n + 0`,
`y` equals `n`, and `p` equals `\k => Vect k a`.

Using `replace` directly is not very convenient, because Idris
can often not infer the value of `p` on its own. Indeed, we
had to give its type explicitly in `replaceVect`.
Idris therefore provides special syntax for such *rewrite rules*,
which will get desugared to calls to `replace` with all the
details filled in for us. Here is an implementation
of `replaceVect` with a rewrite rule:

```idris
rewriteVect : Vect (n + 0) a -> Vect n a
rewriteVect as = rewrite sym (addZeroRight n) in as
```

One source of confusion is that *rewrite* uses proofs
of equality the other way round: Given an `y = x`
it replaces `p x` with `p y`. Hence the need to call `sym`
in our implementation above.

### Use Case: Reversing Vectors

Rewrite rules are often required when we perform interesting
type-level computations. For instance,
we have already seen many interesting examples of functions
operating on `Vect`, which allowed us to keep track of the
exact lengths of the vectors involved, but one key
functionality has been missing from our discussions so far,
and for good reasons: Function `reverse`. Here is a possible
implementation, which is how `reverse` is implemented for
lists:


```repl
revOnto' : Vect m a -> Vect n a -> Vect (m + n) a
revOnto' xs []        = xs
revOnto' xs (x :: ys) = revOnto' (x :: xs) ys


reverseVect' : Vect n a -> Vect n a
reverseVect' = revOnto' []
```

As you might have guessed, this will not compile as the
length indices in the two clauses of `revOnto'` do
not unify.

The *nil* case is a case we've already seen above:
Here `n` is zero, because the second vector is empty,
so we have to convince Idris once again that `m + 0 = m`:

```idris
revOnto : Vect m a -> Vect n a -> Vect (m + n) a
revOnto xs [] = rewrite addZeroRight m in xs
```

The second case is more complex. Here, Idris fails to unify
`S (m + len)` with `m + S len`, where `len` is the length of
`ys`, the tail of the second vector. Module `Data.Nat`
provides many proofs about arithmetic operations on natural
numbers, one of which is `plusSuccRightSucc`. Here's its
type:

```repl
Tutorial.Eq> :t plusSuccRightSucc
Data.Nat.plusSuccRightSucc :  (left : Nat)
                           -> (right : Nat)
                           -> S (left + right) = left + S right
```

In our case, we want to replace `S (m + len)` with `m + S len`,
so we will need the version with arguments flipped. However, there
is one more obstacle: We need to invoke `plusSuccRightSucc`
with the length of `ys`, which is not given as an implicit
function argument of `revOnto`. We therefore need to pattern
match on `n` (the length of the second vector), in order to
bind the length of the tail to a variable. Remember, that we
are allowed to pattern match on an erased argument only if
the constructor used follows from a match on another, unerased,
argument (`ys` in this case). Here's the implementation of the
second case:

```idris
revOnto {n = S len} xs (x :: ys) =
  rewrite sym (plusSuccRightSucc m len) in revOnto (x :: xs) ys
```

I know from my own experience that this can be highly confusing
at first. If you use Idris as a general purpose programming language
and not as a proof assistant, you probably will not have to use
rewrite rules too often. Still, it is important to know that they
exist, as they allow us to teach complex equivalences to Idris.

### A Note on Erasure

Single value data types like `Unit`, `Equal`, or `SameSchema` have
not runtime relevance, as values of these types are always identical.
We can therefore always use them as erased function arguments while
still being able to pattern match on these values.
For instance, when you look at the type of `replace`, you will see
that the equality proof is an erased argument.
This allows us to run arbitrarily complex computations to produce
such values without fear of these computations slowing down
the compiled Idris program.

### Exercises part 4

1. Implement `plusSuccRightSucc` yourself.

2. Proof that `minus n n` equals zero for all natural numbers `n`.

3. Proof that `minus n 0` equals n for all natural numbers `n`

4. Proof that `n * 1 = n` and `1 * n = n`
   for all natural numbers `n`.

5. Proof that addition of natural numbers is
   commutative.

6. Implement a tail-recursive version of `map` for vectors.

7. Proof the following proposition:

   ```idris
   mapAppend :  (f : a -> b)
             -> (xs : List a)
             -> (ys : List a)
             -> map f (xs ++ ys) = map f xs ++ map f ys
   ```

8. Use the proof from exercise 7 to implement again a function
   for  zipping two `Table`s, this time using a rewrite rule
   plus `Data.HList.(++)` instead of custom function `appRows`.

## Conclusion

The concept of *types as propositions, values as proofs* is
a very powerful tool for writing provably correct programs. We
will therefore spend some more time defining data types
for describing contracts between values, and values of these
types as proofs that the contracts hold. This will allow
us to describe necessary pre- and postconditions for our functions,
thus reducing the need to return a `Maybe` or other failure type,
because due to the restricted input, our functions can no longer
fail.

[Next chapter](./Predicates.md)

<!-- vi: filetype=idris2:syntax=markdown
-->
