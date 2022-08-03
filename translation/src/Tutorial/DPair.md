# Sigma Types

So far in our examples of dependently typed programming,
type indices such as the length of vectors were known at
compile time or could be calculated from values known at
compile time. In real applications, however, such information is
often not available until runtime, where values depend on
the decisions made by users or the state of the surrounding world.
For instance, if we store a file's content as a vector of lines
of text, the length of this vector is in general unknown until
the file has been loaded into memory.
As a consequence, the types of values we work with depend on
other values only known at runtime, and we can often only figure out
these types by pattern matching on the values they depend on.
To express these dependencies, we need so called
[*sigma types*](https://en.wikipedia.org/wiki/Dependent_type#%CE%A3_type):
Dependent pairs and their generalization, dependent records.

```idris
module Tutorial.DPair

import Control.Monad.State

import Data.DPair
import Data.Either
import Data.HList
import Data.List
import Data.List1
import Data.Singleton
import Data.String
import Data.Vect

import Text.CSV

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
paired with a vector of length `n` (the second value, the type
of which *depends* on the first value).
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

Note, how `\n => Vect n a` is a function from `Nat` to `Type`.
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

Just like with regular pairs, we can use the dependent pair
syntax to define dependent triples and larger tuples:

```idris
AnyMatrix : (a : Type) -> Type
AnyMatrix a = (m ** n ** Vect m (Vect n a))
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

In order to restore an erased value, data type `Singleton`
from *base* module `Data.Singleton` can be useful: It is
parameterized by the *value* it stores:

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

### 练习第 1 部分

1. Declare and implement a function for filtering a vector similar to
   `Data.List.filter`.

2. Declare and implement a function for mapping a partial function over the
   values of a vector similar to `Data.List.mapMaybe`.

3. Declare and implement a function similar to `Data.List.dropWhile` for
   vectors. Use `Data.DPair.Exists` as your return type.

4. Repeat exercise 3 but return a proper dependent pair. Use the function
   from exercise 3 in your implementation.

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

NucleicAcid : BaseType -> Type
NucleicAcid = List . Nucleobase

RNA : Type
RNA = NucleicAcid RNABase

DNA : Type
DNA = NucleicAcid DNABase

encodeBase : Nucleobase b -> Char
encodeBase Adenine  = 'A'
encodeBase Cytosine = 'C'
encodeBase Guanine  = 'G'
encodeBase Thymine  = 'T'
encodeBase Uracile  = 'U'

encode : NucleicAcid b -> String
encode = pack . map encodeBase
```

It is a type error to use `Uracile` in a strand of DNA:

```idris
failing "Mismatch between: RNABase and DNABase."
  errDNA : DNA
  errDNA = [Uracile, Adenine]
```

Note, how we used a variable for nucleobases `Adenine`, `Cytosine`, and
`Guanine`: These are again universally quantified,
and client code is free to choose a value here. This allows us
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
users of the universally quantified `readAnyBase`
are free to choose what base type they want, but they will
never get a `Thymine` or `Uracile` value.

We can now implement some simple calculations on sequences of
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
Parameter `b` is universally quantified, and the *callers* of
our function can decide what `b` is supposed to
be. We therefore can't just return `Thymine`: Idris will respond
with a type error since callers might want a `Nucleobase RNABase` instead.
One way to go about this is to take an additional unerased argument
(explicit or implicit) representing the base type:

```idris
complementBase : (b : BaseType) -> Nucleobase b -> Nucleobase b
complementBase DNABase Adenine  = Thymine
complementBase RNABase Adenine  = Uracile
complementBase _       Cytosine = Guanine
complementBase _       Guanine  = Cytosine
complementBase _       Thymine  = Adenine
complementBase _       Uracile  = Adenine
```

This is again an example of a dependent *function* type (also called a
[*pi type*](https://en.wikipedia.org/wiki/Dependent_type#%CE%A0_type)):
The input and output types both *depend* on the *value* of the first argument.
We can now use this to calculate the complement of any nucleic acid:

```idris
complement : (b : BaseType) -> NucleicAcid b -> NucleicAcid b
complement b = map (complementBase b)
```

Now, here is an interesting use case: We'd like to read a sequence
of nucleobases from user input, accepting two strings: The first
telling us, whether the user plans to enter a DNA or RNA sequence,
the second being the sequence itself. What should be the type of
such a function? Well, we're describing computations with side effects,
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
can get cumbersome quickly. Also: Why come up with a custom data type when
we already have the tools to deal with this at our hands?

Here is how we can encode this with a dependent pair:

```idris
namespace InputError
  public export
  data InputError : Type where
    UnknownBaseType : String -> InputError
    InvalidSequence : String -> InputError

readAcid : (b : BaseType) -> String -> Either InputError (NucleicAcid b)
readAcid b str =
  let err = InvalidSequence str
   in case b of
        DNABase => maybeToEither err $ readDNA str
        RNABase => maybeToEither err $ readRNA str

getNucleicAcid : IO (Either InputError (b ** NucleicAcid b))
getNucleicAcid = do
  baseString <- getLine
  case baseString of
    "DNA" => map (MkDPair _) . readAcid DNABase <$> getLine
    "RNA" => map (MkDPair _) . readAcid RNABase <$> getLine
    _     => pure $ Left (UnknownBaseType baseString)
```

Note, how we paired the type of nucleobases with the nucleic acid
sequence. Assume now we implement a function for transcribing
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

By pattern matching on the first value of the dependent pair we could
determine, whether the second value is an RNA or DNA sequence.
In the first case, we had to transcribe the
sequence first, in the second case, we could invoke `printRNA` directly.

In a more interesting scenario, we would *translate* the RNA sequence
to the corresponding protein sequence. Still, this example shows
how to deal with a simplified real world scenario: Data may be
encoded differently and coming from different sources. By using precise
types, we are forced to first convert values to the correct
format. Failing to do so leads to a compile time exception instead of
an error at runtime or - even worse - the program silently running
a bogus computation.

### Dependent Records vs Sum Types

Dependent records as shown for `AnyVect a` are a generalization
of dependent pairs: We can have an arbitrary number of fields
and use the values stored therein to calculate the types of
other values. For very simple cases like the example with nucleobases,
it doesn't matter too much, whether we use a `DPair`, a custom
dependent record, or even a sum type. In fact, the three encodings
are equally expressive:

```idris
Acid1 : Type
Acid1 = (b ** NucleicAcid b)

record Acid2 where
  constructor MkAcid2
  baseType : BaseType
  sequence : NucleicAcid baseType

data Acid3 : Type where
  SomeRNA : RNA -> Acid3
  SomeDNA : DNA -> Acid3
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

1. Proof that the three encodings for nucleobases are *isomorphic* (meaning:
   of the same structure) by writing lossless conversion functions from
   `Acid1` to `Acid2` and back. Likewise for `Acid1` and `Acid3`.

2. Sequences of nucleobases can be encoded in one of two directions:
   [*Sense* and
   *antisense*](https://en.wikipedia.org/wiki/Sense_(molecular_biology)).
   Declare a new data type to describe the sense of a sequence of
   nucleobases, and add this as an additional parameter to type `Nucleobase`
   and types `DNA` and `RNA`.

3. Refine the types of `complement` and `transcribe`, so that they reflect
   the changing of *sense*. In case of `transcribe`, a strand of antisense
   DNA is converted to a strand of sense RNA.

4. Define a dependent record storing the base type and sense together with a
   sequence of nucleobases.

5. Adjust `readRNA` and `readDNA` in such a way that the *sense* of a
   sequence is read from the input string.  Sense strands are encoded like
   so: "5Â´-CGGTAG-3Â´". Antisense strands are encoded like so:
   "3Â´-CGGTAG-5Â´".

6. Adjust `encode` in such a way that it includes the sense in its output.

7. Enhance `getNucleicAcid` and `transcribeProg` in such a way that the
   sense and base type are stored together with the sequence, and that
   `transcribeProg` always prints the *sense* RNA strand (after
   transcription, if necessary).

8. Enjoy the fruits of your labour and test your program at the REPL.

Note: Instead of using a dependent record, we could again
have used a sum type of four constructors to encode the different
types of sequences. However, the number of constructors
required corresponds to the *product* of the number of values
of each type level index. Therefore, this number can grow quickly
and sum type encodings can lead to lengthy blocks of pattern matches
in these cases.

## Use Case: CSV Files with a Schema

In this section, we are going to look at an extended example
based on our previous work on CSV parsers. We'd like to
write a small command-line program, where users can specify a
schema for the CSV tables they'd like to parse and load into
memory. Before we begin, here is a REPL session running
the final program, which you will complete in the exercises:

```repl
Solutions.DPair> :exec main
Enter a command: load resources/example
Table loaded. Schema: str,str,fin2023,str?,boolean?
Enter a command: get 3
Row 3:

str   | str    | fin2023 | str? | boolean?
------------------------------------------
Floor | Jansen | 1981    |      | t

Enter a command: add Mikael,Stanne,1974,,
Row prepended:

str    | str    | fin2023 | str? | boolean?
-------------------------------------------
Mikael | Stanne | 1974    |      |

Enter a command: get 1
Row 1:

str    | str    | fin2023 | str? | boolean?
-------------------------------------------
Mikael | Stanne | 1974    |      |

Enter a command: delete 1
Deleted row: 1.
Enter a command: get 1
Row 1:

str | str     | fin2023 | str? | boolean?
-----------------------------------------
Rob | Halford | 1951    |      |

Enter a command: quit
Goodbye.
```

This example was inspired by a similar program used as an example
in the [Type-Driven Development with Idris](https://www.manning.com/books/type-driven-development-with-idris)
book.

We'd like to focus on several things here:

* Purity: With the exception of the main program loop, all functions used in
  the implementation should be pure, which in this context means "not
  running in any monad with side effects such as `IO`".
* Fail early: With the exception of the command parser, all functions
  updating the table and handling queries should be typed and implemented in
  such a way that they cannot fail.

We are often well advised to adhere to these two guidelines, as they can
make the majority of our functions easier to implement and test.

Since we allow users of our library to specify a schema (order and
types of columns) for the table they work with, this information is
not known until runtime. The same goes for the current size of the
table. We will therefore store both values as fields in a
dependent record.

### Encoding the Schema

We need to inspect the table schema at runtime. Although theoretically
possible, it is not advisable to operate on Idris types directly here.
We'd rather use a closed custom data type describing the types of
columns we understand. In a first try, we only support some Idris
primitives:

```idris
data ColType = I64 | Str | Boolean | Float

Schema : Type
Schema = List ColType
```

Next, we need a way to convert a `Schema` to a list of Idris
types, which we will then use as the index of a heterogeneous
list representing the rows in our table:

```idris
IdrisType : ColType -> Type
IdrisType I64     = Int64
IdrisType Str     = String
IdrisType Boolean = Bool
IdrisType Float   = Double

Row : Schema -> Type
Row = HList . map IdrisType
```

We can now describe a table as a dependent record storing
the table's content as a vector of rows. In order to safely
index rows of the table and parse new rows to be added, the
current schema and size of the table must be known at runtime:

```idris
record Table where
  constructor MkTable
  schema : Schema
  size   : Nat
  rows   : Vect size (Row schema)
```

Finally, we define an indexed data type describing commands
operating on the current table. Using the current table as
the command's index allows us to make sure that indices for
accessing and deleting rows are within bounds and that
new rows agree with the current schema. This is necessary
to uphold our second design principle: All functions
operating on tables must do so without the possibility of failure.

```idris
data Command : (t : Table) -> Type where
  PrintSchema : Command t
  PrintSize   : Command t
  New         : (newSchema : Schema) -> Command t
  Prepend     : Row (schema t) -> Command t
  Get         : Fin (size t) -> Command t
  Delete      : Fin (size t) -> Command t
  Quit        : Command t
```

We can now implement the main application logic: How user
entered commands affect the application's current state. As promised,
this comes without the risk of failure, so we don't have to
wrap the return type in an `Either`:

```idris
applyCommand : (t : Table) -> Command t -> Table
applyCommand t                 PrintSchema = t
applyCommand t                 PrintSize   = t
applyCommand _                 (New ts)    = MkTable ts _ []
applyCommand (MkTable ts n rs) (Prepend r) = MkTable ts _ $ r :: rs
applyCommand t                 (Get x)     = t
applyCommand t                 Quit        = t
applyCommand (MkTable ts n rs) (Delete x)  = case n of
  S k => MkTable ts k (deleteAt x rs)
  Z   => absurd x
```

Please understand, that the constructors of `Command t` are typed
in such a way that indices are always within bounds (constructors
`Get` and `Delete`), and new rows adhere to the table's
current schema (constructor `Prepend`).

One thing you might not have seen so far is the call to `absurd`
on the last line. This is a derived function of the
`Uninhabited` interface, which is used to describe types such
as `Void` or - in the case above - `Fin 0`, of which there can
be no value. Function `absurd` is then just another manifestation
of the principle of explosion. If this doesn't make too much sense
yet, don't worry. We will look at `Void` and its uses in the
next chapter.

### Parsing Commands

User input validation is an important topic when writing
applications. If it happens early, you can keep larger parts
of your application pure (which - in this context - means:
"without the possibility of failure") and provably total.
If done properly, this step encodes and handles most if not all
ways in which things can go wrong in your program, allowing
you to come up with clear error messages telling users exactly what caused
an issue. As you surely have experienced yourself, there are few
things more frustrating than a non-trivial computer program terminating
with an unhelpful "There was an error" message.

So, in order to treat this important topic with all due respect,
we are first going to implement a custom error type. This is
not *strictly* necessary for small programs, but once your software
gets more complex, it can be tremendously helpful for keeping track
of what can go wrong where. In order to figure out what can possibly
go wrong, we first need to decide on how the commands should be entered.
Here, we use a single keyword for each command, together with an
optional number of arguments separated from the keyword by a single
space character. For instance: `"new i64,boolean,str,str"`,
for initializing an empty table with a new schema. With this settled,
here is a list of things that can go wrong, and the messages we'd
like to print:

* A bogus command is entered. We repeat the input with a message that we
  don't know the command plus a list of commands we know about.
* An invalid schema was entered. In this case, we list the position of the
  first unknown type, the string we found there, and a list of types we know
  about.
* An invalid CSV encoding of a row was entered. We list the erroneous
  position, the string encountered there, plus the expected type. In case of
  a too small or too large number of fields, we also print a corresponding
  error message.
* An index was out of bounds. This can happen, when users try to access or
  delete specific rows. We print the current number of rows plus the value
  entered.
* A value not representing a natural number was entered as an index.  We
  print an according error message.

That's a lot of stuff to keep track off, so let's encode this in
a sum type:

```idris
data Error : Type where
  UnknownCommand : String -> Error
  UnknownType    : (pos : Nat) -> String -> Error
  InvalidField   : (pos : Nat) -> ColType -> String -> Error
  ExpectedEOI    : (pos : Nat) -> String -> Error
  UnexpectedEOI  : (pos : Nat) -> String -> Error
  OutOfBounds    : (size : Nat) -> (index : Nat) -> Error
  NoNat          : String -> Error
```

In order to conveniently construct our error messages, it is best
to use Idris' string interpolation facilities: We can enclose
arbitrary string expressions in a string literal by enclosing
them in curly braces, the first of which must be escaped with
a backslash. Like so: `"foo \{myExpr a b c}"`.
We can pair this with multiline string literals to get
nicely formatted error messages.

```idris
showColType : ColType -> String
showColType I64      = "i64"
showColType Str      = "str"
showColType Boolean  = "boolean"
showColType Float    = "float"

showSchema : Schema -> String
showSchema = concat . intersperse "," . map showColType

allTypes : String
allTypes = concat
         . List.intersperse ", "
         . map showColType
         $ [I64,Str,Boolean,Float]

showError : Error -> String
showError (UnknownCommand x) = """
  Unknown command: \{x}.
  Known commands are: clear, schema, size, new, add, get, delete, quit.
  """

showError (UnknownType pos x) = """
  Unknown type at position \{show pos}: \{x}.
  Known types are: \{allTypes}.
  """

showError (InvalidField pos tpe x) = """
  Invalid value at position \{show pos}.
  Expected type: \{showColType tpe}.
  Value found: \{x}.
  """

showError (ExpectedEOI k x) = """
  Expected end of input.
  Position: \{show k}
  Input: \{x}
  """

showError (UnexpectedEOI k x) = """
  Unxpected end of input.
  Position: \{show k}
  Input: \{x}
  """

showError (OutOfBounds size index) = """
  Index out of bounds.
  Size of table: \{show size}
  Index: \{show index}
  Note: Indices start at 1.
  """

showError (NoNat x) = "Not a natural number: \{x}"
```

We can now write parsers for the different commands. We need facilities
to parse vector indices, schemata, and CSV rows.
Since we are using a CSV format for encoding
and decoding rows, it makes sense to also encode the schema
as a comma-separated list of values:

```idris
zipWithIndex : Traversable t => t a -> t (Nat, a)
zipWithIndex = evalState 1 . traverse pairWithIndex
  where pairWithIndex : a -> State Nat (Nat,a)
        pairWithIndex v = (,v) <$> get <* modify S

fromCSV : String -> List String
fromCSV = forget . split (',' ==)

readColType : Nat -> String -> Either Error ColType
readColType _ "i64"      = Right I64
readColType _ "str"      = Right Str
readColType _ "boolean"  = Right Boolean
readColType _ "float"    = Right Float
readColType n s          = Left $ UnknownType n s

readSchema : String -> Either Error Schema
readSchema = traverse (uncurry readColType) . zipWithIndex . fromCSV
```

We also need to decode CSV content based on the current schema.
Note, how we can do so in a type safe manner by pattern matching
on the schema, which will not be known until runtime. Unfortunately,
we need to reimplement CSV-parsing, because we want to add the
expected type to the error messages (a thing that would be
much harder to do with interface `CSVLine`
and error type `CSVError`).

```idris
decodeField : Nat -> (c : ColType) -> String -> Either Error (IdrisType c)
decodeField k c s =
  let err = InvalidField k c s
   in case c of
        I64     => maybeToEither err $ read s
        Str     => maybeToEither err $ read s
        Boolean => maybeToEither err $ read s
        Float   => maybeToEither err $ read s

decodeRow : {ts : _} -> String -> Either Error (Row ts)
decodeRow s = go 1 ts $ fromCSV s
  where go : Nat -> (cs : Schema) -> List String -> Either Error (Row cs)
        go k []       []         = Right []
        go k []       (_ :: _)   = Left $ ExpectedEOI k s
        go k (_ :: _) []         = Left $ UnexpectedEOI k s
        go k (c :: cs) (s :: ss) = [| decodeField k c s :: go (S k) cs ss |]
```

There is no hard and fast rule about whether to pass an index as an
implicit argument or not. Some considerations:

* Pattern matching on explicit arguments comes with less syntactic overhead.
* If an argument can be inferred from the context most of the time, consider
  passing it as an implicit to make your function nicer to use in client
  code.
* Use explicit (possibly erased) arguments for values that can't be inferred
  by Idris most of the time.

All that is missing now is a way to parse indices for accessing
the current table's rows. We use the conversion for indices to
start at one instead of zero, which feels more natural for most
non-programmers.

```idris
readFin : {n : _} -> String -> Either Error (Fin n)
readFin s = do
  S k <- maybeToEither (NoNat s) $ parsePositive {a = Nat} s
    | Z => Left $ OutOfBounds n Z
  maybeToEither (OutOfBounds n $ S k) $ natToFin k n
```

We are finally able to implement a parser for user commands.
Function `Data.String.words` is used for splitting a string
at space characters. In most cases, we expect the name of
the command plus a single argument without additional spaces.
CSV rows can have additional space characters, however, so we
use `Data.String.unwords` on the split string.

```idris
readCommand :  (t : Table) -> String -> Either Error (Command t)
readCommand _                "schema"  = Right PrintSchema
readCommand _                "size"    = Right PrintSize
readCommand _                "quit"    = Right Quit
readCommand (MkTable ts n _) s         = case words s of
  ["new",    str] => New     <$> readSchema str
  "add" ::   ss   => Prepend <$> decodeRow (unwords ss)
  ["get",    str] => Get     <$> readFin str
  ["delete", str] => Delete  <$> readFin str
  _               => Left $ UnknownCommand s
```

### Running the Application

All that's left to do is to write functions for
printing the results of commands to users and run
the application in a loop until command `"quit"`
is entered.

```idris
encodeField : (t : ColType) -> IdrisType t -> String
encodeField I64     x     = show x
encodeField Str     x     = show x
encodeField Boolean True  = "t"
encodeField Boolean False = "f"
encodeField Float   x     = show x

encodeRow : (ts : List ColType) -> Row ts -> String
encodeRow ts = concat . intersperse "," . go ts
  where go : (cs : List ColType) -> Row cs -> Vect (length cs) String
        go []        []        = []
        go (c :: cs) (v :: vs) = encodeField c v :: go cs vs

result :  (t : Table) -> Command t -> String
result t PrintSchema = "Current schema: \{showSchema t.schema}"
result t PrintSize   = "Current size: \{show t.size}"
result _ (New ts)    = "Created table. Schema: \{showSchema ts}"
result t (Prepend r) = "Row prepended: \{encodeRow t.schema r}"
result _ (Delete x)  = "Deleted row: \{show $ FS x}."
result _ Quit        = "Goodbye."
result t (Get x)     =
  "Row \{show $ FS x}: \{encodeRow t.schema (index x t.rows)}"

covering
runProg : Table -> IO ()
runProg t = do
  putStr "Enter a command: "
  str <- getLine
  case readCommand t str of
    Left err   => putStrLn (showError err) >> runProg t
    Right Quit => putStrLn (result t Quit)
    Right cmd  => putStrLn (result t cmd) >>
                  runProg (applyCommand t cmd)

covering
main : IO ()
main = runProg $ MkTable [] _ []
```

### Exercises part 3

The challenges presented here all deal with enhancing our
table editor in several interesting ways. Some of them are
more a matter of style and less a matter of learning to write
dependently typed programs, so feel free to solve these as you
please. Exercises 1 to 3 should be considered to be
mandatory.

1. Add support for storing Idris types `Integer` and `Nat` in CSV columns

2. Add support for `Fin n` to CSV columns. Note: We need runtime access to
   `n` in order for this to work.

3. Add support for optional types to CSV columns. Since missing values
   should be encoded by empty strings, it makes no sense to allow for nested
   optional types, meaning that types like `Maybe Nat` should be allowed
   while `Maybe (Maybe Nat)` should not.

   Hint: There are several ways to encode these, one being
   to add a boolean index to `ColType`.

4. Add a command for printing the whole table. Bonus points if all columns
   are properly aligned.

5. Add support for simple queries: Given a column number and a value, list
   all rows where entries match the given value.

   This might be a challenge, as the types get pretty interesting.

6. Add support for loading and saving tables from and to disk.  A table
   should be stored in two files: One for the schema and one for the CSV
   content.

   Note: Reading files in a provably total way can be pretty
   hard and will be a topic for another day. For now,
   just use function `readFile` exported from
   `System.File` in base for reading a file as a whole.
   This function is partial, because
   it will not terminate when used with an infinite input
   stream such as `/dev/urandom` or `/dev/zero`.
   It is important to *not* use `assert_total` here.
   Using partial functions like `readFile` might well impose
   a security risk in a real world application, so eventually,
   we'd have to deal with this and allow for some way to
   limit the size of accepted input. It is therefore best
   to make this partiality visible and annotate all downstream
   functions accordingly.

You can find an implementation of these additions in the
solutions. A small example table can be found in folder
`resources`.

Note: There are of course tons of projects to pursue from
here, such as writing a proper query language, calculating
new rows from existing ones, accumulating values in a
column, concatenating and zipping tables, and so on.
We will stop for now, probably coming back to this in
later examples.

## 结论

Dependent pairs and records are necessary to at runtime
inspect the values defining the types we work with. By pattern
matching on these values, we learn about the types and
possible shapes of other values, allowing us to reduce
the number of potential bugs in our programs.

In the [next chapter](Eq.md) we start learning about how
to write data types, which we use as proofs that certain
contracts between values hold. These will eventually allow
us to define pre- and post conditions for our function
arguments and output types.

<!-- vi: filetype=idris2
-->
