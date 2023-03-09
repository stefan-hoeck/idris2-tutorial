# Interfaces

Function overloading - the definition of functions
with the same name but different implementations - is a concept
found in many programming languages. Idris natively supports overloading
of functions: Two functions with the same name can be defined in
different modules or namespaces, and Idris will try to disambiguate
between these based on the types involved. Here is an example:

```idris
module Tutorial.Interfaces

%default total

namespace Bool
  export
  size : Bool -> Integer
  size True  = 1
  size False = 0

namespace Integer
  export
  size : Integer -> Integer
  size = id

namespace List
  export
  size : List a -> Integer
  size = cast . length
```

Here, we defined three different functions
called `size`, each in its own namespace. We can disambiguate between
these by prefixing them with their namespace:

```repl
Tutorial.Interfaces> :t Bool.size
Tutorial.Interfaces.Bool.size : Bool -> Integer
```

However, this is usually not necessary:

```idris
mean : List Integer -> Integer
mean xs = sum xs `div` size xs
```

As you can see, Idris can disambiguate between the different
`size` functions, since `xs` is of type `List Integer`, which
unifies only with `List a`, the argument type of `List.size`.

## Interface Basics

While function overloading as described above
works well, there are use cases, where
this form of overloaded functions leads to a lot of code duplication.

As an example, consider a function `cmp` (short for *compare*, which is
already exported by the *Prelude*), for describing an ordering
for the values of type `String`:

```idris
cmp : String -> String -> Ordering
```

We'd also like to have similar functions for many other data types.
Function overloading allows us to do just that, but `cmp` is not an
isolated piece of functionality. From it, we can derive functions
like `greaterThan'`, `lessThan'`, `minimum'`, `maximum'`, and many others:

```idris
lessThan' : String -> String -> Bool
lessThan' s1 s2 = LT == cmp s1 s2

greaterThan' : String -> String -> Bool
greaterThan' s1 s2 = GT == cmp s1 s2

minimum' : String -> String -> String
minimum' s1 s2 =
  case cmp s1 s2 of
    LT => s1
    _  => s2

maximum' : String -> String -> String
maximum' s1 s2 =
  case cmp s1 s2 of
    GT => s1
    _  => s2
```

We'd need to implement all of these again for the other types with a `cmp`
function, and most if not all of these implementations would be identical
to the ones written above. That's a lot of code repetition.

One way to solve this is to use higher-order functions.
For instance, we could define function `minimumBy`, which takes
a comparison function as its first argument and returns the smaller
of the two remaining arguments:

```idris
minimumBy : (a -> a -> Ordering) -> a -> a -> a
minimumBy f a1 a2 =
  case f a1 a2 of
    LT => a1
    _  => a2
```

This solution is another proof of how higher-order functions
allow us to reduce code duplication. However, the need to explicitly
pass around the comparison function all the time
can get tedious as well.
It would be nice, if we could teach Idris to come up with
such a function on its own.

Interfaces solve exactly this issue. Here's an example:

```idris
interface Comp a where
  comp : a -> a -> Ordering

implementation Comp Bits8 where
  comp = compare

implementation Comp Bits16 where
  comp = compare
```

The code above defines *interface* `Comp` providing
function `comp` for calculating the
ordering for two values of a type `a`, followed by two *implementations*
of this interface for types `Bits8` and `Bits16`. Note, that the
`implementation` keyword is optional.

The `comp` implementations for `Bits8` and `Bits16` both use
function `compare`, which is part of a similar interface
from the *Prelude* called `Ord`.

The next step is to look at the type of `comp` at the REPL:

```repl
Tutorial.Interfaces> :t comp
Tutorial.Interfaces.comp : Comp a => a -> a -> Ordering
```

The interesting part in the type signature of `comp` is
the initial `Comp a =>` argument. Here, `Comp` is a *constraint* on
type parameter `a`. This signature can be read as:
"For any type `a`, given an implementation
of interface `Comp` for `a`, we can compare two values
of type `a` and return an `Ordering` for these."
Whenever we invoke `comp`, we expect Idris to come up with a
value of type `Comp a` on its own, hence the new `=>` arrow.
If Idris fails to do so, it will answer with a type error.

We can now use `comp` in the implementations of related functions.
All we have to do is to also prefix these derived functions
with a `Comp` constraint:

```idris
lessThan : Comp a => a -> a -> Bool
lessThan s1 s2 = LT == comp s1 s2

greaterThan : Comp a => a -> a -> Bool
greaterThan s1 s2 = GT == comp s1 s2

minimum : Comp a => a -> a -> a
minimum s1 s2 =
  case comp s1 s2 of
    LT => s1
    _  => s2

maximum : Comp a => a -> a -> a
maximum s1 s2 =
  case comp s1 s2 of
    GT => s1
    _  => s2
```

Note, how the definition of `minimum` is almost identical
to `minimumBy`. The only difference being that in case of
`minimumBy` we had to pass the comparison function as an
explicit argument, while for `minimum` it is provided as
part of the `Comp` implementation, which is passed around
by Idris for us.

Thus, we have defined all these utility functions once and for
all for every type with an implementation of interface `Comp`.

### Exercises part 1

1. Implement function `anyLarger`, which should return `True`,
if and only if a list of values contains at least one element larger
than a given reference value. Use interface `Comp` in your
implementation.

2. Implement function `allLarger`, which should return `True`,
if and only if a list of values contains *only* elements larger
than a given reference value. Note, that this is trivially true
for the empty list. Use interface `Comp` in your implementation.

3. Implement function `maxElem`, which tries to extract the
largest element from a list of values with a `Comp` implementation.
Likewise for `minElem`, which tries to extract the smallest element.
Note, that the possibility of the list being empty must be considered
when deciding on the output type.

4. Define an interface `Concat` for values like lists or
strings, which can be concatenated. Provide implementations
for lists and strings.

5. Implement function `concatList` for concatenating the
values in a list holding values with a `Concat` implementation.
Make sure to reflect the possibility of the list being empty in your
output type.

## More about Interfaces

In the last section, we learned about the very basics
of interfaces: Why they are useful and how to define and
implement them.
In this section, we will learn about some slightly
advanced concepts: Extending interfaces, interfaces with
constraints, and default implementations.

### Extending Interfaces

Some interfaces form a kind of hierarchy. For instance, for
the `Concat` interface used in exercise 4, there might
be a child interface called `Empty`, for those types,
which have a neutral element with relation to concatenation.
In such a case, we make an implementation of `Concat` a
prerequisite for implementing `Empty`:

```idris
interface Concat a where
  concat : a -> a -> a

implementation Concat String where
  concat = (++)

interface Concat a => Empty a where
  empty : a

implementation Empty String where
  empty = ""
```

`Concat a => Empty a` should be read as: "An implementation
of `Concat` for type `a` is a *prerequisite* for there being
an implementation of `Empty` for `a`."
But this also means that, whenever we have an implementation
of interface `Empty`, we *must* also have an implementation of `Concat`
and can invoke the corresponding functions:

```idris
concatListE : Empty a => List a -> a
concatListE []        = empty
concatListE (x :: xs) = concat x (concatListE xs)
```

Note, how in the type of `concatListE` we only used an `Empty`
constraint, and how in the implementation we were still able
to invoke both `empty` and `concat`.

### Constrained Implementations

Sometimes, it is only possible to implement an interface
for a generic type, if its type parameters implement
this interface as well. For instance, implementing interface `Comp`
for `Maybe a` makes sense only if type `a` itself implements
`Comp`. We can constrain interface implementations with
the same syntax we use for constrained functions:

```idris
implementation Comp a => Comp (Maybe a) where
  comp Nothing  Nothing  = EQ
  comp (Just _) Nothing  = GT
  comp Nothing  (Just _) = LT
  comp (Just x) (Just y) = comp x y
```

This is not the same as extending an interface, although
the syntax looks very similar. Here, the constraint lies
on a *type parameter* instead of the full type.
The last line in the implementation of `Comp (Maybe a)`
compares the values stored in the two `Just`s. This is
only possible, if there is a `Comp` implementation for
these values as well. Go ahead, and remove the `Comp a`
constraint from the above implementation. Learning to
read and understand Idris' type errors is important
for fixing them.

The good thing is, that Idris will solve all these
constraints for us:

```idris
maxTest : Maybe Bits8 -> Ordering
maxTest = comp (Just 12)
```

Here, Idris tries to find an implementation for `Comp (Maybe Bits8)`.
In order to do so, it needs an implementation for `Comp Bits8`.
Go ahead, and replace `Bits8` in the type of `maxTest` with `Bits64`,
and have a look at the error message Idris produces.

### Default Implementations

Sometimes, we'd like to pack several related functions
in an interface to allow programmers to implement each
in the most efficient way, although they *could* be
implemented in terms of each other. For instance,
consider an interface `Equals` for comparing two
values for equality, with functions `eq` returning
`True` if two values are equal and `neq` returning
`True` if they are not. Surely, we can implement `neq`
in terms of `eq`, so most of the time when implementing
`Equals`, we will only implement the latter.
In this case, we can give an implementation for `neq`
already in the definition of `Equals`:

```idris
interface Equals a where
  eq : a -> a -> Bool

  neq : a -> a -> Bool
  neq a1 a2 = not (eq a1 a2)
```

If in an implementation of `Equals` we only implement `eq`,
Idris will use the default implementation for `neq` as
shown above:

```idris
Equals String where
  eq = (==)
```

If on the other hand we'd like to provide explicit implementations
for both functions, we can do so as well:

```idris
Equals Bool where
  eq True True   = True
  eq False False = True
  eq _ _         = False

  neq True  False = True
  neq False True  = True
  neq _ _         = False
```

### Exercises part 2

1. Implement interfaces `Equals`, `Comp`, `Concat`, and
  `Empty` for pairs, constraining your implementations as necessary.
  (Note, that multiple constraints can be given sequentially like
  other function arguments: `Comp a => Comp b => Comp (a,b)`.)

2. Below is an implementation of a binary tree. Implement
   interfaces `Equals` and `Concat` for this type.

   ```idris
   data Tree : Type -> Type where
     Leaf : a -> Tree a
     Node : Tree a -> Tree a -> Tree a
   ```

## Interfaces in the *Prelude*

The Idris *Prelude* provides several interfaces plus implementations
that are useful in almost every non-trivial program. I'll introduce
the basic ones here. The more advanced ones will be discussed in later
chapters.

Most of these interfaces come with associated mathematical laws,
and implementations are assumed to adhere to these laws. These
laws will be given here as well.

### `Eq`

Probably the most often used interface, `Eq` corresponds to
interface `Equals` we used above as an example. Instead of
`eq` and `neq`, `Eq` provides two operators `(==)` and `(/=)`
for comparing two values of the same type for being equal
or not. Most of the data types defined in the *Prelude* come
with an implementation of `Eq`, and whenever programmers define
their own data types, `Eq` is typically one of the first
interfaces they implement.

#### `Eq` Laws

We expect the following laws to hold for all implementations of `Eq`:

* `(==)` is *reflexive*: `x == x = True` for all `x`. This means, that
every value is equal to itself.

* `(==)` is *symmetric*: `x == y = y == x` for all `x` and `y`.
This means, that the order of arguments passed to `(==)` does not matter.

* `(==)` is *transitive*: From `x == y = True` and `y == z = True` follows
`x == z = True`.

* `(/=)` is the negation of `(==)`: `x == y = not (x /= y)`
for all `x` and `y`.

In theory, Idris has the power to verify these laws at compile time
for many non-primitive types. However, out of pragmatism this is not
required when implementing `Eq`, since writing such proofs can be
quite involved.

### `Ord`

The pendant to `Comp` in the *Prelude* is interface `Ord`. In addition
to `compare`, which is identical to our own `comp` it provides comparison
operators `(>=)`, `(>)`, `(<=)`, and `(<)`, as well as utility functions
`max` and `min`. Unlike `Comp`, `Ord` extends `Eq`,
so whenever there is an `Ord` constraint, we also have access to operators
`(==)` and `(/=)` and related functions.

#### `Ord` Laws

We expect the following laws to hold for all implementations of `Ord`:

* `(<=)` is *reflexive* and *transitive*.
* `(<=)` is *antisymmetric*: From `x <= y = True` and `y <= x = True`
follows `x == y = True`.
* `x <= y = y >= x`.
* `x < y = not (y <= x)`
* `x > y = not (y >= x)`
* `compare x y = EQ` => `x == y = True`
* `compare x y == GT = x > y`
* `compare x y == LT = x < y`

### `Semigroup` and `Monoid`

`Semigroup` is the pendant to our example interface `Concat`,
with operator `(<+>)` (also called *append*) corresponding
to function `concat`.

Likewise, `Monoid` corresponds to `Empty`,
with `neutral` corresponding to `empty`.

These are incredibly important interfaces, which can be used
to combine two or more values of a data type into a single
value of the same type. Examples include but are not limited
to addition or multiplication
of numeric types, concatenation of sequences of data, or
sequencing of computations.

As an example, consider a data type for representing
distances in a geometric application. We could just use `Double`
for this, but that's not very type safe. It would be better
to use a single field record wrapping values type `Double`,
to give such values clear semantics:

```idris
record Distance where
  constructor MkDistance
  meters : Double
```

There is a natural way for combining two distances: We sum up
the values they hold. This immediately leads to an implementation
of `Semigroup`:

```idris
Semigroup Distance where
  x <+> y = MkDistance $ x.meters + y.meters
```

It is also immediately clear, that zero is the neutral element of this
operation: Adding zero to any value does not affect the value at all.
This allows us to implement `Monoid` as well:

```idris
Monoid Distance where
  neutral = MkDistance 0
```

#### `Semigroup` and `Monoid` Laws

We expect the following laws to hold for all implementations of `Semigroup`
and `Monoid`:

* `(<+>)` is *associative*: `x <+> (y <+> z) = (x <+> y) <+> z`, for all
  values `x`, `y`, and `z`.
* `neutral` is the *neutral element* with relation to `(<+>)`:
  `neutral <+> x = x <+> neutral = x`, for all `x`.

### `Show`

The `Show` interface is mainly used for debugging purposes, and is
supposed to display values of a given type as a string, typically closely
resembling the Idris code used to create the value. This includes the
proper wrapping of arguments in parentheses where necessary. For instance,
experiment with the output of the following function at the REPL:

```idris
showExample : Maybe (Either String (List (Maybe Integer))) -> String
showExample = show
```

And at the REPL:

```repl
Tutorial.Interfaces> showExample (Just (Right [Just 12, Nothing]))
"Just (Right [Just 12, Nothing])"
```

We will learn how to implement instances of `Show` in an exercise.

### Overloaded Literals

Literal values in Idris, such as integer literals (`12001`), string
literals (`"foo bar"`), floating point literals (`12.112`), and
character literals  (`'$'`) can be overloaded. This means, that we
can create values of types other than `String` from just a string
literal. The exact workings of this has to wait for another section,
but for many common cases, it is sufficient for a value to implement
interfaces `FromString` (for using string literals), `FromChar` (for using
character literals), or `FromDouble` (for using floating point literals).
The case of integer literals is special, and will be discussed in the next
section.

Here is an example of using `FromString`. Assume, we write an application
where users can identify themselves with a username and password. Both
consist of strings of characters, so it is pretty easy to confuse and mix
up the two things, although they clearly have very different semantics.
In these cases, it is advisable to come up with new types for the two,
especially since getting these things wrong is a security concern.

Here are three example record types to do this:

```idris
record UserName where
  constructor MkUserName
  name : String

record Password where
  constructor MkPassword
  value : String

record User where
  constructor MkUser
  name     : UserName
  password : Password
```

In order to create a value of type `User`, even for testing, we'd have
to wrap all strings using the given constructors:

```idris
hock : User
hock = MkUser (MkUserName "hock") (MkPassword "not telling")
```

This is rather cumbersome, and some people might think this to be too high
a price to pay just for an increase in type safety (I'd tend to disagree).
Luckily, we can get the convenience of string literals back very easily:

```idris
FromString UserName where
  fromString = MkUserName

FromString Password where
  fromString = MkPassword

hock2 : User
hock2 = MkUser "hock" "not telling"
```

### Numeric Interfaces

The *Prelude* also exports several interfaces providing the usual arithmetic
operations. Below is a comprehensive list of the interfaces and the
functions each provides:

* `Num`
  * `(+)` : Addition
  * `(*)` : Multiplication
  * `fromInteger` : Overloaded integer literals

* `Neg`
  * `negate` : Negation
  * `(-)` : Subtraction

* `Integral`
  * `div` : Integer division
  * `mod` : Modulo operation

* `Fractional`
  * `(/)` : Division
  * `recip` : Calculates the reciprocal of a value

As you can see: We need to implement interface `Num` to
use integer literals for a given type. In order to use
negative integer literals like `-12`, we also have to
implement interface `Neg`.

### `Cast`

The last interface we will quickly discuss in this section is `Cast`. It
is used to convert values of one type to values of another via
function `cast`. `Cast` is special, since it is parameterized
over *two* type parameters unlike the other interfaces we looked
at so far, with only one type parameter.

So far, `Cast` is mainly used for interconversion
between primitive types in the standard libraries,
especially numeric types. When you look
at the implementations exported from the *Prelude* (for instance,
by invoking `:doc Cast` at the REPL), you'll see that there are
dozens of implementations for most pairings of primitive types.

Although `Cast` would also be useful for other conversions (for
going from `Maybe` to `List` or for going from `Either e` to `Maybe`,
for instance), the *Prelude* and
*base* seem not to introduce these consistently. For instance,
there are `Cast` implementations from going from `SnocList` to
`List` and vice versa, but not for going from `Vect n` to `List`,
or for going from `List1` to `List`, although these would
be just as feasible.

### Exercises part 3

These exercises are meant to make you comfortable with
implementing interfaces for your own data types, as you
will have to do so regularly when writing Idris code.

While it is immediately clear why interfaces like
`Eq`, `Ord`, or `Num` are useful, the usability of
`Semigroup` and `Monoid` may be harder to appreciate at first.
Therefore, there are several exercises where you'll implement
different instances for these.

1. Define a record type `Complex` for complex numbers, by pairing
   two values of type `Double`.
   Implement interfaces `Eq`, `Num`, `Neg`, and `Fractional` for `Complex`.

2. Implement interface `Show` for `Complex`. Have a look at data type `Prec`
   and function `showPrec` and how these are used in the
   *Prelude* to implement instances for `Either` and `Maybe`.

   Verify the correct behavior of your implementation by wrapping
   a value of type `Complex` in a `Just` and `show` the result at
   the REPL.

3. Consider the following wrapper for optional values:

   ```idris
   record First a where
     constructor MkFirst
     value : Maybe a
   ```

   Implement interfaces `Eq`, `Ord`, `Show`, `FromString`, `FromChar`, `FromDouble`,
   `Num`, `Neg`, `Integral`, and `Fractional` for `First a`. All of these will require
   corresponding constraints on type parameter `a`. Consider implementing and
   using the following utility functions where they make sense:

   ```idris
   pureFirst : a -> First a

   mapFirst : (a -> b) -> First a -> First b

   mapFirst2 : (a -> b -> c) -> First a -> First b -> First c
   ```

4. Implement interfaces `Semigroup` and `Monoid` for `First a` in such a way,
   that `(<+>)` will return the first non-nothing argument and `neutral` is
   the corresponding neutral element. There must be no constraints on type
   parameter `a` in these implementations.

5. Repeat exercises 3 and 4 for record `Last`. The `Semigroup` implementation
   should return the last non-nothing value.

   ```idris
   record Last a where
     constructor MkLast
     value : Maybe a
   ```

6. Function `foldMap` allows us to map a function returning a `Monoid` over
   a list of values and accumulate the result using `(<+>)` at the same time.
   This is a very powerful way to accumulate the values stored in a list.
   Use `foldMap` and `Last` to extract the last element (if any) from a list.

   Note, that the type of `foldMap` is more general and not specialized
   to lists only. It works also for `Maybe`, `Either` and other container
   types we haven't looked at so far. We will learn about
   interface `Foldable` in a later section.

7. Consider record wrappers `Any` and `All` for boolean values:

   ```idris
   record Any where
     constructor MkAny
     any : Bool

   record All where
     constructor MkAll
     all : Bool
   ```

   Implement `Semigroup` and `Monoid` for `Any`, so that the result of
   `(<+>)` is `True`, if and only if at least one of the arguments is `True`.
   Make sure that `neutral` is indeed the neutral element for this operation.

   Likewise, implement `Semigroup` and `Monoid` for `All`, so that the result of
   `(<+>)` is `True`, if and only if both of the arguments are `True`.
   Make sure that `neutral` is indeed the neutral element for this operation.

8. Implement functions `anyElem` and `allElems` using `foldMap` and
   `Any` or `All`, respectively:

   ```idris
   -- True, if the predicate holds for at least one element
   anyElem : (a -> Bool) -> List a -> Bool

   -- True, if the predicate holds for all elements
   allElems : (a -> Bool) -> List a -> Bool
   ```

9. Record wrappers `Sum` and `Product` are mainly used to hold
   numeric types.

   ```idris
   record Sum a where
     constructor MkSum
     value : a

   record Product a where
     constructor MkProduct
     value : a
   ```

   Given an implementation of `Num a`, implement `Semigroup (Sum a)`
   and `Monoid (Sum a)`, so that `(<+>)` corresponds to addition.

   Likewise, implement `Semigroup (Product a)` and `Monoid (Product a)`,
   so that `(<+>)` corresponds to multiplication.

   When implementing `neutral`, remember that you can use integer
   literals when working with numeric types.

10. Implement `sumList` and `productList` by using `foldMap` together
    with the wrappers from Exercise 9:

    ```idris
    sumList : Num a => List a -> a

    productList : Num a => List a -> a
    ```

11. To appreciate the power and versatility of `foldMap`, after
    solving exercises 6 to 10 (or by loading `Solutions.Inderfaces`
    in a REPL session), run the following at the REPL, which will -
    in a single list traversal! - calculate the first and last
    element of the list as well as the sum and product of all values.

    ```repl
    > foldMap (\x => (pureFirst x, pureLast x, MkSum x, MkProduct x)) [3,7,4,12]
    (MkFirst (Just 3), (MkLast (Just 12), (MkSum 26, MkProduct 1008)))
    ```

    Note, that there are also `Semigroup` implementations for
    types with an `Ord` implementation, which will return
    the smaller or larger of two values. In case of types
    with an absolute minimum or maximum (for instance, 0 for
    natural numbers, or 0 and 255 for `Bits8`), these can even
    be extended to `Monoid`.

12. In an earlier exercise, you implemented a data type representing
    chemical elements and wrote a function for calculating their
    atomic masses. Define a new single field record type for
    representing atomic masses, and implement interfaces
    `Eq`, `Ord`, `Show`, `FromDouble`, `Semigroup`, and `Monoid` for this.

13. Use the new data type from exercise 12 to calculate the atomic
    mass of an element and compute the molecular mass
    of a molecule given by its formula.

    Hint: With a suitable utility function, you can use `foldMap`
    once again for this.

Final notes: If you are new to functional programming, make sure
to give your implementations of exercises 6 to 10 a try at the REPL.
Note, how we can implement all of these functions with a minimal amount
of code and how, as shown in exercise 11, these behaviors can be
combined in a single list traversal.

## Conclusion

* Interfaces allow us to implement the same function with different
  behavior for different types.
* Functions taking one or more interface implementations as
  arguments are called *constrained functions*.
* Interfaces can be organized hierarchically by *extending*
  other interfaces.
* Interfaces implementations can themselves be *constrained*
  requiring other implementations to be available.
* Interface functions can be given a *default implementation*,
  which can be overridden by implementers, for instance for reasons
  of efficiency.
* Certain interfaces allow us to use literal values such as
  string or integer literals for our own data types.

Note, that I did not yet tell the whole story about literal values
in this section. More details for using literals with types that
accept only a restricted set of values can be found in the
chapter about [primitives](Prim.md).

### What's next

In the [next chapter](Functions2.md), we have a closer look
at functions and their types. We will learn about named arguments,
implicit arguments, and erased arguments as well as some
constructors for implementing more complex functions.

<!-- vi: filetype=idris2:syntax=markdown
-->
