> 这里是中文版！

# Idris 2 中的函数式编程



这个项目的目标是：要成为 Idris 编程语言的全面指南，其中包含大量针对函数式编程新手的介绍性材料。

内容将分为几个部分，其中关于核心语言特性的部分是 Idris 函数式编程主要指南。每个部分都由几个章节组成，每个章节都试图深入介绍 Idris 编程语言及其核心库的某个方面。大多数章节都附带（有时很多）练习，在目录 `src/Solutions` 中提供了解决方案。

目前，虽然关于核心语言特性的部分还没有完成，但正在积极开发中，并在我自己的几个学生身上进行尝试，其中一些甚至是函数式编程的萌新。

## 目录

### 第 1 部分：核心语言特性

这部分试图对 Idris 编程语言进行深入的介绍。如果您是函数式编程的新手，请确保按顺序阅读这些章节并*解决所有练习*。

如果您已经使用过其他纯函数式编程语言，例如 Haskell，那么您可能会很快完成介绍性材料（函数第 1 部分，代数数据类型和接口），因为这些内容中的大部分内容您已经很熟悉了。

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

### 第 2 部分：附录

附录可用作手头主题的参考。我计划最终对 Idris 语法、典型错误消息、模块系统、交互式编辑以及可能的其他内容有一个简明的参考。

1. [Interactive Editing in Neovim](src/Appendices/Neovim.md)

## 前置条件

目前，该项目正在针对 Idris 2 存储库的主要分支进行积极开发和演进。它每晚在 GitHub 上进行测试，并针对 Idris 2 主分支的最新提交以及文件 `.idris-version` 中列出的 Idris 2 提交进行构建。
