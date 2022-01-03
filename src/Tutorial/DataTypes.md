# Algebraic Data Types

In the [previous part](Functions1.md) of the tutorial,
we learned how to write our own functions and combine
them to create more complex functionality. Of equal importance
is the ability to define our own data types and use them
as arguments and results in functions.

This is a lengthy tutorial, densely packed with information.
If you are new to Idris and functional programming, make
sure to follow along slowly, experimenting with the examples,
and possibly come up with your own examples. Make sure to try
and solve *all* exercises. The solutions to the exercises
can be found [here](../Solutions/DataTypes.idr).

```idris
module Tutorial.DataTypes
```

## Enumerations

Let's start with a data type for the days of the week as an
example.

```idris
data Weekday = Monday
             | Tuesday
             | Wednesday
             | Thursday
             | Friday
             | Saturday
             | Sunday
```

The declaration above defines a new *type* (`Weekday`) and
several new *values* (`Monday` to `Sunday`) of the given
type. Go ahead, and verify this at the REPL:

```repl
Tutorial.DataTypes> :t Monday
Tutorial.DataTypes.Monday : Weekday
Tutorial.DataTypes> :t Weekday
Tutorial.DataTypes.Weekday : Type
```

So, `Monday` is of type `Weekday`, while `Weekday` itself is of
type `Type`.

### Pattern Matching

In order to use our new data type as a function argument, we
need to learn about an important concept in functional programming
languages: Pattern matching. Let's implement a function, which calculates
the successor of a weekday:

```idris
next : Weekday -> Weekday
next Monday    = Tuesday
next Tuesday   = Wednesday
next Wednesday = Thursday
next Thursday  = Friday
next Friday    = Saturday
next Saturday  = Sunday
next Sunday    = Monday
```

In order to inspect a `Weekday` argument, we match on the
different possible values and return a result for each of them.
This is a very powerful concept, as it allows us to match
on and extract values from deeply nested data structures.

### Catch-all Patterns

Sometimes it is convenient to only match on a subset
of the possible values and collect the remaining possibilities
in a catch-all clause:

```idris
isWeekend : Weekday -> Bool
isWeekend Saturday = True
isWeekend Sunday   = True
isWeekend _        = False
```

We can use this, to implement an equality test for `Weekday`
(we will not yet use the `==` operator for this; this will
have to wait until we learn about *interfaces*):

```idris
eqWeekday : Weekday -> Weekday -> Bool
eqWeekday Monday Monday        = True
eqWeekday Tuesday Tuesday      = True
eqWeekday Wednesday Wednesday  = True
eqWeekday Thursday Thursday    = True
eqWeekday Friday Friday        = True
eqWeekday Saturday Saturday    = True
eqWeekday Sunday Sunday        = True
eqWeekday _ _                  = False
```

### Enumeration Types in the Prelude

Data types like `Weekday` consisting of a finite set
of values are sometimes called *enumerations*. The Idris
prelude defines some common enumerations for us, for
instance `Bool` and `Ordering`. As with `Weekday`,
we can use pattern matching when implementing functions
on these types:

```idris
-- this is how `not` is implemented in the prelude
negate : Bool -> Bool
negate False = True
negate True  = False
```

The `Ordering` data type describes an ordering relation
between two values. For instance:

```idris
compareBool : Bool -> Bool -> Ordering
compareBool False False = EQ
compareBool False True  = LT
compareBool True True   = EQ
compareBool True False  = GT
```

Here, `LT` means that the first argument is *less than*
the second, `EQ` means that the two arguments are equal
and `GT` means, that the first argument is *greater than*
the second.

### Case Blocks

Sometimes we need to perform a computation with one
of the arguments and want to pattern match on the result
of this computation. We can use *case blocks* in this
situation:

```idris
-- returns the larger of the two arguments
maxBits8 : Bits8 -> Bits8 -> Bits8
maxBits8 x y = case compare x y of
  LT => y
  _  => x
```

Function `compare` is overloaded for many data types. We will
learn how this works when we talk about interfaces.

#### If Then Else

When working with `Bool`, there is an alternative to pattern matching
common to most programming languages:

```idris
maxBits8' : Bits8 -> Bits8 -> Bits8
maxBits8' x y = if compare x y == LT then y else x
```

Note, that the `if then else` expression always returns a value
and therefore, the `else` branch cannot be dropped. This is different
to the behavior in typical imperative languages, where `if` is
a statement with possible side effects.

### Exercises

1. Use pattern matching to implement your own
versions of boolean operators
`(&&)` and `(||)` calling them `and` and `or`
respectively.

Note: One way to go about this is to enumerate
all four possible combinations of two boolean
values and give the result for each. However, there
is a shorter, more clever way,
requiring only two pattern matches for each of the
two functions.

2. Define your own data type representing different
units of time (seconds, minutes,
hours, days, weeks), and implement the following
functions for converting between time spans using
different units. Hint: Use integer division (`div`)
when going from seconds to some larger unit like
hours).

```idris
data UnitOfTime = Second -- add additional values

-- calculate the number of seconds from a
-- number of steps in the given unit of time
toSeconds : UnitOfTime -> Integer -> Integer

-- Given a number of seconds, calculate the
-- number of steps in the given unit of time
fromSeconds : UnitOfTime -> Integer -> Integer

-- convert the number of steps in a given unit of time
-- to the number of steps in another unit of time.
-- use `fromSeconds` and `toSeconds` in your implementation
convert : UnitOfTime -> Integer -> UnitOfTime -> Integer
```

## Sum Types

Assume we'd like to write some web form, where users of our
web application can decide how they like to be addressed.
We give them a choice between two common predefined
forms of address (Mr and Mrs), but also allow them to
decide on a customized form. The possible
choices should be encapsulated in an Idris data type
like so:

```idris
data Title = Mr | Mrs | Other String
```

This looks almost like an enumeration type, with the exception
that there is a new thing, called a *data constructor*,
which accepts a `String` argument. If we inspect
the types at the REPL, we learn the following:

```repl
Tutorial.DataTypes> :t Mr
Tutorial.DataTypes.Mr : Title
Tutorial.DataTypes> :t Other
Tutorial.DataTypes.Other : String -> Title
```

So, `Other` is a *function* from `String` to `Title`. This
means, that we can pass `Other` a `String` argument and get
a `Title` as the result:

```idris
dr : Title
dr = Other "Dr."
```

Again, we can use pattern matching to implement functions
on the `Title` data type:

```idris
showTitle : Title -> String
showTitle Mr        = "Mr."
showTitle Mrs       = "Mrs."
showTitle (Other x) = x
```

Note, how in the last pattern match, the string value stored
in the `Other` data constructor is *bound* to local variable `x`.
This is a very common way to extract the values from
data constructors.
We can use `showTitle` to implement a function for creating
a courteous greeting:

```idris
greet : Title -> String -> String
greet t name = "Hello, " ++ showTitle t ++ " " ++ name ++ "!"
```

In the implementation of `greet`, we use string literals
and the string concatenation operator `(++)` to
assemble the greeting from its parts.

At the REPL:

```repl
Tutorial.DataTypes> greet dr "Höck"
"Hello, Dr. Höck!"
Tutorial.DataTypes> greet Mrs "Smith"
"Hello, Mrs. Smith!"
```

Data types like `Title` are called *sum types* as they consist
of the sum of their different parts: A value of type `Title`
is either a `Mr`, a `Mrs`, or a `String` wrapped up in `Other`.

Here's another (drastically simplified) example of a sum type.
Assume we allow two forms of authentication in our web application:
Either by entering a user name plus a password (an unsigned 64 bit
integer), or by providing a (very complex) secret key. Here's a data
type to encapsulate this use case:

```idris
data Credentials = Password String Bits64 | Key String
```

As an example of a very primitive login function, we can
hard-code some known credentials:

```idris
login : Credentials -> String
login (Password "Anderson" 6665443) = greet Mr "Anderson"
login (Key "xyz")                   = greet (Other "Agent") "Y"
login _                             = "Access denied!"
```

As can be seen in the example above, we can also pattern
match against primitive values by using integer and
string literals. Give `login` a go at the REPL:

```repl
Tutorial.DataTypes> login (Password "Anderson" 6665443)
"Hello, Mr. Anderson!"
Tutorial.DataTypes> login (Key "xyz")
"Hello, Agent Y!"
Tutorial.DataTypes> login (Key "foo")
"Access denied!"
```

### Exercises

1. Implement an equality test for `Title` (you can use the
equality operator `(==)` for comparing two `String`s):

```idris
eqTitle : Title -> Title -> Bool
```

2. For `Title`, implement a simple test to check, whether
a custom title is being used:

```idris
isOther : Title -> Bool
```

3. Given our simple `Credentials` type, there are three
ways for authentication to fail:

* An unknown user name was used.
* The password given does not match the one associated with
  the user name.
* An invalid key was used.

Encapsulate these three possibilities in a sum type `LoginError`,
but make sure not to disclose any confidential information:
An invalid user name should be stored in the error, but an
invalid password or key should not.

4. Implement function `showError : LoginError -> String`, which
can be used to display an error message to the user who
unsuccessfully tried to login into our web application.

## Records

It is often useful to group together several values
as a logical unit. For instance, in our web application
we might want to group information about a user
in a single data type. Such data types are often called
*product types*. The most common and convenient way to
define them is the `record` construct:

```idris
record User where
  constructor MkUser
  name  : String
  title : Title
  age   : Bits8
```

The declaration above creates a new *type* called `User`,
and a new *data constructor* called `MkUser`. As usual,
have a look at their types in the REPL:

```repl
Tutorial.DataTypes> :t User
Tutorial.DataTypes.User : Type
Tutorial.DataTypes> :t MkUser
Tutorial.DataTypes.MkUser : String -> Title -> Bits8 -> User
```

We can use `MkUser` (which is a function from
`String` to `Title` to `Bits8` to `User`)
to create values of type `User`:

```idris
agentY : User
agentY = MkUser "Y" (Other "Agent") 51

drNo : User
drNo = MkUser "No" dr 73
```

We can also use pattern matching to extract the fields from
a `User` value (they can again be bound to local variables):

```idris
greetUser : User -> String
greetUser (MkUser n t _) = greet t n
```

In the example above, the `name` and `title` field
are bound to two new local variables (`n` and `t` respectively),
which can then be used on the right hand side of `greetUser`'s
implementation. For the `age` field, which is not used
on the right hand side, we can use an underscore as a catch-all
pattern.

Note, how Idris will prevent us from making
a common mistake: If we confuse the order of arguments, the
implementation will no longer type check:

```repl
-- this will result in a type error
greetUser : User -> String
greetUser (MkUser n t _) = greet n t
```

### Syntactic Sugar for Records

As was already mentioned in the [intro](Intro.md), Idris
is a *pure* functional programming language. In pure functions,
we are not allowed to modify global mutable state. As such,
if we want to modify a record value, we will always
create a *new* value with the original value remaining
unchanged: Records and other Idris values are *immutable*.
While this *can* have a slight impact on performance, it has
the benefit that we can freely pass a record value to
different functions, without fear of the functions modifying
the value by in-place mutation.

There are several ways to modify a record, the most
general being to pattern match on the record and
adjust each field as desired. If, for instance, we'd like
to increase the age of a `User` by one, we could do the following:

```idris
incAge : User -> User
incAge (MkUser name title age) = MkUser name title (age + 1)
```

That's a lot of code for such a simple thing, so Idris offers
several syntactic conveniences for this. For instance,
using *record* syntax, we can just access and update the `age`
field of a value:

```idris
incAge2 : User -> User
incAge2 u = { age := u.age + 1 } u
```

Assignment operator `:=` assigns a new value to the `age` field
in `u`. Remember, that this will create a new `User` value. The original
value `u` remains unaffected by this.

This is already better, but the use case of modifying a
record field is so common that Idris provides special syntax
for this as well:

```idris
incAge3 : User -> User
incAge3 u = { age $= (+ 1) } u
```

`(+ 1)` is a partially applied operator. This is
called an *operator section* and has to be put in parentheses.
In all other aspects, it behaves like any other partially applied
function.

As an alternative to an operator section,
we could have used an anonymous function
(called a *lambda*) like so:

```idris
incAge4 : User -> User
incAge4 u = { age $= \x => x + 1 } u
```

Finally, since our function's argument `u` is only used
once at the very end, we can just as well drop it altogether,
to get the following, highly concise version:

```idris
incAge5 : User -> User
incAge5 = { age $= (+ 1) }
```

As usual, we try the result at the REPL:

```repl
Tutorial.DataTypes> incAge5 drNo
MkUser "No" (Other "Dr.") 74
```

It is possible to use this syntax to set and/or update
several record fields at once:

```idris
drNoJunior : User
drNoJunior = { name $= (++ " Jr."), title := Mr, age := 17 } drNo
```

### Tuples

I wrote above that a record is also called a *product type*.
This is quite obvious when we consider the number
of possible values inhabiting a given type. For instance, consider
the following custom record:

```idris
record Foo where
  constructor MkFoo
  wd   : Weekday
  bool : Bool
```

How many possible values of type `Foo` are there? The answer is `7 * 2 = 14`,
as we can pair every possible `Weekday` (seven in total) with every possible
`Bool` (two in total). So, the number of possible values of a record type
is the *product* of the number of possible values for each field.

The canonical product type is the `Pair`, which is available from the *Prelude*:

```idris
weekdayAndBool : Weekday -> Bool -> Pair Weekday Bool
weekdayAndBool wd b = MkPair wd b
```

Since it is quite common to return several values from a function
wrapped in a `Pair` or larger tuple, Idris provides some syntactic
sugar for working with these. Instead of `Pair Weekday Bool`, we
can just write `(Weekday, Bool)`. Likewise, instead of `MkPair wd b`,
we can just write `(wd, b)` (the space is not mandatory):

```idris
weekdayAndBool2 : Weekday -> Bool -> (Weekday, Bool)
weekdayAndBool2 wd b = (wd, b)
```

This works also for nested tuples:

```idris
triple : Pair Bool (Pair Weekday String)
triple = MkPair False (Friday, "foo")

triple2 : (Bool, Weekday, String)
triple2 = (False, Friday, "foo")
```

In the example above, `triple2` is converted to the form
used in `triple` by the Idris compiler.

We can even use tuple syntax in pattern matches:

```idris
bar : Bool
bar = case triple of
  (b,wd,_) => b && isWeekend wd
```
### As Patterns

Sometimes, we'd like to take apart a value by pattern matching
on it but still retain the value as a whole for using it
in further computations:

```idris
baz : (Bool,Weekday,String) -> (Nat,Bool,Weekday,String)
baz t@(_,_,s) = (length s, t)
```

In `baz`, variable `t` is *bound* to the triple as a whole, which
is then reused to construct the resulting quadruple. Remember,
that `(Nat,Bool,Weekday,String)` is just sugar for
`Pair Nat (Bool,Weekday,String)`, and `(length s, t)` is just
sugar for `MkPair (length s) t`. Hence, the implementation above
is correct as is confirmed by the type checker.

### Exercises

1. Define a record type for time spans by pairing a `UnitOfTime`
with an integer representing the duration of the time span in
the given unit of time. Define also a function for converting
a time span to an `Integer` representing the duration in seconds.

2. Implement an equality check for time spans: Two time spans
should be considered equal, if and only if they correspond to
the same number of seconds.

3. Implement a function for pretty printing time spans:
The resulting string should display the time span in its
given unit, plus show the number of seconds in parentheses,
if the unit is not already seconds.

4. Implement a function for adding two time spans. If the
two time spans use different units of time, use the smaller
unit of time, to ensure a lossless conversion in the result.

## Generic Data Types

Sometimes, a concept is general enough that we'd like
to apply it not only to a single type, but to all
kinds of types. For instance, we might not want to define
data types for lists of integers, lists of strings, and lists
of booleans, as this would lead to a lot of code duplication.
Instead, we'd like to have a single generic list type *parameterized*
by the type of values it stores. This section explains how
to define and use generic types.

### Maybe

Consider the case of parsing
a `Weekday` from user input. Surely, such
a function should return `Saturday`, if the
string input was `"Saturday"`, but what if the
input was `"sdfkl332"`? We have several options here.
For instance, we could just return a default result
(`Sunday` perhaps?). But is this the behavior
programmers expect when using our library? Maybe not. To silently
continue with a default value in the face of invalid user input
is hardly ever the best choice and may lead to a lot of
confusion.

In an imperative language, our function would probably
throw an exception. We could do this in Idris as
well (there is function `idris_crash` in the prelude for
this), but doing so, we would abandon totality! A high
price to pay for such a common thing as a parsing error.

In languages like Java, our function might also return some
kind of `null` value (leading to the dreaded `NullPointerException`s if
not handled properly in client code). Our solution will
be similar, but instead of silently returning `null`,
we will make the possibility of failure visible in the types!
We define a custom data type, which encapsulates the possibility
of failure. Defining new data types in Idris is very cheap
(in terms of the amount of code needed), therefore this is
often the way to go in order to increase type safety.
Here's an example how to do this:

```idris
data MaybeWeekday = WD Weekday | NoWeekday

readWeekday : String -> MaybeWeekday
readWeekday "Monday"    = WD Monday
readWeekday "Tuesday"   = WD Tuesday
readWeekday "Wednesday" = WD Wednesday
readWeekday "Thursday"  = WD Thursday
readWeekday "Friday"    = WD Friday
readWeekday "Saturday"  = WD Saturday
readWeekday "Sunday"    = WD Sunday
readWeekday _           = NoWeekday
```

But assume now, we'd also like to read `Bool` values from
user input. We'd now have to write a custom data type
`MaybeBool` and so on for all types we'd like to read
from `String`, and the conversion of which might fail.

Idris, like many other programming languages, allows us
to generalize this behavior by using *generic data
types*. Here's an example:

```idris
data Option a = Some a | None

readBool : String -> Option Bool
readBool "True"    = Some True
readBool "False"   = Some False
readBool _         = None
```

It is important to go to the REPL and look at the types:

```repl
Tutorial.DataTypes> :t Some
Tutorial.DataTypes.Some : a -> Option a
Tutorial.DataTypes> :t None
Tutorial.DataTypes.None : Optin a
Tutorial.DataTypes> :t Option
Tutorial.DataTypes.Option : Type -> Type
```

We need to introduce some jargon here. `Option` is what we call
a *type constructor*. It is not yet a saturated type: It is
a function from `Type` to `Type`.
However, `Option Bool` is a type, as is `Option Weekday`.
Even `Option (Option Bool)` is a valid type. `Option` is
a type constructor *parameterized* over a *parameter* of type `Type`.
`Some` and `None` are `Option`s *data constructors*: The functions
used to create values of type `Option a` for a type `a`.

Let's see some other use cases for `Option`. Below is a safe
division operation:

```idris
safeDiv : Integer -> Integer -> Option Integer
safeDiv n 0 = None
safeDiv n k = Some (n `div` k)
```

The possibility of returning some kind of *null* value in the
face of invalid input is so common, that there is a data type
like `Option` already in the prelude: `Maybe`, consisting
of data constructors `Just` and `Nothing`.

It is important to understand the difference between returning `Maybe Integer`
in a function, which might fail, and returning
`null` in languages like Java: In the former case, the
possibility of failure is visible in the types. The type checker
will force us to treat `Maybe Integer` differently than
`Integer`: We will *not* forget to handle the failure case.
Not so, if `null` is silently returned without adjusting the
types. Programmers may (and often *will*) forget to handle the
`null` case, leading to unexpected and sometimes
hard to debug runtime exceptions. 

### Either

While `Maybe` is very useful to quickly provide a default
value to signal some kind of failure, this value (`Nothing`) is
not very informative. It will not tell us *what exactly*
went wrong. For instance, in case of our `Weekday`
reading function, it might be interesting later on to know
the value of the invalid input string. And just like with
`Maybe` and `Option` above, this concept is general enough
that we might encounter other types of invalid values.
Here's a data type to encapsulate this:

```idris
data Validated e a = Invalid e | Valid a
```

`Validated` is a type constructor parameterized over two
type parameters. It's data constructors are `Invalid` and `Valid`.
Let's see this in action:

```idris
readWeekdayV : String -> Validated String Weekday
readWeekdayV "Monday"    = Valid Monday
readWeekdayV "Tuesday"   = Valid Tuesday
readWeekdayV "Wednesday" = Valid Wednesday
readWeekdayV "Thursday"  = Valid Thursday
readWeekdayV "Friday"    = Valid Friday
readWeekdayV "Saturday"  = Valid Saturday
readWeekdayV "Sunday"    = Valid Sunday
readWeekdayV s           = Invalid s
```

Again, this is such a general concept that a data type
similar to `Validated` is already available from the
prelude: `Either` with data constructors `Left` and `Right`.
It is very common for functions to encapsulate the possibility
of functions by returning an `Either err val`, where `err`
is the error type and `val` is the desired return type. This
is the type safe (and total) alternative to throwing a catchable
error in an imperative language.

### List

One of the most important data structures in pure functional
programming is the singly linked list. Here is its definition
(called `Seq` in order for it not to collide with `List`,
which is of course already available from the Prelude):

```idris
data Seq a = Nil | (::) a (Seq a)
```

This calls for some explanations. `Seq` consists of two *data constructors*:
`Nil` (representing an empty sequence of values) and `(::)` (also
called *cons*), which prepends a new value of type `a` to
an already existing list of values of the same type.

Here is an example (I use `List` here, as this is what you should
use in your own code):

```idris
ints : List Int64
ints = 1 :: 2 :: (-3) :: Nil
```

However, there is a more concise way of writing the above. Idris
accepts special syntax for constructing data types consisting
exactly of the two constructors `Nil` and `(::)`:

```idris
ints2 : List Int64
ints2 = [1, 2, (-3)]
```

The two definitions above are treated identically by the compiler.

There is another thing that's special about `Seq`: It is defined
in terms of itself (the cons operator accepts a value
and another `Seq` as arguments). This means, that in order to
decompose or consume a `Seq`, we typically require a recursive
function. In an imperative language, we might use a for loop or
similar construct to iterate over the values of a `List` or a `Seq`,
but these things do not exist in a language without in-place
mutation. Here's how to sum a list of integers:

```idris
intSum : List Integer -> Integer
intSum Nil       = 0
intSum (n :: ns) = n + intSum ns
```

We will have a closer look at recursion in a later part of
this tutorial, as this one is already getting too long.

### Generic Functions

In order to fully appreciate the versatility that comes with
generic data types, we also need to talk about generic functions.
Like generic types, these are parameterized over one or more
type parameters.

Consider for instance the case of breaking out of the
`Option` data type. In case of a `Sume`, we'd like to return
the stored value, while for the `None` case we provide
a default value. Here's how to do this, specialized to
`Integer`s:

```idris
integerFromOption : Integer -> Option Integer -> Integer
integerFromOption _ (Some y) = y
integerFromOption x None     = x
```

It's pretty obvious that this is, again, not general enough.
Surely, we'd also like to break out of `Option Bool` or
`Option String` in a similar fashion. That's exactly
what the generic function `fromOption` does:

```idris
fromOption : a -> Option a -> a
fromOption _ (Some y) = y
fromOption x None     = x
```

The pendant to `fromOption` for `Maybe` is called `fromMaybe`
and available from module `Data.Maybe` from the *base* library.

Sometimes, `fromOption` is not general enough. Assume we'd like to
print the value of a freshly parsed `Bool`, giving some generic
error message in case of a `None`. We can't use `fromOption`
for this, as we have an `Option Bool` and we'd like to 
return a `String`. Here's how to do this:

```idris
option : b -> (a -> b) -> Option a -> b
option _ f (Some y) = f y
option x _ None     = x

handleBool : Option Bool -> String
handleBool = option "Not a boolean value." show
```

### Exercises

If this is your first time programming in a purely
functional language, the exercises below are *very*
important. Do not skip any of them! Take your time and
work through them all. In most cases,
the types should be enough to explain what's going
on, even though they might appear cryptic in the
beginning. Otherwise, have a look at the comments.
Remember, that lower-case identifiers in a function
signature are treated as type parameters.

1. Implement the following functions for `Maybe`:

```idris
-- make sure to map a `Just` to a `Just`.
mapMaybe : (a -> b) -> Maybe a -> Maybe b

-- Example: `appMaybe (Just (+2)) (Just 20) = Just 22`
appMaybe : Maybe (a -> b) -> Maybe a -> Maybe b

-- Example: `bindMaybe (Just 12) Just = Just 12`
bindMaybe : Maybe a -> (a -> Maybe b) -> Maybe b

-- keep the value in a `Just` only if the given predicate holds
filterMaybe : (a -> Bool) -> Maybe a -> Maybe a

-- keep the first value that is not a `Nothing` (if any)
first : Maybe a -> Maybe a -> Maybe a

-- keep the last value that is not a `Nothing` (if any)
last : Maybe a -> Maybe a -> Maybe a

-- this is another general way to extract a value from a `Maybe`.
-- Make sure the following holds:
-- `foldMaybe (+) 5 Nothing = 5`
-- `foldMaybe (+) 5 (Just 12) = 17`
foldMaybe : (acc -> elem -> acc) -> acc -> Maybe elem -> acc
```

2. Implement the following functions for `Either`:

```idris
mapEither : (a -> b) -> Either e a -> Either e b

-- In case of both `Either`s being `Left`s, keep the
-- value stored in the first `Left`.
appEither : Either e (a -> b) -> Either e a -> Either e b

bindEither : Either e a -> (a -> Either e b) -> Either e b

-- Keep the first value that is not a `Left`
-- If both `Either`s are `Left`s, use the given accumulator
-- for the error values
firstEither : (e -> e -> e) -> Either e a -> Either e a -> Either e a

-- Keep the last value that is not a `Left`
-- If both `Either`s are `Left`s, use the given accumulator
-- for the error values
lastEither : (e -> e -> e) -> Either e a -> Either e a -> Either e a

fromEither : (e -> c) -> (a -> c) -> Either e a -> c
```

3. Implement the following functions for `List`:

```idris
mapList : (a -> b) -> List a -> List b

filterList : (a -> Bool) -> List a -> List a

-- return the first value of a list, if it is non-empty
headMaybe : List a -> Maybe a

-- return everything but the first value of a list, if it is non-empty
tailMaybe : List a -> Maybe (List a)

-- return the last value of a list, if it is non-empty
lastMaybe : List a -> Maybe a

-- return everything but the last value of a list,
-- if it is non-empty
initMaybe : List a -> Maybe (List a)

-- accumulate the values in a list using the given
-- accumulator function and initial result
--
-- Examples:
-- `foldList (+) 10 [1,2,7] = 20`
-- `foldList String.(++) "" ["Hello","World"] = "HelloWorld"
-- `foldList last Nothing (mapList Just [1,2,3]) = Just 3`
foldList : (acc -> elem -> acc) -> acc -> List elem -> acc
```

4. Assume we store user data for our web application in
the following record:

```idris
record Client where
  constructor MkClient
  name     : String
  title    : Title
  age      : Bits8
  password : Either Bits64 String
```

Using `LoginError` from an earlier exercise in this part,
implement function `login`, which, given a list of `Client`s
plus a value of type `Credentials` will return either a `LoginError`
in case no valid credentials where provided, or the first `Client`
for whom the credentials match.

## Alternative Syntax for Data Definitions

While the examples in the section about parameterized
data types are short and concise, there is a slightly
more verbose but much more general form for writing such
definitions, which makes it much clearer what's going on.
In my opinion, this more general form should be preferred
in all but the most simple data definitions.

Here are the definitions of `Option`, `Validated`, and `Seq` again,
using this more general form (I put them in their own *namespace*,
so Idris will not complain about identical names in
the same namespace):

```idris
namespace GADT
  data Option : Type -> Type where
    Some : a -> Option a
    None : Option a

  data Validated : Type -> Type -> Type where
    Invalid : e -> Validated e a
    Valid   : a -> Validated e a

  data Seq : Type -> Type where
    Nil  : Seq a
    (::) : a -> GADT.Seq a -> Seq a
```

Here, `Option` is clearly declared as a type constructor
(a function of type `Type -> Type`), while `Some`
is a generic function of type `a -> Option a` (where `a` is
*type parameter*)
and `None` is a nullary generic function of type `Option a`
(`a` again being a type parameter).
Likewise for `Validated` and `Seq`. Note, that in case
of `Seq` we had to disambiguate between the different
`Seq` definitions in the recursive case. Since we will
usually not define several data types with the same name in
a source file, this is not necessary most of the time.

<!-- vi: filetype=idris2
-->
