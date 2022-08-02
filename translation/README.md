> 这里是中文版！

# Idris 2 中的函数式编程

这个项目的目标是：要成为 Idris 编程语言的全面指南，其中包含大量针对函数式编程新手的介绍性材料。

内容将分为几个部分，其中关于核心语言特性的部分是 Idris 函数式编程主要指南。每个部分都由几个章节组成，每个章节都试图深入介绍 Idris
编程语言及其核心库的某个方面。大多数章节都附带（有时很多）练习，在目录 `src/Solutions` 中提供了解决方案。

目前，甚至关于核心语言特性的部分还没有完成，但正在积极开发并在我自己的几个学生身上进行尝试，其中一些对函数式编程来说是纯萌新。

## 目录

### 第 1 部分：核心语言功能

这部分试图对 Idris 编程语言进行深入的介绍。如果您是函数式编程的新手，请确保按顺序阅读这些章节并*解决所有练习*。

如果您已经使用过其他纯函数式编程语言，例如 Haskell，那么您可能会很快完成介绍性材料（函数第 1
部分，代数数据类型和接口），因为这些内容中的大部分内容您已经很熟悉了。

1. [简介](src/Tutorial/Intro.md)
   1. [关于Idris编程语言](src/Tutorial/Intro.md#about-the-idris-programming-language)
   2. [使用 REPL](src/Tutorial/Intro.md#using-the-repl)
   3. [第一个 Idris 程序](src/Tutorial/Intro.md#a-first-idris-program)
   4. [使用 Idris 定义形状](src/Tutorial/Intro.md#the-shape-of-an-idris-definition)
   5. [在哪里可以获得帮助](src/Tutorial/Intro.md#where-to-get-help)
2. [函数第1部分](src/Tutorial/Functions1.md)
   1. [具有多个参数的函数](src/Tutorial/Functions1.md#functions-with-more-that-one-argument)
   2. [函数组合](src/Tutorial/Functions1.md#function-composition)
   3. [高阶函数](src/Tutorial/Functions1.md#higher-order-functions)
   4. [柯里化](src/Tutorial/Functions1.md#currying)
   5. [匿名函数](src/Tutorial/Functions1.md#anonymous-functions)
   6. [运算符](src/Tutorial/Functions1.md#operators)
3. [代数数据类型](src/Tutorial/DataTypes.md)
   1. [枚举](src/Tutorial/DataTypes.md#enumerations)
   2. [和类型](src/Tutorial/DataTypes.md#sum-types)
   3. [记录](src/Tutorial/DataTypes.md#records)
   4. [通用数据类型](src/Tutorial/DataTypes.md#generic-data-types)
   5. [数据定义的替代语法](src/Tutorial/DataTypes.md#alternative-syntax-for-data-definitions)
4. [接口](src/Tutorial/Interfaces.md)
   1. [接口基础](src/Tutorial/Interfaces.md#interface-basics)
   2. [更多关于接口](src/Tutorial/Interfaces.md#more-about-interfaces)
   3. [Prelude 中的接口](src/Tutorial/Interfaces.md#interfaces-in-the-prelude)
5. [函数第二部分](src/Tutorial/Functions2.md)
   1. [绑定和局部定义](src/Tutorial/Functions2.md#let-bindings-and-local-definitions)
   2. [函数参数的真相](src/Tutorial/Functions2.md#the-truth-about-function-arguments)
   3. [使用孔进行编程](src/Tutorial/Functions2.md#programming-with-holes)
6. [依赖类型](src/Tutorial/Dependent.md)
   1. [长度索引列表](src/Tutorial/Dependent.md#length-indexed-lists)
   2. [Fin：向量的安全索引](src/Tutorial/Dependent.md#fin-safe-indexing-into-vectors)
   3. [编译期计算](src/Tutorial/Dependent.md#compile-time-computations)
7. [IO：有副作用的编程](src/Tutorial/IO.md)
   1. [纯副作用？](src/Tutorial/IO.md#pure-side-effects)
   2. [Do 程序块, 脱糖](src/Tutorial/IO.md#do-blocks-desugared)
   3. [操作文件](src/Tutorial/IO.md#working-with-files)
   4. [IO是如何实现的](src/Tutorial/IO.md#how-io-is-implemented)
8. [函子和它的小朋友们](src/Tutorial/Functor.md)
   1. [函子](src/Tutorial/Functor.md#functor)
   2. [应用子](src/Tutorial/Functor.md#applicative)
   3. [单子](src/Tutorial/Functor.md#monad)
   4. [背景与延伸阅读】(src/Tutorial/Functor.md#background-and-further-reading)
9. [递归与折叠](src/Tutorial/Folds.md)
   1. [递归](src/Tutorial/Folds.md#recursion)
   2. [关于完全性检查的几点说明】(src/Tutorial/Folds.md#a-few-notes-on-totality-checking)
   3. [foldable 接口](src/Tutorial/Folds.md#interface-foldable)
10. [遍历副作用](src/Tutorial/Traverse.md)
    1. [读取CSV表格](src/Tutorial/Traverse.md#reading-csv-tables)
    2. [有状态编程](src/Tutorial/Traverse.md#programming-with-state)
    3. [组合的力量](src/Tutorial/Traverse.md#the-power-of-composition)
11. [Sigma 类型](src/Tutorial/DPair.md)
    1. [依赖对](src/Tutorial/DPair.md#dependent-pairs)
    2. [用例：核酸](src/Tutorial/DPair.md#use-case-nucleic-acids)
    3. [用例：带有 Schema 的 CSV 文件](src/Tutorial/DPair.md#use-case-csv-files-with-a-schema)
12. [命题等式](src/Tutorial/Eq.md)
    1. [作为类型的相等性](src/Tutorial/Eq.md#equality-as-a-type)
    2. [程序作为证明](src/Tutorial/Eq.md#programs-as-proofs)
    3. [遁入虚无](src/Tutorial/Eq.md#into-the-void)
    4. [重写规则](src/Tutorial/Eq.md#rewrite-rules)
13. [谓词和证明搜索](src/Tutorial/Predicates.md)
    1. [前置条件](src/Tutorial/Predicates.md#preconditions)
    2. [值之间的契约](src/Tutorial/Predicates.md#contracts-between-values)
    3. [用例：灵活的错误处理](src/Tutorial/Predicates.md#use-case-flexible-error-handling)
    4. [接口的真相](src/Tutorial/Predicates.md#the-truth-about-interfaces)
14. [原语](src/Tutorial/Prim.md)
    1. [原语是如何实现的](src/Tutorial/Prim.md#how-primitives-are-implemented)
    2. [使用字符串](src/Tutorial/Prim.md#working-with-strings)
    3. [整数](src/Tutorial/Prim.md#integers)
    4. [改进原语](src/Tutorial/Prim.md#refined-primitives)

### 第 2 部分：附录

附录可用作手头主题的参考。我计划最终对 Idris 语法、典型错误消息、模块系统、交互式编辑以及可能的其他内容有一个简明的参考。

1. [Neovim 中的交互式编辑](src/Appendices/Neovim.md)

## 先决条件

目前，该项目正在针对 Idris 2 存储库的主要分支进行积极开发和演进。它每晚在 GitHub 上进行测试，并针对 Idris 2
主分支的最新提交以及文件 `.idris-version` 中列出的 Idris 2 提交进行构建。
