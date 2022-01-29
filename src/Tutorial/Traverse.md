# Effectful Traversals

In this chapter, we are going to bring our treatment
of the higher-kinded interfaces in the *Prelude* to an
end. In order to do so, we will continue developing the
CSV reader we started implementing in chapter
[Functor and Friends](Functor.md). I moved some of
the data types and interfaces from that chapter to
their own modules, so we can reimport them here without
the need to start from scratch.

Note, that unlike our original CSV-reader, we will use
`Validated` instead of `Either`, since this will allow
us to accumulate all errors when reading a CSV file.

```idris
module Tutorial.Traverse

import Data.HList
import Data.Validated
import Text.CSV

%default total
```

## Reading CSV Tables

We stopped developing our CSV reader with function
`hdecode`, which allows us to read a single line
in a CSV-file and decode it to a heterogeneous list.
As a reminder, here is how to use `hdecode` at the REPL:

```repl
Tutorial.Traverse> hdecode [Bool,String,Bits8] 1 "f,foo,12"
Valid [False, "foo", 12]
```

The next step will be to parse a whole CSV-table, represented
as a list of string, where each string corresponds to a line.
We will go about this stepwise as there are several aspects
to handle this properly. What we are looking for - eventually -
is a function of the following type (we are going to
implement several version of this function, hence the
numbering):

```idris
hreadTable1 :  (0 ts : List Type)
            -> CSVLine (HList ts)
            => List String
            -> Validated CSVError (List $ HList ts)
```

In our first implementation, we are not going to care
about line numbers:

```idris
hreadTable1 _  []        = pure []
hreadTable1 ts (s :: ss) = [| hdecode ts 0 s :: hreadTable1 ts ss |]
```

Note, how we can just use applicative syntax in the implementation
of `hreadTable1`. To make this clearer, I used `pure []` on the first
line instead of the more specific `Valid []`. In fact, if we used
`Either` or `Maybe` instead of `Validated` for error handling,
the implementation of `hreadTable1` would look exactly the same.

The question is: Can we extract a pattern to abstract over
from this observation? What we do in `hreadTable1` is running
an effectful computation of type `String -> Validated CSVError (HList ts)`
over a list of strings, so that the result is a list of `HList ts`
wrapped in a `Validated CSVError`. The first step when abstracting
this should be to use generic types for the input and output:
Run a computation of type `a -> Validated CSVError b` over a
list `List a`:

```idris
traverseValidatedList :  (a -> Validated CSVError b)
                      -> List a
                      -> Validated CSVError (List b)
traverseValidatedList _ []        = pure []
traverseValidatedList f (x :: xs) = [| f x :: traverseValidatedList f xs |]

hreadTable2 :  (0 ts : List Type)
            -> CSVLine (HList ts)
            => List String
            -> Validated CSVError (List $ HList ts)
hreadTable2 ts = traverseValidatedList (hdecode ts 0)
```

But our observation was, that the implementation of `hreadTable1`
would be exactly the same if we used `Either CSVError` or `Maybe`
as our effect type instead of `Validated CSVError`.
So, the next step should be to abstract over the *effect type*.
We note, that we used applicative syntax (idiom brackets and
`pure`) in our implementation, so we will need to write
an constrained function with an `Applicative` constraint
on the effect type:

```idris
traverseList :  Applicative f => (a -> f b) -> List a -> f (List b)
traverseList _ []        = pure []
traverseList f (x :: xs) = [| f x :: traverseList f xs |]

hreadTable3 :  (0 ts : List Type)
            -> CSVLine (HList ts)
            => List String
            -> Validated CSVError (List $ HList ts)
hreadTable3 ts = traverseList (hdecode ts 0)
```

Let's give this a go at the REPL:

```repl
Tutorial.Traverse> hreadTable3 [Bool,Bits8] ["f,12","t,0"]
Valid [[False, 12], [True, 0]]
Tutorial.Traverse> hreadTable3 [Bool,Bits8] ["f,12","t,1000"]
Invalid (FieldError 0 2 "1000")
Tutorial.Traverse> hreadTable3 [Bool,Bits8] ["1,12","t,1000"]
Invalid (Append (FieldError 0 1 "1") (FieldError 0 2 "1000"))
```

<!-- vi: filetype=idris2
-->
