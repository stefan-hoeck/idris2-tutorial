# Functions Part 2

So far, we learned about the core features of the Idris
language, which it has in common with several other
pure, strongly typed programming languages like Haskell:
(Higher order) Functions, algebraic data types, pattern matching
and parametric polymorphism (generic types and functions).

In this part we start to dissect Idris functions for real.
We learn about implicit and named arguments, erasure and
quantities and auto implicits.

```idris
module Tutorial.Functions2

%default total
```

## `let` Bindings and `where` Blocks

The functions we looked at so far where simple enough
to be implemented directly via pattern matching
without the need of additional auxiliary functions or
variables. This is not always the case, and there are two
important language constructs for introducing and reusing
new local variables and functions.

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

At this moment, you might think: "Why is that useful?
It's not about lists at all! And what are those strange
arrows in the function's signature?" I keep repeating myself:
You will learn about how this works in due time. For
the time being, suffice to say that `sum` allows us to
sum up different kinds of numeric values stored in
different kinds of container types like `List`, `Maybe`,
`Either`, and several others you have not yet learned about.

In order to also calculate the variance,
we need to convert every value in the list to
a new value, as we have to subtract the mean
from every value in the list and square the
result. In the previous section's exercises, we
defined function `mapList` for this. The *Prelude* - of course -
already exports a similar function called `map`,
which is again more general
and works also like our `mapMaybe` for `Maybe`
and `mapEither` for `Either e`. Have a look at its
type, if you'd like to freak out again :-).

```repl
Main> :t map
Prelude.map : Functor f => (a -> b) -> f a -> f b
```

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
of the implementation. To do so, we us a `let` binding. This
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
of having to write some rather boring utility functions.

For instance, we will need check pairs of values of types
`Artist`, `Email`, and `Password` for being equal. With `String`,
we could just have used the equality operator `(==)`, but
with our custom data types, this is no longer possible. (Actually,
it *is* possible and very straight forward, but we'll have to
learn about interfaces first.)

We therefore have to write some quick boilerplate code. Utility
function `on` from the *Prelude* is very useful here. Don't
forget to inspect its type at the REPL, and try to understand what's
going on here.

```idris
eqArtist : Artist -> Artist -> Bool
eqArtist = (==) `on` name

eqEmail : Email -> Email -> Bool
eqEmail = (==) `on` value

eqPassword : Password -> Password -> Bool
eqPassword = (==) `on` value
```

We will also need to compare two `Album`s for equality.

```idris
eqAlbum : Album -> Album -> Bool
eqAlbum (MkAlbum n1 a1) (MkAlbum n2 a2) = n1 == n2 && eqArtist a1 a2
```

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
to start the actual album stream, but we will just
wrap up the album we found.

We can now go ahead and simulate the handling of
a request at the server. To emulate our user data base,
we just use a list of users. Here's the type of the
function we'd like to implement:

```idris
DB : Type
DB = List User

handleRequest : DB -> Request -> Response
```

Note, how we defined a shorter alias for `List User` called `DB`.
This is often useful to make lengthy type signatures more readable
and communicate the meaning of a type in the given context. Note,
however, that this will *not* introduce a new type, nor will it
increase type safety: `DB` is *identical* to `List User`, and as
such a value of type `DB` can be used wherever a `List User` is
expected and vice versa. In more complex programs it is therefore
often preferable to define a new types by wrapping values in
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
      if eqPassword password pw
         then lookupAlbum albums
         else InvalidPassword

    Nothing => UnknownUser email

  where lookupUser : List User -> Maybe User
        lookupUser []        = Nothing
        lookupUser (x :: xs) =
          if eqEmail x.email email then Just x else lookupUser xs

        lookupAlbum : List Album -> Response
        lookupAlbum []        = AccessDenied email album
        lookupAlbum (x :: xs) =
          if eqAlbum x album then Success album else lookupAlbum xs
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

Unlike in a `let` binding where we can often omit explicit
type annotations, local functions in a `where` block need to
be explicitly typed. Also, all functions in a `where` block
must be indented by the same amount of whitespace.

### Exercises

The exercises in this section are supposed to increase
you experience in writing purely functional code. In some
cases it might be useful to use `let` expressions or
`where` blocks, but this will not always be required.

Exercise 3 is again of utmost importance. `traverseList`
is a specialized version of the more general `traverse`,
one of the most powerful and versatile functions
available in the *Prelude*.

1. Module `Data.List` in *base* exports functions `find` and `elemBy`.
Inspect their types and use these in the implementation of
`handleRequest`. This should allow you to completely get rid
of the `where` block.

2. Define an enumeration type listing the four nucleobases
occurring in DNA strands. Define also a type alias
`DNA` for lists of nucleobases.
Declare and implement function `readBase`
for converting a single character (type `Char`) to a nucleobase.
You can use character literals in your implementation like so:
`'A'`, `'a'`. Note, that this function might fail, so adjust the
result type accordingly.

3. Implement the following function, which tries to convert all
values in a list with a function which might fail. The
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

Function `zipEitherWith` is a generic function combining the
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
but this is not mandatory. We are free to use different names in the
implementation. There are several reasons, why we'd choose to name our
arguments. It can serve as documentation, but it also
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
argument of type `Bool` a name (`v`), in order to reference it in
the result type `IntOrString v`.

You might wonder at this moment, why this is useful and why we should
ever want to define a function with such a strange type. We will see
lots of very useful examples in due time! For now, suffice to say that
in order to express dependent function types, we need to name
at least some of the function's arguments in order to refer to them
in the types of other arguments.

### Implicit Arguments

Implicit arguments are arguments, the values of which the compiler
should infer and fill in for us automatically. For instance, in
the following function signature, we expect the compiler to
infer the value of type parameter `a` automatically from the
types of the other arguments (ignore the 0 quantity for the moment;
I'll explain it in the next session):

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

Since we haven't learned about interfaces yet, you might not fully understand
the error message above. However, note the question mark in front of the
type parameter: `?a`. This means, Idris could not figure out the
value of the implicit argument from the other arguments. This
is not always a problem, but here, Idris
can't decide how to properly display the result using `show`
without knowing the value of `?a`.
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
the serve quite different purposes: `the` is used to help
with type inference, while `id` is used whenever we'd like
to return an argument without modifying it at all (which,
in the presence of higher order functions,
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

* `0`, meaning that the variable is *erased* at runtime
* `1`, meaning that the variable is used *exactly once* at runtime
* *Unrestricted* (the default), meaning that the variable is used
an arbitrary number of times at runtime

We will not talk about the most complex of the three, multiplicity `1`, here.
We are, however, often interested in multiplicity `0`: A variable with
multiplicity `0` is only relevant at *compile time*. It will not make
any appearance at runtime, and the computation of such a multiplicity will
never affect a program's runtime performance.

In the type signature of `maybeToEither` we see that type
parameter `a` has multiplicity `0`, and will therefore be erased and
only relevant at compile time, while the `Maybe a` argument
has *unrestricted* multiplicity.

It is also possible to annotate explicit arguments with multiplicities,
in which case the argument must again be put in parentheses. We'll
see examples of this later on.

### Underscores

It is often desirable, to only write as little code as necessary
and let Idris figure out the rest. There are several occasions, where
we need to fill in some piece of information, but would rather
use a placeholder and let Idris figure out the rest.
We have already learned about one such occasion: Catch-all patterns.
If a variable in a pattern match is not used on the right hand side,
we can't just drop, but we can use an underscore as a placeholder instead:

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

## Interfaces and Auto Implicits

Finally, it is time to learn the basics about interfaces. We will not
yet cover all the details here, and we will definitely not yet
introduce all the interfaces available from the *Prelude*, as some
of them can be rather mind-boggling when use for the first time.

We have already seen several occasions, where we used the
same kind of functionality for different types, the most
prevalent probably being comparing two values for being
equal.

<!-- vi: filetype=idris2
-->
