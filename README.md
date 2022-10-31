# Functional Programming in Idris 2

The goal of this project is quickly explained: To become a more
or less comprehensive guide to the Idris programming language,
with a lot of introductory material targeted at newcomers to
functional programming.

The content will be organized in several parts, with the part
about the core language features being the main guide to
functional programming in Idris. Every part consists of several
chapters, each trying to cover in depth a certain aspect
of the Idris programming language and its core libraries. Most
chapters come with (sometimes lots of) exercises, with
solutions available in directory `src/Solutions`.

Right now, even the part about core language features is not
yet finished, but is being actively developed and tried on
several of my own students, some of which are completely
new to functional programming.

## Table of Contents

### Part 1: Core Language Features

This part tries to give a solid introduction to the
Idris programming language. If you are new to functional programming,
make sure to follow these chapters in order and *solve all the
exercises*.

If you already used other pure functional programming languages like
Haskell, you might go through the introductory material (Functions Part 1,
Algebraic Data Types, and Interfaces) pretty quickly, as most of this
stuff will already be familiar to you.

1. [Introduction](src/Tutorial/Intro.md)
   1. [About the Idris Programming Language](src/Tutorial/Intro.md#about-the-idris-programming-language)
   2. [Using the REPL](src/Tutorial/Intro.md#using-the-repl)
   3. [A First Idris Program](src/Tutorial/Intro.md#a-first-idris-program)
   4. [The Shape of an Idris Definition](src/Tutorial/Intro.md#the-shape-of-an-idris-definition)
   5. [Where to get Help](src/Tutorial/Intro.md#where-to-get-help)
2. [Functions Part 1](src/Tutorial/Functions1.md)
   1. [Functions with more that one Argument](src/Tutorial/Functions1.md#functions-with-more-that-one-argument)
   2. [Function Composition](src/Tutorial/Functions1.md#function-composition)
   3. [Higher-order Functions](src/Tutorial/Functions1.md#higher-order-functions)
   4. [Currying](src/Tutorial/Functions1.md#currying)
   5. [Anonymous Functions](src/Tutorial/Functions1.md#anonymous-functions)
   6. [Operators](src/Tutorial/Functions1.md#operators)
3. [Algebraic Data Types](src/Tutorial/DataTypes.md)
   1. [Enumerations](src/Tutorial/DataTypes.md#enumerations)
   2. [Sum Types](src/Tutorial/DataTypes.md#sum-types)
   3. [Records](src/Tutorial/DataTypes.md#records)
   4. [Generic Data Types](src/Tutorial/DataTypes.md#generic-data-types)
   5. [Alternative Syntax for Data Definitions](src/Tutorial/DataTypes.md#alternative-syntax-for-data-definitions)
4. [Interfaces](src/Tutorial/Interfaces.md)
   1. [Interface Basics](src/Tutorial/Interfaces.md#interface-basics)
   2. [More about Interfaces](src/Tutorial/Interfaces.md#more-about-interfaces)
   3. [Interfaces in the Prelude](src/Tutorial/Interfaces.md#interfaces-in-the-prelude)
5. [Functions Part 2](src/Tutorial/Functions2.md)
   1. [Let Bindings and Local Definitions](src/Tutorial/Functions2.md#let-bindings-and-local-definitions)
   2. [The Truth about Function Arguments](src/Tutorial/Functions2.md#the-truth-about-function-arguments)
   3. [Programming with Holes](src/Tutorial/Functions2.md#programming-with-holes)
6. [Dependent Types](src/Tutorial/Dependent.md)
   1. [Length-Indexed Lists](src/Tutorial/Dependent.md#length-indexed-lists)
   2. [Fin: Safe Indexing into Vectors](src/Tutorial/Dependent.md#fin-safe-indexing-into-vectors)
   3. [Compile-Time Computations](src/Tutorial/Dependent.md#compile-time-computations)
7. [IO: Programming with Side Effects](src/Tutorial/IO.md)
   1. [Pure Side Effects?](src/Tutorial/IO.md#pure-side-effects)
   2. [Do Blocks, Desugared](src/Tutorial/IO.md#do-blocks-desugared)
   3. [Working with Files](src/Tutorial/IO.md#working-with-files)
   4. [How IO is Implemented](src/Tutorial/IO.md#how-io-is-implemented)
8. [Functor and Friends](src/Tutorial/Functor.md)
   1. [Functor](src/Tutorial/Functor.md#functor)
   2. [Applicative](src/Tutorial/Functor.md#applicative)
   3. [Monad](src/Tutorial/Functor.md#monad)
   4. [Background and further Reading](src/Tutorial/Functor.md#background-and-further-reading)
9. [Recursion and Folds](src/Tutorial/Folds.md)
   1. [Recursion](src/Tutorial/Folds.md#recursion)
   2. [A few Notes on Totality Checking](src/Tutorial/Folds.md#a-few-notes-on-totality-checking)
   3. [Interface Foldable](src/Tutorial/Folds.md#interface-foldable)
10. [Effectful Traversals](src/Tutorial/Traverse.md)
    1. [Reading CSV Tables](src/Tutorial/Traverse.md#reading-csv-tables)
    2. [Programming with State](src/Tutorial/Traverse.md#programming-with-state)
    3. [The Power of Composition](src/Tutorial/Traverse.md#the-power-of-composition)
11. [Sigma Types](src/Tutorial/DPair.md)
    1. [Dependent Pairs](src/Tutorial/DPair.md#dependent-pairs)
    2. [Use Case: Nucleic Acids](src/Tutorial/DPair.md#use-case-nucleic-acids)
    3. [Use Case: CSV Files with a Schema](src/Tutorial/DPair.md#use-case-csv-files-with-a-schema)
12. [Propositional Equality](src/Tutorial/Eq.md)
    1. [Equality as a Type](src/Tutorial/Eq.md#equality-as-a-type)
    2. [Programs as Proofs](src/Tutorial/Eq.md#programs-as-proofs)
    3. [Into the Void](src/Tutorial/Eq.md#into-the-void)
    4. [Rewrite Rules](src/Tutorial/Eq.md#rewrite-rules)
13. [Predicates and Proof Search](src/Tutorial/Predicates.md)
    1. [Preconditions](src/Tutorial/Predicates.md#preconditions)
    2. [Contracts between Values](src/Tutorial/Predicates.md#contracts-between-values)
    3. [Use Case: Flexible Error Handling](src/Tutorial/Predicates.md#use-case-flexible-error-handling)
    4. [The Truth about Interfaces](src/Tutorial/Predicates.md#the-truth-about-interfaces)
14. [Primitives](src/Tutorial/Prim.md)
    1. [How Primitives are Implemented](src/Tutorial/Prim.md#how-primitives-are-implemented)
    2. [Working with Strings](src/Tutorial/Prim.md#working-with-strings)
    3. [Integers](src/Tutorial/Prim.md#integers)
    4. [Refined Primitives](src/Tutorial/Prim.md#refined-primitives)

### Part 2: Appendices

The appendices can be used as references for the topics at
hand. I plan to eventually have a concise reference on Idris
syntax, typical error messages, the module system, interactive
editing and possibly others.

1. [Getting Started with pack and Idris2](src/Appendices/Install.md)
2. [Interactive Editing in Neovim](src/Appendices/Neovim.md)

## Prerequisites

At the moment, this project is being actively developed and
evolved against the main branch of the Idris 2 repository.
It is being tested nightly on GitHub and built against
the latest version of [pack's package collection](https://github.com/stefan-hoeck/idris2-pack-db).

In order to follow along with this tutorial, it is strongly suggested to install
Idris via the pack package manager as described [here](src/Appendices/Install.md).
