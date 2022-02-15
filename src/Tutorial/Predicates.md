# Predicates

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

%default total
```

## Non-empty Lists

A very common function when working with lists or other
container types is to extract the first value in the sequence.
This function, however, cannot work in the general case, because
in order to extract a value from the list, the list must not
be empty. Here are a couple of ways to encode and implement
this, each with its own advantages and disadvantages:

* Wrap the result in a failure type, such as a `Maybe` or
  `Either e` with some custom error type `e`. This makes it
  immediately clear that the function might not be able to
  return a result. It is a natural way to deal with unvalidated
  input from unknown sources. The drawback of this approach is
  that results will carry the `Maybe` stain, even if we *know*
  that the *nil* case is impossible, for instance because we
  know the list argument at compile-time, or because we already
  *refined* the input value in such a way that we can be sure
  it is not empty.

* Define a new data type for non-empty lists and use this
  as the function's argument. This is the approach taken in
  module `Data.List1`. It allows us to return a pure value
  (meaning "not wrapped in a failure type" here), because the
  function cannot possibly fail, but it comes with the
  burden of reimplementing many of the utility functions and
  interfaces we already implemented for `List`. For a very common
  data structure, this might be an option, but for rare use cases
  it probably is too cumbersome.

* Use an index to keep track of the property we are interested
  in. This was the approach we took with type family `List01`,
  which we saw in several examples and exercises in this guide
  so far. This is also the approach taken with vectors,
  where we use the exact length as our index, which is even
  more expressive. While this allows us to implement many functions
  only once and with greater precision in the types, it
  also comes with the burden of keeping track of changes
  at the type level, making for more complex function types,
  and forcing us at times to return existentially quantified
  wrappers, because the outcome of a computation is not
  known at compile time.

* Fail with a runtime exception. This is a popular solution
  in many programming languages, but in Idris, we try to avoid
  this, because it breaks totality in a way, which also affects
  client code. Luckily, we can make use of our powerful and
  expressive type system to avoid this situation in general.

* Take an additional (possibly erased) argument of a type
  we can use as a witness that the input value is of the
  correct shape. This is the solution we will discuss in this
  chapter in great detail. It is an incredibly powerful way
  to talk about restrictions on values without having to
  replicate a lot of already existing functionality.

There is a time and place for most if not all of the solutions
listed above in Idris, but we will often turn to the last one and
refine function arguments with predicates.

<!-- vi: filetype=idris2
-->
