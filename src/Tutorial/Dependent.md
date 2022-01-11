# Dependent Types

The ability to calculate types from values, pass them as arguments
to functions, and return them as results from functions - in
short, being a dependently typed language - is one of the
most distinguishing features of Idris. Many of the more advanced
type level extensions of languages like Haskell can be treated
in one fell swoop by dependent types.

```idris
module Tutorial.Dependent

%default total
```

## Fighting Bugs with More Precise Types

Consider the following functions:

```idris
bogusMapList : (a -> b) -> List a -> List b
bogusMapList _ _ = []

bogusZipList : (a -> b -> c) -> List a -> List b -> List c
bogusZipList _ _ _ = []
```

The implementations type check, and still, they are obviously not
what users of our library would expect. In the first example, we'd expect
the implementation to apply the function argument to all values stored
in the list, without dropping any of them or changing their order.
The second is trickier: The two list arguments might be of different length.
What are we supposed when that's the case? Return a list of the same
length as the smaller of the two? Return an empty list? Or shouldn't
we in most use cases expect the two lists be of the same length?
How could we even describe such a precondition?

### Length Indexed Lists

The answer to the issues described above is of course: Dependent types.
And the most common introductory example is the *vector*: A list indexed
by its length:

```idris
data Vect : (len : Nat) -> (a : Type) -> Type where
  Nil  : Vect 0 a
  (::) : (x : a) -> (xs : Vect n a) -> Vect (S n) a
```

Before we move on, please compare this with the implementation of `Seq` in
the [section about algebraic data types](DataTypes.md). The constructors
are exactly the same: `Nil` and `(::)`. But there is an important difference:
`Vect`, unlike `Seq`, is not a function from `Type` to `Type`, it is
a function from `Nat` to `Type` to `Type`. Go ahead! Open the REPL and
verify this! The `Nat` argument (also called an *index*) describes
the *length* of the vector. `Nil` has type `Vect 0 a`: A vector of length
zero. *Cons* has type `a -> Vect n a -> Vect (S n) a`: It is exactly one
element longer than its second argument.

Let's experiment with this idea to gain a better understanding.
There is only one way to come up with a vector of length zero:

```idris
ex1 : Vect 0 Integer
ex1 = Nil
```

The following, on the other hand, leads to a type error (a pretty complicated
one, actually):

```repl
ex2 : Vect 0 Integer
ex2 = [12]
```

The problem: `[12]` gets desugared to `12 :: Nil`, but this has the wrong
type! Since `Nil` has type `Vect 0 Integer` here, `12 :: Nil` has type
`Vect (S 0) Integer`, which is identical to `Vect 1 Integer`. Idris verifies,
at compile time, that our vector is of the correct length!

```idris
ex3 : Vect 1 Integer
ex3 = [12]
```

So, we found a way to encode the *length* of a list-like data type in
its *type*, and it is a *type error* if the number of elements in
a vector does not agree with then length given in its type. We will
now see several use cases, where this additional piece of information
allows us to be more precise in our types.

### Length-preserving map

Function `bogusMapList` behaved unexpectedly, because it always
returned the empty list. With `Vect`, we need to be true to the
types here. If we map over a `Vect`, the argument *and* output type
contain a length index, and these length indices will tell us
*exactly*, if and how the length of our vectors are modified:

```idris
map3_1 : (a -> b) -> Vect 3 a -> Vect 1 b
map3_1 f [_,y,_] = [f y]

map5_0 : (a -> b) -> Vect 5 a -> Vect 0 b
map5_0 f _ = []

map5_10 : (a -> b) -> Vect 5 a -> Vect 10 b
map5_10 f [u,v,w,x,y] = [f u, f u, f v, f v, f w, f w, f x, f x, f y, f y]
```

While this *might* be interesting, it is not really useful, is it?
However, instead of using concrete lengths in type signatures,
we can also use *variables*:

```idris
mapVect' : (a -> b) -> Vect n a -> Vect n b
```

This type signature describes a length-preserving map. It is actually
more instructive, to include implicit arguments as well:

```idris
mapVect : {0 a,b : _} -> {0 n : Nat} -> (a -> b) -> Vect n a -> Vect n b
```

We ignore the two type parameters `a`, and `b`, as these just
describe a generic function (note, however, that we can group arguments
of the same type and quantity in a single pare of curly braces).
The implicit argument of type `Nat` however, tells us that the
input and output `Vect` are of the same length. It is a type error
to not uphold this contract. In order to implement `mapVect`, it
is very instructive to follow along and use some holes. In order
to get *any* information about the length of the `Vect` argument,
we need to pattern match on it:

```repl
mapVect _ Nil       = ?impl_0
mapVect f (x :: xs) = ?impl_1
```

At the REPL, we learn the following:

```repl
Tutorial.Dependent> :t impl_0
 0 a : Type
 0 b : Type
 0 n : Nat
------------------------------
impl_0 : Vect 0 b


Tutorial.Dependent> :t impl_1
 0 a : Type
 0 b : Type
   x : a
   xs : Vect n a
   f : a -> b
 0 n : Nat
------------------------------
impl_1 : Vect (S n) b
```

The first hole, `impl_0` is of type `Vect 0 b`. There is only one such
value, as discussed above:

```idris
mapVect _ Nil       = Nil
```

The second case is again more interesting. We note, that `xs` is
of type `Vect n a`, for an arbitrary length `n` (given as an erased
argument), while the result is of type `Vect (S n) b`. So, the
result has to be one element longer than `xs`. Luckily, we
have a value of type `a` (bound to variable `x`) and a function
from `a` to `b` (bound to variable `f`), so we can apply `f`
to `x` and prepend the result to a yet unknown remainder:

```repl
mapVect f (x :: xs) = f x :: ?rest
```

Let's inspect the new hole at the REPL:

```repl
Tutorial.Dependent> :t rest
 0 a : Type
 0 b : Type
   x : a
   xs : Vect n a
   f : a -> b
 0 n : Nat
------------------------------
rest : Vect n b
```

Now, we have a `Vect n a` and need a `Vect n b`, without knowing anything
else about `n`. We *could* learn more about `n` by pattern matching further
on `xs`, but this would quickly lead us down a rabbit hole, since after
such a pattern match, we'd end up with another `Nil` case and another
*cons* case, with a new tail of unknown length. Instead, we can invoke
`mapVect` recursively to convert the remainder (`xs`) to a `Vect n b`.
The type checker guarantees, that the lengths of `xs` and `mapVect f xs`,
are the same, so the whole expression type checks, and we are done:

```idris
mapVect f (x :: xs) = f x :: mapVect f xs
```

### Zipping Vectors

Let us now have a look at `bogusZipList`: We'd like to pairwise merge
two lists holding elements of (possibly) distinct types through a
given binary function. As discussed above, the most reasonable thing
to do, is to expect the two lists as well as the result to be of equal length.
With `Vect`, this can be done as follows:

```idris
zipWith : (a -> b -> c) -> Vect n a -> Vect n b -> Vect n c
zipWith f []        []         = Nil
zipWith f (x :: xs) (y :: ys)  = f x y :: zipWith f xs ys
```

Now, here is an interesting thing: The totality checker (activated
throughout this source file due to the initial `%default total` pragma),
accepts the above implementation as being total, although it is
missing two more cases. The reason why this works is, that Idris
can figure out on its own, that the other two cases are *impossible*.
From the pattern match on the first `Vect` argument, Idris learns
whether `n` is zero or the successor of another natural number. But
from this it can derive, whether the second vector, being of length `n`,
is a `Nil` or a *cons*. Still, it can be informative, to add the
impossible cases explicitly. We can use keyword `impossible` to
do so:

```idris
zipWith _ [] (_ :: _) impossible
zipWith _ (_ :: _) [] impossible
```

Let's give this a spin at the REPL:

```repl
Tutorial.Dependent> zipWith (*) [1,2,3] [10,20,30]
[10, 40, 90]
Tutorial.Dependent> zipWith (\x,y => x ++ ": " ++ show y) ["The answer"] [42]
["The answer: 42"]
Tutorial.Dependent> zipWith (*) [1,2,3] [10,20]
... Nasty type error ...
```

### Exercises

1. Implement function `head` for non-empty vectors:

   ```idris
   head : Vect (S n) a -> a
   ```

   Note, how we can describe non-emptiness by using a *pattern*
   in length of `Vect`. This rules out the `Nil` case, and we can
   return a value of type `a`, without having to wrap it in
   a `Maybe`! Make sure to add an `impossible` clause for the `Nil`
   case (although this is not strictly necessary here).

2. Using `head` as a reference, declare and implement function `tail`
   for non-empty vectors. The types should reflect, that the result
   is exactly one element shorter than the input.

3. Implement `zipWith3`. If possible, try to do so without looking at
   the implementation of `zipWith`:

   ```idris
   zipWith3 : (a -> b -> c -> d) -> Vect n a -> Vect n b -> Vect n c -> Vect n d

4. Declare and implement a function for accumulating the values stored
   in a list through `Semigroup`s append operator (`(<+>)`).

5. Do the same as in Exercise 4, but for non-empty vectors. How
   does a vector's non-emptyness affect the output type.

<!-- vi: filetype=idris2
-->
