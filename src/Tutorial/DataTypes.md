# Algebraic Data Types

In the [previous chapter](Functions1.md),
we learned how to write our own functions and combine
them to create more complex functionality. Of equal importance
is the ability to define our own data types and use them
as arguments and results in functions.

This is a lengthy chapter, densely packed with information.
If you are new to Idris and functional programming, make
sure to follow along slowly, experimenting with the examples,
and possibly coming up with your own. Make sure to try
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

It is important to note that a value of type `Weekday` can only
ever be one of the values listed above. It is a *type error* to
use anything else where a `Weekday` is expected.

### Pattern Matching

In order to use our new data type as a function argument, we
need to learn about an important concept in functional programming
languages: Pattern matching. Let's implement a function which calculates
the successor of a weekday:

```idris
total
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
The different cases in a pattern match are inspected from
top to bottom, each being compared against the current
function argument. Once a matching pattern is found, the
computation on the right hand side of this pattern is
evaluated. Later patterns are then ignored.

For instance, if we invoke `next` with argument `Thursday`,
the first three patterns (`Monday`, `Tuesday`, and `Wednesday`)
will be checked against the argument, but they do not match.
The fourth pattern is a match, and result `Friday` is being
returned. Later patterns are then ignored, even if they would
also match the input (this becomes relevant with catch-all patterns,
which we will talk about in a moment).

The function above is provably total. Idris knows about the
possible values of type `Weekday`, and can therefore figure
out that our pattern match covers all possible cases. We can
therefore annotate the function with the `total` keyword, and
Idris will answer with a type error if it can't verify the
function's totality. (Go ahead, and try removing one of
the clauses in `next` to get an idea about how an error
message from the coverage checker looks like.)

Please remember that these are very strong guarantees from
the type checker: Given enough resources,
a provably total function will *always* return
a result of the given type in a finite amount of time
(*resources* here meaning computational resources like
memory or, in case of recursive functions, stack space).

### Catch-all Patterns

Sometimes, it is convenient to only match on a subset
of the possible values and collect the remaining possibilities
in a catch-all clause:

```idris
total
isWeekend : Weekday -> Bool
isWeekend Saturday = True
isWeekend Sunday   = True
isWeekend _        = False
```

The final line with the catch-all pattern is only invoked
if the argument is not equal to `Saturday` or `Sunday`.
Remember: Patterns in a pattern match are matched against
the input from top to bottom, and the first match decides
which path on the right hand side will be taken.

We can use catch-all patterns to implement an equality test for
`Weekday` (we will not yet use the `==` operator for this; this will
have to wait until we learn about *interfaces*):

```idris
total
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
*Prelude* defines some common enumerations for us: for
instance, `Bool` and `Ordering`. As with `Weekday`,
we can use pattern matching when implementing functions
on these types:

```idris
-- this is how `not` is implemented in the *Prelude*
total
negate : Bool -> Bool
negate False = True
negate True  = False
```

The `Ordering` data type describes an ordering relation
between two values. For instance:

```idris
total
compareBool : Bool -> Bool -> Ordering
compareBool False False = EQ
compareBool False True  = LT
compareBool True True   = EQ
compareBool True False  = GT
```

Here, `LT` means that the first argument is *less than*
the second, `EQ` means that the two arguments are *equal*
and `GT` means, that the first argument is *greater than*
the second.

### Case Expressions

Sometimes we need to perform a computation with one
of the arguments and want to pattern match on the result
of this computation. We can use *case expressions* in this
situation:

```idris
-- returns the larger of the two arguments
total
maxBits8 : Bits8 -> Bits8 -> Bits8
maxBits8 x y =
  case compare x y of
    LT => y
    _  => x
```

The first line of the case expression (`case compare x y of`)
will invoke function `compare` with arguments `x` and `y`. On
the following (indented) lines, we pattern match on the result
of this computation. This is of type `Ordering`, so we expect
one of the three constructors `LT`, `EQ`, or `GT` as the result.
On the first line, we handle the `LT` case explicitly, while
the other two cases are handled with an underscore as a catch-all
pattern.

Note that indentation matters here: The case block as a whole
must be indented (if it starts on a new line), and the different
cases must also be indented by the same amount of whitespace.

Function `compare` is overloaded for many data types. We will
learn how this works when we talk about interfaces.

#### If Then Else

When working with `Bool`, there is an alternative to pattern matching
common to most programming languages:

```idris
total
maxBits8' : Bits8 -> Bits8 -> Bits8
maxBits8' x y = if compare x y == LT then y else x
```

Note that the `if then else` expression always returns a value
and, therefore, the `else` branch cannot be dropped. This is different
from the behavior in typical imperative languages, where `if` is
a statement with possible side effects.

### Naming Conventions: Identifiers

While we are free to use lower-case and upper-case identifiers for
function names, type- and data constructors must be given upper-case
identifiers in order not to confuse Idris (operators are also fine).
For instance, the following data definition is not valid, and Idris
will complain that it expected upper-case identifiers:

```repl
data foo = bar | baz
```

The same goes for similar data definitions like records and sum types
(both will be explained below):

```repl
-- not valid Idris
record Foo where
  constructor mkfoo
```

On the other hand, we typically use lower-case identifiers for function
names, unless we plan to use them mostly during type checking (more on this
later). This is not enforced by Idris, however, so if you are working in
a domain where upper-case identifiers are preferable, feel free to use
those:

```idris
foo : Bits32 -> Bits32
foo = (* 2)

Bar : Bits32 -> Bits32
Bar = foo
```

### Exercises part 1

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
   total
   toSeconds : UnitOfTime -> Integer -> Integer

   -- Given a number of seconds, calculate the
   -- number of steps in the given unit of time
   total
   fromSeconds : UnitOfTime -> Integer -> Integer

   -- convert the number of steps in a given unit of time
   -- to the number of steps in another unit of time.
   -- use `fromSeconds` and `toSeconds` in your implementation
   total
   convert : UnitOfTime -> Integer -> UnitOfTime -> Integer
   ```

3. Define a data type for representing a subset of the
   chemical elements: Hydrogen (H), Carbon (C), Nitrogen (N),
   Oxygen (O), and Fluorine (F).

   Declare and implement function `atomicMass`, which for each element
   returns its atomic mass in dalton:

   ```repl
   Hydrogen : 1.008
   Carbon : 12.011
   Nitrogen : 14.007
   Oxygen : 15.999
   Fluorine : 18.9984
   ```

## Sum Types

Assume we'd like to write some web form, where users of our
web application can decide how they like to be addressed.
We give them a choice between two common predefined
forms of address (Mr and Mrs), but also allow them to
decide on a customized form. The possible
choices can be encapsulated in an Idris data type:

```idris
data Title = Mr | Mrs | Other String
```

This looks almost like an enumeration type, with the exception
that there is a new thing, called a *data constructor*,
which accepts a `String` argument (actually, the values
in an enumeration are also called (nullary) data constructors).
If we inspect the types at the REPL, we learn the following:

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
total
dr : Title
dr = Other "Dr."
```

Again, a value of type `Title` can only consist of one
of the three choices listed above, and again,
we can use pattern matching to implement functions
on the `Title` data type in a provably total way:

```idris
total
showTitle : Title -> String
showTitle Mr        = "Mr."
showTitle Mrs       = "Mrs."
showTitle (Other x) = x
```

Note, how in the last pattern match, the string value stored
in the `Other` data constructor is *bound* to local variable `x`.
Also, the `Other x` pattern has to be wrapped in parentheses,
as otherwise Idris would think `Other` and `x` were to
distinct function arguments.

This is a very common way to extract the values from
data constructors.
We can use `showTitle` to implement a function for creating
a courteous greeting:

```idris
total
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
Either by entering a username plus a password (for which we'll use
an unsigned 64 bit integer here), or by providing user name
plus a (very complex) secret key.
Here's a data type to encapsulate this use case:

```idris
data Credentials = Password String Bits64 | Key String String
```

As an example of a very primitive login function, we can
hard-code some known credentials:

```idris
total
login : Credentials -> String
login (Password "Anderson" 6665443) = greet Mr "Anderson"
login (Key "Y" "xyz")               = greet (Other "Agent") "Y"
login _                             = "Access denied!"
```

As can be seen in the example above, we can also pattern
match against primitive values by using integer and
string literals. Give `login` a go at the REPL:

```repl
Tutorial.DataTypes> login (Password "Anderson" 6665443)
"Hello, Mr. Anderson!"
Tutorial.DataTypes> login (Key "Y" "xyz")
"Hello, Agent Y!"
Tutorial.DataTypes> login (Key "Y" "foo")
"Access denied!"
```

### Exercises part 2

1. Implement an equality test for `Title` (you can use the
   equality operator `(==)` for comparing two `String`s):

   ```idris
   total
   eqTitle : Title -> Title -> Bool
   ```

2. For `Title`, implement a simple test to check, whether
   a custom title is being used:

   ```idris
   total
   isOther : Title -> Bool
   ```

3. Given our simple `Credentials` type, there are three
   ways for authentication to fail:

   * An unknown username was used.
   * The password given does not match the one associated with
     the username.
   * An invalid key was used.

   Encapsulate these three possibilities in a sum type
   called `LoginError`,
   but make sure not to disclose any confidential information:
   An invalid username should be stored in the corresponding
   error value, but an invalid password or key should not.

4. Implement function `showError : LoginError -> String`, which
   can be used to display an error message to the user who
   unsuccessfully tried to login into our web application.

## Records

It is often useful to group together several values
as a logical unit. For instance, in our web application
we might want to group information about a user
in a single data type. Such data types are often called
*product types* (see below for an explanation).
The most common and convenient way to
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
total
agentY : User
agentY = MkUser "Y" (Other "Agent") 51

total
drNo : User
drNo = MkUser "No" dr 73
```

We can also use pattern matching to extract the fields from
a `User` value (they can again be bound to local variables):

```idris
total
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
implementation will no longer type check. We can verify this
by putting the erroneous code in a `failing` block: This
is an indented code block, which will lead to an error
during elaboration (type checking). We can give part
of the expected error message as an optional string argument to
a failing block. If this does not match part of
the error message (or the whole code block does not fail
to type check) the `failing` block itself fails to type
check. This is a useful tool to demonstrate that type
safety works in two directions: We can show that valid
code type checks but also that invalid code is rejected
by the Idris elaborator:

```idris
failing "Mismatch between: String and Title"
  greetUser' : User -> String
  greetUser' (MkUser n t _) = greet n t
```

In addition, for every record field, Idris creates an
extractor function of the same name. This can either
be used as a regular function, or it can be used in
postfix notation by appending it to a variable of
the record type separated by a dot. Here are two examples
for extracting the age from a user:

```idris
getAgeFunction : User -> Bits8
getAgeFunction u = age u

getAgePostfix : User -> Bits8
getAgePostfix u = u.age
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
the value by in-place mutation. These are, again, very strong
guarantees, which makes it drastically easier to reason
about our code.

There are several ways to modify a record, the most
general being to pattern match on the record and
adjust each field as desired. If, for instance, we'd like
to increase the age of a `User` by one, we could do the following:

```idris
total
incAge : User -> User
incAge (MkUser name title age) = MkUser name title (age + 1)
```

That's a lot of code for such a simple thing, so Idris offers
several syntactic conveniences for this. For instance,
using *record* syntax, we can just access and update the `age`
field of a value:

```idris
total
incAge2 : User -> User
incAge2 u = { age := u.age + 1 } u
```

Assignment operator `:=` assigns a new value to the `age` field
in `u`. Remember, that this will create a new `User` value. The original
value `u` remains unaffected by this.

We can access a record field, either by using the field name
as a projection function (`age u`; also have a look at `:t age`
in the REPL), or by using dot syntax: `u.age`. This is special
syntax and *not* related to the dot operator for function
composition (`(.)`).

The use case of modifying a record field is so common
that Idris provides special syntax for this as well:

```idris
total
incAge3 : User -> User
incAge3 u = { age $= (+ 1) } u
```

Here, I used an *operator section* (`(+ 1)`) to make
the code more concise.
As an alternative to an operator section,
we could have used an anonymous function like so:

```idris
total
incAge4 : User -> User
incAge4 u = { age $= \x => x + 1 } u
```

Finally, since our function's argument `u` is only used
once at the very end, we can drop it altogether,
to get the following, highly concise version:

```idris
total
incAge5 : User -> User
incAge5 = { age $= (+ 1) }
```

As usual, we should have a look at the result at the REPL:

```repl
Tutorial.DataTypes> incAge5 drNo
MkUser "No" (Other "Dr.") 74
```

It is possible to use this syntax to set and/or update
several record fields at once:

```idris
total
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
total
weekdayAndBool : Weekday -> Bool -> Pair Weekday Bool
weekdayAndBool wd b = MkPair wd b
```

Since it is quite common to return several values from a function
wrapped in a `Pair` or larger tuple, Idris provides some syntactic
sugar for working with these. Instead of `Pair Weekday Bool`, we
can just write `(Weekday, Bool)`. Likewise, instead of `MkPair wd b`,
we can just write `(wd, b)` (the space is optional):

```idris
total
weekdayAndBool2 : Weekday -> Bool -> (Weekday, Bool)
weekdayAndBool2 wd b = (wd, b)
```

This works also for nested tuples:

```idris
total
triple : Pair Bool (Pair Weekday String)
triple = MkPair False (Friday, "foo")

total
triple2 : (Bool, Weekday, String)
triple2 = (False, Friday, "foo")
```

In the example above, `triple2` is converted to the form
used in `triple` by the Idris compiler.

We can even use tuple syntax in pattern matches:

```idris
total
bar : Bool
bar = case triple of
  (b,wd,_) => b && isWeekend wd
```

### As Patterns

Sometimes, we'd like to take apart a value by pattern matching
on it but still retain the value as a whole for using it
in further computations:

```idris
total
baz : (Bool,Weekday,String) -> (Nat,Bool,Weekday,String)
baz t@(_,_,s) = (length s, t)
```

In `baz`, variable `t` is *bound* to the triple as a whole, which
is then reused to construct the resulting quadruple. Remember,
that `(Nat,Bool,Weekday,String)` is just sugar for
`Pair Nat (Bool,Weekday,String)`, and `(length s, t)` is just
sugar for `MkPair (length s) t`. Hence, the implementation above
is correct as is confirmed by the type checker.

### Exercises part 3

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
unit of time to ensure a lossless conversion.

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
well (there is function `idris_crash` in the *Prelude* for
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

total
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

total
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
Tutorial.DataTypes.None : Option a
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
total
safeDiv : Integer -> Integer -> Option Integer
safeDiv n 0 = None
safeDiv n k = Some (n `div` k)
```

The possibility of returning some kind of *null* value in the
face of invalid input is so common, that there is a data type
like `Option` already in the *Prelude*: `Maybe`, with
data constructors `Just` and `Nothing`.

It is important to understand the difference between returning `Maybe Integer`
in a function, which might fail, and returning
`null` in languages like Java: In the former case, the
possibility of failure is visible in the types. The type checker
will force us to treat `Maybe Integer` differently than
`Integer`: Idris will *not* allow us to forget to
eventually handle the failure case.
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
type parameters `e` and `a`. It's data constructors
are `Invalid` and `Valid`,
the former holding a value describing some error condition,
the latter the result in case of a successful computation.
Let's see this in action:

```idris
total
readWeekdayV : String -> Validated String Weekday
readWeekdayV "Monday"    = Valid Monday
readWeekdayV "Tuesday"   = Valid Tuesday
readWeekdayV "Wednesday" = Valid Wednesday
readWeekdayV "Thursday"  = Valid Thursday
readWeekdayV "Friday"    = Valid Friday
readWeekdayV "Saturday"  = Valid Saturday
readWeekdayV "Sunday"    = Valid Sunday
readWeekdayV s           = Invalid ("Not a weekday: " ++ s)
```

Again, this is such a general concept that a data type
similar to `Validated` is already available from the
*Prelude*: `Either` with data constructors `Left` and `Right`.
It is very common for functions to encapsulate the possibility
of failure by returning an `Either err val`, where `err`
is the error type and `val` is the desired return type. This
is the type safe (and total!) alternative to throwing a catchable
exception in an imperative language.

Note, however, that the semantics of `Either` are not always "`Left` is
an error and `Right` a success". A function returning an `Either` just
means that it can have to different types of results, each of which
are *tagged* with the corresponding data constructor.

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
called the *cons operator*), which prepends a new value of type `a` to
an already existing list of values of the same type. As you can see,
we can also use operators as data constructors, but please do not overuse
this. Use clear names for your functions and data constructors and only
introduce new operators when it truly helps readability!

Here is an example of how to use the `List` constructors
(I use `List` here, as this is what you should use in your own code):

```idris
total
ints : List Int64
ints = 1 :: 2 :: -3 :: Nil
```

However, there is a more concise way of writing the above. Idris
accepts special syntax for constructing data types consisting
exactly of the two constructors `Nil` and `(::)`:

```idris
total
ints2 : List Int64
ints2 = [1, 2, -3]

total
ints3 : List Int64
ints3 = []
```

The two definitions `ints` and `ints2`
are treated identically by the compiler.
Note, that list syntax can also be used in pattern matches.

There is another thing that's special about
`Seq` and `List`: Each of them is defined
in terms of itself (the cons operator accepts a value
and another `Seq` as arguments). We call such data types
*recursive* data types, and their recursive nature means, that in order to
decompose or consume them, we typically require recursive
functions. In an imperative language, we might use a for loop or
similar construct to iterate over the values of a `List` or a `Seq`,
but these things do not exist in a language without in-place
mutation. Here's how to sum a list of integers:

```idris
total
intSum : List Integer -> Integer
intSum Nil       = 0
intSum (n :: ns) = n + intSum ns
```

Recursive functions can be hard to grasp at first, so I'll break
this down a bit. If we invoke `intSum` with the empty list,
the first pattern matches and the function returns zero immediately.
If, however, we invoke `intSum` with a non-empty list - `[7,5,9]`
for instance - the following happens:

1. The second pattern matches and splits the list into two
   parts: Its head (`7`) is bound to variable `n` and its tail
   (`[5,9]`) is bound to `ns`:

   ```repl
   7 + intSum [5,9]
   ```
2. In a second invocation, `intSum` is called with a new list: `[5,9]`.
   The second pattern matches and `n` is bound to `5` and `ns` is bound
   to `[9]`:

   ```repl
   7 + (5 + intSum [9])
   ```

3. In a third invocation `intSum` is called with list `[9]`.
   The second pattern matches and `n` is bound to `9` and `ns` is bound
   to `[]`:

   ```repl
   7 + (5 + (9 + intSum [])
   ```

4. In a fourth invocation, `intSum` is called with list `[]` and
   returns `0` immediately:

   ```repl
   7 + (5 + (9 + 0)
   ```

5. In the third invocation, `9` and `0` are added and `9` is
   returned:

   ```repl
   7 + (5 + 9)
   ```

6. In the second invocation, `5` and `9` are added and `14` is
   returned:

   ```repl
   7 + 14
   ```

7. Finally, our initial invocation of `intSum` adds `7` and `14`
   and returns `21`.

Thus, the recursive implementation of `intSum` leads to a sequence of
nested calls to `intSum`, which terminates once the argument is the
empty list.

### Generic Functions

In order to fully appreciate the versatility that comes with
generic data types, we also need to talk about generic functions.
Like generic types, these are parameterized over one or more
type parameters.

Consider for instance the case of breaking out of the
`Option` data type. In case of a `Some`, we'd like to return
the stored value, while for the `None` case we provide
a default value. Here's how to do this, specialized to
`Integer`s:

```idris
total
integerFromOption : Integer -> Option Integer -> Integer
integerFromOption _ (Some y) = y
integerFromOption x None     = x
```

It's pretty obvious that this, again, is not general enough.
Surely, we'd also like to break out of `Option Bool` or
`Option String` in a similar fashion. That's exactly
what the generic function `fromOption` does:

```idris
total
fromOption : a -> Option a -> a
fromOption _ (Some y) = y
fromOption x None     = x
```

The lower-case `a` is again a *type parameter*. You can read
the type signature as follows: "For any type `a`, given a *value*
of type `a`, and an `Option a`, we can return a value of
type `a`." Note, that `fromOption` knows nothing else about
`a`, other than it being a type. It is therefore not possible,
to conjure a value of type `a` out of thin air. We *must* have
a value available to deal with the `None` case.

The pendant to `fromOption` for `Maybe` is called `fromMaybe`
and is available from module `Data.Maybe` from the *base* library.

Sometimes, `fromOption` is not general enough. Assume we'd like to
print the value of a freshly parsed `Bool`, giving some generic
error message in case of a `None`. We can't use `fromOption`
for this, as we have an `Option Bool` and we'd like to
return a `String`. Here's how to do this:

```idris
total
option : b -> (a -> b) -> Option a -> b
option _ f (Some y) = f y
option x _ None     = x

total
handleBool : Option Bool -> String
handleBool = option "Not a boolean value." show
```

Function `option` is parameterized over *two* type parameters:
`a` represents the type of values stored in the `Option`,
while `b` is the return type. In case of a `Just`, we need
a way to convert the stored `a` to a `b`, an that's done
using the function argument of type `a -> b`.

In Idris, lower-case identifiers in function types are
treated as *type parameters*, while upper-case identifiers
are treated as types or type constructors that must
be in scope.

### Exercises part 4

If this is your first time programming in a purely
functional language, the exercises below are *very*
important. Do not skip any of them! Take your time and
work through them all. In most cases,
the types should be enough to explain what's going
on, even though they might appear cryptic in the
beginning. Otherwise, have a look at the comments (if any)
of each exercise.

Remember, that lower-case identifiers in a function
signature are treated as type parameters.

1. Implement the following generic functions for `Maybe`:

   ```idris
   -- make sure to map a `Just` to a `Just`.
   total
   mapMaybe : (a -> b) -> Maybe a -> Maybe b

   -- Example: `appMaybe (Just (+2)) (Just 20) = Just 22`
   total
   appMaybe : Maybe (a -> b) -> Maybe a -> Maybe b

   -- Example: `bindMaybe (Just 12) Just = Just 12`
   total
   bindMaybe : Maybe a -> (a -> Maybe b) -> Maybe b

   -- keep the value in a `Just` only if the given predicate holds
   total
   filterMaybe : (a -> Bool) -> Maybe a -> Maybe a

   -- keep the first value that is not a `Nothing` (if any)
   total
   first : Maybe a -> Maybe a -> Maybe a

   -- keep the last value that is not a `Nothing` (if any)
   total
   last : Maybe a -> Maybe a -> Maybe a

   -- this is another general way to extract a value from a `Maybe`.
   -- Make sure the following holds:
   -- `foldMaybe (+) 5 Nothing = 5`
   -- `foldMaybe (+) 5 (Just 12) = 17`
   total
   foldMaybe : (acc -> el -> acc) -> acc -> Maybe el -> acc
   ```

2. Implement the following generic functions for `Either`:

   ```idris
   total
   mapEither : (a -> b) -> Either e a -> Either e b

   -- In case of both `Either`s being `Left`s, keep the
   -- value stored in the first `Left`.
   total
   appEither : Either e (a -> b) -> Either e a -> Either e b

   total
   bindEither : Either e a -> (a -> Either e b) -> Either e b

   -- Keep the first value that is not a `Left`
   -- If both `Either`s are `Left`s, use the given accumulator
   -- for the error values
   total
   firstEither : (e -> e -> e) -> Either e a -> Either e a -> Either e a

   -- Keep the last value that is not a `Left`
   -- If both `Either`s are `Left`s, use the given accumulator
   -- for the error values
   total
   lastEither : (e -> e -> e) -> Either e a -> Either e a -> Either e a

   total
   fromEither : (e -> c) -> (a -> c) -> Either e a -> c
   ```

3. Implement the following generic functions for `List`:

   ```idris
   total
   mapList : (a -> b) -> List a -> List b

   total
   filterList : (a -> Bool) -> List a -> List a

   -- return the first value of a list, if it is non-empty
   total
   headMaybe : List a -> Maybe a

   -- return everything but the first value of a list, if it is non-empty
   total
   tailMaybe : List a -> Maybe (List a)

   -- return the last value of a list, if it is non-empty
   total
   lastMaybe : List a -> Maybe a

   -- return everything but the last value of a list,
   -- if it is non-empty
   total
   initMaybe : List a -> Maybe (List a)

   -- accumulate the values in a list using the given
   -- accumulator function and initial value
   --
   -- Examples:
   -- `foldList (+) 10 [1,2,7] = 20`
   -- `foldList String.(++) "" ["Hello","World"] = "HelloWorld"`
   -- `foldList last Nothing (mapList Just [1,2,3]) = Just 3`
   total
   foldList : (acc -> el -> acc) -> acc -> List el -> acc
   ```

4. Assume we store user data for our web application in
   the following record:

   ```idris
   record Client where
     constructor MkClient
     name          : String
     title         : Title
     age           : Bits8
     passwordOrKey : Either Bits64 String
   ```

   Using `LoginError` from an earlier exercise,
   implement function `login`, which, given a list of `Client`s
   plus a value of type `Credentials` will return either a `LoginError`
   in case no valid credentials where provided, or the first `Client`
   for whom the credentials match.

5. Using your data type for chemical elements from an
   earlier exercise, implement a function for calculating
   the molar mass of a molecular formula.

   Use a list of elements each paired with its count
   (a natural number) for representing formulae. For
   instance:

   ```idris
   ethanol : List (Element,Nat)
   ethanol = [(C,2),(H,6),(O,1)]
   ```

   Hint: You can use function `cast` to convert a natural
   number to a `Double`.

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
the same source file):

```idris
-- GADT is an acronym for "generalized algebraic data type"
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
a *type parameter*)
and `None` is a nullary generic function of type `Option a`
(`a` again being a type parameter).
Likewise for `Validated` and `Seq`. Note, that in case
of `Seq` we had to disambiguate between the different
`Seq` definitions in the recursive case. Since we will
usually not define several data types with the same name in
a source file, this is not necessary most of the time.

## Conclusion

We covered a lot of ground in this chapter,
so I'll summarize the most important points below:

* Enumerations are data types consisting of a finite
number of possible *values*.

* Sum types are data types with more than one data
constructor, where each constructor describes a
*choice* that can be made.

* Product types are data types with a single constructor
used to group several values of possibly different types.

* We use pattern matching to deconstruct immutable
values in Idris. The possible patterns correspond to
a data type's data constructors.

* We can *bind* variables to values in a pattern or
use an underscore as a placeholder for a value that's
not needed on the right hand side of an implementation.

* We can pattern match on an intermediary result by introducing
a *case block*.

* The preferred way to define new product types is
to define them as *records*, since these come with
additional syntactic conveniences for setting and
modifying individual *record fields*.

* Generic types and functions allow us generalize
certain concepts and make them available for many
types by using *type parameters* instead of
concrete types in function and type signatures.

* Common concepts like *nullary values* (`Maybe`),
computations that might fail with some error
condition (`Either`), and handling collections
of values of the same type at once (`List`) are
example use cases of generic types and functions
already provided by the *Prelude*.

## What's next

In the [next section](Interfaces.md), we will introduce
*interfaces*, another approach to *function overloading*.

<!-- vi: filetype=idris2:syntax=markdown
-->
