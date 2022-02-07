# Relations

In the last couple of chapters, we looked at how to abstract over
recurring patterns in pure, strongly typed functional programming
languages. We learned how to describe and run computations with
side effects, how to sequence effectful computations to create
more complex programs, and how to describe folds
and traversals over immutable data structures in a flexible and
reusable way.
For programmers coming from languages like Haskell, OCaml, or
Scala, most of these things are already well known. What sets
Idris apart from these languages, is its support for first class
types: The ability to calculate types from values.
We will therefore spend some time looking at how we can
use dependent types to describe properties of and relations
(or contracts) between *values*, and how we can use values of
these dependent types as proofs that our functions behave
correctly.

```idris
module Tutorial.Relations

import Data.Either
import Data.Vect
import Data.String

%default total
```

## Equality as a Type

In the first section of this chapter we saw, how dependent pairs
and records can be used to calculate *types* from values only known
at runtime by pattern matching on these values. We will now look
at how we can describe relations - or *contracts* - between
values as types, and how we can use values of these types as
proofs that the contracts hold.

Imagine, we'd like to concatenate two strands of nucleobases
of unknown source. We can't do the following without risk
of having to drop all uracile and thymine bases in the
second strand, as we will never convince the type checker
that `b1` and `b2` are identical.

```idris
data BaseType = DNABase | RNABase

data Nucleobase : BaseType -> Type where
  Adenine  : Nucleobase b
  Cytosine : Nucleobase b
  Guanine  : Nucleobase b
  Thymine  : Nucleobase DNABase
  Uracile  : Nucleobase RNABase

concatBases1 :  List (Nucleobase b1)
             -> List (Nucleobase b2)
             -> List (Nucleobase b1)
```

There problem with `concatBases` is, that `b1` and `b2` are erased
implicits and we can't inspect them at runtime. We can change that
and arrive at the following implementation:

```idris
concatBases2 :  {b1, b2 : _}
             -> List (Nucleobase b1)
             -> List (Nucleobase b2)
             -> Maybe (List $ Nucleobase b1)
concatBases2 {b1 = DNABase} {b2 = DNABase} xs ys = Just $ xs ++ ys
concatBases2 {b1 = RNABase} {b2 = RNABase} xs ys = Just $ xs ++ ys
concatBases2                               _  _  = Nothing
```

Once again, we could with a pattern match on unerased type
arguments (`b1` and `b2`) learn something about the types themselves.
It should therefore be straight forward to use `concatBases2`
with two strands of nucleic acids, the types of which are known
at runtime.

However, if we already know the types of nucleobases involved,
shouldn't it be possible to establish their equivalence in advance
*before* even invoking `concatBase2`? For instance, in the
following we and Idris know, that we're dealing with two
DNA sequences, because thymine makes an appearance in both,
and yet, we still get a `Maybe` as a result, which we are
then forced to carry around in future computations.

One could argue that in a case as described above, we could
just use `(++)` directly, but `Maybe` as a return type can
still be annoying, especially if we already established a
proof that the `Nothing` case can't happen.

### A Type for Equivalent Base Types

Idris, being dependently typed, allows us to encode
relations between values as new types and use values
of these types as a proof that the relation holds. Here is
a type, the values of which will serve as a proof that the
two `BaseType` indices are identical:

```idris
data SameBT : (b1 : BaseType) -> (b2 : BaseType) -> Type where
  Same : (b1 : BaseType) -> SameBT b1 b1
```

In order to understand what's going on here, we need to look
at several examples. First note, that `SameBT DNABase DNABase` is
a *type*, and we can define a constant with this type:

```idris
sameDNA : SameBT DNABase DNABase
sameDNA = Same DNABase
```

Likewise for `RNABase`:

```idris
sameRNA : SameBT RNABase RNABase
sameRNA = Same RNABase
```

Now, here is an interesting case: Even `SameBT RNABase DNABase` is
a type:

```repl
Tutorial.Relations> :t SameBT RNABase DNABase
SameBT RNABase DNABase : Type
```

But *there is no value of this type*. You will not be able to
implement the following constant in a provably total way:

```idris
sameRNA_DNA : SameBT RNABase DNABase
```

The problem is, that `SameBT` has only one constructor, which will
take a single `BaseType` argument and use this argument as the
value of both its indices. But this is exactly what we want: We
want to limit the possible pairings of base types to only those
cases where the two values are identical.

We can now use a value of type `SameBT b1 b2` as a *proof* that
`b1` and `b2` are identical. This allows us to drop the `Maybe`
in `concatBases`:

```idris
concatBases :  SameBT b1 b2
            -> List (Nucleobase b1)
            -> List (Nucleobase b2)
            -> List (Nucleobase b1)
concatBases (Same _) xs ys = xs ++ ys
```

Actually, since we are not *really* pattern matching on the
`SameBT` value (it has only a single constructor, and we
are not using the wrapped value any further), we can use
the `SameBT` proof as an erased argument:

```idris
concatBases0 :  (0 _ : SameBT b1 b2)
             -> List (Nucleobase b1)
             -> List (Nucleobase b2)
             -> List (Nucleobase b1)
concatBases0 (Same _) xs ys = xs ++ ys
```

It is important to note, that the pattern match on the
`SameBT` proof is necessary, otherwise, `b1` and `b2`
won't unify. We can see this, by inserting a hole and
inspecting the types at the REPL:

```idris
concatBasesHole1 :  (0 _ : SameBT b1 b2)
                 -> List (Nucleobase b1)
                 -> List (Nucleobase b2)
                 -> List (Nucleobase b1)
concatBasesHole1 prf xs ys = ?cbh1
```

By inspecting the type of `cbh1` at the REPL, we see that
Idris still treats `prf` as an erased value of type
`SameBT b1 b2` without having a clue that this leads
to the conclusion that `b1` and `b2` are identical:

```repl
Tutorial.Relations> :t cbh1
 0 b2 : BaseType
 0 b1 : BaseType
   ys : List (Nucleobase b2)
   xs : List (Nucleobase b1)
 0 prf : SameBT b1 b2
------------------------------
cbh1 : List (Nucleobase b1)
```

Consider now the version with an explicit pattern match
on `prf`:

```idris
concatBasesHole2 :  (0 _ : SameBT b1 b2)
                 -> List (Nucleobase b1)
                 -> List (Nucleobase b2)
                 -> List (Nucleobase b1)
concatBasesHole2 (Same b1) xs ys = ?cbh2
```

First, note that Idris accepts this as being valid and
provably total, because `SameBT` has only a single
data constructor and we don't use the wrapped value `b1`
anywhere else. Second, the type of `Same b1` is
`SameBT b1 b1`, which follows from the definition of `Same`.
But this means that `b1` and `b2` unify, because that's
what was stated in the type of `concatBasesHole2`. Indeed,
this can be seen when inspecting the context of `cbh2` at
the REPL:

```repl
Tutorial.Relations> :t cbh2
 0 b1 : BaseType
   ys : List (Nucleobase b1)
   xs : List (Nucleobase b1)
 0 b2 : BaseType
------------------------------
cbh2 : List (Nucleobase b1)
```

## Programs as Proofs

<!-- vi: filetype=idris2
-->
