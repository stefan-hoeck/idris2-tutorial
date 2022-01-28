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
  6. [Summary](src/Tutorial/Intro.md#summary)
2. [Functions Part 1](src/Tutorial/Functions1.md)
3. [Algebraic Data Types](src/Tutorial/DataTypes.md)
4. [Interfaces](src/Tutorial/Interfaces.md)
5. [Functions Part 2](src/Tutorial/Functions2.md)
6. [Dependent Types](src/Tutorial/Dependent.md)
7. [IO: Programming with Side Effects](src/Tutorial/IO.md)
8. [Functor and Friends](src/Tutorial/Functor.md)
9. [Recursion and Folds](src/Tutorial/Folds.md)

## Prerequisites

At the moment, this project is being actively developed and
evolved against the main branch of the Idris 2 repository.
It is been tested nightly on GitHub to still build against
the latest commit of the Idris 2 main branch as well as the
Idris 2 commit listed in file `.idris-version`.
