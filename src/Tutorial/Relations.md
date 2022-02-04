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

import Data.Vect
import Data.String

%default total
```

## Dependent Pairs

We've already seen several examples of how useful the length
index of a vector is to describe more precisely in the types what
a function can and can't do. For instance, `map` or `traverse`
operating on a vector will return a vector of exactly
the same length. The types guarantee that this is true, therefore
the following function is perfectly safe and provably total:

```idris
parseAndDrop : Vect (3 + n) String -> Maybe (Vect n Nat)
parseAndDrop = map (drop 3) . traverse parsePositive
```

Since the argument of `traverse parsePositive`
is of type `Vect (3 + n) String`, its result will be of
type `Maybe (Vect (3 + n) Nat)`. It is therefore
safe to use this in a call to `drop 3`. Note, how all of this
is known at compile time: We encoded the prerequisite
that the first argument is a vector of at least three elements
in the length index and could derive the length
of the result from this.

### Vectors of Unknown Length

However, this is not always possible. Consider the following function,
defined on `List` and exported by `Data.List`:

```repl
Tutorial.Relations> :t takeWhile
Data.List.takeWhile : (a -> Bool) -> List a -> List a
```

This will take the longest prefix of the list argument, for which
the given predicate returns `True`. In this case, it depends on
the list elements and the predicate, how long this prefix will be.
Can we write such a function for vectors? Let's give it a try:

```idris
takeWhile' : (a -> Bool) -> Vect n a -> Vect m a
```

Go ahead, and try to implement this. Don't try too long, as you will not
be able to do so in a provably total way. The question is: What is the
problem here?
In order to understand this, we have to realize what the type of `takeWhile'`
promises: "For all predicates operating on values on type `a`, and for
all vectors holding values of this type, and for all lengths `m`, I
give you a vector of length `m` holding values of type `a`".
All three arguments are said to be
[*universally quantified*](https://en.wikipedia.org/wiki/Universal_quantification):
The caller of our function is free to choose the predicate,
the input vector, the type of values the vector holds,
and *the length of the output vector*. Don't believe me? See here:

```idris
-- This looks like trouble: We got a non-empty vector of `Void`...
voids : Vect 7 Void
voids = takeWhile' (const True) []

-- ...from which immediately follows a proof of `Void`
proofOfVoid : Void
proofOfVoid = head voids
```

See how I could freely decide on the value of `m` when invoking `takeWhile'`?
Although I passed `takeWhile'` an empty vector (the only existing vector
holding values of type `Void`), the function's type promises me
to return a possibly non-empty vector holding values of the same
type, from which I freely extracted the first one.

Luckily, Idris doesn't allow this: We won't be able to
implement `takeWhile'` without cheating (for instance, by
turning totality checking off and looping forever).
So, the question remains, how to express the result of `takeWhile'`
in a type. The answer to this is: "Use a *dependent pair*". A vector
paired with a value corresponding to its length:

```idris
record AnyVect a where
  constructor MkAnyVect
  length : Nat
  vect   : Vect length a
```

This corresponds to [*existential quantification*](https://en.wikipedia.org/wiki/Existential_quantification)
in predicate logic: There is a natural number, which corresponds to
the length of the vector I have here. Note, how from the outside
of `AnyVect a`, the length of the wrapped vector is no longer
visible at the type level but we can still inspect it and learn
something about it at runtime, since it is wrapped up together
with the actual vector. We can implement `takeWhile` in such
a way that it returns a value of type `AnyVect a`:

```idris
takeWhile : (a -> Bool) -> Vect n a -> AnyVect a
takeWhile f []        = MkAnyVect 0 []
takeWhile f (x :: xs) = case f x of
  False => MkAnyVect 0 []
  True  => let MkAnyVect n ys = takeWhile f xs in MkAnyVect (S n) (x :: ys)
```

This works in a provably total way, because callers of this function
can no longer choose the length of the resulting vector themselves. Our
function, `takeWhile`, decides on this length and returns it together
with the vector, and the type checker verifies that we
make no mistakes when pairing the two values. In fact,
the length can be inferred automatically by Idris, so we can replace
it with underscores, if we so desire:

```idris
takeWhile2 : (a -> Bool) -> Vect n a -> AnyVect a
takeWhile2 f []        = MkAnyVect _ []
takeWhile2 f (x :: xs) = case f x of
  False => MkAnyVect 0 []
  True  => let MkAnyVect _ ys = takeWhile2 f xs in MkAnyVect _ (x :: ys)
```

To summarize: Parameters in generic function types are
universally quantified, and their values can be decided on at the
call site of such functions. Dependent record types allow us
to describe existentially quantify values. Callers can not choose
such values freely: They are returned as part of a function's result.

Note, that Idris allows us to be explicit about universal quantification.
The type of `takeWhile'` can also be written like so:

```idris
takeWhile'' : forall a, n, m . (a -> Bool) -> Vect n a -> Vect m a
```

Universally quantified arguments are desugared to implicit
erased arguments by Idris. The above is a less verbose version
of the following function type, the likes of which we have seen
before:

```idris
takeWhile''' :  {0 a : _}
             -> {0 n : _}
             -> {0 m : _}
             -> (a -> Bool)
             -> Vect n a
             -> Vect m a
```

In Idris, we are free to choose whether we want to be explicit
about universal quantification. Sometimes it can help understanding
what's going on at the type level. Other languages - for instance
[PureScript](https://www.purescript.org/) - are more strict about
this: There, explicit annotations on universally quantified parameters
are [mandatory](https://github.com/purescript/documentation/blob/master/language/Differences-from-Haskell.md#explicit-forall).

### The Essence of Dependent Pairs

It can take some time and experience to understand what's going on here. At
least in my case, it took many sessions programming in Idris, before I figured
out what dependent pairs are about: They pair a *value* of some type with a
a value of another type, which was calculated from the first value.
For instance, a natural number `n` (the value)
paired with a vector of length `n` (the second value, who's type *depends*
on the first value).

This is such a fundamental concept of programming with dependent types, that
a general dependent pair type is provided by the *Prelude*. Here is its
implementation (primed for disambiguation):

```idris
record DPair' (a : Type) (p : a -> Type) where
  constructor MkDPair'
  fst : a
  snd : p fst
```

It is essential to understand what's going on here. There are two
parameters: A type `a`, and a function `p`, calculating a *type*
from a *value* of type `a`. Such a value (`fst`) is then used
to calculate the *type* of the second value (`snd`).

For instance, here is `AnyVect a` represented as a `DPair`:

```idris
AnyVect' : (a : Type) -> Type
AnyVect' a = DPair Nat (\n => Vect n a)
```

Note, how `\x => Vect x a` is a function from `Nat` to `Type`.
Idris provides special syntax for describing dependent pairs, as
they are important building blocks for programming in languages
with first class type:

```idris
AnyVect'' : (a : Type) -> Type
AnyVect'' a = (n : Nat ** Vect n a)
```

We can inspect at the REPL, that the right hand side of `AnyVect''`
get's desugared to the right hand side of `AnyVect'`:

```repl
Tutorial.Relations> (n : Nat ** Vect n Int)
DPair Nat (\n => Vect n Int)
```

Idris can infer, that `n` must be of type `Nat`, so we can drop
this information. (We still need to put the whole expression in
parentheses.)

```idris
AnyVect3 : (a : Type) -> Type
AnyVect3 a = (n ** Vect n a)
```

This allows us to pair a natural number `n` with a vector of
length `n`, which is exactly what we did with `AnyVect`. We can
therefore rewrite `takeWhile` to return a `DPair` instead of
our custom type `AnyVect`. Note, that like with regular pairs,
we can use the same syntax `(x ** y)` for creating and
pattern matching on dependent pairs:

```idris
takeWhile3 : (a -> Bool) -> Vect m a -> (n ** Vect n a)
takeWhile3 f []        = (_ ** [])
takeWhile3 f (x :: xs) = case f x of
  False => (_ ** [])
  True  => let (_  ** ys) = takeWhile3 f xs in (_ ** x :: ys)
```

### Use Case: Nucleic Acids

We'd like to come up with a small library for running computations
on nucleic acids: RNA and DNA. These are built from five types of
nucleobases, three of which are used in both types of nucleic
acids and two bases specific for each type of acid. We'd like
to make sure that only valid bases are in strands of nucleic acids.
Here's a possible encoding:

```idris
data BaseType = DNABase | RNABase

data Nucleobase : BaseType -> Type where
  Adenine  : Nucleobase b
  Cytosine : Nucleobase b
  Guanine  : Nucleobase b
  Thymine  : Nucleobase DNABase
  Uracile  : Nucleobase RNABase

RNA : Type
RNA = List (Nucleobase RNABase)

DNA : Type
DNA = List (Nucleobase DNABase)
```

It is a type error to use `Uracile` in a strand of DNA:

```repl
Tutorial.Relations> the DNA [Uracile,Adenine]
Error: When unifying:
    Nucleobase RNABase
and:
    Nucleobase DNABase
Mismatch between: RNABase and DNABase.

(Interactive):1:10--1:17
 1 | the DNA [Uracile,Adenine]
```

Note, how we used a variable for nucleobases `Adenine`, `Cytosine`, and
`Guanine`: Client code is free to choose a value here. This allows us
to use these bases in strands of DNA *and* RNA:

```idris
dna1 : DNA
dna1 = [Adenine, Cytosine, Guanine]

rna1 : RNA
rna1 = [Adenine, Cytosine, Guanine]
```

With `Thymine` and `Uracile`, we are more restrictive: `Thymine` is only
allowed in DNA, while `Uracile` is restricted to be used in RNA strands.
Let's write parsers for strands of DNA and RNA:

```idris
readAnyBase : Char -> Maybe (Nucleobase b)
readAnyBase 'A' = Just Adenine
readAnyBase 'C' = Just Cytosine
readAnyBase 'G' = Just Guanine
readAnyBase _   = Nothing

readRNABase : Char -> Maybe (Nucleobase RNABase)
readRNABase 'U' = Just Uracile
readRNABase c   = readAnyBase c

readDNABase : Char -> Maybe (Nucleobase DNABase)
readDNABase 'T' = Just Thymine
readDNABase c   = readAnyBase c

readRNA : String -> Maybe RNA
readRNA = traverse readRNABase . unpack

readDNA : String -> Maybe DNA
readDNA = traverse readDNABase . unpack
```

Again, in case of the bases appearing in both kinds of strands,
users of `readAnyBase` are free to choose what base type they want.

We can now implement some simple calculation on sequences of
nucleobases. For instance, we can come up with the complementary
strand:

```idris
complementRNA' : RNA -> RNA
complementRNA' = map calc
  where calc : Nucleobase RNABase -> Nucleobase RNABase
        calc Guanine  = Cytosine
        calc Cytosine = Guanine
        calc Adenine  = Uracile
        calc Uracile  = Adenine

complementDNA' : DNA -> DNA
complementDNA' = map calc
  where calc : Nucleobase DNABase -> Nucleobase DNABase
        calc Guanine  = Cytosine
        calc Cytosine = Guanine
        calc Adenine  = Thymine
        calc Thymine  = Adenine
```

Ugh, code repetition! Not too bad here, but imagine there were
dozens of bases with only few specialized ones. Surely, we can
do better? Unfortunately, the following won't work:

```idris
complementBase' : Nucleobase b -> Nucleobase b
complementBase' Adenine  = ?what_now
complementBase' Cytosine = Guanine
complementBase' Guanine  = Cytosine
complementBase' Thymine  = Adenine
complementBase' Uracile  = Adenine
```

All goes well with the exception of the `Adenine` case. Remember:
The *callers* of our function can decide what `b` is supposed to
be. We therefore can't just return `Thymine`: Idris will respond
with a type error since callers might want a `Nucleobase RNABase` instead.
One way to go about this is to take an additional (unerased) argument
representing the base type:

```idris
complementBase : (b : BaseType) -> Nucleobase b -> Nucleobase b
complementBase DNABase Adenine  = Thymine
complementBase RNABase Adenine  = Uracile
complementBase _       Cytosine = Guanine
complementBase _       Guanine  = Cytosine
complementBase _       Thymine  = Adenine
complementBase _       Uracile  = Adenine
```

This is again an example of a dependent type: The input and
output types both *depend* on the *value* of the first argument.
We can now use this to calculate the complement of any
nucleic acid:

```idris
complement : (b : BaseType) -> List (Nucleobase b) -> List (Nucleobase b)
complement b = map (complementBase b)
```

Now, here is an interesting use case: We'd like to read a sequence
of a nucleobase from user input, accepting two strings: The first
telling us, whether the user plans to enter a DNA or RNA sequence,
the second being the sequence itself. What should be the type of
such a function? Well, we're describing computations with side effect,
so something involving `IO` seems about right. User input almost
always needs to be validated or translated, so something might go wrong
and we need an error type for this case. Finally, our users can
decide whether they want to enter a strand of RNA or DNA, so this
distinction should be encoded as well.

Of course, it is always possible to write a custom sum type for
such a use case:

```idris
data Result : Type where
  UnknownBaseType : String -> Result
  InvalidSequence : String -> Result
  GotDNA          : DNA -> Result
  GotRNA          : RNA -> Result
```

This has all possible outcomes are encoded in a single data type.
However, it is lacking in terms of flexibility. If we want to handle
errors early on and just extract a strand of RNA or DNA, we need
yet another data type:

```idris
data RNAOrDNA = ItsRNA RNA | ItsDNA DNA
```

This might be the way to go, but for results with many options, this
can get cumbersome quickly. Also: Why come up with a new data type when
we already have the tools to deal with this?

Here is how we can encode this with a dependent pair:

```idris
namespace InputError
  public export
  data InputError : Type where
    UnknownBaseType : String -> InputError
    InvalidSequence : String -> InputError

readNucleobase : IO (Either InputError (b ** List (Nucleobase b)))
readNucleobase = do
  baseString <- getLine
  case baseString of
    "DNA" => do
      strand <- getLine
      pure $ maybe (Left $ InvalidSequence strand)
                   (\v => Right (DNABase ** v))
                   (readDNA strand)
    "RNA" => do
      strand <- getLine
      pure $ maybe (Left $ InvalidSequence strand)
                   (\v => Right (RNABase ** v))
                   (readRNA strand)

    _     => pure $ Left (UnknownBaseType baseString)
```

<!-- vi: filetype=idris2
-->
