# Dependent Types

The ability to calculate types from values, pass them as arguments
to functions, and return them as results from functions - in
short, being a dependently typed language - is one of the
most distinguishing features of Idris. Many of the more advanced
type level extensions of languages like Haskell (and quite a
bit more) can be treated in one fell swoop with dependent types.

```idris
module Tutorial.Dependent

%default total
```

## Fighting Bugs with Precise Types

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
What are we supposed to do when that's the case? Return a list of the same
length as the smaller of the two? Return an empty list? Or shouldn't
we in most use cases expect the two lists to be of the same length?
How could we even describe such a precondition?

### Length-Indexed Lists

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
`Vect`, unlike `Seq` or `List`, is not a function from `Type` to `Type`, it is
a function from `Nat` to `Type` to `Type`. Go ahead! Open the REPL and
verify this! The `Nat` argument (also called an *index*) represents
the *length* of the vector here.
`Nil` has type `Vect 0 a`: A vector of length
zero. *Cons* has type `a -> Vect n a -> Vect (S n) a`: It is exactly one
element longer (`S n`) than its second argument, which is of length `n`.

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

So, we found a way to encode the *length* of a list-like data structure in
its *type*, and it is a *type error* if the number of elements in
a vector does not agree with then length given in its type. We will
shortly see several use cases, where this additional piece of information
allows us to be more precise in the types and rule out additional
programming mistakes. But first, we need to quickly clarify some
jargon.

#### Type Indices versus Type Parameters

`Vect` is not only a generic type, parameterized over the type
of elements it holds, it is actually a *family of types*, each
of them associated with a natural number representing it's
length. We also say, the type family `Vect` is *indexed* by
its length.

The difference between a type parameter and an index is, that
the latter can and does change across data constructors, while
the former is the same for all data constructors. Or, put differently,
we can learn about the *value* of an index by pattern matching
on a *value* of the type family, while this is not possible
with a type parameter.

Let's demonstrate this with a contrived example:

```idris
data Indexed : Nat -> Type where
  I0 : Indexed 0
  I3 : Indexed 3
  I4 : String -> Indexed 4
```

Here, `Indexed` is indexed over its `Nat` argument, as
values of the index changes across constructors (I chose some
arbitrary value for each constructor), and we
can learn about these values by pattern matching on `Indexed` values.
We can use this, for instance, to create a `Vect` of the same length
as the index of `Indexed`:

```idris
fromIndexed : Indexed n -> a -> Vect n a
```

Go ahead, and try implementing this yourself! Work with
holes, pattern match on the `Indexed` argument, and
learn about the expected output type in each case by
inspecting the holes and their context.

Here is my implementation:

```idris
fromIndexed I0     va = []
fromIndexed I3     va = [va, va, va]
fromIndexed (I4 _) va = [va, va, va, va]
```

As you can see, by pattern matching on the value of the
`Indexed n` argument, we learned about the value of
the `n` index itself, which was necessary to return a
`Vect` of the correct length.

### Length-Preserving `map`

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

While these examples are quite interesting,
they are not really useful, are they? This is, because they are too
specialized. We'd like to have a *general* function for mapping
vectors of any length.
Instead of using concrete lengths in type signatures,
we can also use *variables* as already seen in the definition of `Vect`.
This allows us declare the general case:

```idris
mapVect' : (a -> b) -> Vect n a -> Vect n b
```

This type describes a length-preserving map. It is actually
more instructive (but not necessary) to include the
implicit arguments as well:

```idris
mapVect : {0 a,b : _} -> {0 n : Nat} -> (a -> b) -> Vect n a -> Vect n b
```

We ignore the two type parameters `a`, and `b`, as these just
describe a generic function (note, however, that we can group arguments
of the same type and quantity in a single pair of curly braces; this
is optional, but it sometimes helps making type signatures a bit
shorter). The implicit argument of type `Nat`, however, tells us that the
input and output `Vect` are of the same length. It is a type error
to not uphold to this contract. When implementing `mapVect`, it
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
result has to be one element longer than `xs`. Luckily, we already
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
The type checker guarantees, that the lengths of `xs` and `mapVect f xs`
are the same, so the whole expression type checks and we are done:

```idris
mapVect f (x :: xs) = f x :: mapVect f xs
```

### Zipping Vectors

Let us now have a look at `bogusZipList`: We'd like to pairwise merge
two lists holding elements of (possibly) distinct types through a
given binary function. As discussed above, the most reasonable thing
to do is to expect the two lists as well as the result to be of equal length.
With `Vect`, this can be expressed and implemented as follows:

```idris
zipWith : (a -> b -> c) -> Vect n a -> Vect n b -> Vect n c
zipWith f []        []         = Nil
zipWith f (x :: xs) (y :: ys)  = f x y :: zipWith f xs ys
```

Now, here is an interesting thing: The totality checker (activated
throughout this source file due to the initial `%default total` pragma)
accepts the above implementation as being total, although it is
missing two more cases. This works, because Idris
can figure out on its own, that the other two cases are *impossible*.
From the pattern match on the first `Vect` argument, Idris learns
whether `n` is zero or the successor of another natural number. But
from this it can derive, whether the second vector, being also
of length `n`, is a `Nil` or a *cons*. Still, it can be informative to add the
impossible cases explicitly. We can use keyword `impossible` to
do so:

```idris
zipWith _ [] (_ :: _) impossible
zipWith _ (_ :: _) [] impossible
```

It is - of course - a type error to annotate a case in a pattern
match with `impossible`, if Idris cannot verify that this case is
indeed impossible. We will learn in a later section what to do,
when we think we are right about an impossible case
and Idris is not.

Let's give `zipWith` a spin at the REPL:

```repl
Tutorial.Dependent> zipWith (*) [1,2,3] [10,20,30]
[10, 40, 90]
Tutorial.Dependent> zipWith (\x,y => x ++ ": " ++ show y) ["The answer"] [42]
["The answer: 42"]
Tutorial.Dependent> zipWith (*) [1,2,3] [10,20]
... Nasty type error ...
```

#### Simplifying Type Errors

It is amazing to experience the amount of work Idris can do
for use and the amount of things it can infer on its own when
things go well. When things don't go well, however, the
errors messages we get from Idris can
be quite long and hard to understand, especially
for programmers new to the language. For instance, the error
message in the last REPL example above was pretty long, listing
different things Idris tried to do together with the reason
why each of them failed.

If this happens, it often means that a combination of a type error
and an ambiguity resulting from overloaded function names is
at work. In the example above, the two vectors are of distinct
length, which leads to a type error if we interpret the list
literals as vectors. However, list literals are overloaded to work
with all data types with constructors `Nil` and `(::)`, so Idris
will now try other data constructors than those of `Vect` (the
ones of `List` and `Stream` from the *Prelude* in this case),
each of which will again fail with a type error since `zipWith`
expects arguments of type `Vect`, and neither `List` nor `Stream`
will work.

If this happens, it can often simplify things, if we help Idris
disambiguate overloaded function names by prefixing them with
their namespace:

```repl
Tutorial.Dependent> zipWith (*) (Dependent.(::) 1 Dependent.Nil) Dependent.Nil
Error: When unifying:
    Vect 0 ?c
and:
    Vect 1 ?c
Mismatch between: 0 and 1.
```

Here, the message is much clearer: Idris can't *unify* the length of the
two vectors. *Unification* means: Idris tries to at compile time convert
two expressions to the same normal form. If this succeeds,
the two expressions are considered to be equivalent,
if it doesn't, Idris fails with a unification error.

As an alternative to prefixing overloaded functions with their
namespace, we can use `the` to help with type inference:

```repl
Tutorial.Dependent> zipWith (*) (the (Vect 3 _) [1,2,3]) (the (Vect 2 _) [10,20])
Error: When unifying:
    Vect 2 ?c
and:
    Vect 3 ?c
Mismatch between: 0 and 1.
```

It is interesting to note, that the error above is not "Mismatch between: 2 and 3"
but "Mismatch between: 0 and 1" instead. Here's what's going on: Idris tries to
unify integer literals `2` and `3`, which are first converted to the
corresponding `Nat` values `S (S Z)` and `S (S (S Z))`, respectively.
The two patterns match until we arrive at `Z` vs `S Z`, corresponding
to values `0` and `1`, which is the discrepancy reported in the error message.

### Creating Vectors

So far, we were able to learn something about the lengths
of our vectors by pattern matching on them. In the `Nil`
case, it was clear that the length is 0, while in the *cons*
case the length was the successor of another natural number.
This is not possible, when we want to create a new vector:

```idris
fill : a -> Vect n a
```

You will have a hard time implementing `fill`. The following,
for instance, leads to a type error:

```repl
fill va = [va,va]
```

The problem is, that the callers of our function decide on
the length of the resulting vector. The following type checks
perfectly fine:

```idris
vect10 : Vect 10 Char
vect10 = fill 'a'
```

However, in order to implement `fill`, we need to know what
`n` actually is. But this is impossible, since right now,
`n` is an erased implicit argument. But this also the
solution: We need to pass `n` as an explicit argument, which
will allow us to pattern match on it:

```idris
replicate : (n : Nat) -> a -> Vect n a
```

Now, `replicate` is a *dependent function type*: The output type
*depends* on the value of one the arguments. It is now possible to
implement `replicate` by pattern matching on `n`:

```idris
replicate 0     _  = []
replicate (S k) va = va :: replicate k va
```

This is a pattern that comes up often when working with
indexed types: We can learn about the values of indices
by pattern matching on a value of the type family. However,
in order to come up with a value of the type family, we
need to either know the values of the indices at compile
time (see constants `ex1` or `ex3`, for instance), or we
need to have access to the values of the indices, in
which case we can pattern match on them a learn from
this, which constructor of the type family to use.

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

6. Given an initial value of type `a` and a function `a -> a`,
   we'd like to generate `Vect`s of `a`s, the first value of
   which is `a`, the second value being `f a`, the third
   being `f (f a)`.

   For instance, if `a` is 1 and `f` is `(* 2)`, we'd like
   to get results similar to the following: `[1,2,4,8,16,...]`.

   Declare and implement function `iterate`, which should
   encapsulate this behavior. Get some inspiration from `replicate`
   if don't know where to start.

7. Given an initial value of a state type `s` and
   a function `fun : s -> (s,a)`,
   we'd like to generate `Vect`s of `a`s. Declare and implement
   function `generate` to encapsulate this behavior. Make sure to use
   the updated state in every new invocation of `fun`.

8. Implement function `fromList`, which converts a list of
   values to a `Vect` of the same length. Use holes if you
   get stuck:

   ```idris
   fromList : (as : List a) -> Vect (length as) a
   ```

   Note, how in the type of `fromList`, we can *calculate* the
   length of the resulting vector, by passing the list argument
   to function *length*.

9. Consider the following declarations:

   ```idris
   maybeSize : Maybe a -> Nat

   fromMaybe : (m : Maybe a) -> Vect (maybeSize m) a
   ```

   Choose a reasonable implementation for `maybeSize` and
   implement `fromMaybe` afterwards.

<!-- vi: filetype=idris2
-->