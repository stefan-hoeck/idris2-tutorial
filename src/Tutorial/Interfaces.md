# Interfaces

Function overloading - the definition of functions of the
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

In the code section above, we define three different functions
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

As an example, consider a function `comp`, for describing an ordering
for the values of type `String`:

```idris
cmp : String -> String -> Ordering
```

We'd also like to have a similar function for many other data types.
Function overloading allows us to do just that, but `cmp` is not an
isolated piece of functionality. From this, we can derive functions
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

All of these, we'd need to implement for the other types with a `cmp`
function as well, and many of these implementations would be identical
to the ones written above. That's a lot of code repetition.

Interfaces solve exactly this issue. Here's an example:

```idris
interface Comp a where
  comp : a -> a -> Ordering

implementation Comp Bits8 where
  comp = compare

implementation Comp Bits16 where
  comp = compare
```

The above code snippet defines interface `Comp` for ordering
two values of a type `a`, followed by two *implementations*
of this interface for types `Bits8` and `Bits16`. (The implementations
actually use an already existing interface called `Ord`.
More on this below.)

The next step is to look at the type of `comp` in the REPL:

```repl
Tutorial.Interfaces> :t comp
Tutorial.Interfaces.comp : Comp a => a -> a -> Ordering
```

The interesting part in the type signature of `comp` is
the initial `Comp a =>`. Here, `Comp` is a *constraint* on
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

Thus, we have defined the above utility functions once and for
all for every type with an implementation of interface `Comp`.

### Exercises

1. Implement function `anyLarger`, which should return `True`,
if and only if a list of values contains at least one element larger
than a given reference value. Use interface `Comp` in your
implementation.

2. Implement function `allLarger`, which should return `True`,
if and only if a list of values contains *only* elements larger
than a given reference value (this includes the empty list, where
this trivially holds). Use interface `Comp` in your
implementation.

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
Make sure to reflect the possibility of empty lists in your
return type.

## More About Interfaces


### Extending Interfaces

Some interfaces form a kind of hierarchy. For instance, for
the `Concat` interface used in exercise 4, there might
be a child interface called `Empty`, for those type,
which have a neutral element w.r.t. concatenation:

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

### Constrained Implementations

Sometimes it is only possible to implement an interface
for a given type, if parts of this type already implement
this interface as well. For instance, implementing interface `Comp`
for a `Maybe a` makes sense only if type `a` itself implements
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
compares the values stored in case of two `Just`s. This is
only possible, if there is a `Comp` implementation for
these values as well. Go ahead, and remove the `Comp a`
constrain from the above implementation. Learning to
read and understand Idris' type errors is important
for fixing them.

<!-- vi: filetype=idris2
-->
