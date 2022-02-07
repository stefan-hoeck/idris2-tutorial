# Dependent Records

```idris
module Tutorial.DPair

import Data.DPair
import Data.Either
import Data.Singleton
import Data.String
import Data.Vect

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
in a type. The answer to this is: "Use a *dependent pair*", a vector
paired with a value corresponding to its length.

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
to describe existentially quantified values. Callers cannot choose
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
out what dependent pairs are about: They pair a *value* of some type with
a second value of a type calculated from the first value.
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
with first class types:

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

### Erased Existentials

Sometimes, it is possible to determine the value of an
index by pattern matching on a value of the indexed type.
For instance, by pattern matching on a vector, we can learn
about its length index. In these cases, it is not strictly
necessary to carry around the index at runtime,
and we can write a special version of a dependent pair
where the first argument has quantity zero. Module `Data.DPair`
from *base* exports data type `Exists` for this use case.

As an example, here is a version of `takeWhile` returning
a value of type `Exists`:

```idris
takeWhileExists : (a -> Bool) -> Vect m a -> Exists (\n => Vect n a)
takeWhileExists f []        = Evidence _ []
takeWhileExists f (x :: xs) = case f x of
  True  => let Evidence _ ys = takeWhileExists f xs
           in Evidence _ (x :: ys)
  False => takeWhileExists f xs
```

In order to restore an erased value, data type `Data.Singleton`
from *base* can be useful: It is parameterized by the *value*
it stores:

```idris
true : Singleton True
true = Val True
```

This is called a *singleton* type: A type corresponding to
exactly one value. It is a type error to return any other
value for constant `true`, and Idris knows this:

```idris
true' : Singleton True
true' = Val _
```

We can use this to conjure the (erased!) length of a vector
out of thin air:

```idris
vectLength : Vect n a -> Singleton n
vectLength []        = Val 0
vectLength (x :: xs) = let Val k = vectLength xs in Val (S k)
```

This function comes with much stronger guarantees
than `Data.Vect.length`: The latter claims to just return
*any* natural number, while `vectLength` *must* return
exactly `n` in order to type check. As a demonstration,
here is a well-typed bogus implementation of `length`:

```idris
bogusLength : Vect n a -> Nat
bogusLength = const 0
```

This would not be accepted as a valid implementation of
`vectLength`, as you may quickly verify yourself.

With the help of `vectLength` (but not with `Data.Vect.length`)
we can convert an erased existential to a proper dependent
pair:

```idris
toDPair : Exists (\n => Vect n a) -> (m ** Vect m a)
toDPair (Evidence _ as) = let Val m = vectLength as in (m ** as)
```

Again, as a quick exercise, try implementing `toDPair` in terms
of `length`, and note how Idris will fail to unify the
result of `length` with the actual length of the vector.

### Exercises part 1

1. Declare and implement a function for filtering a
   vector similar to `Data.List.filter`.

2. Declare and implement a function for mapping a partial
   function over the values of a vector similar
   to `Data.List.mapMaybe`.

3. Declare and implement a function similar to
   `Data.List.dropWhile` for vectors. Use `Data.DPair.Exists`
   as your return type.

4. Repeat exercise 3 but return a proper dependent pair. Use
   the function from exercise 3 in your implementation.

## Use Case: Nucleic Acids

We'd like to come up with a small, simplified library for running computations
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

encode : List (Nucleobase b) -> String
encode = pack . map encodeBase
  where encodeBase : Nucleobase c -> Char
        encodeBase Adenine  = 'A'
        encodeBase Cytosine = 'C'
        encodeBase Guanine  = 'G'
        encodeBase Thymine  = 'T'
        encodeBase Uracile  = 'U'
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

This has all possible outcomes encoded in a single data type.
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

readAcid : (b : BaseType) -> String -> Either InputError (List $ Nucleobase b)
readAcid b str =
  let err = InvalidSequence str
   in case b of
        DNABase => maybeToEither err $ readDNA str
        RNABase => maybeToEither err $ readRNA str

getNucleicAcid : IO (Either InputError (b ** List (Nucleobase b)))
getNucleicAcid = do
  baseString <- getLine
  case baseString of
    "DNA" => map (MkDPair _) . readAcid DNABase <$> getLine
    "RNA" => map (MkDPair _) . readAcid RNABase <$> getLine
    _     => pure $ Left (UnknownBaseType baseString)
```

Note, how we paired the type of nucleobase with nucleic acid
strand. Assume now, we implement a function for transcribing
a strand of DNA to RNA, and we'd like to convert a sequence of
nucleobases from user input to the corresponding RNA sequence.
Here's how to do this:

```idris
transcribeBase : Nucleobase DNABase -> Nucleobase RNABase
transcribeBase Adenine  = Uracile
transcribeBase Cytosine = Guanine
transcribeBase Guanine  = Cytosine
transcribeBase Thymine  = Adenine

transcribe : DNA -> RNA
transcribe = map transcribeBase

printRNA : RNA -> IO ()
printRNA = putStrLn . encode

transcribeProg : IO ()
transcribeProg = do
  Right (b ** seq) <- getNucleicAcid
    | Left (InvalidSequence str) => putStrLn $ "Invalid sequence: " ++ str
    | Left (UnknownBaseType str) => putStrLn $ "Unknown base type: " ++ str
  case b of
    DNABase => printRNA $ transcribe seq
    RNABase => printRNA seq
```

By pattern matching on the first value of the dependent pair, we could
determine, whether the second value is a list of RNA bases or
a list of DNA bases. In the first case, we had to transcribe the
sequence first, in the second case, we could invoke `printRNA` directly.

### Dependent Records vs Sum Types

Dependent records as shown for `AnyVect a` are a generalization
of dependent pairs: We can have an arbitrary number of fields
and use the values stored therein to calculate the types of
other values. For very simple cases like the example with nucleobases,
it doesn't matter too mach, whether we use a `DPair`, a custom
dependent record, or even a sum type. In fact, the three encodings
are equally expressive:

```idris
Nucleobase1 : Type
Nucleobase1 = (b ** List (Nucleobase b))

record Nucleobase2 where
  constructor MkNucleobase
  baseType : BaseType
  sequence : List (Nucleobase baseType)

data Nucleobase3 : Type where
  SomeRNA : RNA -> Nucleobase3
  SomeDNA : DNA -> Nucleobase3
```

It is trivial to write lossless conversions between these
encodings, and with each encoding we can decide with a simple
pattern match, whether we currently have a sequence of
RNA or DNA. However, dependent types can depend on more than
one value, as we will see in the exercises. In such cases,
sum types and dependent pairs quickly become unwieldy, and
you should go for an encoding as a dependent record.

### Exercises part 2

Sharpen your skills in using dependent pairs and dependent
records! In exercises 2 to 7 you have to decide yourself,
when a function should return a dependent pair or record,
when a function requires additional arguments, on which you
can pattern match, and what other utility functions might be
necessary.

1. Proof that the three encodings for nucleobases are *isomorphic*
   (meaning: of the same structure) by writing lossless conversion
   functions from `Nucleobase1` to `Nucleobase2` and back. Likewise
   for `Nucleobase1` and `Nucleobase3`.

2. Sequences of nucleobases can be encoded in one of two directions:
   [*Sense* and *antisense*](https://en.wikipedia.org/wiki/Sense_(molecular_biology))
   Declare a new data type to describe
   the sense of a sequence of nucleobases, and add this as an
   additional parameter to type `Nucleobase` and types `DNA` and
   `RNA`.

3. Refine the types of `complement` and `transcribe`, so that they
   reflect the changing of *sense*. In case of `transcribe`, a
   strand of antisense DNA is converted to a strand of sense RNA.

4. Define a dependent record storing the base type and sense
   together with a sequence of nucleobases.

5. Adjust `readRNA` and `readDNA` in such a way that
   the *sense* of a sequence is read from the input string.
   Sense strands are encoded like so: "5´-CGGTAG-3´". Antisense
   strands are encoded like so: "3´-CGGTAG-5´".

6. Adjust `encode` in such a way that it includes the sense
   in its output.

7. Enhance `getNucleicAcid` and `transcribeProg` in such a way that
   the sense and base type are stored together with the sequence,
   and that `transcribeProg` always prints the antisense RNA strand
   after transcription.

8. Enjoy the fruits of your labour and test your program at the REPL.

Note: Instead of using a dependent record, we could again
have used a sum type of four constructors to encode the different
types of sequences. However, the number of constructors
required corresponds to the *product* of the number of values
of each type level tag. Therefore, this number can grow quickly
and lead to lengthy blocks of pattern matches when encoded as
a sum type.

## Use Case: CSV Files with a Schema

<!-- vi: filetype=idris2
-->
