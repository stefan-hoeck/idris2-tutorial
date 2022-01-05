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
these, by prefixing them with their namespace:

```repl
Tutorial.Interfaces> :t Bool.size
Tutorial.Interfaces.Bool.size : Bool -> Integer
```

However, this is usually not necessary:

```idris
mean : List Integer -> Integer
mean xs = sum xs `div` size xs
```

## The Basics about Interfaces

While function overloading as described at the beginning of this tutorial
works well and is already really very powerful, there are use cases, where
this form of overloaded functions leads to a lot of code duplication.

As an example, consider a function `cmp`, for describing an ordering
for the values of type `String`:

```idris
cmp : String -> String -> Ordering
```

We'd also like to have similar functions for many other data types.
Function overloading allows us to do just that, but `cmp` is not an
isolated piece of functionality. From it, we can derive functions
like `greaterThan'`, `lessThan'`, `minmum'`, `maximum'`, and many others:

```idris
lessThan' : String -> String -> Bool
lessThan' s1 s2 = LT == cmp s1 s2

greaterThan' : String -> String -> Bool
greaterThan' s1 s2 = GT == cmp s1 s2

minimum' : String -> String -> String
minimum' s1 s2 = case cmp s1 s2 of
  LT => s1
  _  => s2

maximum' : String -> String -> String
maximum' s1 s2 = case cmp s1 s2 of
  GT => s1
  _  => s2
```

We'd need to implement all of these again for the other types with a `cmp`
function, and many of these implementations would be identical
to the ones written above. That's a lot of code repetition.

One way to go about this, is to use higher order functions.
For instance, we could define function `minimumBy`, which takes
a comparison function as its first argument:

```idris
minimumBy : (a -> a -> Ordering) -> a -> a -> a
minimumBy f a1 a2 = case f a1 a2 of
  LT => a1
  _  => a2
```

This solution is another proof of how higher order functions
allow us to reduce code duplication. However, the need to explicitly
pass the comparison function all the time can get tedious as well.
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

The code above defines *interface* `Comp` for ordering
two values of a type `a`, followed by two *implementations*
of this interface for types `Bits8` and `Bits16`. Note, that
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
type `a`. This signature can be read as: "Given an implementation
of interface `Comp` for type `a`, we can compare two values
of type `a` and return an `Ordering` for these."

We expect Idris to come up with a value of type `Comp a`
on its own, whenever we invoke `comp`. If Idris fails to
do so, it will answer with a type error.

We can now use `comp` in the implementation of related functions.
All we have to do is to also prefix these derived functions
with a `Comp` constraint:

```idris
lessThan : Comp a => a -> a -> Bool
lessThan s1 s2 = LT == comp s1 s2

greaterThan : Comp a => a -> a -> Bool
greaterThan s1 s2 = GT == comp s1 s2

minimum : Comp a => a -> a -> a
minimum s1 s2 = case comp s1 s2 of
  LT => s1
  _  => s2

maximum : Comp a => a -> a -> a
maximum s1 s2 = case comp s1 s2 of
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

### Exercises

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
when choosing the return type.

4. Define an interface `Concat` for values like lists or
strings, which can be concatenated. Provide implementations
for lists and strings.

5. Implement function `concatList` for concatenating the
values in a list holding values with a `Concat` implementation.
Make sure to reflect the possibility of the list being empty in your
return type.

## More About Interfaces

In the last sections, we learned about the very basics
of interfaces: Why they are useful and how to define and
implement them.

In this section, we will learn about some slightly
advanced concepts: Extending interfaces, interfaces with
constraints, and default implementations.

### Extending Interfaces

Some interfaces form a kind of hierarchy. For instance, for
the `Concat` interface used in exercise 4, there might
be a child interface called `Empty`, for those type,
which have a neutral element with relation to concatenation:

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

But this also means that, whenever we have an implementation
of interface `Empty`, we also an implementation of `Concat`
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

Sometimes, for a generic type it is only possible
to implement an interface, if its type parameters implement
this interface as well. For instance, implementing interface `Comp`
for `Maybe a` makes sense only if type `a` itself implements
`Comp`. We can constrain interface implementations with
the same syntax we use for constrained functions:

```idris
implementation Comp a => Comp (Maybe a) where
  comp Nothing Nothing = EQ
  comp (Just _) Nothing = GT
  comp Nothing (Just _) = LT
  comp (Just x) (Just y) = comp x y
```

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
`Equals`, we will only implement the former.

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
for both functions, we can do that as well:

```idris
Equals Bool where
  eq True True   = True
  eq False False = True
  eq _ _         = False

  neq True  False = True
  neq False True  = True
  neq _ _         = False
```

### Exercises

1. Implement interfaces `Equals`, `Comp`, `Concat`, and
`Empty` for pairs, constraining your implementations as necessary.
(Note, that multiple constraints can be given sequentially like
other function arguments: `Comp a => Comp b => Comp (a,b)`.

2. Below is an implementation of a binary tree. Implement
interfaces `Equals` and `Concat` for this type.

```idris
data Tree : Type -> Type where
  Leaf : a -> Tree a
  Node : Tree a -> Tree a
```

## Interfaces in the *Prelude*

The Idris *Prelude* provides several interfaces plus implementations
that are useful in almost every non-trivial program. I'll introduce
the basic ones here. The more advanced will be discussed in another
chapter.

Most of these interfaces come with associated mathematical laws,
and implementations are assumed to adhere to these laws.

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

* `(==)` is *reflexive*: `va == va = True` for all `va`. This means, that
every value is equal to itself.

* `(==)` is *symmetric*: `va == vb = vb == va` for all `va` and `vb`.
This means, that the order of arguments passed to `(==)` does not matter.

* `(==)` is *transitive*: From `va == vb = True` and `vb == vc = True` follows
`va == vc = True`.

* `(/=)` is the negation of `(==)`: `va == vb = not (va /= vb)`
for all `va` and `vb`.

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

<!-- vi: filetype=idris2
-->
