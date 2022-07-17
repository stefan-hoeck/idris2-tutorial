# Functor and Friends

Programming, like mathematics, is about abstraction. We
try to model parts of the real world, reusing recurring
patterns by abstracting over them.

In this chapter, we will learn about several related interfaces,
which are all about abstraction and therefore can be hard to
understand at the beginning. Especially figuring out
*why* they are useful and *when* to use them will take
time and experience. This chapter therefore comes
with tons of exercises, most of which can be solved
with only a few short lines of code. Don't skip them.
Come back to them several times until these things start
feeling natural to you. You will then realize that their
initial complexity has vanished.

```idris
module Tutorial.Functor

import Data.List1
import Data.String
import Data.Vect

%default total
```

## Functor

What do type constructors like `List`, `List1`, `Maybe`, or
`IO` have in common? First, all of them are of type
`Type -> Type`. Second, they all put values of a given type
in a certain *context*. With `List`,
the *context* is *non-determinism*: We know there to
be zero or more values, but we don't know the exact number
until we start taking the list apart by pattern matching
on it. Likewise for `List1`, though we know for sure that
there is at least one value. For `Maybe`, we are still not
sure about how many values there are, but the possibilities
are much smaller: Zero or one. With `IO`, the context is a different one:
Arbitrary side effects.

Although the type constructors discussed above are quite
different in how they behave and when they are useful,
there are certain operations that keep coming up
when working with them. The first such operation
is *mapping a pure function over the data type, without
affecting its underlying structure*.

For instance, given a list of numbers, we'd like to multiply
each number by two, without changing their order or removing
any values:

```idris
multBy2List : Num a => List a -> List a
multBy2List []        = []
multBy2List (x :: xs) = 2 * x :: multBy2List xs
```

But we might just as well convert every string in a
list of strings to upper case characters:

```idris
toUpperList : List String -> List String
toUpperList []        = []
toUpperList (x :: xs) = toUpper x :: toUpperList xs
```

Sometimes, the type of the stored value changes. In the
next example, we calculate the lengths of the strings stored
in a list:

```idris
toLengthList : List String -> List Nat
toLengthList []        = []
toLengthList (x :: xs) = length x :: toLengthList xs
```

I'd like you to appreciate, just how boring these functions are. They
are almost identical, with the only interesting part being
the function we apply to each element. Surely, there must be a
pattern to abstract over:

```idris
mapList : (a -> b) -> List a -> List b
mapList f []        = []
mapList f (x :: xs) = f x :: mapList f xs
```

This is often the first step of abstraction in functional
programming: Write a (possibly generic) higher-order function.
We can now concisely implement all examples shown above in
terms of `mapList`:

```idris
multBy2List' : Num a => List a -> List a
multBy2List' = mapList (2 *)

toUpperList' : List String -> List String
toUpperList' = mapList toUpper

toLengthList' : List String -> List Nat
toLengthList' = mapList length
```

But surely we'd like to do the same kind of thing with
`List1` and `Maybe`! After all, they are just container
types like `List`, the only difference being some detail
about the number of values they can or can't hold:

```idris
mapMaybe : (a -> b) -> Maybe a -> Maybe b
mapMaybe f Nothing  = Nothing
mapMaybe f (Just v) = Just (f v)
```

Even with `IO`, we'd like to be able to map pure functions
over effectful computations. The implementation is
a bit more involved, due to the nested layers of
data constructors, but if in doubt, the types will surely
guide us. Note, however, that `IO` is not publicly exported,
so its data constructor is unavailable to us. We can use
functions `toPrim` and `fromPrim`, however, for converting
`IO` from and to `PrimIO`, which we can freely dissect:

```idris
mapIO : (a -> b) -> IO a -> IO b
mapIO f io = fromPrim $ mapPrimIO (toPrim io)
  where mapPrimIO : PrimIO a -> PrimIO b
        mapPrimIO prim w =
          let MkIORes va w2 = prim w
           in MkIORes (f va) w2
```

From the concept of *mapping a pure function over
values in a context* follow some derived functions, which are
often useful. Here are some of them for `IO`:

```idris
mapConstIO : b -> IO a -> IO b
mapConstIO = mapIO . const

forgetIO : IO a -> IO ()
forgetIO = mapConstIO ()
```

Of course, we'd want to implement `mapConst` and `forget` as well
for `List`, `List1`, and `Maybe` (and dozens of other type
constructors with some kind of mapping function), and they'd
all look the same and be equally boring.

When we come upon a recurring class of functions with
several useful derived functions, we should consider defining
an interface. But how should we go about this here?
When you look at the types of `mapList`, `mapMaybe`, and `mapIO`,
you'll see that it's the `List`, `List1`, and `IO` types we
need to get rid of. These are not of type `Type` but of type
`Type -> Type`. Luckily, there is nothing preventing us
from parametrizing an interface over something else than
a `Type`.

The interface we are looking for is called `Functor`.
Here is its definition and an example implementation (I appended
a tick at the end of the names for them not to overlap with
the interface and functions exported by the *Prelude*):

```idris
interface Functor' (0 f : Type -> Type) where
  map' : (a -> b) -> f a -> f b

implementation Functor' Maybe where
  map' _ Nothing  = Nothing
  map' f (Just v) = Just $ f v
```

Note, that we had to give the type of parameter `f` explicitly,
and in that case it needs to be annotated with quantity zero if
you want it to be erased at runtime (which you almost always want).

Now, reading type signatures consisting only of type parameters
like the one of `map'` can take some time to get used to, especially
when some type parameters are applied to other parameters as in
`f a`. It can be very helpful to inspect these signatures together
with all implicit arguments at the REPL (I formatted the output to
make it more readable):

```repl
Tutorial.Functor> :ti map'
Tutorial.Functor.map' :  {0 b : Type}
                      -> {0 a : Type}
                      -> {0 f : Type -> Type}
                      -> Functor' f
                      => (a -> b)
                      -> f a
                      -> f b
```

It can also be helpful to replace type parameter `f` with a concrete
value of the same type:

```repl
Tutorial.Functor> :t map' {f = Maybe}
map' : (?a -> ?b) -> Maybe ?a -> Maybe ?b
```

Remember, being able to interpret type signatures is paramount to
understanding what's going on in an Idris declaration. You *must*
practice this and make use of the tools and utilities given to you.

### Derived Functions

There are several functions and operators directly derivable from interface
`Functor`. Eventually, you should know and remember all of them as
they are highly useful. Here they are together with their types:

```repl
Tutorial.Functor> :t (<$>)
Prelude.<$> : Functor f => (a -> b) -> f a -> f b

Tutorial.Functor> :t (<&>)
Prelude.<&> : Functor f => f a -> (a -> b) -> f b

Tutorial.Functor> :t ($>)
Prelude.$> : Functor f => f a -> b -> f b

Tutorial.Functor> :t (<$)
Prelude.<$ : Functor f => b -> f a -> f b

Tutorial.Functor> :t ignore
Prelude.ignore : Functor f => f a -> f ()
```

`(<$>)` is an operator alias for `map` and allows you to sometimes
drop some parentheses. For instance:

```idris
tailShowReversNoOp : Show a => List1 a -> List String
tailShowReversNoOp xs = map (reverse . show) (tail xs)

tailShowReverse : Show a => List1 a -> List String
tailShowReverse xs = reverse . show <$> tail xs
```

`(<&>)` is an alias for `(<$>)` with the arguments flipped.
The other three (`ignore`, `($>)`, and `(<$)`) are all used
to replace the values in a context with a constant. They are often useful
when you don't care about the values themselves but
want to keep the underlying structure.

### Functors with more than one Type Parameter

The type constructors we looked at so far were all
of type `Type -> Type`. However, we can also implement `Functor`
for other type constructors. The only prerequisite is that
the type parameter we'd like to change with function `map` must
be the last in the argument list. For instance, here is the
`Functor` implementation for `Either e` (note, that `Either e`
has of course type `Type -> Type` as required):

```idris
implementation Functor' (Either e) where
  map' _ (Left ve)  = Left ve
  map' f (Right va) = Right $ f va
```

Here is another example, this time for a type constructor of
type `Bool -> Type -> Type` (you might remember this from
the exercises in the [last chapter](IO.md)):

```idris
data List01 : (nonEmpty : Bool) -> Type -> Type where
  Nil  : List01 False a
  (::) : a -> List01 False a -> List01 ne a

implementation Functor (List01 ne) where
  map _ []        = []
  map f (x :: xs) = f x :: map f xs
```

### Functor Composition

The nice thing about functors is how they can be paired and
nested with other functors and the results are functors again:

```idris
record Product (f,g : Type -> Type) (a : Type) where
  constructor MkProduct
  fst : f a
  snd : g a

implementation Functor f => Functor g => Functor (Product f g) where
  map f (MkProduct l r) = MkProduct (map f l) (map f r)
```

The above allows us to conveniently map over a pair of functors. Note,
however, that Idris needs some help with inferring the types involved:

```idris
toPair : Product f g a -> (f a, g a)
toPair (MkProduct fst snd) = (fst, snd)

fromPair : (f a, g a) -> Product f g a
fromPair (x,y) = MkProduct x y

productExample :  Show a
               => (Either e a, List a)
               -> (Either e String, List String)
productExample = toPair . map show . fromPair {f = Either e, g = List}
```

More often, we'd like to map over several layers of nested functors
at once. Here's how to do this with an example:

```idris
record Comp (f,g : Type -> Type) (a : Type) where
  constructor MkComp
  unComp  : f (g a)

implementation Functor f => Functor g => Functor (Comp f g) where
  map f (MkComp v) = MkComp $ map f <$> v

compExample :  Show a => List (Either e a) -> List (Either e String)
compExample = unComp . map show . MkComp {f = List, g = Either e}
```

#### Named Implementations

Sometimes, there are more ways to implement an interface for
a given type. For instance, for numeric types we can have
a `Monoid` representing addition and one representing multiplication.
Likewise, for nested functors, `map` can be interpreted as a mapping
over only the first layer of values, or a mapping over several layers
of values.

One way to go about this is to define single-field wrappers as
shown with data type `Comp` above. However, Idris also allows us
to define additional interface implementations, which must then
be given a name. For instance:

```idris
[Compose'] Functor f => Functor g => Functor (f . g) where
  map f = (map . map) f
```

Note, that this defines a new implementation of `Functor`, which will
*not* be considered during implicit resolution in order
to avoid ambiguities. However,
it is possible to explicitly choose to use this implementation
by passing it as an explicit argument to `map`, prefixed with an `@`:

```idris
compExample2 :  Show a => List (Either e a) -> List (Either e String)
compExample2 = map @{Compose} show
```

In the example above, we used `Compose` instead of `Compose'`, since
the former is already exported by the *Prelude*.

### Functor Laws

Implementations of `Functor` are supposed to adhere to certain laws,
just like implementations of `Eq` or `Ord`. Again, these laws are
not verified by Idris, although it would be possible (and
often cumbersome) to do so.

1. `map id = id`: Mapping the identity function over a functor
    must not have any visible effect such as changing a container's
    structure or affecting the side effects perfomed when
    running an `IO` action.

2. `map (f . g) = map f . map g`: Sequencing two mappings must be identical
   to a single mapping using the composition of the two functions.

Both of these laws request, that `map` is preserving the *structure*
of values. This is easier to understand with container types like
`List`, `Maybe`, or `Either e`, where `map` is not allowed to
add or remove any wrapped value, nor - in case of `List` -
change their order. With `IO`, this can best be described as `map`
not performing additional side effects.

### Exercises part 1

1. Write your own implementations of `Functor'` for `Maybe`, `List`,
   `List1`, `Vect n`, `Either e`, and `Pair a`.

2. Write a named implementation of `Functor` for pairs of functors
   (similar to the one implemented for `Product`).

3. Implement `Functor` for data type `Identity` (which is available
   from `Control.Monad.Identity` in *base*):

   ```idris
   record Identity a where
     constructor Id
     value : a
   ```

4. Here is a curious one: Implement `Functor` for `Const e` (which is also
   available from `Control.Applicative.Const` in *base*). You might be
   confused about the fact that the second type parameter has absolutely
   no relevance at runtime, as there is no value of that type. Such
   types are sometimes called *phantom types*. They can be quite useful
   for tagging values with additional typing information.

   Don't let the above confuse you: There is only one possible implementation.
   As usual, use holes and let the compiler guide you if you get lost.

   ```idris
   record Const (e,a : Type) where
     constructor MkConst
     value : e
   ```

5. Here is a sum type for describing CRUD operations
   (Create, Read, Update, and Delete) in a data store:

   ```idris
   data Crud : (i : Type) -> (a : Type) -> Type where
     Create : (value : a) -> Crud i a
     Update : (id : i) -> (value : a) -> Crud i a
     Read   : (id : i) -> Crud i a
     Delete : (id : i) -> Crud i a
   ```

   Implement `Functor` for `Crud i`.

6. Here is a sum type for describing responses from a data server:

   ```idris
   data Response : (e, i, a : Type) -> Type where
     Created : (id : i) -> (value : a) -> Response e i a
     Updated : (id : i) -> (value : a) -> Response e i a
     Found   : (values : List a) -> Response e i a
     Deleted : (id : i) -> Response e i a
     Error   : (err : e) -> Response e i a
   ```

   Implement `Functor` for `Repsonse e i`.

7. Implement `Functor` for `Validated e`:

   ```idris
   data Validated : (e,a : Type) -> Type where
     Invalid : (err : e) -> Validated e a
     Valid   : (val : a) -> Validated e a
   ```

## Applicative

While `Functor` allows us to map a pure, unary function
over a value in a context, it doesn't allow us to combine
n such values under an n-ary function.

For instance, consider the following functions:

```idris
liftMaybe2 : (a -> b -> c) -> Maybe a -> Maybe b -> Maybe c
liftMaybe2 f (Just va) (Just vb) = Just $ f va vb
liftMaybe2 _ _         _         = Nothing

liftVect2 : (a -> b -> c) -> Vect n a -> Vect n b -> Vect n c
liftVect2 _ []        []        = []
liftVect2 f (x :: xs) (y :: ys) = f x y :: liftVect2 f xs ys

liftIO2 : (a -> b -> c) -> IO a -> IO b -> IO c
liftIO2 f ioa iob = fromPrim $ go (toPrim ioa) (toPrim iob)
  where go : PrimIO a -> PrimIO b -> PrimIO c
        go pa pb w =
          let MkIORes va w2 = pa w
              MkIORes vb w3 = pb w2
           in MkIORes (f va vb) w3
```

This behavior is not covered by `Functor`, yet it is a very
common thing to do. For instance, we might want to read two numbers
from standard input (both operations might fail), calculating the
product of the two. Here's the code:

```idris
multNumbers : Num a => Neg a => IO (Maybe a)
multNumbers = do
  s1 <- getLine
  s2 <- getLine
  pure $ liftMaybe2 (*) (parseInteger s1) (parseInteger s2)
```

And it won't stop here. We might just as well want to have
`liftMaybe3` for ternary functions and three `Maybe` arguments
and so on, for arbitrary numbers of arguments.

But there is more: We'd also like to lift pure values into
the context in question. With this, we could do the following:

```idris
liftMaybe3 : (a -> b -> c -> d) -> Maybe a -> Maybe b -> Maybe c -> Maybe d
liftMaybe3 f (Just va) (Just vb) (Just vc) = Just $ f va vb vc
liftMaybe3 _ _         _         _         = Nothing

pureMaybe : a -> Maybe a
pureMaybe = Just

multAdd100 : Num a => Neg a => String -> String -> Maybe a
multAdd100 s t = liftMaybe3 calc (parseInteger s) (parseInteger t) (pure 100)
  where calc : a -> a -> a -> a
        calc x y z = x * y + z
```

As you'll of course already know, I am now going to present a new
interface to encapsulate this behavior. It's called `Applicative`.
Here is its definition and an example implementation:

```idris
interface Functor' f => Applicative' f where
  app   : f (a -> b) -> f a -> f b
  pure' : a -> f a

implementation Applicative' Maybe where
  app (Just fun) (Just val) = Just $ fun val
  app _          _          = Nothing

  pure' = Just
```

Interface `Applicative` is of course already exported by the *Prelude*.
There, function `app` is an operator sometimes called *app* or *apply*:
`(<*>)`.

You may wonder, how functions like `liftMaybe2` or `liftIO3` are related
to operator *apply*. Let me demonstrate this:

```idris
liftA2 : Applicative f => (a -> b -> c) -> f a -> f b -> f c
liftA2 fun fa fb = pure fun <*> fa <*> fb

liftA3 : Applicative f => (a -> b -> c -> d) -> f a -> f b -> f c -> f d
liftA3 fun fa fb fc = pure fun <*> fa <*> fb <*> fc
```

It is really important for you to understand what's going on here, so let's
break these down. If we specialize `liftA2` to use `Maybe` for `f`,
`pure fun` is of type `Maybe (a -> b -> c)`. Likewise, `pure fun <*> fa`
is of type `Maybe (b -> c)`, as `(<*>)` will apply the value stored
in `fa` to the function stored in `pure fun` (currying!).

You'll often see such chains of applications of *apply*, the number
of *applies* corresponding to the arity of the function we lift.
You'll sometimes also see the following, which allows us to drop
the initial call to `pure`, and use the operator version of `map`
instead:

```idris
liftA2' : Applicative f => (a -> b -> c) -> f a -> f b -> f c
liftA2' fun fa fb = fun <$> fa <*> fb

liftA3' : Applicative f => (a -> b -> c -> d) -> f a -> f b -> f c -> f d
liftA3' fun fa fb fc = fun <$> fa <*> fb <*> fc
```

So, interface `Applicative` allows us to lift values (and functions!)
into computational contexts and apply them to values in the same
contexts. Before we will see an extended example why this is
useful, I'll quickly introduce some syntactic sugar for working
with applicative functors.

### Idiom Brackets

The programming style used for implementing `liftA2'` and `liftA3'`
is also referred to as *applicative style* and is used a lot
in Haskell for combining several effectful computations
with a single pure function.

In Idris, there is an alternative to using such chains of
operator applications: Idiom brackets. Here's another
reimplementation of `liftA2` and `liftA3`:

```idris
liftA2'' : Applicative f => (a -> b -> c) -> f a -> f b -> f c
liftA2'' fun fa fb = [| fun fa fb |]

liftA3'' : Applicative f => (a -> b -> c -> d) -> f a -> f b -> f c -> f d
liftA3'' fun fa fb fc = [| fun fa fb fc |]
```

The above implementations will be desugared to the one given
for `liftA2` and `liftA3`, again *before disambiguating,
type checking, and filling in of implicit values*. Like with the
*bind* operator, we can therefore write custom implementations
for `pure` and `(<*>)`, and Idris will use these if it
can disambiguate between the overloaded function names.

### Use Case: CSV Reader

In order to understand the power and versatility that comes
with applicative functors, we will look at a slightly
extended example. We are going to write some utilities
for parsing and decoding content from CSV files. These
are files where each line holds a list of values separated
by commas (or some other delimiter). Typically, they are
used to store tabular data, for instance from spread sheet
applications. What we would like to do is convert
lines in a CSV file and store the result in custom
records, where each record field corresponds to a column
in the table.

For instance, here is a simple example
file, containing tabular user information from a web
store: First name, last name, age (optional), email address,
gender, and password.

```repl
Jon,Doe,42,jon@doe.ch,m,weijr332sdk
Jane,Doe,,jane@doe.ch,f,aa433sd112
Stefan,Hoeck,,nope@goaway.ch,m,password123
```

And here are the Idris data types necessary to hold
this information at runtime. We use again custom
string wrappers for increased type safety and
because it will allow us to define for each data type
what we consider to be valid input:

```idris
data Gender = Male | Female | Other

record Name where
  constructor MkName
  value : String

record Email where
  constructor MkEmail
  value : String

record Password where
  constructor MkPassword
  value : String

record User where
  constructor MkUser
  firstName : Name
  lastName  : Name
  age       : Maybe Nat
  email     : Email
  gender    : Gender
  password  : Password
```

We start by defining an interface for reading fields
in a CSV file and writing implementations for
the data types we'd like to read:

```idris
interface CSVField a where
  read : String -> Maybe a
```

Below are implementations for `Gender` and `Bool`. I decided
to in these cases encode each value with a single lower
case character:

```idris
CSVField Gender where
  read "m" = Just Male
  read "f" = Just Female
  read "o" = Just Other
  read _   = Nothing

CSVField Bool where
  read "t" = Just True
  read "f" = Just False
  read _   = Nothing
```

For numeric types, we can use the parsing functions
from `Data.String`:

```idris
CSVField Nat where
  read = parsePositive

CSVField Integer where
  read = parseInteger

CSVField Double where
  read = parseDouble
```

For optional values, the stored type must itself
come with an instance of `CSVField`. We can then treat
the empty string `""` as `Nothing`, while a non-empty
string will be passed to the encapsulated type's field reader.
(Remember that `(<$>)` is an alias for `map`.)

```idris
CSVField a => CSVField (Maybe a) where
  read "" = Just Nothing
  read s  = Just <$> read s
```

Finally, for our string wrappers, we need to decide what
we consider to be valid values. For simplicity, I decided
to limit the length of allowed strings and the set of
valid characters.

```idris
readIf : (String -> Bool) -> (String -> a) -> String -> Maybe a
readIf p mk s = if p s then Just (mk s) else Nothing

isValidName : String -> Bool
isValidName s =
  let len = length s
   in 0 < len && len <= 100 && all isAlpha (unpack s)

CSVField Name where
  read = readIf isValidName MkName

isEmailChar : Char -> Bool
isEmailChar '.' = True
isEmailChar '@' = True
isEmailChar c   = isAlphaNum c

isValidEmail : String -> Bool
isValidEmail s =
  let len = length s
   in 0 < len && len <= 100 && all isEmailChar (unpack s)

CSVField Email where
  read = readIf isValidEmail MkEmail

isPasswordChar : Char -> Bool
isPasswordChar ' ' = True
isPasswordChar c   = not (isControl c) && not (isSpace c)

isValidPassword : String -> Bool
isValidPassword s =
  let len = length s
   in 8 < len && len <= 100 && all isPasswordChar (unpack s)

CSVField Password where
  read = readIf isValidPassword MkPassword
```

In a later chapter, we will learn about refinement types and
how to store an erased proof of validity together with
a validated value.

We can now start to decode whole lines in a CSV file.
In order to do so, we first introduce a custom error
type encapsulating how things can go wrong:

```idris
data CSVError : Type where
  FieldError           : (line, column : Nat) -> (str : String) -> CSVError
  UnexpectedEndOfInput : (line, column : Nat) -> CSVError
  ExpectedEndOfInput   : (line, column : Nat) -> CSVError
```

We can now use `CSVField` to read a single field at a given
line and position in a CSV file, and return a `FieldError` in case
of a failure.

```idris
readField : CSVField a => (line, column : Nat) -> String -> Either CSVError a
readField line col str =
  maybe (Left $ FieldError line col str) Right (read str)
```

If we know in advance the number of fields we need to read,
we can try and convert a list of strings to a `Vect` of
the given length. This facilitates reading record values of
a known number of fields, as we get the correct number
of string variables when pattern matching on the vector:

```idris
toVect : (n : Nat) -> (line, col : Nat) -> List a -> Either CSVError (Vect n a)
toVect 0     line _   []        = Right []
toVect 0     line col _         = Left (ExpectedEndOfInput line col)
toVect (S k) line col []        = Left (UnexpectedEndOfInput line col)
toVect (S k) line col (x :: xs) = (x ::) <$> toVect k line (S col) xs
```

Finally, we can implement function `readUser` to try and convert
a single line in a CSV-file to a value of type `User`:

```idris
readUser' : (line : Nat) -> List String -> Either CSVError User
readUser' line ss = do
  [fn,ln,a,em,g,pw] <- toVect 6 line 0 ss
  [| MkUser (readField line 1 fn)
            (readField line 2 ln)
            (readField line 3 a)
            (readField line 4 em)
            (readField line 5 g)
            (readField line 6 pw) |]

readUser : (line : Nat) -> String -> Either CSVError User
readUser line = readUser' line . forget . split (',' ==)
```

Let's give this a go at the REPL:

```repl
Tutorial.Functor> readUser 1 "Joe,Foo,46,j@f.ch,m,pw1234567"
Right (MkUser (MkName "Joe") (MkName "Foo")
  (Just 46) (MkEmail "j@f.ch") Male (MkPassword "pw1234567"))
Tutorial.Functor> readUser 7 "Joe,Foo,46,j@f.ch,m,shortPW"
Left (FieldError 7 6 "shortPW")
```

Note, how in the implementation of `readUser'` we used
an idiom bracket to map a function of six arguments (`MkUser`)
over six values of type `Either CSVError`. This will automatically
succeed, if and only if all of the parsings have
succeeded. It would have been notoriously cumbersome resulting
in much less readable code to implement
`readUser'` with a succession of six nested pattern matches.

However, the idiom bracket above looks still quite repetitive.
Surely, we can do better?

#### A Case for Heterogeneous Lists

It is time to learn about a family of types, which can
be used as a generic representation for record types, and
which will allow us to represent and read rows in
heterogeneous tables with a minimal amount of code: Heterogeneous
lists.

```idris
namespace HList
  public export
  data HList : (ts : List Type) -> Type where
    Nil  : HList Nil
    (::) : (v : t) -> (vs : HList ts) -> HList (t :: ts)
```

A heterogeneous list is a list type indexed over a *list of types*.
This allows us to at each position store a value of the
type at the same position in the list index. For instance,
here is a variant, which stores three values of types
`Bool`, `Nat`, and `Maybe String` (in that order):

```idris
hlist1 : HList [Bool, Nat, Maybe String]
hlist1 = [True, 12, Nothing]
```

You could argue that heterogeneous lists are just tuples
storing values of the given types. That's right, of course,
however, as you'll learn the hard way in the exercises,
we can use the list index to perform compile-time computations
on `HList`, for instance when concatenating two such lists
to keep track of the types stored in the result at the
same time.

But first, we'll make use of `HList` as a means to
concisely parse CSV-lines. In order to do that, we
need to introduce a new interface for types corresponding
to whole lines in a CSV-file:

```idris
interface CSVLine a where
  decodeAt : (line, col : Nat) -> List String -> Either CSVError a
```

We'll now write two implementations of `CSVLine` for `HList`:
One for the `Nil` case, which will succeed if and only if
the current list of strings is empty. The other for the *cons*
case, which will try and read a single field from the head
of the list and the remainder from its tail. We use
again an idiom bracket to concatenate the results:

```idris
CSVLine (HList []) where
  decodeAt _ _ [] = Right Nil
  decodeAt l c _  = Left (ExpectedEndOfInput l c)

CSVField t => CSVLine (HList ts) => CSVLine (HList (t :: ts)) where
  decodeAt l c []        = Left (UnexpectedEndOfInput l c)
  decodeAt l c (s :: ss) = [| readField l c s :: decodeAt l (S c) ss |]
```

And that's it! All we need to add is two utility function
for decoding whole lines before they have been split into
tokens, one of which is specialized to `HList` and takes an
erased list of types as argument to make it more convenient to
use at the REPL:

```idris
decode : CSVLine a => (line : Nat) -> String -> Either CSVError a
decode line = decodeAt line 1 . forget . split (',' ==)

hdecode :  (0 ts : List Type)
        -> CSVLine (HList ts)
        => (line : Nat)
        -> String
        -> Either CSVError (HList ts)
hdecode _ = decode
```

It's time to reap the fruits of our labour and give this a go at
the REPL:

```repl
Tutorial.Functor> hdecode [Bool,Nat,Double] 1 "f,100,12.123"
Right [False, 100, 12.123]
Tutorial.Functor> hdecode [Name,Name,Gender] 3 "Idris,,f"
Left (FieldError 3 2 "")
```

### Applicative Laws

Again, `Applicative` implementations must follow certain
laws. Here they are:

* `pure id <*> fa = fa`: Lifting and applying the identity
  function has no visible effect.

* `[| f . g |] <*> v = f <*> (g <*> v)`:
  I must not matter, whether we compose our functions
  first and then apply them, or whether we apply
  our functions first and then compose them.

  The above might be hard to understand, so here
  they are again with explicit types and implementations:

  ```idris
  compL : Maybe (b -> c) -> Maybe (a -> b) -> Maybe a -> Maybe c
  compL f g v = [| f . g |] <*> v

  compR : Maybe (b -> c) -> Maybe (a -> b) -> Maybe a -> Maybe c
  compR f g v = f <*> (g <*> v)
  ```

  The second applicative law states, that the two implementations
  `compL` and `compR` should behave identically.

* `pure f <*> pure x = pure (f x)`. This is also called the
  *homomorphism* law. It should be pretty self-explaining.

* `f <*> pure v = pure ($ v) <*> f`. This is called the law
  of *interchange*.

  This should again be explained with a concrete example:

  ```idris
  interL : Maybe (a -> b) -> a -> Maybe b
  interL f v = f <*> pure v

  interR : Maybe (a -> b) -> a -> Maybe b
  interR f v = pure ($ v) <*> f
  ```

  Note, that `($ v)` has type `(a -> b) -> b`, so this
  is a function type being applied to `f`, which has
  a function of type `a -> b` wrapped in a `Maybe`
  context.

  The law of interchange states that it must not matter
  whether we apply a pure value from the left or
  right of the *apply* operator.

### Exercises part 2

1. Implement `Applicative'` for `Either e` and `Identity`.

2. Implement `Applicative'` for `Vect n`. Note: In order to
   implement `pure`, the length must be known at runtime.
   This can be done by passing it as an unerased implicit
   to the interface implementation:

   ```idris
   implementation {n : _} -> Applicative' (Vect n) where
   ```

3. Implement `Applicative'` for `Pair e`, with `e` having
   a `Monoid` constraint.

4. Implement `Applicative` for `Const e`, with `e` having
   a `Monoid` constraint.

5. Implement `Applicative` for `Validated e`, with `e` having
   a `Semigroup` constraint. This will allow us to use `(<+>)`
   to accumulate errors in case of two `Invalid` values in
   the implementation of *apply*.

6. Add an additional data constructor of
   type `CSVError -> CSVError -> CSVError`
   to `CSVError` and use this to implement `Semigroup` for
   `CSVError`.

7. Refactor our CSV-parsers and all related functions so that
   they return `Validated` instead of `Either`. This will only
   work, if you solved exercise 6.

   Two things to note: You will have to adjust very little of
   the existing code, as we can still use applicative syntax
   with `Validated`. Also, with this change, we enhanced our CSV-parsers
   with the ability of error accumulation. Here are some examples
   from a REPL session:

   ```repl
   Solutions.Functor> hdecode [Bool,Nat,Gender] 1 "t,12,f"
   Valid [True, 12, Female]
   Solutions.Functor> hdecode [Bool,Nat,Gender] 1 "o,-12,f"
   Invalid (App (FieldError 1 1 "o") (FieldError 1 2 "-12"))
   Solutions.Functor> hdecode [Bool,Nat,Gender] 1 "o,-12,foo"
   Invalid (App (FieldError 1 1 "o")
     (App (FieldError 1 2 "-12") (FieldError 1 3 "foo")))
   ```

   Behold the power of applicative functors and heterogeneous lists: With
   only a few lines of code we wrote a pure, type-safe, and total
   parser with error accumulation for lines in CSV-files, which is
   very convenient to use at the same time!

8. Since we introduced heterogeneous lists in this chapter, it
   would be a pity not to experiment with them a little.

   This exercise is meant to sharpen your skills in type wizardry.
   It therefore comes with very few hints. Try to decide yourself
   what behavior you'd expect from a given function, how to express
   this in the types, and how to implement it afterwards.
   If your types are correct and precise enough, the implementations
   will almost come for free. Don't give up too early if you get stuck.
   Only if you truly run out of ideas should you have a glance
   at the solutions (and then, only at the types at first!)

   1. Implement `head` for `HList`.

   2. Implement `tail` for `HList`.

   3. Implement `(++)` for `HList`.

   4. Implement `index` for `HList`. This might be harder than the other three.
      Go back and look how we implemented `indexList` in an
      [earlier exercise](Dependent.md) and start from there.

   5. Package *contrib*, which is part of the Idris project, provides
      `Data.HVect.HVect`, a data type for heterogeneous vectors. The only difference
      to our own `HList` is, that `HVect` is indexed over a vector of
      types instead of a list of types. This makes it easier to express certain
      operations at the type level.

      Write your own implementation of `HVect` together with functions
      `head`, `tail`, `(++)`, and `index`.

   6. For a real challenge, try implementing a function for
      transposing a `Vect m (HVect ts)`. You'll first have to
      be creative about how to even express this in the types.

      Note: In order to implement this, you'll need to pattern match
      on an erased argument in at least one case to help Idris with
      type inference. Pattern matching on erased arguments is forbidden
      (they are erased after all, so we can't inspect them at runtime),
      *unless* the structure of the value being matched on can be derived
      from another, un-erased argument.

      Also, don't worry if you get stuck on this one. It took me several
      tries to figure it out. But I enjoyed the experience, so I just *had*
      to include it here. :-)

      Note, however, that such a function might be useful when working with
      CSV-files, as it allows us to convert a table represented as
      rows (a vector of tuples) to one represented as columns (a tuple of vectors).

9. Show, that the composition of two applicative functors is
   again an applicative functor by implementing `Applicative`
   for `Comp f g`.

10. Show, that the product of two applicative functors is
    again an applicative functor by implementing `Applicative`
    for `Prod f g`.

## Monad

Finally, `Monad`. A lot of ink has been spilled about this one.
However, after what we already saw in the [chapter about `IO`](IO.md),
there is not much left to discuss here. `Monad` extends
`Applicative` and adds two new related functions: The *bind*
operator (`(>>=)`) and function `join`. Here is its definition:

```idris
interface Applicative' m => Monad' m where
  bind  : m a -> (a -> m b) -> m b
  join' : m (m a) -> m a
```

Implementers of `Monad` are free to choose to either implement
`(>>=)` or `join` or both. You will show in an exercise, how
`join` can be implemented in terms of *bind* and vice versa.

The big difference between `Monad` and `Applicative` is, that the
former allows a computation to depend on the result of an
earlier computation. For instance, we could decide based on
a string read from standard input whether to delete a file
or play a song. The result of the first `IO` action
(reading some user input) will affect, which `IO` action to run next.
This is not possible with the *apply* operator:

```repl
(<*>) : IO (a -> b) -> IO a -> IO b
```

The two `IO` actions have already been decided on when they
are being passed as arguments to `(<*>)`. The result of the first
cannot - in the general case - affect which computation to
run in the second. (Actually, with `IO` this would theoretically be
possible via side effects: The first action could write some
command to a file or overwrite some mutable state, and the
second action could read from that file or state, thus
deciding on the next thing to do. But this is a speciality
of `IO`, not of applicative functors in general. If the functor in
question was `Maybe`, `List`, or `Vector`, no such thing
would be possible.)

Let's demonstrate the difference with an example. Assume
we'd like to enhance our CSV-reader with the ability to
decode a line of tokens to a sum type. For instance,
we'd like to decode CRUD requests from the lines of a
CSV-file:

```idris
data Crud : (i : Type) -> (a : Type) -> Type where
  Create : (value : a) -> Crud i a
  Update : (id : i) -> (value : a) -> Crud i a
  Read   : (id : i) -> Crud i a
  Delete : (id : i) -> Crud i a
```

We need a way to on each line decide, which data constructor
to choose for our decoding. One way to do this is to
put the name of the data constructor (or some other
tag of identification) in the first column of the CSV-file:

```idris
hlift : (a -> b) -> HList [a] -> b
hlift f [x] = f x

hlift2 : (a -> b -> c) -> HList [a,b] -> c
hlift2 f [x,y] = f x y

decodeCRUD :  CSVField i
           => CSVField a
           => (line : Nat)
           -> (s    : String)
           -> Either CSVError (Crud i a)
decodeCRUD l s =
  let h ::: t = split (',' ==) s
   in do
     MkName n <- readField l 1 h
     case n of
       "Create" => hlift  Create  <$> decodeAt l 2 t
       "Update" => hlift2 Update  <$> decodeAt l 2 t
       "Read"   => hlift  Read    <$> decodeAt l 2 t
       "Delete" => hlift  Delete  <$> decodeAt l 2 t
       _        => Left (FieldError l 1 n)
```

I added two utility function for helping with type inference
and to get slightly nicer syntax. The important thing to note
is, how we pattern match on the result of the first
parsing function to decide on the data constructor
and thus the next parsing function to use.

Here's how this works at the REPL:

```repl
Tutorial.Functor> decodeCRUD {i = Nat} {a = Email} 1 "Create,jon@doe.ch"
Right (Create (MkEmail "jon@doe.ch"))
Tutorial.Functor> decodeCRUD {i = Nat} {a = Email} 1 "Update,12,jane@doe.ch"
Right (Update 12 (MkEmail "jane@doe.ch"))
Tutorial.Functor> decodeCRUD {i = Nat} {a = Email} 1 "Delete,jon@doe.ch"
Left (FieldError 1 2 "jon@doe.ch")
```

To conclude, `Monad`, unlike `Applicative`, allows us to
chain computations sequentially, where intermediary
results can affect the behavior of later computations.
So, if you have n unrelated effectful computations and want
to combine them under a pure, n-ary function, `Applicative`
will be sufficient. If, however, you want to decide
based on the result of an effectful computation what
computation to run next, you need a `Monad`.

Note, however, that `Monad` has one important drawback
compared to `Applicative`: In general, monads don't compose.
For instance, there is no `Monad` instance for `Either e . IO`.
We will later learn about monad transformers, which can
be composed with other monads.

### Monad Laws

Without further ado, here are the laws for `Monad`:

* `ma >>= pure = ma` and `pure v >>= f = f v`.
  These are monad's identity laws. Here they are as
  concrete examples:

  ```idris
  id1L : Maybe a -> Maybe a
  id1L ma = ma >>= pure

  id2L : a -> (a -> Maybe b) -> Maybe b
  id2L v f = pure v >>= f

  id2R : a -> (a -> Maybe b) -> Maybe b
  id2R v f = f v
  ```

  These two laws state that `pure` should behave
  neutrally w.r.t. *bind*.

* (m >>= f) >>= g = m >>= (f >=> g)
  This is the law of associativity for monad.
  You might not have seen the second operator `(>=>)`.
  It can be used to sequence effectful computations
  and has the following type:

  ```repl
  Tutorial.Functor> :t (>=>)
  Prelude.>=> : Monad m => (a -> m b) -> (b -> m c) -> a -> m c
  ```

The above are the *official* monad laws. However, we need to
consider a third one, given that in Idris (and Haskell)
`Monad` extends `Applicative`: As `(<*>)` can be implemented
in terms of `(>>=)`, the actual implementation of `(<*>)`
must behave the same as the implementation in terms of `(>>=)`:

* `mf <*> ma = mf >>= (\fun => map (fun $) ma)`.

### Exercises part 3

1. `Applicative` extends `Functor`, because every `Applicative`
   is also a `Functor`. Proof this by implementing `map` in
   terms of `pure` and `(<*>)`.

2. `Monad` extends `Applicative`, because every `Monad` is
   also an `Applicative`. Proof this by implementing
   `(<*>)` in terms of `(>>=)` and `pure`.

3. Implement `(>>=)` in terms of `join` and other functions
   in the `Monad` hierarchy.

4. Implement `join` in terms of `(>>=)` and other functions
   in the `Monad` hierarchy.

5. There is no lawful `Monad` implementation for `Validated e`.
   Why?

6. In this slightly extended exercise, we are going to simulate
   CRUD operations on a data store. We will use a mutable
   reference (imported from `Data.IORef` from the *base* library)
   holding a list of `User`s paired with a unique ID
   of type `Nat` as our user data base:

   ```idris
   DB : Type
   DB = IORef (List (Nat,User))
   ```

   Most operations on a database come with a risk of failure:
   When we try to update or delete a user, the entry in question
   might no longer be there. When we add a new user, a user
   with the given email address might already exist. Here is
   a custom error type to deal with this:

   ```idris
   data DBError : Type where
     UserExists        : Email -> Nat -> DBError
     UserNotFound      : Nat -> DBError
     SizeLimitExceeded : DBError
   ```

   In general, our functions will therefore have a
   type similar to the following:

   ```idris
   someDBProg : arg1 -> arg2 -> DB -> IO (Either DBError a)
   ```

   We'd like to abstract over this, by introducing a new wrapper
   type:

   ```idris
   record Prog a where
     constructor MkProg
     runProg : DB -> IO (Either DBError a)
   ```

   We are now ready to write us some utility functions. Make sure
   to follow the following business rules when implementing the
   functions below:

   * Email addresses in the DB must be unique. (Consider
     implementing `Eq Email` to verify this).

   * The size limit of 1000 entries must not be exceeded.

   * Operations trying to lookup a user by their ID must
     fail with `UserNotFound` in case no entry was found
     in the DB.

   You'll need the following functions from `Data.IORef` when working
   with mutable references: `newIORef`, `readIORef`, and `writeIORef`.
   In addition, functions `Data.List.lookup` and `Data.List.find` might
   be useful to implement some of the functions below.

   1. Implement interfaces `Functor`, `Applicative`, and `Monad` for `Prog`.

   2. Implement interface `HasIO` for `Prog`.

   3. Implement the following utility functions:

      ```idris
      throw : DBError -> Prog a

      getUsers : Prog (List (Nat,User))

      -- check the size limit!
      putUsers : List (Nat,User) -> Prog ()

      -- implement this in terms of `getUsers` and `putUsers`
      modifyDB : (List (Nat,User) -> List (Nat,User)) -> Prog ()
      ```

   4. Implement function `lookupUser`. This should fail
      with an appropriate error, if a user with the given ID
      cannot be found.

      ```idris
      lookupUser : (id : Nat) -> Prog User
      ```

   5. Implement function `deleteUser`. This should fail
      with an appropriate error, if a user with the given ID
      cannot be found. Make use of `lookupUser` in your
      implementation.

      ```idris
      deleteUser : (id : Nat) -> Prog ()
      ```

   6. Implement function `addUser`. This should fail, if
      a user with the given `Email` already exists, or
      if the data banks size limit of 1000 entries is exceeded.
      In addition, this should create and return a unique
      ID for the new user entry.

      ```idris
      addUser : (new : User) -> Prog Nat
      ```

   7. Implement function `updateUser`. This should fail, if
      the user in question cannot be found or
      a user with the updated user's `Email` already exists.
      The returned value should be the updated user.

      ```idris
      updateUser : (id : Nat) -> (mod : User -> User) -> Prog User
      ```

   8. Data type `Prog` is actually too specific. We could just
      as well abstract over the error type and the `DB`
      environment:

      ```idris
      record Prog' env err a where
        constructor MkProg
        runProg' : env -> IO (Either err a)
      ```

      Verify, that all interface implementations you wrote
      for `Prog` can be used verbatim to implement the same
      interfaces for `Prog' env err`. The same goes for
      `throw` with only a slight adjustment in the function's
      type.

## Background and further Reading

Concepts like *functor* and *monad* have their origin in *category theory*,
a branch of mathematics. That is also where their laws come from.
Category theory was found to have applications in
programming language theory, especially functional programming.
It is a highly abstract topic, but there is a pretty accessible
introduction for programmers, written by
[Bartosz Milewski](https://bartoszmilewski.com/2014/10/28/category-theory-for-programmers-the-preface/).

The usefulness of applicative functors as a middle ground between
functor and monad was discovered several years after monads had
already been in use in Haskell. They where introduced in the
article [*Applicative Programming with Effects*](https://www.staff.city.ac.uk/~ross/papers/Applicative.html),
which is freely available online and a highly recommended read.

## Conclusion

* Interfaces `Functor`, `Applicative`, and `Monad` abstract over
  programming patterns that come up when working with type
  constructors of type `Type -> Type`. Such data types are also
  referred to as *values in a context*, or *effectful computations*.

* `Functor` allows us to *map* over values in a context without
  affecting the context's underlying structure.

* `Applicative` allows us to apply n-ary functions to n effectful
  computations and to lift pure values into a context.

* `Monad` allows us to chain effectful computations, where the
  intermediary results can affect, which computation to run
  further down the chain.

* Unlike `Monad`, `Functor` and `Applicative` compose: The
  product and composition of two functors or applicatives
  are again functors or applicatives, respectively.

* Idris provides syntactic sugar for working with some of
  the interfaces presented here: Idiom brackets for `Applicative`,
  *do blocks* and the bang operator for `Monad`.

### What's next?

In the [next chapter](Folds.md) we get to learn more about
recursion, totality checking, and an interface for
collapsing container types: `Foldable`.

<!-- vi: filetype=idris2
-->
