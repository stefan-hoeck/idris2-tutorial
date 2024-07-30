# A Deep Dive into Quantitative Type Theory

*This section was guest-written by [Kiana Sheibani](https://github.com/kiana-S).*

In the tutorial proper, when discussing functions, Idris 2's quantity
system was introduced. The description was intentionally a bit
simplified - the inner workings of quantities are complicated, and
that complication would have only confused any newcomers to Idris 2.

Here, I'll provide a more proper and thorough treatment of
Quantitative Type Theory (QTT), including how quantity checking is
performed and the theory behind it. Most of the information here will
be unnecessary for understanding and writing Idris programs, and you
are free to keep thinking about quantities like they were explained
before. When working with quantities in their full complexity,
however, a better understanding of how they work can be helpful to
avoid misconceptions.

## The Quantity Semiring

Quantitative Type Theory, as you probably already know, uses a set of
quantities. The core theory allows for any quantities to be used, but
Idris 2 in particular has three: erased, linear, and unrestricted.
These are usually written as `0`, `1`, and `ω` (the Greek lowercase
omega) respectively.

As QTT requires, these three quantities are equipped with the
structure of an *ordered semiring*. The exact mathematical details of
what that means aren't important; what it means for us is that
quantities can be added and multiplied together, and that there is an
ordering relation on them. Here are the tables for each of these
operations, where the first argument is on the left and the second is
on the top:

**Addition**

| `+`     | `0` | `1` | `ω` |
|:-------:|:---:|:---:|:---:|
| **`0`** | `0` | `1` | `ω` |
| **`1`** | `1` | `ω` | `ω` |
| **`ω`** | `ω` | `ω` | `ω` |

**Multiplication**

| `*`     | `0` | `1` | `ω` |
|:-------:|:---:|:---:|:---:|
| **`0`** | `0` | `0` | `0` |
| **`1`** | `0` | `1` | `ω` |
| **`ω`** | `0` | `ω` | `ω` |

**Order**

| `≤`     | `0`   | `1`   | `ω`  |
|:-------:|:-----:|:-----:|:----:|
| **`0`** | true  | false | true |
| **`1`** | false | true  | true |
| **`ω`** | false | false | true |

These operations behave mostly how you might expect, with `0` and `1`
being the usual numbers and `ω` being a sort of "infinity" value. (We
have `1 + 1 = ω` instead of `2` because there isn't a `2` quantity in
our system.)

There is one big difference in our ordering, though: `0 ≤ 1` is false!
We have that `0 ≤ ω` and `1 ≤ ω`, but not `0 ≤ 1`, or `1 ≤ 0` for that
matter. In the language of mathematics, we say that `0` and `1` are
*incomparable*. We'll get into why this is the case later, when we
talk about what these operations mean and how they're used.

## Variables and Contexts

In QTT, each variable in each context has an associated quantity.
These quantities can be plainly seen when inspecting holes in the
REPL. Here's an example from the tutorial:

```repl
 0 b : Type
 0 a : Type
   xs : List a
   f : a -> b
   x : a
   prf : length xs = length (map f xs)
------------------------------
mll1 : S (length xs) = S (length (map f xs))
```

In this hole's context, The type variables `a` and `b` have `0`
quantity, while the others have `ω` quantity.

Since the context is what stores quantities, only names that appear in
the context can have a quantity, including:

- Function/lambda parameters
- Pattern matching bindings
- `let` bindings

These do not appear in the context, and thus do NOT have quantities:

- Top-level definitions
- `where` definitions
- All non-variable expressions

### A Change in Perspective

When writing Idris programs using holes, we tend to use a
top-to-bottom approach: we start with looking at the context for the
whole function, and then we look at smaller and smaller
sub-expressions as we fill in the code. This means that quantities in
the context tend to decrease over time - if the variable `x` has
quantity `1` and you use it once, the quantity will decrease to `0`.

When looking at how typechecking works, however, it's more natural to
look at contexts in the other direction, from smaller sub-expressions
to larger ones. This means that the quantities we're looking at will
tend to increase instead. As an example, let's look at this simple
function:

```idris
square : Num a => a -> a
square x = x * x
```

Let's first look at the context for the smallest sub-expression of
this function, just the variable `x`:

```repl
 0 a : Type
 1 x : a
------------------------------
x : a
```

Now let's look at the context for the larger expression `x * x`:

```repl
 0 a : Type
   x : a
------------------------------
(x * x) : a
```

The quantity of the parameter `x` increased from `1` to `ω`, since we
went from using it once to using it multiple times. When looking at
expressions like this, we can think of the quantity `q` as saying that
the variable is "used `q` times" in the expression.

## Quantity Checking

With all of that background information established, we can finally
see how quantity checking actually works. Let's follow what happens to
a single variable `x` in our context as we perform different
operations.

To illustrate how quantities evolve, I will provide Idris-style
context diagrams showing the various cases. In these, capital-letter
names `T`, `E`, etc. stand for any expression, and `q`, `r`, etc.
stand for any quantity.

### Variables and Literals

```repl
 1 x : T
------------------------------
x : T
```

In the simplest case, an expression is just a single variable. That
variable will have quantity `1` in the context, while all others have
quantity `0`. (Other variables may also be missing entirely, which for
quantity checking is equivalent to them having `0` quantity.)

```repl
 0 x : T
------------------------------
True : Bool
```

For literals such as `1`, or constructors such as `True`, all
variables in the context have quantity 0, since all variables are used
0 times in a constructor.

### Function Application

```repl
 qf x : T
------------------------------
F : (r _ : A) -> B

 qe x : T
------------------------------
E : A

 (qf + r*qe) x : T
------------------------------
(F E) : B
```

This is the most complicated of QTT's rules. We have a function `F`
whose parameter has `r` quantity, and we're applying it to `E`. If our
variable `x` is used `qf` times in `F` and `qe` times in `E`, then it
is used `qf + r*qe` times in the full expression.

To better understand this rule, let's look at some simpler cases.
First, let's assume that `x` is not used in the function `F`, so that
`qf = 0`. Then, `x`'s full quantity is `r * qe`. For example, let's
look at these two functions:

```idris
f x = id x

g x = id 1
```

Here, `id` has type `a -> a`, where its input is unrestricted (`ω`).
In the first function, we can see that `x` is used once in the input
of `id`, so the quantity of `x` in the whole expression is `ω * 1 = ω`.
In the second function, `x` is used zero times in the input of
`id`, so its quantity in the whole expression is `ω * 0 = 0`. The
function `g` will typecheck if you mark its input as erased, but not
`f`.

As another simplified case, let's assume that `F` is a linear
function, meaning that `r = 1`. Then `x`'s full quantity is `qf + qe`,
the simple sum of the quantities of each part. Here's a function that
demonstrates this:

```idris
ldup x = (#) x x
```

The linear pair constructor `(#)` is linear in both arguments, so to
find the quantity of `x` in the full expression we can just add up the
quantities in each part. `x` is used zero times in `(#)` and one time
in `x`, so the total quantity is `0 + 1 + 1 = ω`. If the second `x`
were replaced by something else, like a literal, the quantity would
only be `0 + 1 + 0 = 1`. Intuitively, you can think of these as
"parallel expressions", and the addition operation tells you how
quantities combine in parallel.

### Subusaging

```repl
 q x : T
------------------------------
E : T'

(q ≤ r)

 r x : T
------------------------------
E : T'
```

This rule is where the order relation on quantities comes in. It
allows us to convert a quantity in our context to another one, given
that the new context is greater than or equal to the old one. Type
theorists call this *subusaging*, as it lets us use variables less
often than we claim in our types.

Subusaging is why this function definition is allowed:

```idris
ignore : a -> Int
ignore x = 42
```

The input `x` is used zero times, which would normally mean its
quantity would have to be `0`; however, since `0 ≤ ω`, we can use
subusaging to increase the quantity to `ω`.

This also explains the mysterious fact we pointed out earlier, that
`0 ≰ 1` in our quantity ordering. If it were true that `0 ≤ 1`, then we
could also increase the quantity of `x` from `0` to `1`:

```idris
ignoreLinear : (1 x : a) -> Int
ignoreLinear x = 42
```

This would mean that the quantity `1` would be for variables used *at
most* once, rather than *exactly* once. Idris's designers decided that
they wanted linearity to have the second meaning, not the first.

### Lambdas and Other Bindings

```repl
 q x : A
------------------------------
E : B

(\q x => E) : (q x : A) -> B
```

This rule is the most important, as it is the only one in which
quantities actually impact typechecking. It is also one of the most
straightforward: a lambda expression `\q x => E` is only valid if `x`
is used `q` times inside `E`. This rule doesn't only apply to lambdas,
actually - it applies to any syntax where a variable that has a
quantity is bound, such as function parameters, `let`, `case`, `with`,
and so on.

```idris
let x = 1 in x + x
```

To see how quantity checking would work with this let-expression, we
can simply desugar it into its equivalent lambda form:

```idris
(\x => x + x) 1
```

An explicit quantity `q` isn't given for the lambda in this
expression, so Idris will try to infer the quantity, then check to see
if it's valid. In this case, Idris will infer that `x` is
unrestricted.

#### Pattern Matching

All of the binding constructs that this rule applies to support
pattern matching, so we need to determine how quantities interact with
patterns. To be more specific, if we have a function that
pattern-matches like this:

```idris
func : (1 _ : LPair a b) -> c
func (x # y) = ?impl
```

How does the linear quantity of this function's input "descend" into
the bindings `x` and `y`?

A simple rule is to apply the same function-application rule we looked
at earlier, but to the left side of the equation. For example, here's
how we compute the quantity required for `x` in this function
definition:

```idris
func      (((#)      x)       y)
  0 + 1 * (( 0 + 1 * 1) + 1 * 0)  = 1
```

We start from the outside and work our way inwards, applying the
`qf + r*qe` rule as we go. `x` is used zero times in the constant
`func`, and its argument is linear. We know that `x` is used once
inside of the linear pair `(x # y)` (aside from being obvious, we can
compute this fact ourselves), so the number of times `x` must be used
in `func`'s definition is `0 + 1 * 1 = 1`.

The same argument applies to `y`, meaning that `y` should also be used
once inside of `func` for this definition to pass quantity checking.
And in fact, if we look at the context of the hole `?impl`, that's
exactly what we see!

```repl
 0 a : Type
 0 b : Type
 0 c : Type
 1 x : a
 1 y : b
------------------------------
impl : c
```

As a final note, pattern matching in Idris 2 is only allowed when the
value in question exists at runtime, meaning that it isn't erased.
This is because in QTT, a value must be constructed before it can be
pattern-matched: if you match on a variable `x`, the resources
required to make that variable's value are added to the total count.

```repl
 1 x : T
------------------------------
x : T

 q x : T
------------------------------
E : T'

 (1 + q) x : T
------------------------------
(case x of ... => E) : T'
```

For this reason, the total uses of the variable `x` when
pattern-matching on it must be `1 + q`, where `q` is the uses of `x`
after the pattern-match (`x` is still possible to use with an
as-pattern `x@...`). This prevents the quantity from being `0`.

## The Erased Fragment

Earlier I stated that only variables in the context can have
quantities, which in particular means top-level definitions cannot
have them. This is *mostly* true, but there is one slight exception: a
function can be marked as erased by placing a `0` before its name.

```idris
0 erasedId : (0 x : a) -> a
erasedId x = x
```

This tells the type system to define this function within the *erased
fragment*, which is a fragment of the type system wherein all quantity
checks are ignored. In the `erasedId` function above, we use the
function's input `x` once despite labeling it as erased. This would
normally result in a quantity error, but this function is allowed due
to being defined in the erased fragment.

This quantity freedom the erased fragment gives us comes with a big
drawback, though - erased functions are banned from being used at
runtime. In terms of the type theory, what this means is that an
erased function can only ever be used in these two places:

1. Inside of another erased-fragment function or expression;
2. Inside of a function argument that's erased:

```idris
constInt : (0 _ : a) -> Int
constInt _ = 2

erased2 : Int
erased2 = constInt (erasedId 1)
```

This makes sure that quantities are always handled correctly at
runtime, which is where it matters!

There is another important place where the erased fragment comes into
play, and that's in type signatures. The type signatures of
definitions are always erased, so erased functions can be used inside
of them.

```idris
erasedPrf : erasedId 0 = 0
erasedPrf = Refl
```

For this reason, erased functions are sometimes thought of as
"exclusively type-level functions", though as we've seen, that's not
entirely accurate.

## Conclusion

This concludes our thorough discussion of Quantitative Type Theory. In
this section, we learned about the various operations on quantities:
their addition, multiplication, and ordering. We saw how quantities
were linked to the context, and how to properly think about the
context when analyzing type systems (bottom-to-top instead of
top-to-bottom). We then moved on to studying QTT proper, and we saw
how the quantities in our context change as the expressions we write
grow more complex. Finally, we looked at the erased fragment, and how
we can define erased functions.

In Idris 2's current state, most of this information is still entirely
unnecessary for learning the language. That may not always be the
case, though: there have been some discussions to change the quantity
semiring that Idris 2 uses, or even to allow the programmer to choose
which set of quantities to use. Whether those discussions lead to
anything or not, it can still useful to better understand how
Quantitative Type Theory functions in order to write better Idris 2
code.

### A Note on Mathematical Accuracy

The information in this appendix is partially based on Robert Atkey's
2018 paper [Syntax and Semantics of Quantitative Type
Theory](https://bentnib.org/quantitative-type-theory.pdf), which
outlines QTT in the standard language of type theory. The QTT
presented in Atkey's paper is roughly similar to Idris 2's type system
except for these differences:

1. Atkey's theory does not have subusaging, and so the quantity
   semiring in Atkey's paper is not ordered.
2. In Atkey's theory, types can only be constructed in the erased
   fragment, which means it is impossible to construct a type at
   runtime. Idris 2 allows constructing types at runtime, but still
   uses the erased fragment when inside of type signatures.

To resolve these differences, I directly observed how Idris 2's type
system behaved in practice in order to determine where to deviate from
Atkey's paper.

While I tried to be as mathematically accurate as possible in this
section, some accuracy had to be sacrificed for the sake of
simplicity. In particular, the description of pattern matching given
here is substantially oversimplified. A proper formal treatment of
pattern matching would require introducing an eliminator function for
each datatype; this eliminator would serve to determine how that
datatype's constructors interacted with quantity checking. The details
of how this would work for a few simple types (such as the boolean
type `Bool`) are in Atkey's paper above. I did not include these
details because I decided that what I was describing was complicated
enough already.

<!-- vi: filetype=idris2:syntax=markdown -->
