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

### Auto Implicits

Having to manually pass a proof of being non-empty to
`head1` makes this function unnecessarily cumbersome to
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
In order to do so, Idris will try and build such a value from
the data type's constructors. If it succeeds, this value will
then be automatically filled in as the desired argument, otherwise,
Idris will fail with a type error.

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
function body by its name (if any) or by means of the `%search` pragma.
Here is another implementation of `head`:

```idris
head' : (as : List a) -> (0 _ : NotNil as) => a
head' (x :: _) = x
head' [] impossible
```

During proof search, Idris will also look for values of
the given type in the current function context. This allows
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
handled by the `Here` constructor. The case where the value
is deeper within  the list is handled by the `There`
constructor. Let's write down some examples to get a feel
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

Such a schema could of course be again be read from user
input, but we will wait with implementing a parser until
the next section.

Using this with an `HList` directly, led to issues
with type inference, therefore I quickly wrote a custom
row type: A heterogeneous list indexed over a schema:

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
      -> (prf : InSchema name ss c)
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

We could now define a command for extracting a single
column from a CSV table. I just give a skeleton of an
example here. You are free to try and embed this in the
command-line application you implemented in earlier
exercises.

```idris
record Table where
  constructor MkTable
  schema : Schema
  size   : Nat
  table  : Vect size (Row schema)

data Command : (t : Table) -> Type where
  GetColumn :  (name    : String)
            -> (colType : ColType)
            -> (prf     : InSchema name t.schema colType)
            -> Command t
```

Instead of converting the result of applying our command
to a string directly, we calculate the result type from
the command and table in question:

```idris
0 ResultType : (t : Table) -> (cmd : Command t) -> Type
ResultType t (GetColumn name ct prf) = Vect t.size (IdrisType ct)

run : (t : Table) -> (cmd : Command t) -> ResultType t cmd
run t (GetColumn name ct prf) = map (\row => getAt name row) t.table
```

### Exercises part 2

1. Convert `inSchema` to a decidable conversion function, by
   changing its return type to `Dec (c ** InSchema n ss c)`.

2. Declare and implement a function for modifying a field
   in a row based on the column name given.

3. Define a predicate to be used as a witness that one
   list contains only elements in the second list in the
   same order.

   For instance, `[2,4,5]` contains elements from
   `[1,2,3,4,5,6]` in the correct order, but `[4,2,5]`
   does not.

   Use this predicate to extract several columns from a row at once.

4. We improve the functionality from exercise 3 by defining a new
   predicate, witnessing that all strings in a list correspond
   to column names in a schema (in arbitrary order).

   Use this to extract several columns from a row at once in
   arbitrary order.

   Hint: Make sure to include the resulting schema as an index,
   but search only based on the list of names and the input
   schema.

## Use Case: Flexible Error Handling

A common recurring pattern when writing larger applications is
the combination of different parts of a program each with
their own failure types in a larger effectful computation.
We saw this, for instance, when implementing a command line
tool for handling CSV files. There, we read and wrote data
from and to files, we parsed column types and schemata,
we parsed row and column indices and command line commands.
All these operations came with the potential of failure and
might be implemented in different parts of our application.
In order to unify these different failure types, we wrote
a custom sum type encapsulating each of them, and wrote a
single handler for this sum type. This approach was alright
then, but it doesn't scale well and is lacking in terms of
flexibility. We are therefore trying a different
approach here. Before we continue, we quickly implement a
couple of functions with the potential of failure plus
some custom error types:

```idris
record NoInteger where
  constructor MkNoInteger
  str : String

readInt' : String -> Either NoInteger Integer
readInt' s = maybeToEither (MkNoInteger s) $ parseInteger s

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

record OutOfBounds where
  constructor MkOutOfBounds
  size  : Nat
  index : Nat
```

However, if we now wanted to parse a `Fin n`, there are already
two ways how this could fail: The string in question could not
represent a natural number (leading to a `NoNat` error), or it
could be out of bounds (leading to an `OutOfBounds` error). So,
already here we have to encode these two possibilities in the
return type, for instance, by using an `Either` as the error
type:

```idris
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
a single value of exactly one of the types in question:

```idris
data Sum : List Type -> Type where
  MkSum : (val : t) -> Sum ts
```

However, there is a crucial piece of information missing:
We have not verified, that `t` is an element of `ts`, nor
*which* type it actually is. In fact, this is another case
of an erased existential, and we will have no way to at runtime
learn something about `t`. What we need to do, is pair the value
with a proof, that its type `t` is an element of `ts`.
We could use `Elem` again for this, but we will later need
something a bit more powerful. We will therefore use
a vector instead of a list as our index:

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
  U : {0 ts : _} -> (ix : Has t ts) -> (val : t) -> Union ts

Uninhabited (Union []) where
  uninhabited (U ix _) = absurd ix
```

Now, unlike `HList`, which as a *generalized product type*
indexed over a list of types holds one value for each type
in its index, `Union` is a *generalized sum type*: It holds
only a single value of a type listed in the index. With
this we can now define a much more flexible error type:

```idris
0 Err : Vect n Type -> Type -> Type
Err ts t = Either (Union ts) t
```

We can now implement some utility functions.

```idris
inject : Has t ts => (v : t) -> Union ts
inject v = U %search v

fail : Has t ts => (err : t) -> Err ts a
fail err = Left $ inject err

failMaybe : Has t ts => (err : Lazy t) -> Maybe a -> Err ts a
failMaybe err = maybeToEither (inject err)
```

And here is a reimplementation of the parsers we wrote above:

```idris
readInt : Has NoInteger ts => String -> Err ts Integer
readInt s = failMaybe (MkNoInteger s) $ parseInteger s

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
0 All : List Type -> Vect n Type -> Type
All []        _  = ()
All (x :: xs) ts = (Has x ts, All xs ts)
```

Function `All` returns a tuple of constraints. This can
be used as a witness that all listed types are present
in the vector of types: Idris will automatically extract
the proofs from the tuple as needed.


```idris
readFin : {n : _} -> All [NoNat, OutOfBounds] ts => String -> Err ts (Fin n)
readFin s = do
  ix <- readNat s
  failMaybe (MkOutOfBounds n ix) $ natToFin ix n
```

As a last example, here is a parser for schemata:

```idris
record InvalidColumn where
  constructor MkInvalidColumn
  str : String

readColumn : All [InvalidColumn, NoColType] ts => String -> Err ts Column
readColumn s = case forget $ split (':' ==) s of
  [n,ct] => MkColumn n <$> readColType ct
  _      => fail $ MkInvalidColumn s

readSchema : All [InvalidColumn, NoColType] ts => String -> Err ts Schema
readSchema = traverse readColumn . forget . split (',' ==)
```

Here is an example REPL session, where I test `readSchema`. I define
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

#### Error Handling

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

And here is a handler for a single error. Error handling often
happens in an effectful context (we might want to print a
message to the console or write the error to a log file), so
we use an applicative effect type to handle our error in:

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

## The Truth about Interfaces

Well, here it finally is: The truth about interfaces. Internally,
an interface is just a record data type, with its fields corresponding
to the members of the interface. An interface implementation is
a *value* of such a record, annotated with a `%hint` pragma (see
below) to make the value available during proof search. Finally,
a constrained function is just a function with an auto implicit
argument. For instance, here is the same function for looking up
an element in a list, once with the known syntax for constrained
functions, and once with an auto implicit argument. The code
produced is the same in both cases:

```idris
isElem1 : Eq a => a -> List a -> Bool
isElem1 v []        = False
isElem1 v (x :: xs) = x == v || isElem1 v xs

isElem2 : {auto _ : Eq a} -> a -> List a -> Bool
isElem2 v []        = False
isElem2 v (x :: xs) = x == v || isElem2 v xs
```

Still don't believe interfaces are mere records? Well, we can
take them as regular arguments and dissect them with a pattern
match:

```idris
eq : Eq a -> a -> a -> Bool
eq (MkEq feq fneq) = feq
```

### A manual Interface Definition

I'll now demonstrate how we can achieve the same behavior
with proof search as with a regular interface definition
plus implementations. First, an interface is just a record:

```idris
-- An interface for types with a default value
record Default a where
  constructor MkDefault
  value : a
```

In order to access the record in a constrained function,
we use the `%search` keyword, which will try to conjure a
value of the desired type (`Default a` in this case) by
means of a proof search:

```idris
deflt : Default a => a
deflt = value %search
```

As an alternative, we could use a named constraint, and access
it directly via its name:

```idris
deflt2 : (impl : Default a) => a
deflt2 = value impl
```

As yet another alternative, we could use the syntax for auto
implicit arguments:

```idris
deflt3 : {auto impl : Default a} -> a
deflt3 = value impl
```

All three versions of `deflt` behave exactly the same at runtime.
So, whenever we write `{auto x : Foo} ->` we could just as well
write `(x : Foo) =>` and vice versa.

Interface implementations are then just values of the given
record type, but in order to be available during proof search,
these need to be annotated with a `%hint` pragma:

```idris
%hint
defaultNat : Default Nat
defaultNat = MkDefault 0

%hint
defaultString : Default String
defaultString = MkDefault ""

%hint
defaultPair : Default a => Default b => Default (a,b)
defaultPair = MkDefault (deflt, deflt)
```

An here is to show that it works:

```idris
defaultExample : (Nat,String)
defaultExample = deflt
```

Defining interfaces this way can be an advantage, as there
is much less magic going on, and we have more fine grained
control over the types and values of our fields. Note also,
that all of the magic comes from the search hints, with
which our "interface implementations" were annotated.
These adds the corresponding values and functions to
the search space used during proof search.

<!-- vi: filetype=idris2
-->
