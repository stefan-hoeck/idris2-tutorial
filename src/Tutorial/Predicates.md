# Predicates and Proof Search

In the [last chapter](Eq.md) we learned about propositional
equality, which allowed us to proof that two values are
equal. Equality is a relation between values, and we used
an indexed data type to encode this relation by limiting
the degrees of freedom of the indices in the sole data
constructor. There are other relations and contracts we
can encode this way. This will allow us to restrict the
values we accept as a function's arguments or the values
returned by functions.

```idris
module Tutorial.Predicates

import Data.Either
import Data.List1
import Data.String
import Data.Vect
import Data.HList
import Decidable.Equality

import Text.CSV
import System.File

%default total
```

## Preconditions

Often, when we implement functions operating on values
of a given type, not all values are considered to be
valid arguments for the function in question. For instance,
we typically do not allow division by zero, as the result
is undefined in the general case. This concept of putting
a *precondition* on a function argument comes up pretty often,
and there are several ways to go about this.

A very common operation when working with lists or other
container types is to extract the first value in the sequence.
This function, however, cannot work in the general case, because
in order to extract a value from a list, the list must not
be empty. Here are a couple of ways to encode and implement
this, each with its own advantages and disadvantages:

* Wrap the result in a failure type, such as a `Maybe` or
  `Either e` with some custom error type `e`. This makes it
  immediately clear that the function might not be able to
  return a result. It is a natural way to deal with unvalidated
  input from unknown sources. The drawback of this approach is
  that results will carry the `Maybe` stain, even in situations
  when we *know* that the *nil* case is impossible, for instance because we
  know the value of the list argument at compile-time,
  or because we already *refined* the input value in such a
  way that we can be sure it is not empty (due to an earlier
  pattern match, for instance).

* Define a new data type for non-empty lists and use this
  as the function's argument. This is the approach taken in
  module `Data.List1`. It allows us to return a pure value
  (meaning "not wrapped in a failure type" here), because the
  function cannot possibly fail, but it comes with the
  burden of reimplementing many of the utility functions and
  interfaces we already implemented for `List`. For a very common
  data structure this can be a valid option, but for rare use cases
  it is often too cumbersome.

* Use an index to keep track of the property we are interested
  in. This was the approach we took with type family `List01`,
  which we saw in several examples and exercises in this guide
  so far. This is also the approach taken with vectors,
  where we use the exact length as our index, which is even
  more expressive. While this allows us to implement many functions
  only once and with greater precision at the type level, it
  also comes with the burden of keeping track of changes
  in the types, making for more complex function types
  and forcing us to at times return existentially quantified
  wrappers (for instance, dependent pairs),
  because the outcome of a computation is not known until
  runtime.

* Fail with a runtime exception. This is a popular solution
  in many programming languages (even Haskell), but in Idris
  we try to avoid this, because it breaks totality in a way,
  which also affects client code. Luckily, we can make use of
  our powerful type system to avoid this situation in general.

* Take an additional (possibly erased) argument of a type
  we can use as a witness that the input value is of the
  correct kind or shape. This is the solution we will discuss
  in this chapter in great detail. It is an incredibly powerful way
  to talk about restrictions on values without having to
  replicate a lot of already existing functionality.

There is a time and place for most if not all of the solutions
listed above in Idris, but we will often turn to the last one and
refine function arguments with predicates (so called
*preconditions*), because it makes our functions nice to use at
runtime *and* compile time.

### Example: Non-empty Lists

Remember how we implemented an indexed data type for
propositional equality: We restricted the valid
values of the indices in the constructors. We can do
the same thing for a predicate for non-empty lists:

```idris
data NotNil : (as : List a) -> Type where
  IsNotNil : NotNil (h :: t)
```

This is a single-value data type, so we can always use it
as an erased function argument and still pattern match on
it. We can now use this to implement a safe and pure `head`
function:

```idris
head1 : (as : List a) -> (0 _ : NotNil as) -> a
head1 (h :: _) _ = h
head1 [] IsNotNil impossible
```

Note, how value `IsNotNil` is a *witness* that its index,
which corresponds to our list argument, is indeed non-empty,
because this is what we specified in its type.
The impossible case in the implementation of `head1` is not
strictly necessary here. It was given above for completeness.

We call `NotNil` a *predicate* on lists, as it restricts
the values allowed in the index. We can express a function's
preconditions by adding additional (possibly erased) predicates
to the function's list of arguments.

The first really cool thing is how we can safely use `head1`,
if we can at compile-time show that our list argument is
indeed non-empty:

```idris
headEx1 : Nat
headEx1 = head1 [1,2,3] IsNotNil
```

It is a bit cumbersome that we have to pass the `IsNotNil` proof
manually. Before we scratch that itch, we will first discuss what
to do with lists, the values of which are not known until
runtime. For these cases, we have to try and produce a value
of the predicate programmatically by inspecting the runtime
list value. In the most simple case, we can wrap the proof
in a `Maybe`, but if we can show that our predicate is *decidable*,
we can get even stronger guarantees by returning a `Dec`:

```idris
Uninhabited (NotNil []) where
  uninhabited IsNotNil impossible

nonEmpty : (as : List a) -> Dec (NotNil as)
nonEmpty (x :: xs) = Yes IsNotNil
nonEmpty []        = No uninhabited
```

With this, we can implement function `headMaybe`, which
is to be used with lists of unknown origin:

```idris
headMaybe1 : List a -> Maybe a
headMaybe1 as = case nonEmpty as of
  Yes prf => Just $ head1 as prf
  No  _   => Nothing
```

Of course, for trivial functions like `headMaybe` it makes
more sense to implement them directly by pattern matching on
the list argument, but we will soon see examples of predicates
the values of which are more cumbersome to create.

### Auto Implicits

Having to manually pass a proof of being non-empty to
`head1` makes this function unnecessarily verbose to
use at compile time. Idris allows us to define implicit
function arguments, the values of which it tries to assemble
on its own by means of a technique called *proof search*. This is not
to be confused with type inference, which means inferring
values or types from the surrounding context. It's best
to look at some examples to explain the difference.

Let us first have a look at the following implementation of
`replicate` for vectors:

```idris
replicate' : {n : _} -> a -> Vect n a
replicate' {n = 0}   _ = []
replicate' {n = S _} v = v :: replicate' v
```

Function `replicate'` takes an unerased implicit argument.
The *value* of this argument must be derivable from the surrounding
context. For instance, in the following example it is
immediately clear that `n` equals three, because that is
the length of the vector we want:

```idris
replicateEx1 : Vect 3 Nat
replicateEx1 = replicate' 12
```

In the next example, the value of `n` is not known at compile time,
but it is available as an unerased implicit, so this can again
be passed as is to `replicate'`:

```idris
replicateEx2 : {n : _} -> Vect n Nat
replicateEx2 = replicate' 12
```

However, in the following example, the value of `n` can't
be inferred, as the intermediary vector is immediately converted
to a list of unknown length. Although Idris could try and insert
any value for `n` here, it won't do so, because it can't be
sure that this is the length we want. We therefore have to pass the
length explicitly:

```idris
replicateEx3 : List Nat
replicateEx3 = toList $ replicate' {n = 17} 12
```

Note, how the *value* of `n` had to be inferable in
these examples, which means it had to make an appearance
in the surrounding context. With auto implicit arguments,
this works differently. Here is the `head` example, this
time with an auto implicit:

```idris
head : (as : List a) -> {auto 0 prf : NotNil as} -> a
head (x :: _) = x
head [] impossible
```

Note the `auto` keyword before the quantity of implicit argument
`prf`. This means, we want Idris to construct this value
on its own, without it being visible in the surrounding context.
In order to do so, Idris will have to at compile time know the
structure of the list argument `as`. It will then try and build
such a value from the data type's constructors. If it succeeds,
this value will then be automatically filled in as the desired argument,
otherwise, Idris will fail with a type error.

Let's see this in action:

```idris
headEx3 : Nat
headEx3 = Predicates.head [1,2,3]
```

The following example fails with an error:

```repl
Tutorial.Predicates> Predicates.head []
Error: Can't find an implementation for NotNil [].

(Interactive):1:1--1:8
 1 | head []
     ^^^^^^^
```

Wait! "Can't find an implementation for..."? Is this not the
error message we get for missing interface implementations?
That's correct, and I'll show you that interface resolution
is just proof search at the end of this chapter. What I can
show you already, is that writing the lengthy `{auto prf : t} ->`
all the times can be cumbersome. Idris therefore allows us
to use the same syntax as for constrained functions instead:
`(prf : t) =>`, or even `t =>`, if we don't need to name the
constraint. As usual, we can then access a constraint in the
function body by its name (if any). Here is another implementation
of `head`:

```idris
head' : (as : List a) -> (0 _ : NotNil as) => a
head' (x :: _) = x
head' [] impossible
```

During proof search, Idris will also look for values of
the required type in the current function context. This allows
us to implement `headMaybe` without having to pass on
the `NotNil` proof manually:

```idris
headMaybe : List a -> Maybe a
headMaybe as = case nonEmpty as of
  -- `prf` is available during proof seach
  Yes prf => Just $ Predicates.head as
  No  _   => Nothing
```

To conclude: Predicates allow us to restrict the values
a function accepts as arguments. At runtime, we need to
build such *witnesses* by pattern matching on the function
arguments. These operations can typically fail. At compile
time, we can let Idris try and build these values for us
using a technique called *proof search*. This allows us
to make functions safe and convenient to use at the same
time.

### Exercises part 1

In these exercises, you'll have to implement several
functions making use of auto implicits, to constrain
the values accepted as function arguments. The results
should be *pure*, that is, not wrapped in a failure type
like `Maybe`.

1. Implement `tail` for lists.

2. Implement `concat1` and `foldMap1` for lists. These
   should work like `concat` and `foldMap`, but taking only
   a `Semigroup` constraint on the element type.

3. Implement functions for returning the largest and smallest
   element in a list.

4. Define a predicate for strictly positive natural numbers
   and use it to implement a safe and provably total division
   function on natural numbers.

5. Define a predicate for a non-empty `Maybe` and use it to
   safely extract the value stored in a `Just`. Show that this
   predicate is decidable by implementing a corresponding
   conversion function.

6. Define and implement functions for safely extracting values
   from a `Left` and a `Right` by using suitable predicates.
   Show again that these predicates are decidable.

The predicates you implemented in these exercises are already
available in the *base* library: `Data.List.NonEmpty`,
`Data.Maybe.IsJust`, `Data.Either.IsLeft`, `Data.Either.IsRight`,
and `Data.Nat.IsSucc`.

## Contracts between Values

The predicates we saw so far restricted the values of
a single type, but it is also possible to define predicates
describing contracts between several values of possibly
distinct types.

### The `Elem` Predicate

Assume we'd like to extract a value of a given type from
a heterogeneous list:

```idris
get' : (0 t : Type) -> HList ts -> t
```

This can't work in general: If we could implement this we would
immediately have a proof of void:

```idris
voidAgain : Void
voidAgain = get' Void []
```

The problem is obvious: The type of which we'd like to extract
a value must be an element of the index of the heterogeneous list.
Here is a predicate, with which we can express this:

```idris
data Elem : (elem : a) -> (as : List a) -> Type where
  Here  : Elem x (x :: xs)
  There : Elem x xs -> Elem x (y :: xs)
```

This is a predicate describing a contract between two values:
A value of type `a` and a list of `a`s. Values of this predicate
are witnesses that the value is an element of the list.
Note, how this is defined recursively: The case
where the value we look for is at the head of the list is
handled by the `Here` constructor, where the same variable (`x`) is used
for the element and the head of the list. The case where the value
is deeper within  the list is handled by the `There`
constructor. This can be read as follows: If `x` is and element
of `xs`, then `x` is also an element of `y :: xs` for any
value `y`. Let's write down some examples to get a feel
for these:

```idris
MyList : List Nat
MyList = [1,3,7,8,4,12]

oneElemMyList : Elem 1 MyList
oneElemMyList = Here

sevenElemMyList : Elem 7 MyList
sevenElemMyList = There $ There Here
```

Now, `Elem` is just another way of indexing into a list
of values. Instead of using a `Fin` index, which is limited
by the list's length, we use a proof that a value can be found
at a certain position.

We can use the `Elem` predicate to extract a value from
the desired type of a heterogeneous list:

```idris
get : (0 t : Type) -> HList ts -> (prf : Elem t ts) => t
```

It is important to note that the auto implicit must not be
erased in this case. This is no longer a single value data type,
and we must be able to pattern match on this value in order to
figure out, how far within the heterogeneous list our value
is stored:

```idris
get t (v :: vs) {prf = Here}    = v
get t (v :: vs) {prf = There p} = get t vs
get _ [] impossible
```

It can be instructive to implement `get` yourself, using holes on
the right hand side to see the context and types of values Idris
infers based on the value of the `Elem` predicate.

Let's give this a spin at the REPL:

```repl
Tutorial.Predicates> get Nat ["foo", Just "bar", S Z]
1
Tutorial.Predicates> get Nat ["foo", Just "bar"]
Error: Can't find an implementation for Elem Nat [String, Maybe String].

(Interactive):1:1--1:28
 1 | get Nat ["foo", Just "bar"]
     ^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

With this example we start to appreciate what *proof search*
actually means: Given a value `v` and a list of values `vs`, Idris tries
to find a proof that `v` is an element of `vs`.
Now, before we continue, please note that proof search is
not a silver bullet. The search algorithm has a reasonably limited
*search depth*, and will fail with the search if this limit
is exceeded. For instance:

```idris
Tps : List Type
Tps = List.replicate 50 Nat ++ [Maybe String]

hlist : HList Tps
hlist = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        , Nothing ]
```

And at the REPL:

```repl
Tutorial.Predicates> get (Maybe String) hlist
Error: Can't find an implementation for Elem (Maybe String) [Nat,...
```

As you can see, Idris fails to find a proof that `Maybe String`
is an element of `Tps`. The search depth can be increased with
the `%auto_implicit_depth` directive, which will hold for the
rest of the source file or until set to a different value.
The default value is set at 25. In general, it is not advisable
to set this to a too large value as this can drastically increase
compile times.

```idris
%auto_implicit_depth 100
aMaybe : Maybe String
aMaybe = get _ hlist

%auto_implicit_depth 25
```

### Use Case: A nicer Schema

In the chapter about [sigma types](DPair.md), we introduced
a schema for CSV files. This was not very nice to use, because
we had to use natural numbers to access a certain column. Even
worse, users of our small library had to do the same. There was
no way to define a name for each column and access columns by
name. We are going to change this. Here is an encoding
for this use case:

```idris
data ColType = I64 | Str | Boolean | Float

IdrisType : ColType -> Type
IdrisType I64     = Int64
IdrisType Str     = String
IdrisType Boolean = Bool
IdrisType Float   = Double

record Column where
  constructor MkColumn
  name : String
  type : ColType

infixr 8 :>

(:>) : String -> ColType -> Column
(:>) = MkColumn

Schema : Type
Schema = List Column

Show ColType where
  show I64     = "I64"
  show Str     = "Str"
  show Boolean = "Boolean"
  show Float   = "Float"

Show Column where
  show (MkColumn n ct) = "\{n}:\{show ct}"

showSchema : Schema -> String
showSchema = concat . intersperse "," . map show
```

As you can see, in a schema we now pair a column's type
with its name. Here is an example schema for a CSV file
holding information about employees in a company:

```idris
EmployeeSchema : Schema
EmployeeSchema = [ "firstName"  :> Str
                 , "lastName"   :> Str
                 , "email"      :> Str
                 , "age"        :> I64
                 , "salary"     :> Float
                 , "management" :> Boolean
                 ]
```

Such a schema could of course again be read from user
input, but we will wait with implementing a parser until
later in this chapter.
Using this new schema with an `HList` directly led to issues
with type inference, therefore I quickly wrote a custom
row type: A heterogeneous list indexed over a schema.

```idris
data Row : Schema -> Type where
  Nil  : Row []

  (::) :  {0 name : String}
       -> {0 type : ColType}
       -> (v : IdrisType type)
       -> Row ss
       -> Row (name :> type :: ss)
```

In the signature of *cons*, I list the erased implicit arguments
explicitly. This is good practice, as otherwise Idris will often
issue shadowing warnings when using such data constructors in client
code.

We can now define a type alias for CSV rows representing employees:

```idris
0 Employee : Type
Employee = Row EmployeeSchema

hock : Employee
hock = [ "Stefan", "Höck", "hock@foo.com", 46, 5443.2, False ]
```

Note, how I gave `Employee` a zero quantity. This means, we are
only ever allowed to use this function at compile time
but never at runtime. This is a safe way to make sure
our type-level functions and aliases do not leak into the
executable when we build our application. We are allowed
to use zero-quantity functions and values in type signatures
and when computing other erased values, but not for runtime-relevant
computations.

We would now like to access a value in a row based on
the name given. For this, we write a custom predicate, which
serves as a witness that a column with the given name is
part of the schema. Now, here is an important thing to note:
In this predicate we include an index for the *type* of the
column with the given name. We need this, because when we
access a column by name, we need a way to figure out
the return type. But during proof search, this type will
have to be derived by Idris based on the column name and
schema in question (otherwise, the proof search will fail
unless the return type is known in advance).
We therefore *must* tell Idris, that
it can't include this type in the list of search criteria,
otherwise it will try and infer the column type from the
context (using type inference) before running the proof
search. This can be done by listing the indices to be used in
the search like so: `[search name schema]`.

```idris
data InSchema :  (name    : String)
              -> (schema  : Schema)
              -> (colType : ColType)
              -> Type where
  [search name schema]
  IsHere  : InSchema n (n :> t :: ss) t
  IsThere : InSchema n ss t -> InSchema n (fld :: ss) t

Uninhabited (InSchema n [] c) where
  uninhabited IsHere impossible
  uninhabited (IsThere _) impossible
```

With this, we are now ready to access the value
at a given column based on the column's name:

```idris
getAt :  {0 ss : Schema}
      -> (name : String)
      -> (row  : Row ss)
      -> (prf  : InSchema name ss c)
      => IdrisType c
getAt name (v :: vs) {prf = IsHere}    = v
getAt name (_ :: vs) {prf = IsThere p} = getAt name vs
```

Below is an example how to use this at compile time. Note
the amount of work Idris performs for us: It first comes
up with proofs that `firstName`, `lastName`, and `age`
are indeed valid names in the `Employee` schema. From
these proofs it automatically figures out the return types
of the calls to `getAt` and extracts the corresponding values
from the row. All of this happens in a provably total and type
safe way.

```idris
shoeck : String
shoeck =  getAt "firstName" hock
       ++ " "
       ++ getAt "lastName" hock
       ++ ": "
       ++ show (getAt "age" hock)
       ++ " years old."
```

In order to at runtime specify a column name, we need a way
for computing values of type `InSchema` by comparing
the column names with the schema in question. Since we have
to compare two string values for being propositionally equal,
we use the `DecEq` implementation for `String` here (Idris provides `DecEq`
implementations for all primitives). We extract the column type
at the same time and pair this (as a dependent pair) with
the `InSchema` proof:

```idris
inSchema : (ss : Schema) -> (n : String) -> Maybe (c ** InSchema n ss c)
inSchema []                    _ = Nothing
inSchema (MkColumn cn t :: xs) n = case decEq cn n of
  Yes Refl   => Just (t ** IsHere)
  No  contra => case inSchema xs n of
    Just (t ** prf) => Just $ (t ** IsThere prf)
    Nothing         => Nothing
```

At the end of this chapter we will use `InSchema` in
our CSV command-line application to list all values
in a column.

### Exercises part 2

1. Show that `InSchema` is decidable by changing the output type
   of `inSchema` to `Dec (c ** InSchema n ss c)`.

2. Declare and implement a function for modifying a field
   in a row based on the column name given.

3. Define a predicate to be used as a witness that one
   list contains only elements in the second list in the
   same order and use this predicate to extract several columns
   from a row at once.

   For instance, `[2,4,5]` contains elements from
   `[1,2,3,4,5,6]` in the correct order, but `[4,2,5]`
   does not.

4. Improve the functionality from exercise 3 by defining a new
   predicate, witnessing that all strings in a list correspond
   to column names in a schema (in arbitrary order).
   Use this to extract several columns from a row at once in
   arbitrary order.

   Hint: Make sure to include the resulting schema as an index,
   but search only based on the list of names and the input
   schema.

## Use Case: Flexible Error Handling

A recurring pattern when writing larger applications is
the combination of different parts of a program each with
their own failure types in a larger effectful computation.
We saw this, for instance, when implementing a command-line
tool for handling CSV files. There, we read and wrote data
from and to files, we parsed column types and schemata,
we parsed row and column indices and command-line commands.
All these operations came with the potential of failure and
might be implemented in different parts of our application.
In order to unify these different failure types, we wrote
a custom sum type encapsulating each of them, and wrote a
single handler for this sum type. This approach was alright
then, but it does not scale well and is lacking in terms of
flexibility. We are therefore trying a different
approach here. Before we continue, we quickly implement a
couple of functions with the potential of failure plus
some custom error types:

```idris
record NoNat where
  constructor MkNoNat
  str : String

readNat' : String -> Either NoNat Nat
readNat' s = maybeToEither (MkNoNat s) $ parsePositive s

record NoColType where
  constructor MkNoColType
  str : String

readColType' : String -> Either NoColType ColType
readColType' "I64"     = Right I64
readColType' "Str"     = Right Str
readColType' "Boolean" = Right Boolean
readColType' "Float"   = Right Float
readColType' s         = Left $ MkNoColType s
```

However, if we wanted to parse a `Fin n`, there'd be already
two ways how this could fail: The string in question could not
represent a natural number (leading to a `NoNat` error), or it
could be out of bounds (leading to an `OutOfBounds` error).
We have to somehow encode these two possibilities in the
return type, for instance, by using an `Either` as the error
type:

```idris
record OutOfBounds where
  constructor MkOutOfBounds
  size  : Nat
  index : Nat

readFin' : {n : _} -> String -> Either (Either NoNat OutOfBounds) (Fin n)
readFin' s = do
  ix <- mapFst Left (readNat' s)
  maybeToEither (Right $ MkOutOfBounds n ix) $ natToFin ix n
```

This is incredibly ugly. A custom sum type might have been slightly better,
but we still would have to use `mapFst` when invoking `readNat'`, and
writing custom sum types for every possible combination of errors
will get cumbersome very quickly as well.
What we are looking for, is a generalized sum type: A type
indexed by a list of types (the possible choices) holding
a single value of exactly one of the types in question.
Here is a first naive try:

```idris
data Sum : List Type -> Type where
  MkSum : (val : t) -> Sum ts
```

However, there is a crucial piece of information missing:
We have not verified that `t` is an element of `ts`, nor
*which* type it actually is. In fact, this is another case
of an erased existential, and we will have no way to at runtime
learn something about `t`. What we need to do is to pair the value
with a proof, that its type `t` is an element of `ts`.
We could use `Elem` again for this, but for some use cases
we will require access to the number of types in the list.
We will therefore use a vector instead of a list as our index.
Here is a predicate similar to `Elem` but for vectors:

```idris
data Has :  (v : a) -> (vs  : Vect n a) -> Type where
  Z : Has v (v :: vs)
  S : Has v vs -> Has v (w :: vs)

Uninhabited (Has v []) where
  uninhabited Z impossible
  uninhabited (S _) impossible
```

A value of type `Has v vs` is a witness that `v` is an
element of `vs`. With this, we can now implement an indexed
sum type (also called an *open union*):

```idris
data Union : Vect n Type -> Type where
  U : (ix : Has t ts) -> (val : t) -> Union ts

Uninhabited (Union []) where
  uninhabited (U ix _) = absurd ix
```

Note the difference between `HList` and `Union`. `HList` is
a *generalized product type*: It holds a value for each type
in its index. `Union` is a *generalized sum type*: It holds
only a single value, which must be of a type listed in the index.
With this we can now define a much more flexible error type:

```idris
0 Err : Vect n Type -> Type -> Type
Err ts t = Either (Union ts) t
```

A function returning an `Err ts a` describes a computation, which
can fail with one of the errors listed in `ts`.
We first need some utility functions.

```idris
inject : (prf : Has t ts) => (v : t) -> Union ts
inject v = U prf v

fail : Has t ts => (err : t) -> Err ts a
fail err = Left $ inject err

failMaybe : Has t ts => (err : Lazy t) -> Maybe a -> Err ts a
failMaybe err = maybeToEither (inject err)
```

Next, we can write more flexible versions of the
parsers we wrote above:

```idris
readNat : Has NoNat ts => String -> Err ts Nat
readNat s = failMaybe (MkNoNat s) $ parsePositive s

readColType : Has NoColType ts => String -> Err ts ColType
readColType "I64"     = Right I64
readColType "Str"     = Right Str
readColType "Boolean" = Right Boolean
readColType "Float"   = Right Float
readColType s         = fail $ MkNoColType s
```

Before we implement `readFin`, we introduce a short cut for
specifying that several error types must be present:

```idris
0 Errs : List Type -> Vect n Type -> Type
Errs []        _  = ()
Errs (x :: xs) ts = (Has x ts, Errs xs ts)
```

Function `Errs` returns a tuple of constraints. This can
be used as a witness that all listed types are present
in the vector of types: Idris will automatically extract
the proofs from the tuple as needed.


```idris
readFin : {n : _} -> Errs [NoNat, OutOfBounds] ts => String -> Err ts (Fin n)
readFin s = do
  S ix <- readNat s | Z => fail (MkOutOfBounds n Z)
  failMaybe (MkOutOfBounds n (S ix)) $ natToFin ix n
```

As a last example, here are parsers for schemata and
CSV rows:

```idris
fromCSV : String -> List String
fromCSV = forget . split (',' ==)

record InvalidColumn where
  constructor MkInvalidColumn
  str : String

readColumn : Errs [InvalidColumn, NoColType] ts => String -> Err ts Column
readColumn s = case forget $ split (':' ==) s of
  [n,ct] => MkColumn n <$> readColType ct
  _      => fail $ MkInvalidColumn s

readSchema : Errs [InvalidColumn, NoColType] ts => String -> Err ts Schema
readSchema = traverse readColumn . fromCSV

data RowError : Type where
  InvalidField  : (row, col : Nat) -> (ct : ColType) -> String -> RowError
  UnexpectedEOI : (row, col : Nat) -> RowError
  ExpectedEOI   : (row, col : Nat) -> RowError

decodeField :  Has RowError ts
            => (row,col : Nat)
            -> (c : ColType)
            -> String
            -> Err ts (IdrisType c)
decodeField row col c s =
  let err = InvalidField row col c s
   in case c of
        I64     => failMaybe err $ read s
        Str     => failMaybe err $ read s
        Boolean => failMaybe err $ read s
        Float   => failMaybe err $ read s

decodeRow :  Has RowError ts
          => {s : _}
          -> (row : Nat)
          -> (str : String)
          -> Err ts (Row s)
decodeRow row = go 1 s . fromCSV
  where go : Nat -> (cs : Schema) -> List String -> Err ts (Row cs)
        go k []       []                    = Right []
        go k []       (_ :: _)              = fail $ ExpectedEOI row k
        go k (_ :: _) []                    = fail $ UnexpectedEOI row k
        go k (MkColumn n c :: cs) (s :: ss) =
          [| decodeField row k c s :: go (S k) cs ss |]
```

Here is an example REPL session, where I test `readSchema`. I defined
variable `ts` using the `:let` command to make this more convenient.
Note, how the order of error types is of no importance, as long
as types `InvalidColumn` and `NoColType` are present in the list of
errors:

```repl
Tutorial.Predicates> :let ts = the (Vect 3 _) [NoColType,NoNat,InvalidColumn]
Tutorial.Predicates> readSchema {ts} "foo:bar"
Left (U Z (MkNoColType "bar"))
Tutorial.Predicates> readSchema {ts} "foo:Float"
Right [MkColumn "foo" Float]
Tutorial.Predicates> readSchema {ts} "foo Float"
Left (U (S (S Z)) (MkInvalidColumn "foo Float"))
```

### Error Handling

There are several techniques for handling errors, all of which
are useful at times. For instance, we might want to handle some
errors early on and individually, while dealing with others
much later in our application. Or we might want to handle
them all in one fell swoop. We look at both approaches here.

First, in order to handle a single error individually, we need
to *split* a union into one of two possibilities: A value of
the error type in question or a new union, holding one of the
other error types. We need a new predicate for this, which
not only encodes the presence of a value in a vector
but also the result of removing that value:

```idris
data Rem : (v : a) -> (vs : Vect (S n) a) -> (rem : Vect n a) -> Type where
  [search v vs]
  RZ : Rem v (v :: rem) rem
  RS : Rem v vs rem -> Rem v (w :: vs) (w :: rem)
```

Once again, we want to use one of the indices (`rem`) in our
functions' return types, so we only use the other indices during
proof search. Here is a function for splitting off a value from
an open union:

```idris
split : (prf : Rem t ts rem) => Union ts -> Either t (Union rem)
split {prf = RZ}   (U Z     val) = Left val
split {prf = RZ}   (U (S x) val) = Right (U x val)
split {prf = RS p} (U Z     val) = Right (U Z val)
split {prf = RS p} (U (S x) val) = case split {prf = p} (U x val) of
  Left vt        => Left vt
  Right (U ix y) => Right $ U (S ix) y
```

This tries to extract a value of type `t` from a union. If it works,
the result is wrapped in a `Left`, otherwise a new union is returned
in a `Right`, but this one has `t` removed from its list of possible
types.

With this, we can implement a handler for single errors.
Error handling often happens in an effectful context (we might want to
print a message to the console or write the error to a log file), so
we use an applicative effect type to handle errors in.

```idris
handle :  Applicative f
       => Rem t ts rem
       => (h : t -> f a)
       -> Err ts a
       -> f (Err rem a)
handle h (Left x)  = case split x of
  Left v    => Right <$> h v
  Right err => pure $ Left err
handle _ (Right x) = pure $ Right x
```

For handling all errors at once, we can use a handler type
indexed by the vector of errors, and parameterized by the
output type:

```idris
namespace Handler
  public export
  data Handler : (ts : Vect n Type) -> (a : Type) -> Type where
    Nil  : Handler [] a
    (::) : (t -> a) -> Handler ts a -> Handler (t :: ts) a

extract : Handler ts a -> Has t ts -> t -> a
extract (f :: _)  Z     val = f val
extract (_ :: fs) (S y) val = extract fs y val
extract []        ix    _   = absurd ix

handleAll : Applicative f => Handler ts (f a) -> Err ts a -> f a
handleAll _ (Right v)       = pure v
handleAll h (Left $ U ix v) = extract h ix v
```

Below, we will see an additional way of handling all
errors at once by defining a custom interface for
error handling.

### Exercises part 3

1. Implement the following utility functions for `Union`:

   ```idris
   project : (0 t : Type) -> (prf : Has t ts) => Union ts -> Maybe t

   project1 : Union [t] -> t

   safe : Err [] a -> a
   ```
2. Implement the following two functions for embedding
   an open union in a larger set of possibilities.
   Note the unerased implicit in `extend`!

   ```idris
   weaken : Union ts -> Union (ts ++ ss)

   extend : {m : _} -> {0 pre : Vect m _} -> Union ts -> Union (pre ++ ts)
   ```

3. Find a general way to embed a `Union ts` in a `Union ss`,
   so that the following is possible:

   ```idris
   embedTest :  Err [NoNat,NoColType] a
             -> Err [FileError, NoColType, OutOfBounds, NoNat] a
   embedTest = mapFst embed
   ```

4. Make `handle` more powerful, by letting the handler convert
   the error in question to an `f (Err rem a)`.

## The Truth about Interfaces

Well, here it finally is: The truth about interfaces. Internally,
an interface is just a record data type, with its fields corresponding
to the members of the interface. An interface implementation is
a *value* of such a record, annotated with a `%hint` pragma (see
below) to make the value available during proof search. Finally,
a constrained function is just a function with one or more auto implicit
arguments. For instance, here is the same function for looking up
an element in a list, once with the known syntax for constrained
functions, and once with an auto implicit argument. The code
produced by Idris is the same in both cases:

```idris
isElem1 : Eq a => a -> List a -> Bool
isElem1 v []        = False
isElem1 v (x :: xs) = x == v || isElem1 v xs

isElem2 : {auto _ : Eq a} -> a -> List a -> Bool
isElem2 v []        = False
isElem2 v (x :: xs) = x == v || isElem2 v xs
```

Being mere records, we can also take interfaces as
regular function arguments and dissect them with a pattern
match:

```idris
eq : Eq a -> a -> a -> Bool
eq (MkEq feq fneq) = feq
```

### A manual Interface Definition

I'll now demonstrate how we can achieve the same behavior
with proof search as with a regular interface definition
plus implementations. Since I want to finish the CSV
example with our new error handling tools, we are
going to implement some error handlers.
First, an interface is just a record:

```idris
record Print a where
  constructor MkPrint
  print' : a -> String
```

In order to access the record in a constrained function,
we use the `%search` keyword, which will try to conjure a
value of the desired type (`Print a` in this case) by
means of a proof search:

```idris
print : Print a => a -> String
print = print' %search
```

As an alternative, we could use a named constraint, and access
it directly via its name:

```idris
print2 : (impl : Print a) => a -> String
print2 = print' impl
```

As yet another alternative, we could use the syntax for auto
implicit arguments:

```idris
print3 : {auto impl : Print a} -> a -> String
print3 = print' impl
```

All three versions of `print` behave exactly the same at runtime.
So, whenever we write `{auto x : Foo} ->` we can just as well
write `(x : Foo) =>` and vice versa.

Interface implementations are just values of the given
record type, but in order to be available during proof search,
these need to be annotated with a `%hint` pragma:

```idris
%hint
noNatPrint : Print NoNat
noNatPrint = MkPrint $ \e => "Not a natural number: \{e.str}"

%hint
noColTypePrint : Print NoColType
noColTypePrint = MkPrint $ \e => "Not a column type: \{e.str}"

%hint
outOfBoundsPrint : Print OutOfBounds
outOfBoundsPrint = MkPrint $ \e => "Index is out of bounds: \{show e.index}"

%hint
rowErrorPrint : Print RowError
rowErrorPrint = MkPrint $
  \case InvalidField r c ct s =>
          "Not a \{show ct} in row \{show r}, column \{show c}. \{s}"
        UnexpectedEOI r c =>
          "Unexpected end of input in row \{show r}, column \{show c}."
        ExpectedEOI r c =>
          "Expected end of input in row \{show r}, column \{show c}."
```

We can also write an implementation of `Print` for
a union or errors. For this, we first come up with a
proof that all types in the union's index come with an
implementation of `Print`:

```idris
0 All : (f : a -> Type) -> Vect n a -> Type
All f []        = ()
All f (x :: xs) = (f x, All f xs)

unionPrintImpl : All Print ts => Union ts -> String
unionPrintImpl (U Z val)     = print val
unionPrintImpl (U (S x) val) = unionPrintImpl $ U x val

%hint
unionPrint : All Print ts => Print (Union ts)
unionPrint = MkPrint unionPrintImpl
```

Defining interfaces this way can be an advantage, as there
is much less magic going on, and we have more fine grained
control over the types and values of our fields. Note also,
that all of the magic comes from the search hints, with
which our "interface implementations" were annotated.
These made the corresponding values and functions available
during proof search.

#### Parsing CSV Commands

To conclude this chapter, we reimplement our CSV command
parser, using the flexible error handling approach from
the last section. While not necessarily less verbose than
the original parser, this approach decouples the handling
of errors and printing of error messages from the rest
of the application: Functions with a possibility of failure
are reusable in different contexts, as are the pretty
printers we use for the error messages.

First, we repeat some stuff from earlier chapters. I sneaked
in a new command for printing all values in a column:

```idris
record Table where
  constructor MkTable
  schema : Schema
  size   : Nat
  rows   : Vect size (Row schema)

data Command : (t : Table) -> Type where
  PrintSchema :  Command t
  PrintSize   :  Command t
  New         :  (newSchema : Schema) -> Command t
  Prepend     :  Row (schema t) -> Command t
  Get         :  Fin (size t) -> Command t
  Delete      :  Fin (size t) -> Command t
  Col         :  (name : String)
              -> (tpe  : ColType)
              -> (prf  : InSchema name t.schema tpe)
              -> Command t
  Quit        : Command t

applyCommand : (t : Table) -> Command t -> Table
applyCommand t                 PrintSchema = t
applyCommand t                 PrintSize   = t
applyCommand _                 (New ts)    = MkTable ts _ []
applyCommand (MkTable ts n rs) (Prepend r) = MkTable ts _ $ r :: rs
applyCommand t                 (Get x)     = t
applyCommand t                 Quit        = t
applyCommand t                 (Col _ _ _) = t
applyCommand (MkTable ts n rs) (Delete x)  = case n of
  S k => MkTable ts k (deleteAt x rs)
  Z   => absurd x
```

Next, below is the command parser reimplemented. In total,
it can fail in seven different was, at least some of which
might also be possible in other parts of a larger application.

```idris
record UnknownCommand where
  constructor MkUnknownCommand
  str : String

%hint
unknownCommandPrint : Print UnknownCommand
unknownCommandPrint = MkPrint $ \v => "Unknown command: \{v.str}"

record NoColName where
  constructor MkNoColName
  str : String

%hint
noColNamePrint : Print NoColName
noColNamePrint = MkPrint $ \v => "Unknown column: \{v.str}"

0 CmdErrs : Vect 7 Type
CmdErrs = [ InvalidColumn
          , NoColName
          , NoColType
          , NoNat
          , OutOfBounds
          , RowError
          , UnknownCommand ]

readCommand : (t : Table) -> String -> Err CmdErrs (Command t)
readCommand _                "schema"  = Right PrintSchema
readCommand _                "size"    = Right PrintSize
readCommand _                "quit"    = Right Quit
readCommand (MkTable ts n _) s         = case words s of
  ["new",    str] => New     <$> readSchema str
  "add" ::   ss   => Prepend <$> decodeRow 1 (unwords ss)
  ["get",    str] => Get     <$> readFin str
  ["delete", str] => Delete  <$> readFin str
  ["column", str] => case inSchema ts str of
    Just (ct ** prf) => Right $ Col str ct prf
    Nothing          => fail $ MkNoColName str
  _               => fail $ MkUnknownCommand s
```

Note, how we could invoke functions like `readFin` or
`readSchema` directly, because the necessary error types
are part of our list of possible errors.

To conclude this sections, here is the functionality
for printing the result of a command plus the application's
main loop. Most of this is repeated from earlier chapters,
but note how we can handle all errors at once with a single
call to `print`:

```idris
encodeField : (t : ColType) -> IdrisType t -> String
encodeField I64     x     = show x
encodeField Str     x     = show x
encodeField Boolean True  = "t"
encodeField Boolean False = "f"
encodeField Float   x     = show x

encodeRow : (s : Schema) -> Row s -> String
encodeRow s = concat . intersperse "," . go s
  where go : (s' : Schema) -> Row s' -> Vect (length s') String
        go []        []        = []
        go (MkColumn _ c :: cs) (v :: vs) = encodeField c v :: go cs vs

encodeCol :  (name : String)
          -> (c    : ColType)
          -> InSchema name s c
          => Vect n (Row s)
          -> String
encodeCol name c = unlines . toList . map (\r => encodeField c $ getAt name r)

result :  (t : Table) -> Command t -> String
result t PrintSchema   = "Current schema: \{showSchema t.schema}"
result t PrintSize     = "Current size: \{show t.size}"
result _ (New ts)      = "Created table. Schema: \{showSchema ts}"
result t (Prepend r)   = "Row prepended: \{encodeRow t.schema r}"
result _ (Delete x)    = "Deleted row: \{show $ FS x}."
result _ Quit          = "Goodbye."
result t (Col n c prf) = "Column \{n}:\n\{encodeCol n c t.rows}"
result t (Get x)       =
  "Row \{show $ FS x}: \{encodeRow t.schema (index x t.rows)}"

covering
runProg : Table -> IO ()
runProg t = do
  putStr "Enter a command: "
  str <- getLine
  case readCommand t str of
    Left err   => putStrLn (print err) >> runProg t
    Right Quit => putStrLn (result t Quit)
    Right cmd  => putStrLn (result t cmd) >>
                  runProg (applyCommand t cmd)

covering
main : IO ()
main = runProg $ MkTable [] _ []
```

Here is an example REPL session:

```repl
Tutorial.Predicates> :exec main
Enter a command: new name:Str,age:Int64,salary:Float
Not a column type: Int64
Enter a command: new name:Str,age:I64,salary:Float
Created table. Schema: name:Str,age:I64,salary:Float
Enter a command: add John Doe,44,3500
Row prepended: "John Doe",44,3500.0
Enter a command: add Jane Doe,50,4000
Row prepended: "Jane Doe",50,4000.0
Enter a command: get 1
Row 1: "Jane Doe",50,4000.0
Enter a command: column salary
Column salary:
4000.0
3500.0

Enter a command: quit
Goodbye.
```

## Conclusion

Predicates allow us to describe contracts between types
and to refine the values we accept as valid function arguments.
They allow us to make a function safe and convenient to use
at runtime *and* compile time by using them as auto implicit
arguments, which Idris should try to construct on its own if
it has enough information about the structure of a function's
arguments.

<!-- vi: filetype=idris2
-->
