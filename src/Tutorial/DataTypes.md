# Algebraic Data Types

In the [previous part](Functions1.md) of the tutorial,
we learned how to write our own functions and combine
them to create more complex functionality. Of equal importance
is the ability to define our own data types and use them
as arguments and results in our functions.

```idris
module Tutorial.DataTypes
```

## Enumerations

Let's start with a data type for the days of the week.

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

So, in order to inspect a `Weekday` argument, we match on the
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

## Sum Types

Assume we'd like to write some web form, where users of our
web application can decide how they like to be addressed.
We give them a choice between two common predefined
forms of address (Mr and Mrs), but also allow them to
decide on a different form of address. The possible
choices should be encapsulated in an Idris data type:

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
a `Title` as the results:

```idris
dr : Title
dr = Other "Dr."
```

Again, we can use pattern matching to implement function
on the `Title` data type:

```idris
showTitle : Title -> String
showTitle Mr        = "Mr."
showTitle Mrs       = "Mrs."
showTitle (Other x) = x
```

We can use this to implement a function, which creates
a courteous greeting:

```idris
greet : Title -> String -> String
greet t name = "Hello, " ++ showTitle t ++ " " ++ name ++ "!"
```

In the implementation of `greet`, we use string literals
and the string concatenation operator `(++)` to
create the greeting from its different parts.

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
match against primitive data types by using integer and
string literals. Give it a go at the REPL:

```repl
Tutorial.DataTypes> login (Password "Anderson" 6665443)
"Hello, Mr. Anderson!"
Tutorial.DataTypes> login (Key "xyz")
"Hello, Agent Y!"
Tutorial.DataTypes> login (Key "foo")
"Access denied!"
```

## Records

It is often useful to group together several values
in a logical unit. For instance, in our web application
we might want to group information about a user
in a single data type. Such data types are often called
*product types*. The most common and convenient way to
define such data types is the `record` construct:

```idris
record User where
  constructor MkUser
  name  : String
  title : Title
  age   : Bits8
```

The above declaration creates a new *type* called `User`,
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
a `User` value:

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

Note how Idris will prevent us from making
a common mistake: If we confuse the order of arguments, the
implementation will no longer type check:

```repl
-- this will result in a type error
greetUser : User -> String
greetUser (MkUser n t _) = greet n t
```

### Syntactic Sugar for Records

<!-- vi: filetype=idris2
-->
