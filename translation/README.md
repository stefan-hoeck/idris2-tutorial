> 这里是中文版！

# Idris 2 中的函数式编程



这个项目的目标是：要成为 Idris 编程语言的全面指南，其中包含大量针对函数式编程新手的介绍性材料。

内容将分为几个部分，其中关于核心语言特性的部分是 Idris 函数式编程主要指南。每个部分都由几个章节组成，每个章节都试图深入介绍 Idris 编程语言及其核心库的某个方面。大多数章节都附带（有时很多）练习，在目录 `src/Solutions` 中提供了解决方案。

目前，虽然关于核心语言特性的部分还没有完成，但正在积极开发中，并在我自己的几个学生身上进行尝试，其中一些甚至是函数式编程的萌新。

## 目录

### 第 1 部分：核心语言特性

这部分试图对 Idris 编程语言进行深入的介绍。如果您是函数式编程的新手，请确保按顺序阅读这些章节并*解决所有练习*。

如果您已经使用过其他纯函数式编程语言，例如 Haskell，那么您可能会很快完成介绍性材料（函数第 1 部分，代数数据类型和接口），因为这些内容中的大部分内容您已经很熟悉了。

1. [介绍](src/Tutorial/Intro.md)

   1. [关于 Idris 函数式编程](src/Tutorial/Intro.md#关于-Idris-函数式编程)

   2. [使用 REPL](src/Tutorial/Intro.md#使用-REPL)

   3. [第一个 Idris 程序](src/Tutorial/Intro.md#第一个-Idris-程序)

   4. [如何声明一个 Idris 定义](src/Tutorial/Intro.md#如何声明一个-Idris-定义)

   5. [在哪里可以获得帮助](src/Tutorial/Intro.md#在哪里可以获得帮助)

2. [函数第 1 部分](src/Tutorial/Functions1.md)

   1. [多参函数](src/Tutorial/Functions1.md#多参函数)

   2. [函数组合](src/Tutorial/Functions1.md#函数组合])

   3. [高阶函数](src/Tutorial/Functions1.md#高阶函数)

   4. [柯里化](src/Tutorial/Functions1.md#柯里化)

   5. [匿名函数](src/Tutorial/Functions1.md#匿名函数)

   6. [运算符](src/Tutorial/Functions1.md#运算符)

3. [代数数据类型](src/Tutorial/DataTypes.md)

   1. [枚举](src/Tutorial/DataTypes.md#枚举)

   2. [和类型](src/Tutorial/DataTypes.md#和类型)

   3. [记录](src/Tutorial/DataTypes.md#记录)

   4. [泛型数据类型](src/Tutorial/DataTypes.md#泛型数据类型)

   5. [数据定义的替代语法](src/Tutorial/DataTypes.md#数据定义的替代语法)

4. [接口](src/Tutorial/Interfaces.md)

   1. [接口基础](src/Tutorial/Interfaces.md#接口基础)

   2. [接口的更多内容](src/Tutorial/Interfaces.md#接口的更多内容)

   3. [Prelude 中的接口](src/Tutorial/Interfaces.md#Prelude-中的接口)

5. [函数第 2 部分](src/Tutorial/Functions2.md)

   1. [绑定和局部定义](src/Tutorial/Functions2.md#绑定和局部定义)

   2. [函数参数的真相](src/Tutorial/Functions2.md#函数参数的真相)

   3. [使用孔编程](src/Tutorial/Functions2.md#使用孔编程)

6. [依赖类型](src/Tutorial/Dependent.md)

   1. [长度索引列表](src/Tutorial/Dependent.md#长度索引列表)

   2. [Fin: 向量的安全索引](src/Tutorial/Dependent.md#Fin:-向量的安全索引)

   3. [编译期计算](src/Tutorial/Dependent.md#编译期计算)

7. [IO：带有副作用的编程](src/Tutorial/IO.md)

   1. [纯的副作用？](src/Tutorial/IO.md#纯的副作用？)

   2. [Do 块，脱糖](src/Tutorial/IO.md#Do-块，脱糖)

   3. [使用文件](src/Tutorial/IO.md#使用文件)

   4. [IO 是如何实现的](src/Tutorial/IO.md#IO-是如何实现的)

8. [函子和它的伙伴们](src/Tutorial/Functor.md)

   1. [函子](src/Tutorial/Functor.md#函子)

   2. [应用函子](src/Tutorial/Functor.md#应用函子)

   3. [单子](src/Tutorial/Functor.md#单子)

   4. [背景与延伸阅读](src/Tutorial/Functor.md#背景与延伸阅读)

9. [递归与折叠](src/Tutorial/Folds.md)

   1. [递归](src/Tutorial/Folds.md#递归)

   2. [关于完全性检查的一些注意事项](src/Tutorial/Folds.md#关于完全性检查的一些注意事项)

   3. [Foldable 接口](src/Tutorial/Folds.md#Foldable-接口)

10. [带副作用的遍历](src/Tutorial/Traverse.md)

    1. [阅读 CSV 表格](src/Tutorial/Traverse.md#阅读-CSV-表格)

    2. [使用状态编程](src/Tutorial/Traverse.md#使用状态编程)

    3. [组合的力量](src/Tutorial/Traverse.md#组合的力量)

11. [Sigma 类型](src/Tutorial/DPair.md)

    1. [依赖对](src/Tutorial/DPair.md#依赖对)

    2. [用例：核酸](src/Tutorial/DPair.md#用例：核酸)

    3. [用例：带有模式的 CSV 文件](src/Tutorial/DPair.md#用例：带有模式的-CSV-文件)

12. [命题等式 Equality](src/Tutorial/Eq.md)

    1. [相等作为类型](src/Tutorial/Eq.md#相等作为类型)

    2. [程序作为证明](src/Tutorial/Eq.md#程序作为证明)

    3. [遁入虚无](src/Tutorial/Eq.md#遁入虚无)

    4. [重写规则](src/Tutorial/Eq.md#重写规则)

13. [谓词和证明搜索](src/Tutorial/Predicates.md)

    1. [前置条件](src/Tutorial/Predicates.md#前置条件)

    2. [值之间的契约](src/Tutorial/Predicates.md#值之间的契约)

    3. [用例：灵活的错误处理](src/Tutorial/Predicates.md#用例：灵活的错误处理)

    4. [接口的真相](src/Tutorial/Predicates.md#接口的真相)

14. [原语](src/Tutorial/Prim.md)

    1. [原语的实现](src/Tutorial/Prim.md#原语的实现)

    2. [使用字符串](src/Tutorial/Prim.md#使用字符串)

    3. [整数](src/Tutorial/Prim.md#整数)

    4. [细化原语](src/Tutorial/Prim.md#细化原语)


### 第 2 部分：附录

附录可用作手头主题的参考。我计划最终对 Idris 语法、典型错误消息、模块系统、交互式编辑以及可能的其他内容有一个简明的参考。

1. [Neovim 中的交互式编辑](src/Appendices/Neovim.md)


## 前置条件

目前，该项目正在针对 Idris 2 存储库的主要分支进行积极开发和演进。它每晚在 GitHub 上进行测试，并针对 Idris 2 主分支的最新提交以及文件 `.idris-version` 中列出的 Idris 2 提交进行构建。
