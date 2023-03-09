# Functions Part 2

So far, we learned about the core features of the Idris
language, which it has in common with several other
pure, strongly typed programming languages like Haskell:
(Higher-order) Functions, algebraic data types, pattern matching,
parametric polymorphism (generic types and functions), and
ad hoc polymorphism (interfaces and constrained functions).

In this chapter, we start to dissect Idris functions and their types
for real. We learn about implicit arguments, named arguments, as well
as erasure and quantities. But first, we'll look at `let` bindings
and `where` blocks, which help us implement functions too complex
to fit on a single line of code. Let's get started!

```idris
module Tutorial.Functions2

%default total
```

## Let Bindings and Local Definitions

The functions we looked at so far were simple enough
to be implemented directly via pattern matching
without the need of additional auxiliary functions or
variables. This is not always the case, and there are two
important language constructs for introducing and reusing
new local variables and functions. We'll look at these
in two case studies.

### Use Case 1: Arithmetic Mean and Standard Deviation

In this example, we'd like to calculate the arithmetic
mean and the standard deviation of a list of floating point values.
There are several things we need to consider.

First, we need a function for calculating the sum of
a list of numeric values. The *Prelude* exports function
`sum` for this:

```repl
Main> :t sum
Prelude.sum : Num a => Foldable t => t a -> a
```

This is - of course - similar to `sumList` from Exercise 10
of the [last section](Interfaces.md), but generalized to all
container types with a `Foldable` implementation. We will
learn about interface `Foldable` in a later section.

In order to also calculate the variance,
we need to convert every value in the list to
a new value, as we have to subtract the mean
from every value in the list and square the
result. In the previous section's exercises, we
defined function `mapList` for this. The *Prelude* - of course -
already exports a similar function called `map`,
which is again more general
and works also like our `mapMaybe` for `Maybe`
and `mapEither` for `Either e`. Here's its type:

```repl
Main> :t map
Prelude.map : Functor f => (a -> b) -> f a -> f b
```

Interface `Functor` is another one we'll talk about
in a later section.

Finally, we need a way to calculate the length of
a list of values. We use function `length` for this:

```repl
Main> :t List.length
Prelude.List.length : List a -> Nat
```

Here, `Nat` is the type of natural numbers
(unbounded, unsigned integers). `Nat` is actually not a primitive data
type but a sum type defined in the *Prelude* with
data constructors `Z : Nat` (for zero)
and `S : Nat -> Nat` (for successor). It might seem highly inefficient
to define natural numbers this way, but the Idris compiler
treats these and several other *number-like* types specially, and
replaces them with primitive integers during code generation.

We are now ready to give the implementation of `mean` a go.
Since this is Idris, and we care about clear semantics, we will
quickly define a custom record type instead of just returning
a tuple of `Double`s. This makes it clearer, which floating
point number corresponds to which statistic entity:

```idris
square : Double -> Double
square n = n * n

record Stats where
  constructor MkStats
  mean      : Double
  variance  : Double
  deviation : Double

stats : List Double -> Stats
stats xs =
  let len      := cast (length xs)
      mean     := sum xs / len
      variance := sum (map (\x => square (x - mean)) xs) / len
   in MkStats mean variance (sqrt variance)
```

As usual, we first try this at the REPL:

```repl
Tutorial.Functions2> stats [2,4,4,4,5,5,7,9]
MkStats 5.0 4.0 2.0
```

Seems to work, so let's digest this step by step.
We introduce several new local variables
(`len`, `mean`, and `variance`),
which all will be used more than once in the remainder
of the implementation. To do so, we use a `let` binding. This
consists of the `let` keyword, followed by one or more
variable assignments, followed by the final expression,
which has to be prefixed by `in`. Note, that whitespace
is significant again: We need to properly align the three
variable names. Go ahead, and try out what happens if
you remove a space in front of `mean` or `variance`.
Note also, that the alignment of assignment operators
`:=` is optional. I do this, since I thinks it helps
readability.

Let's also quickly look at the different variables
and their types. `len` is the length of the list
cast to a `Double`, since this is what's needed
later on, where we divide other values of type `Double`
by the length. Idris is very strict about this: We are
not allowed to mix up numeric types without explicit
casts. Please note, that in this case Idris is able
to *infer* the type of `len` from the surrounding
context. `mean` is straight forward: We `sum` up the
values stored in the list and divide by the list's
length. `variance` is the most involved of the
three: We map each item in the list to a new value
using an anonymous function to subtract the mean
and square the result. We then sum up the new terms
and divide again by the number of values.

### Use Case 2: Simulating a Simple Web Server

In the second use case, we are going to write a slightly
larger application. This should give you an idea about how to
design data types and functions around some business
logic you'd like to implement.

Assume we run a music streaming web server, where users
can buy whole albums and listen to them online. We'd
like to simulate a user connecting to the server and
getting access to one of the albums they bought.

We first define a bunch of record types:

```idris
record Artist where
  constructor MkArtist
  name : String

record Album where
  constructor MkAlbum
  name   : String
  artist : Artist

record Email where
  constructor MkEmail
  value : String

record Password where
  constructor MkPassword
  value : String

record User where
  constructor MkUser
  name     : String
  email    : Email
  password : Password
  albums   : List Album
```

Most of these should be self-explanatory. Note, however, that
in several cases (`Email`, `Artist`, `Password`) we wrap a
single value in a new record type. Of course, we *could* have
used the unwrapped `String` type instead, but we'd have ended
up with many `String` fields, which can be hard to disambiguate.
In order not to confuse an email string with a password string,
it can therefore be helpful to wrap both of them in a new
record type to drastically increase type safety at the cost
of having to reimplement some interfaces.
Utility function `on` from the *Prelude* is very useful for this. Don't
forget to inspect its type at the REPL, and try to understand what's
going on here.

```idris
Eq Artist where (==) = (==) `on` name

Eq Email where (==) = (==) `on` value

Eq Password where (==) = (==) `on` value

Eq Album where (==) = (==) `on` \a => (a.name, a.artist)
```

In case of `Album`, we wrap the two fields of the record in
a `Pair`, which already comes with an implementation of `Eq`.
This allows us to again use function `on`, which is very convenient.

Next, we have to define the data types representing
server requests and responses:

```idris
record Credentials where
  constructor MkCredentials
  email    : Email
  password : Password

record Request where
  constructor MkRequest
  credentials : Credentials
  album       : Album

data Response : Type where
  UnknownUser     : Email -> Response
  InvalidPassword : Response
  AccessDenied    : Email -> Album -> Response
  Success         : Album -> Response
```

For server responses, we use a custom sum type encoding
the possible outcomes of a client request. In practice,
the `Success` case would return some kind of connection
to start the actual album stream, but we just
wrap up the album we found to simulate this behavior.

We can now go ahead and simulate the handling of
a request at the server. To emulate our user data base,
a simple list of users will do. Here's the type of the
function we'd like to implement:

```idris
DB : Type
DB = List User

handleRequest : DB -> Request -> Response
```

Note, how we defined a short alias for `List User` called `DB`.
This is often useful to make lengthy type signatures more readable
and communicate the meaning of a type in the given context. However,
this will *not* introduce a new type, nor will it
increase type safety: `DB` is *identical* to `List User`, and as
such, a value of type `DB` can be used wherever a `List User` is
expected and vice versa. In more complex programs it is therefore
usually preferable to define new types by wrapping values in
single-field records.

The implementation will proceed as follows: It will first
try and lookup a `User` by is email address in the data
base. If this is successful, it will compare the provided password
with the user's actual password. If the two match, it will
lookup the requested album in the user's list of albums.
If all of these steps succeed, the result will be an `Album`
wrapped in a `Success`. If any of the steps fails, the
result will describe exactly what went wrong.

Here's a possible implementation:

```idris
handleRequest db (MkRequest (MkCredentials email pw) album) =
  case lookupUser db of
    Just (MkUser _ _ password albums)  =>
      if password == pw then lookupAlbum albums else InvalidPassword

    Nothing => UnknownUser email

  where lookupUser : List User -> Maybe User
        lookupUser []        = Nothing
        lookupUser (x :: xs) =
          if x.email == email then Just x else lookupUser xs

        lookupAlbum : List Album -> Response
        lookupAlbum []        = AccessDenied email album
        lookupAlbum (x :: xs) =
          if x == album then Success album else lookupAlbum xs
```

I'd like to point out several things in this example. First,
note how we can extract values from nested records in a
single pattern match.
Second, we defined two *local* functions in a `where` block: `lookupUser`,
and `lookupAlbum`. Both of these have access to all variables
in the surrounding scope. For instance, `lookupUser` uses the
`album` variable from the pattern match in the implementation's
first line. Likewise, `lookupAlbum` makes use of the `album`
variable.

A `where` block introduces new local definitions, accessible
only from the surrounding scope and from other functions
defined later in the same `where` block. These need to
be explicitly typed and indented by the same amount of whitespace.

Local definitions can also be introduce *before* a function's
implementation by using the `let` keyword. This usage
of `let` is not to be confused with *let bindings* described
above, which are used to bind and reuse the results of intermediate
computations. Below is how we could have implemented `handleRequest` with
local definitions introduced by the `let` keyword. Again,
all definitions have to be properly typed and indented:

```idris
handleRequest' : DB -> Request -> Response
handleRequest' db (MkRequest (MkCredentials email pw) album) =
  let lookupUser : List User -> Maybe User
      lookupUser []        = Nothing
      lookupUser (x :: xs) =
        if x.email == email then Just x else lookupUser xs

      lookupAlbum : List Album -> Response
      lookupAlbum []        = AccessDenied email album
      lookupAlbum (x :: xs) =
        if x == album then Success album else lookupAlbum xs

   in case lookupUser db of
        Just (MkUser _ _ password albums)  =>
          if password == pw then lookupAlbum albums else InvalidPassword

        Nothing => UnknownUser email
```

### Exercises

The exercises in this section are supposed to increase
you experience in writing purely functional code. In some
cases it might be useful to use `let` expressions or
`where` blocks, but this will not always be required.

Exercise 3 is again of utmost importance. `traverseList`
is a specialized version of the more general `traverse`,
one of the most powerful and versatile functions
available in the *Prelude* (check out its type!).

1. Module `Data.List` in *base* exports functions `find` and `elem`.
   Inspect their types and use these in the implementation of
   `handleRequest`. This should allow you to completely get rid
   of the `where` block.

2. Define an enumeration type listing the four
   [nucleobases](https://en.wikipedia.org/wiki/Nucleobase)
   occurring in DNA strands. Define also a type alias
   `DNA` for lists of nucleobases.
   Declare and implement function `readBase`
   for converting a single character (type `Char`) to a nucleobase.
   You can use character literals in your implementation like so:
   `'A'`, `'a'`. Note, that this function might fail, so adjust the
   result type accordingly.

3. Implement the following function, which tries to convert all
   values in a list with a function, which might fail. The
   result should be a `Just` holding the list of converted
   values in unmodified order, if and
   only if every single conversion was successful.

   ```idris
   traverseList : (a -> Maybe b) -> List a -> Maybe (List b)
   ```

   You can verify, that the function behaves correctly with
   the following test: `traverseList Just [1,2,3] = Just [1,2,3]`.

4. Implement function `readDNA : String -> Maybe DNA`
   using the functions and types defined in exercises 2 and 3.
   You will also need function `unpack` from the *Prelude*.

5. Implement function `complement : DNA -> DNA` to
   calculate the complement of a strand of DNA.

## The Truth about Function Arguments

So far, when we defined a top level function, it looked something
like the following:

```idris
zipEitherWith : (a -> b -> c) -> Either e a -> Either e b -> Either e c
zipEitherWith f (Right va) (Right vb) = Right (f va vb)
zipEitherWith f (Left e)   _          = Left e
zipEitherWith f _          (Left e)   = Left e
```

Function `zipEitherWith` is a generic higher-order function combining the
values stored in two `Either`s via a binary function. If either
of the `Either` arguments is a `Left`, the result is also a `Left`.

This is a *generic function* with *type parameters* `a`, `b`, `c`, and `e`.
However, there is a more verbose type for `zipEitherWith`, which is
visible in the REPL when entering `:ti zipEitherWith` (the `i` here
tells Idris to include `implicit` arguments). You will get a type
similar to this:

```idris
zipEitherWith' :  {0 a : Type}
               -> {0 b : Type}
               -> {0 c : Type}
               -> {0 e : Type}
               -> (a -> b -> c)
               -> Either e a
               -> Either e b
               -> Either e c
```

In order to understand what's going on here, we will have to talk about
named arguments, implicit arguments, and quantities.

### Named Arguments

In a function type, we can give each argument a name. Like so:

```idris
fromMaybe : (deflt : a) -> (ma : Maybe a) -> a
fromMaybe deflt Nothing = deflt
fromMaybe _    (Just x) = x
```

Here, the first argument is given name `deflt`, the second `ma`. These
names can be reused in a function's implementation, as was done for `deflt`,
but this is not mandatory: We are free to use different names in the
implementation. There are several reasons, why we'd choose to name our
arguments: It can serve as documentation, but it also
allows us to pass the arguments to a function in arbitrary order
when using the following syntax:

```idris
extractBool : Maybe Bool -> Bool
extractBool v = fromMaybe { ma = v, deflt = False }
```

Or even :

```idris
extractBool2 : Maybe Bool -> Bool
extractBool2 = fromMaybe { deflt = False }
```

The arguments in a record's constructor are automatically named
in accordance with the field names:

```idris
record Dragon where
  constructor MkDragon
  name      : String
  strength  : Nat
  hitPoints : Int16

gorgar : Dragon
gorgar = MkDragon { strength = 150, name = "Gorgar", hitPoints = 10000 }
```

For the use cases described above, named arguments are merely a
convenience and completely optional. However, Idris is a *dependently typed*
programming language: Types can be calculated from and depend on
values. For instance, the *result type* of a function can *depend* on
the *value* of one of its arguments. Here's a contrived example:

```idris
IntOrString : Bool -> Type
IntOrString True  = Integer
IntOrString False = String

intOrString : (v : Bool) -> IntOrString v
intOrString False = "I'm a String"
intOrString True  = 1000
```

If you see such a thing for the first time, it can be hard to understand
what's going on here. First, function `IntOrString` computes a `Type`
from a `Bool` value: If the argument is `True`, it returns type `Integer`,
if the argument is `False` it returns `String`. We use this to
calculate the return type of function `intOrString` based on its
boolean argument `v`: If `v` is `True`, the return type is (in accordance
with `IntOrString True = Integer`) `Integer`, otherwise it is `String`.

Note, how in the type signature of `intOrString`, we *must* give the
argument of type `Bool` a name (`v`) in order to reference it in
the result type `IntOrString v`.

You might wonder at this moment, why this is useful and why we would
ever want to define a function with such a strange type. We will see
lots of very useful examples in due time! For now, suffice to say that
in order to express dependent function types, we need to name
at least some of the function's arguments and refer to them by name
in the types of other arguments.

### Implicit Arguments

Implicit arguments are arguments, the values of which the compiler
should infer and fill in for us automatically. For instance, in
the following function signature, we expect the compiler to
infer the value of type parameter `a` automatically from the
types of the other arguments (ignore the 0 quantity for the moment;
I'll explain it in the next subsection):

```idris
maybeToEither : {0 a : Type} -> Maybe a -> Either String a
maybeToEither Nothing  = Left "Nope"
maybeToEither (Just x) = Right x

-- Please remember, that the above is
-- equivalent to the following:
maybeToEither' : Maybe a -> Either String a
maybeToEither' Nothing  = Left "Nope"
maybeToEither' (Just x) = Right x
```

As you can see, implicit arguments are wrapped in curly braces,
unlike explicit named arguments, which are wrapped in parentheses.
Inferring the value of an implicit argument is not always possible.
For instance, if we enter the following
at the REPL, Idris will fail with an error:

```repl
Tutorial.Functions2> show (maybeToEither Nothing)
Error: Can't find an implementation for Show (Either String ?a).
```

Idris is unable to find an implementation of `Show (Either String a)`
without knowing what `a` actually is.
Note the question mark in front of the
type parameter: `?a`.
If this happens, there are several ways to help the type checker.
We could, for instance, pass a value for the implicit argument
explicitly. Here's the syntax to do this:

```repl
Tutorial.Functions2> show (maybeToEither {a = Int8} Nothing)
"Left "Nope""
```

As you can see, we use the same syntax
as shown above for explicit named arguments and the
two forms of argument passing can be mixed.

We could also specify the type of the whole expression using
utility function `the` from the *Prelude*:

```repl
Tutorial.Functions2> show (the (Either String Int8) (maybeToEither Nothing))
"Left "Nope""
```

It is instructive to have a look at the type of `the`:

```repl
Tutorial.Functions2> :ti the
Prelude.the : (0 a : Type) -> a -> a
```

Compare this with the identity function `id`:

```repl
Tutorial.Functions2> :ti id
Prelude.id : {0 a : Type} -> a -> a
```

The only difference between the two: In case of `the`,
the type parameter `a` is an *explicit* argument, while
in case of `id`, it is an *implicit* argument. Although
the two functions have almost identical types (and implementations!),
they serve quite different purposes: `the` is used to help
type inference, while `id` is used whenever we'd like
to return an argument without modifying it at all (which,
in the presence of higher-order functions,
happens surprisingly often).

Both ways to improve type inference shown above
are used quite often, and must be understood by Idris
programmers.

### Multiplicities

Finally, we need to talk about the zero multiplicity, which appeared
in several of the type signatures in this section. Idris 2, unlike
its predecessor Idris 1, is based on a core language called
*quantitative type theory* (QTT): Every variable in Idris 2 is
associated with one of three possible multiplicities:

* `0`, meaning that the variable is *erased* at runtime.
* `1`, meaning that the variable is used *exactly once* at runtime.
* *Unrestricted* (the default), meaning that the variable is used
   an arbitrary number of times at runtime.

We will not talk about the most complex of the three, multiplicity `1`, here.
We are, however, often interested in multiplicity `0`: A variable with
multiplicity `0` is only relevant at *compile time*. It will not make
any appearance at runtime, and the computation of such a variable will
never affect a program's runtime performance.

In the type signature of `maybeToEither` we see that type
parameter `a` has multiplicity `0`, and will therefore be erased and
is only relevant at compile time, while the `Maybe a` argument
has *unrestricted* multiplicity.

It is also possible to annotate explicit arguments with multiplicities,
in which case the argument must again be put in parentheses. For an example,
look again at the type signature of `the`.

### Underscores

It is often desirable, to only write as little code as necessary
and let Idris figure out the rest.
We have already learned about one such occasion: Catch-all patterns.
If a variable in a pattern match is not used on the right hand side,
we can't just drop it, as this would make it impossible for
Idris, which of several arguments we were planning to drop,
but we can use an underscore as a placeholder instead:

```idris
isRight : Either a b -> Bool
isRight (Right _) = True
isRight _         = False
```

But when we look at the type signature of `isRight`, we will note
that type parameters `a` and `b` are also only used once, and
are therefore of no importance. Let's get rid of them:

```idris
isRight' : Either _ _ -> Bool
isRight' (Right _) = True
isRight' _         = False
```

In the detailed type signature of `zipEitherWith`, it should
be obvious for Idris that the implicit arguments are of type `Type`.
After all, all of them are later on applied to the `Either` type
constructor, which is of type `Type -> Type -> Type`. Let's get rid
of them:

```idris
zipEitherWith'' :  {0 a : _}
                -> {0 b : _}
                -> {0 c : _}
                -> {0 e : _}
                -> (a -> b -> c)
                -> Either e a
                -> Either e b
                -> Either e c
```

Consider the following contrived example:

```idris
foo : Integer -> String
foo n = show (the (Either String Integer) (Right n))
```

Since we wrap an `Integer` in a `Right`, it is obvious
that the second argument in `Either String Integer` is
`Integer`. Only the `String` argument can't be inferred
by Idris. Even better, the `Either` itself is obvious!
Let's get rid of the unnecessary noise:

```idris
foo' : Integer -> String
foo' n = show (the (_ String _) (Right n))
```

Please note, that using underscores as in `foo'` is
not always desirable, as it can quite drastically
obfuscate the written code. Always use a syntactic
convenience to make code more readable, and not to
show people how clever you are.

## Programming with Holes

Solved all the exercises so far? Got angry at the type checker
for always complaining and never being really helpful? It's time
to change that. Idris comes with several highly useful interactive
editing features. Sometimes, the compiler is able to implement
complete functions for us (if the types are specific enough). Even
if that's not possible, there's an incredibly useful and important
feature, which can help us when the types are getting too complicated: Holes.
Holes are variables, the names of which are prefixed with a question mark.
We can use them as placeholders whenever we plan to implement a piece
of functionality at a later time. In addition, their types and the types
and quantities of all other variables in scope can be inspected
at the REPL (or in your editor, if you setup the necessary plugin).
Let's see them holes in action.

Remember the `traverseList` example from an Exercise earlier in
this section? If this was your first encounter with applicative list
traversals, this might have been a nasty bit of work. Well, let's just
make it a wee bit harder still. We'd like to implement the same
piece of functionality for functions returning `Either e`, where
`e` is a type with a `Semigroup` implementation, and we'd like
to accumulate the values in all `Left`s we meet along the way.

Here's the type of the function:

```idris
traverseEither :  Semigroup e
               => (a -> Either e b)
               -> List a
               -> Either e (List b)
```

Now, in order to follow along, you might want to start your own
Idris source file, load it into a REPL session and adjust the
code as described here. The first thing we'll do, is write a
skeleton implementation with a hole on the right hand side:

```repl
traverseEither fun as = ?impl
```

When you now go to the REPL and reload the file using command `:r`,
you can enter `:m` to list all the *metavariables*:

```repl
Tutorial.Functions2> :m
1 hole:
  Tutorial.Functions2.impl : Either e (List b)
```

Next, we'd like to display the hole's type (including all variables in the
surrounding context plus their types):

```repl
Tutorial.Functions2> :t impl
 0 b : Type
 0 a : Type
 0 e : Type
   as : List a
   fun : a -> Either e b
------------------------------
impl : Either e (List b)
```

So, we have some erased type parameters (`a`, `b`, and `e`), a value
of type `List a` called `as`, and a function from `a` to
`Either e b` called `fun`. Our goal is to come up with a value
of type `Either a (List b)`.

We *could* just return a `Right []`, but that only make sense
if our input list is indeed the empty list. We therefore should
start with a pattern match on the list:

```repl
traverseEither fun []        = ?impl_0
traverseEither fun (x :: xs) = ?impl_1
```

The result is two holes, which must be given distinct names. When inspecting `impl_0`,
we get the following result:

```repl
Tutorial.Functions2> :t impl_0
 0 b : Type
 0 a : Type
 0 e : Type
   fun : a -> Either e b
------------------------------
impl_0 : Either e (List b)
```

Now, this is an interesting situation. We are supposed to come up with a value
of type `Either e (List b)` with nothing to work with. We know nothing
about `a`, so we can't provide an argument with which to invoke `fun`.
Likewise, we know nothing about `e` or `b` either, so we can't produce
any values of these either. The *only* option we have is to replace `impl_0`
with an empty list wrapped in a `Right`:

```idris
traverseEither fun []        = Right []
```

The non-empty case is of course slightly more involved. Here's the context
of `?impl_1`:

```repl
Tutorial.Functions2> :t impl_1
 0 b : Type
 0 a : Type
 0 e : Type
   x : a
   xs : List a
   fun : a -> Either e b
------------------------------
impl_1 : Either e (List b)
```

Since `x` is of type `a`, we can either use it as an argument
to `fun` or drop and ignore it. `xs`, on the other hand, is
the remainder of the list of type `List a`. We could again
drop it or process it further by invoking `traverseEither`
recursively. Since the goal is to try and convert *all* values,
we should drop neither. Since in case of two `Left`s we
are supposed to accumulate the values, we eventually need to
run both computations anyway (invoking `fun`, and recursively
calling `traverseEither`). We therefore can do both at the
same time and analyze the results in a single pattern match
by wrapping both in a `Pair`:

```repl
traverseEither fun (x :: xs) =
  case (fun x, traverseEither fun xs) of
   p => ?impl_2
```

Once again, we inspect the context:

```repl
Tutorial.Functions2> :t impl_2
 0 b : Type
 0 a : Type
 0 e : Type
   xs : List a
   fun : a -> Either e b
   x : a
   p : (Either e b, Either e (List b))
------------------------------
impl_2 : Either e (List b)
```

We'll definitely need to pattern match on pair `p` next
to figure out, which of the two computations succeeded:

```repl
traverseEither fun (x :: xs) =
  case (fun x, traverseEither fun xs) of
    (Left y, Left z)   => ?impl_6
    (Left y, Right _)  => ?impl_7
    (Right _, Left z)  => ?impl_8
    (Right y, Right z) => ?impl_9
```

At this point we might have forgotten what we actually
wanted to do (at least to me, this happens annoyingly often),
so we'll just quickly check what our goal is:

```repl
Tutorial.Functions2> :t impl_6
 0 b : Type
 0 a : Type
 0 e : Type
   xs : List a
   fun : a -> Either e b
   x : a
   y : e
   z : e
------------------------------
impl_6 : Either e (List b)
```

So, we are still looking for a value of type `Either e (List b)`, and
we have two values of type `e` in scope. According to the spec we
want to accumulate these using `e`s `Semigroup` implementation.
We can proceed for the other cases in a similar manner, remembering
that we should return a `Right`, if and only if all conversions
where successful:

```idris
traverseEither fun (x :: xs) =
  case (fun x, traverseEither fun xs) of
    (Left y, Left z)   => Left (y <+> z)
    (Left y, Right _)  => Left y
    (Right _, Left z)  => Left z
    (Right y, Right z) => Right (y :: z)
```

To reap the fruits of our labour, let's show off with a small example:

```idris
data Nucleobase = Adenine | Cytosine | Guanine | Thymine

readNucleobase : Char -> Either (List String) Nucleobase
readNucleobase 'A' = Right Adenine
readNucleobase 'C' = Right Cytosine
readNucleobase 'G' = Right Guanine
readNucleobase 'T' = Right Thymine
readNucleobase c   = Left ["Unknown nucleobase: " ++ show c]

DNA : Type
DNA = List Nucleobase

readDNA : String -> Either (List String) DNA
readDNA = traverseEither readNucleobase . unpack
```

Let's try this at the REPL:

```repl
Tutorial.Functions2> readDNA "CGTTA"
Right [Cytosine, Guanine, Thymine, Thymine, Adenine]
Tutorial.Functions2> readDNA "CGFTAQ"
Left ["Unknown nucleobase: 'F'", "Unknown nucleobase: 'Q'"]
```

### Interactive Editing

There are plugins available for several editors and
programming environments, which facilitate interacting
with the Idris compiler when implementing your functions.
One editor, which is well supported in the Idris
community, is Neovim. Since I am a Neovim user myself,
I added some examples of what's possible to the
[appendix](../Appendices/Neovim.md). Now would be a good
time to start using the utilities discussed there.

If you use a different editor, probably with less support
for the Idris programming language, you should at the very
least have a REPL session open all the time, where the
source file you are currently working on is loaded. This
allows you to introduce new metavariables and inspect their
types and context as you develop your code.

## Conclusion

We again covered a lot of ground in this section. I can't stress enough that you
should get yourselves accustomed to programming with holes and let the
type checker help you figure out what to do next.

* When in need of local utility functions, consider defining them
as local definitions in a *where block*.

* Use *let expressions* to define and reuse local variables.

* Function arguments can be given a name, which can serve as documentation,
can be used to pass arguments in any order, and is used to refer to
them in dependent types.

* Implicit arguments are wrapped in curly braces. The compiler is
supposed to infer them from the context. If that's not possible,
they can be passed explicitly as other named arguments.

* Whenever possible, Idris adds implicit erased arguments for all
type parameters automatically.

* Quantities allow us to track how often a function argument is
used. Quantity 0 means, the argument is erased at runtime.

* Use *holes* as placeholders for pieces of code you plan to fill
in at a later time. Use the REPL (or your editor) to inspect
the types of holes together with the names, types, and quantities of all
variables in their context.

### What's next

In the [next chapter](Dependent.md)
we'll start using dependent types to help us write provably correct code.
Having a good understanding of how to read
Idris' type signatures will be of paramount importance there. Whenever
you feel lost, add one or more holes and inspect their context to decide what to
do next.

<!-- vi: filetype=idris2:syntax=markdown
-->
