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

import Data.Vect

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
  that results will carry the `Maybe` stain, even if we *know*
  that the *nil* case is impossible, for instance because we
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
data NonEmpty : (as : List a) -> Type where
  IsNonEmpty : NonEmpty (h :: t)
```

This is a single-value data type, so we can always use it
as an erased function argument and still pattern match on
it. We can now use this to implement a safe and pure `head`
function:

```idris
head1 : (as : List a) -> (0 _ : NonEmpty as) -> a
head1 (h :: _) _ = h
head1 [] IsNonEmpty impossible
```

Note, how value `IsNonEmpty` is a *witness* that its index,
which corresponds to our list argument, is indeed non-empty,
because this is what we specified in its type.
The impossible case in the implementation of `head1` is not
strictly necessary here. It was given above for completeness.

We call `NonEmpty` a *predicate* on lists, as it restricts
the values allowed in the index. We can express a function's
preconditions by adding additional (possibly erased) predicates
to the function's list of arguments.

The first really cool thing is how we can safely use `head1`,
if we can at compile-time show that our list argument is
indeed non-empty:

```idris
headEx1 : Nat
headEx1 = head1 [1,2,3] IsNonEmpty
```

It is a bit cumbersome that we have to pass the `IsNonEmpty` proof
manually. Before we scratch that itch, we will first discuss what
to do with lists, the values of which are not known until
runtime. For these cases, we write what we call a *covering
function*: A function, which tries to construct a proof of
the desired type by pattern matching on the indexed value(s).
In the most simple case, we can wrap the proof in a `Maybe`,
but if we'd like to have stronger guarantees about the
correctness of our covering function, we wrap the proof
in a `Dec`:

```idris
Uninhabited (NonEmpty []) where
  uninhabited IsNonEmpty impossible

nonEmpty : (as : List a) -> Dec (NonEmpty as)
nonEmpty (x :: xs) = Yes IsNonEmpty
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
use. Idris allows us to define implicit function arguments,
the values of which it tries to assemble on its own by
means of a technique called *proof search*. This is not
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

However, in the following example, the value of `n` can't
be inferred, as the intermediary vector is immediately converted
to a list of unknown length. Although Idris could try and insert
any value for `n` here, it won't do so, because it can't be
sure that this is the length we want. We therefore have to pass the
length explicitly:

```idris
replicateEx2 : List Nat
replicateEx2 = toList $ replicate' {n = 17} 12
```

Note, how the *value* of `n` had to be inferable in
these examples, which means it had to make an appearance
in the surrounding context. With auto implicit arguments,
this works differently. Here is the `head` example, this
time with an auto implicit:

```idris
head : (as : List a) -> {auto 0 prf : NonEmpty as} -> a
head (x :: _) = x
head [] impossible
```

Note the `auto` keyword before the quantity of implicit argument
`prf`. This means, we want Idris to construct this value
on its own, without it being visible in the surrounding context.
In order to do so, Idris will try and build such a value from
the data type's constructors. If it succeeds, this value will
then be automatically filled in as the desired argument, otherwise,
Idris will fail with type error.

Let's see this in action:

```idris
headEx3 : Nat
headEx3 = head [1,2,3]
```

The following example fails with an error:

```repl
Tutorial.Predicates> head []
Error: Can't find an implementation for NonEmpty [].

(Interactive):1:1--1:8
 1 | head []
     ^^^^^^^
```

Wait! "Can't find an implementation for..."? Is this not the
error message we get for missing interface implementations?
That's correct, and I'll show you that interface resolution
is just proof search at the end of this chapter.

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

3. Implement functions for return the largest and smallest
   element in a list.

4. Define a predicate for strictly positive natural numbers
   and use it to implement a safe and provably total division
   function on natural numbers.

5. Define a predicate for a non-empty `Maybe` and use it to
   safely extract the value stored in a `Just`. Implement
   also a decidable covering function.

6. Define and implement functions for safely extracting values
   from a `Left` and a `Right` by using suitable predicates.
   Implement also decidable covering functions.

The predicates you implemented in these exercises are already
available in the *base* library: `Data.List.NonEmpty`,
`Data.Maybe.IsJust`, `Data.Either.IsLeft`, `Data.Either.IsRight`,
and `Data.Nat.IsSucc`.

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
control over the types and values of our fields.

<!-- vi: filetype=idris2
-->
