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

## Length-Indexed Lists

The answer to the issues described above is of course: Dependent types.
Before we proceed to our example, first consider how Idris recursively
defines the natural numbers:

```idris
data Nat : Type where
  Z : Nat
  S : Nat -> Nat
```

In this scheme, 0 is represented by `Z`, 1 is represented by `S Z`, 2 is
represented by `S (S Z)`, and so on. Idris does this automatically so if you
enter `Z` or `S Z` into the REPL, it will return `0` or `1`. Note that the
only function inherently available to act on the natural numbers is our data
constructor `S`, which represents the successor function, i.e. adding 1.

Note that in Idris, every natural number can be represented as either a `Z` or
an `S n` where `n` is another natural number. Much like the fact that every
`List a` can be represented as either a `Nil` or an `x :: xs` (where `x` is
an `a` and `xs` is a `List a`), this informs our pattern matching when
solving problems.

Now we can consider the textbook introductory example of dependent types,
the *vector*, which is a list indexed by its length:

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

```idris
failing "Mismatch between: S ?n and 0."
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
terminology.

### Type Indices versus Type Parameters

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
*exactly*, if and how the lengths of our vectors are modified:

```idris
map3_1 : (a -> b) -> Vect 3 a -> Vect 1 b
map3_1 f [_,y,_] = [f y]

map5_0 : (a -> b) -> Vect 5 a -> Vect 0 b
map5_0 f _ = []

map5_10 : (a -> b) -> Vect 5 a -> Vect 10 b
map5_10 f [u,v,w,x,y] = [f u, f u, f v, f v, f w, f w, f x, f x, f y, f y]
```

While these examples are quite interesting,
they are not really useful, are they? That's because they are too
specialized. We'd like to have a *general* function for mapping
vectors of any length.
Instead of using concrete lengths in type signatures,
we can also use *variables* as already seen in the definition of `Vect`.
This allows us to declare the general case:

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
for us and the amount of things it can infer on its own when
things go well. When things don't go well, however, the
error messages we get from Idris can
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

If this happens, prefixing overloaded function names with
their namespaces can often simplify things, as Idris no
longer needs to disambiguate these functions:

```repl
Tutorial.Dependent> zipWith (*) (Dependent.(::) 1 Dependent.Nil) Dependent.Nil
Error: When unifying:
    Vect 0 ?c
and:
    Vect 1 ?c
Mismatch between: 0 and 1.
```

Here, the message is much clearer: Idris can't *unify* the lengths of the
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
of vectors by pattern matching on them. In the `Nil`
case, it was clear that the length is 0, while in the *cons*
case the length was the successor of another natural number.
This is not possible when we want to create a new vector:

```idris
failing "Mismatch between: S ?n and n."
  fill : a -> Vect n a
```

You will have a hard time implementing `fill`. The following,
for instance, leads to a type error:

```idris
  fill va = [va,va]
```

The problem is, that *the callers of our function decide about
the length of the resulting vector*. The full type of `fill` is
actually the following:

```idris
fill' : {0 a : Type} -> {0 n : Nat} -> a -> Vect n a
```

You can read this type as follows: For every type `a` and for
every natural number `n` (about which I know *nothing* at runtime,
since it has quantity zero), given a value of type `a`, I'll give
you a vector holding exactly `n` elements of type `a`. This is
like saying: "Think about a natural number `n`, and
I'll give you `n` apples without you telling me the value of `n`".
Idris is powerful, but it is not a clairvoyant.

In order to implement `fill`, we need to know what
`n` actually is: We need to pass `n` as an explicit, unerased argument, which
will allow us to pattern match on it and decide - based on this pattern
match - which constructors of `Vect` to use:

```idris
replicate : (n : Nat) -> a -> Vect n a
```

Now, `replicate` is a *dependent function type*: The output type
*depends* on the value of one of the arguments. It is straight forward
to implement `replicate` by pattern matching on `n`:

```idris
replicate 0     _  = []
replicate (S k) va = va :: replicate k va
```

This is a pattern that comes up often when working with
indexed types: We can learn about the values of the indices
by pattern matching on the values of the type family. However,
in order to return a value of the type family from a function,
we need to either know the values of the indices at compile
time (see constants `ex1` or `ex3`, for instance), or we
need to have access to the values of the indices at runtime, in
which case we can pattern match on them and learn from
this, which constructor(s) of the type family to use.

### Exercises part 1

1. Implement a function `len : List a -> Nat` for calculating the
   length of a `List`. For example, `len [1, 1, 1]` produces `3`.

2. Implement function `head` for non-empty vectors:

   ```idris
   head : Vect (S n) a -> a
   ```

   Note, how we can describe non-emptiness by using a *pattern*
   in the length of `Vect`. This rules out the `Nil` case, and we can
   return a value of type `a`, without having to wrap it in
   a `Maybe`! Make sure to add an `impossible` clause for the `Nil`
   case (although this is not strictly necessary here).

3. Using `head` as a reference, declare and implement function `tail`
   for non-empty vectors. The types should reflect that the output
   is exactly one element shorter than the input.

4. Implement `zipWith3`. If possible, try to doing so without looking at
   the implementation of `zipWith`:

   ```idris
   zipWith3 : (a -> b -> c -> d) -> Vect n a -> Vect n b -> Vect n c -> Vect n d
   ```

5. Declare and implement a function `foldSemi`
   for accumulating the values stored
   in a `List` through `Semigroup`s append operator (`(<+>)`).
   (Make sure to only use a `Semigroup` constraint, as opposed to
   a `Monoid` constraint.)

6. Do the same as in Exercise 4, but for non-empty vectors. How
   does a vector's non-emptiness affect the output type?

7. Given an initial value of type `a` and a function `a -> a`,
   we'd like to generate `Vect`s of `a`s, the first value of
   which is `a`, the second value being `f a`, the third
   being `f (f a)` and so on.

   For instance, if `a` is 1 and `f` is `(* 2)`, we'd like
   to get results similar to the following: `[1,2,4,8,16,...]`.

   Declare and implement function `iterate`, which should
   encapsulate this behavior. Get some inspiration from `replicate`
   if you don't know where to start.

8. Given an initial value of a state type `s` and
   a function `fun : s -> (s,a)`,
   we'd like to generate `Vect`s of `a`s. Declare and implement
   function `generate`, which should encapsulate this behavior. Make sure to use
   the updated state in every new invocation of `fun`.

   Here's an example how this can be used to generate the first
   `n` Fibonacci numbers:

   ```repl
   generate 10 (\(x,y) => let z = x + y in ((y,z),z)) (0,1)
   [1, 2, 3, 5, 8, 13, 21, 34, 55, 89]
   ```

9. Implement function `fromList`, which converts a list of
   values to a `Vect` of the same length. Use holes if you
   get stuck:

   ```idris
   fromList : (as : List a) -> Vect (length as) a
   ```

   Note how, in the type of `fromList`, we can *calculate* the
   length of the resulting vector by passing the list argument
   to function *length*.

10. Consider the following declarations:

   ```idris
   maybeSize : Maybe a -> Nat

   fromMaybe : (m : Maybe a) -> Vect (maybeSize m) a
   ```

   Choose a reasonable implementation for `maybeSize` and
   implement `fromMaybe` afterwards.

## `Fin`: Safe Indexing into Vectors

Consider function `index`, which tries to extract a value from
a `List` at the given position:

```idris
indexList : (pos : Nat) -> List a -> Maybe a
indexList _     []        = Nothing
indexList 0     (x :: _)  = Just x
indexList (S k) (_ :: xs) = indexList k xs
```

Now, here is a thing to consider when writing functions like `indexList`:
Do we want to express the possibility of failure in the output type,
or do we want to restrict the accepted arguments,
so the function can no longer fail? These are important design decisions,
especially in larger applications.
Returning a `Maybe` or `Either` from a function forces client code to eventually
deal with the `Nothing` or `Left` case, and until this happens, all intermediary
results will carry the `Maybe` or `Either` stain, which will make it more
cumbersome to run calculations with these intermediary results.
On the other hand, restricting the
values accepted as input will complicate the argument types
and will put the burden of input validation on our functions' callers,
(although, at compile time we can get help from Idris, as we will
see when we talk about auto implicits) while keeping the output pure and clean.

Languages without dependent types (like Haskell), can often only take
the route described above: To wrap the result in a `Maybe` or `Either`.
However, in Idris we can often *refine* the input types to restrict the
set of accepted values, thus ruling out the possibility of failure.

Assume, as an example, we'd like to extract a value from a `Vect n a`
at (zero-based) index `k`. Surely, this can succeed if and only if
`k` is a natural number strictly smaller than the length `n` of
the vector. Luckily, we can express this precondition in an indexed
type:

```idris
data Fin : (n : Nat) -> Type where
  FZ : {0 n : Nat} -> Fin (S n)
  FS : (k : Fin n) -> Fin (S n)
```

`Fin n` is the type of natural numbers strictly smaller than `n`.
It is defined inductively: `FZ` corresponds to natural number *zero*,
which, as can be seen in its type, is strictly smaller than
`S n` for any natural number `n`. `FS` is the inductive case:
If `k` is strictly smaller than `n` (`k` being of type `Fin n`),
then `FS k` is strictly smaller than `S n`.

Let's come up with some values of type `Fin`:

```idris
fin0_5 : Fin 5
fin0_5 = FZ

fin0_7 : Fin 7
fin0_7 = FZ

fin1_3 : Fin 3
fin1_3 = FS FZ

fin4_5 : Fin 5
fin4_5 = FS (FS (FS (FS FZ)))
```

Note, that there is no value of type `Fin 0`. We will learn
in a later session, how to express "there is no value of type `x`"
in a type.

Let us now check, whether we can use `Fin` to safely index
into a `Vect`:

```idris
index : Fin n -> Vect n a -> a
```

Before you continue, try to implement `index` yourself, making use
of holes if you get stuck.

```idris
index FZ     (x :: _) = x
index (FS k) (_ :: xs) = index k xs
```

Note, how there is no `Nil` case and the totality checker is still
happy. That's because `Nil` is of type `Vect 0 a`, but there is no
value of type `Fin 0`! We can verify this by adding the missing
impossible clauses:

```idris
index FZ     Nil impossible
index (FS _) Nil impossible
```

### Exercises part 2

1. Implement function `update`, which, given a function of
   type `a -> a`, updates the value in a`Vect n a` at position `k < n`.

2. Implement function `insert`, which inserts a value of type `a`
   at position `k <= n` in a `Vect n a`. Note, that `k` is the
   index of the freshly inserted value, so that the following holds:

   ```repl
   index k (insert k v vs) = v
   ```

3. Implement function `delete`, which deletes a value from a
   vector at the given index.

   This is trickier than Exercises 1 and 2, as we have to properly
   encode in the types that the vector is getting one element shorter.

4. We can use `Fin` to implement safe indexing into `List`s as well. Try to
   come up with a type and implementation for `safeIndexList`.

   Note: If you don't know how to start, look at the type of `fromList`
   for some inspiration. You might also need give the arguments in
   a different order than for `index`.

5. Implement function `finToNat`, which converts a `Fin n` to the
   corresponding natural number, and use this to declare and
   implement function `take` for splitting of the first `k`
   elements of a `Vect n a` with `k <= n`.

6. Implement function `minus` for subtracting a value `k` from
   a natural number `n` with `k <= n`.

7. Use `minus` from Exercise 6 to declare and implement function
   `drop`, for dropping the first `k` values from a `Vect n a`,
   with `k <= n`.

8. Implement function `splitAt` for splitting a `Vect n a` at
   position `k <= n`, returning the prefix and suffix of the
   vector wrapped in a pair.

   Hint: Use `take` and `drop` in your implementation.

Hint: Since `Fin n` consists of the values strictly smaller
than `n`, `Fin (S n)` consists of the values smaller than
or equal to `n`.

Note: Functions `take`, `drop`, and `splitAt`, while correct and
provably total, are rather cumbersome to type.
There is an alternative way to declare their types,
as we will see in the next section.

## Compile-Time Computations

In the last section - especially in some of the exercises - we
started more and more to use compile time computations to
describe the types of our functions and values.
This is a very powerful concept, as it allows us to
compute output types from input types. Here's an example:

It is possible to concatenate two `List`s with the `(++)`
operator. Surely, this should also be possible for
`Vect`. But `Vect` is indexed by its length, so we have
to reflect in the types exactly how the lengths of the
inputs affect the lengths of the output. Here's how to
do this:

```idris
(++) : Vect m a -> Vect n a -> Vect (m + n) a
(++) []        ys = ys
(++) (x :: xs) ys = x :: (xs ++ ys)
```

Note, how we keep track of the lengths at the type-level, again
ruling out certain common programming errors like inadvertently dropping
some values.

We can also use type-level computations as patterns
on the input types. Here is an alternative type and implementation
for `drop`, which you implemented in the exercises by
using a `Fin n` argument:

```idris
drop' : (m : Nat) -> Vect (m + n) a -> Vect n a
drop' 0     xs        = xs
drop' (S k) (_ :: xs) = drop' k xs
```

Note that changing the order from `(m + n)` to `(n + m)`
in the second parameter will cause an error at the second `xs`:

```repl
While processing right hand side of drop'. Can't solve constraint between: plus n 0 and n.
```

You will learn why in the next section.

### Limitations

After all the examples and exercises in this section
you might have come to the conclusion that we can
use arbitrary expressions in the types and Idris
will happily evaluate and unify all of them for us.

I'm afraid that's not even close to the truth. The examples
in this section were hand-picked because they are known
to *just work*. The reason being, that there was always
a direct link between our own pattern matches and the
implementations of functions we used at compile time.

For instance, here is the implementation of addition of
natural numbers:

```idris
add : Nat -> Nat -> Nat
add Z     n = n
add (S k) n = S $ add k n
```

As you can see, `add` is implemented via a pattern match
on its *first* argument, while the second argument is never
inspected. Note, how this is exactly how `(++)` for `Vect`
is implemented: There, we also pattern match on the first
argument, returning the second unmodified in the `Nil`
case, and prepending the head to the result of appending
the tail in the *cons* case. Since there is a direct
correspondence between the two pattern matches, it
is possible for Idris to unify `0 + n` with `n` in the
`Nil` case, and `(S k) + n` with `S (k + n)` in the
*cons* case.

Here is a simple example, where Idris will not longer
be convinced without some help from us:

```idris
failing "Can't solve constraint"
  reverse : Vect n a -> Vect n a
  reverse []        = []
  reverse (x :: xs) = reverse xs ++ [x]
```

When we type-check the above,
Idris will fail with the following error message:
"Can't solve constraint between: plus n 1 and S n."
Here's what's going on: From the pattern match on the
left hand side, Idris knows that the length of the
vector is `S n`, for some natural number `n`
corresponding to the length of `xs`. The length
of the vector on the right hand side is `n + 1`,
according to the type of `(++)` and the lengths
of `xs` and `[x]`. Overloaded operator `(+)`
is implemented via function `Prelude.plus`, that's
why Idris replaces `(+)` with `plus` in the error message.

As you can see from the above, Idris can't verify on
its own that `1 + n` is the same thing as `n + 1`.
It can accept some help from us, though. If we come
up with a *proof* that the above equality holds
(or - more generally - that our implementation of
addition for natural numbers is *commutative*),
we can use this proof to *rewrite* the types on
the right hand side of `reverse`. Writing proofs and
using `rewrite` will require some in-depth explanations
and examples. Therefore, these things will have to wait
until another chapter.

### Unrestricted Implicits

In functions like `replicate`, we pass a natural number `n`
as an explicit, unrestricted argument from which we infer
the length of the vector to return.
In some circumstances, `n` can be inferred from the context.
For instance, in the following example it is tedious to
pass `n` explicitly:

```idris
ex4 : Vect 3 Integer
ex4 = zipWith (*) (replicate 3 10) (replicate 3 11)
```

The value `n` is clearly derivable from the context, which
can be confirmed by replacing it with underscores:

```idris
ex5 : Vect 3 Integer
ex5 = zipWith (*) (replicate _ 10) (replicate _ 11)
```

We therefore can implement an alternative version of `replicate`,
where we pass `n` as an implicit argument of *unrestricted*
quantity:

```idris
replicate' : {n : _} -> a -> Vect n a
replicate' = replicate n
```

Note how, in the implementation of `replicate'`, we can refer to `n`
and pass it as an explicit argument to `replicate`.

Deciding whether to pass potentially inferable arguments to a function implicitly
or explicitly is a question of how often the arguments actually *are* inferable
by Idris. Sometimes it might even be useful to have both versions
of a function. Remember, however, that even in case of an implicit argument
we can still pass the value explicitly:

```idris
ex6 : Vect ? Bool
ex6 = replicate' {n = 2} True
```

In the type signature above, the question mark (`?`) means, that Idris
should try and figure out the value on its own by unification. This
forces us to specify `n` explicitly on the right hand side of `ex6`.

#### Pattern Matching on Implicits

The implementation of `replicate'` makes use of function `replicate`,
where we could pattern match on the explicit argument `n`. However, it
is also possible to pattern match on implicit, named arguments of
non-zero quantity:

```idris
replicate'' : {n : _} -> a -> Vect n a
replicate'' {n = Z}   _ = Nil
replicate'' {n = S _} v = v :: replicate'' v
```

### Exercises part 3

1. Here is a function declaration for flattening a `List` of `List`s:

   ```idris
   flattenList : List (List a) -> List a
   ```

   Implement `flattenList` and declare and implement a similar
   function `flattenVect` for flattening vectors of vectors.

2. Implement functions `take'` and `splitAt'` like in
   the exercises of the previous section but using the
   technique shown for `drop'`.

3. Implement function `transpose` for converting an
   `m x n`-matrix (represented as a `Vect m (Vect n a)`)
   to an `n x m`-matrix.

   Note: This might be a challenging exercise, but make sure
   to give it a try. As usual, make use of holes if you get stuck!

   Here is an example how this should work in action:

   ```repl
   Solutions.Dependent> transpose [[1,2,3],[4,5,6]]
   [[1, 4], [2, 5], [3, 6]]
   ```

## Conclusion

* Dependent types allow us to calculate types from values.
  This makes it possible to encode properties of values
  at the type-level and verify these properties at compile
  time.

* Length-indexed lists (vectors) let us rule out certain implementation
  errors, by forcing us to be precise about the lengths of input
  and output vectors.

* We can use patterns in type signatures, for instance to
  express that the length of a vector is non-zero and therefore,
  the vector is non-empty.

* When creating values of a type family, the values of the indices
  need to be known at compile time, or they need to be passed as
  arguments to the function creating the values, where we can
  pattern match on them to figure out, which constructors to use.

* We can use `Fin n`, the type of natural numbers strictly smaller
  than `n`, to safely index into a vector of length `n`.

* Sometimes, it is convenient to pass inferable arguments as
  non-erased implicits, in which case we can still inspect them
  by pattern matching or pass them to other functions, while Idris
  will try and fill in the values for us.

Note, that data type `Vect` together with many of the functions we
implemented here is available from module `Data.Vect` from the *base*
library. Likewise, `Fin` is available from `Data.Fin` from *base*.

### What's next

In the [next section](IO.md), it is time to learn how to write effectful programs
and how to do this while still staying *pure*.

<!-- vi: filetype=idris2:syntax=markdown
-->
