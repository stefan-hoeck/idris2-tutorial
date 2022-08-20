# 遍历副作用

在本章中，我们将带来 *Prelude* 中更高种类的接口。为此，我们将继续开发
我们在 [函子和朋友](Functor.md) 章节中开始实现的 CSV 阅读器。我移动了一些
该章的数据类型和接口到他们自己的模块，所以我们可以在这里导入它们而无需从头开始。

请注意，与我们原来的 CSV 阅读器不同，我们将使用 `Validated` 而不是 `Either` 处理异常，
因为这将使我们能够累积读取 CSV 文件时的所有错误。

```idris
module Tutorial.Traverse

import Data.HList
import Data.IORef
import Data.List1
import Data.String
import Data.Validated
import Data.Vect
import Text.CSV

%default total
```

## 读取 CSV 表

我们停止开发具有 `hdecode` 函数—的 CSV 阅读器，它允许我们在 CSV 文件中读取单行并将其解码为异构列表。
提醒一下，这里是如何在 REPL 中使用 `hdecode` ：

```repl
Tutorial.Traverse> hdecode [Bool,String,Bits8] 1 "f,foo,12"
Valid [False, "foo", 12]
```

下一步将解析整个 CSV 表作为字符串列表，其中每个字符串对应一个
表的一行。
我们将逐步进行，因为有几个方面可以正确地做到这一点。我们正在寻找的——最终—— 是以下类型的函数（我们将实现这个函数的几个版本，因此我们给它了编号）：

```idris
hreadTable1 :  (0 ts : List Type)
            -> CSVLine (HList ts)
            => List String
            -> Validated CSVError (List $ HList ts)
```

在我们的第一个实现中，我们不会关心
关于行号的事情：

```idris
hreadTable1 _  []        = pure []
hreadTable1 ts (s :: ss) = [| hdecode ts 0 s :: hreadTable1 ts ss |]
```

注意，我们如何在 `hreadTable1` 的实现中使用应用函子语法。为了更清楚，我优先使用 `pure []` 而不是更具体的 `Valid []`。事实上，如果我们使用
`Either` 或 `Maybe` 而不是 `Validated` 用于错误处理，
`hreadTable1` 的实现看起来完全一样。

问题是：我们从这个观察中可以提取一个模式来抽象吗？我们在 `hreadTable1` 中运行字符串列表上的副作用计算，类型为 `String -> Validated CSVError (HList ts)`，因此结果是 `HList ts` 的列表
且包裹在 `Validated CSVError` 中。抽象的第一步
应该是对输入和输出使用类型参数：
在列表 `List a` 上运行 `a -> Validated CSVError b` 类型的计算：

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

但我们的观察是，如果我们使用 `Either CSVError` 或 `Maybe` 代替 `Validated CSVError`作为我们的副作用类型，`hreadTable1` 的实现将完全相同。
所以，下一步应该是对*副作用类型*进行抽象。
我们注意到，我们使用了应用函子语法（习语括号和
`pure`) 在我们的实现中，所以我们需要编写
关于副作用类型具有 `Applicative` 约束的函数：

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

注意，`traverseList`的实现和 `traverseValidatedList` 完全一样的，但类型更通用
因此，`traverseList` 更强大。

让我们在 REPL 上试一试：

```repl
Tutorial.Traverse> hreadTable3 [Bool,Bits8] ["f,12","t,0"]
Valid [[False, 12], [True, 0]]
Tutorial.Traverse> hreadTable3 [Bool,Bits8] ["f,12","t,1000"]
Invalid (FieldError 0 2 "1000")
Tutorial.Traverse> hreadTable3 [Bool,Bits8] ["1,12","t,1000"]
Invalid (Append (FieldError 0 1 "1") (FieldError 0 2 "1000"))
```

这已经很好用了，但请注意我们的错误消息是如何做的，
尚未打印正确的行号。这并不奇怪，
因为我们在调用 `hdecode` 时使用了一个虚拟常量。
我们将研究如何得出行号
当我们在本章后面讨论有状态计算时会飞起来。
现在，我们可以手动注释这些行号并将一对列表传递给 `hreadTable`：

```idris
hreadTable4 :  (0 ts : List Type)
            -> CSVLine (HList ts)
            => List (Nat, String)
            -> Validated CSVError (List $ HList ts)
hreadTable4 ts = traverseList (uncurry $ hdecode ts)
```

如果这是你第一次遇到函数 `uncurry`，
确保您查看了它的类型并尝试找出它在这里被使用的原因。在 *Prelude* 中有几个这样的实用函数，如`curry`、`uncurry`、`flip`，还有 `id`，所有这些在处理高阶函数时都非常有用。

虽然不完美，但这个版本至少允许我们在 REPL 进行验证行号正确传递的错误消息：

```repl
Tutorial.Traverse> hreadTable4 [Bool,Bits8] [(1,"t,1000"),(2,"1,100")]
Invalid (Append (FieldError 1 2 "1000") (FieldError 2 1 "1"))
```

### Traversable 接口

现在，这里有一个有趣的现象：我们可以实现一个函数，
像其他容器类型的 `traverseList` 那样。你可能认为那是很简单的，鉴于我们可以通过以下方式将容器类型转换为列表
来自接口 `Foldable` 的函数 `toList`。然而，通过 `List` 来处理在某些情况下可能是可行的，一般来说，我们会丢失了类型信息。例如，这里 `Vect` 的函数是这样的：

```idris
traverseVect' : Applicative f => (a -> f b) -> Vect n a -> f (List b)
traverseVect' fun = traverseList fun . toList
```

注意我们是如何丢失了所有关于原始容器类型结构的信息的。我们要找的是像`traverseVect'` 的一个函数，它保留了这个类型级别的信息：结果应该是与输入长度相同的向量。

```idris
traverseVect : Applicative f => (a -> f b) -> Vect n a -> f (Vect n b)
traverseVect _   []        = pure []
traverseVect fun (x :: xs) = [| fun x :: traverseVect fun xs |]
```

那好多了！正如我上面写的，我们可以很容易地得到相同的对于其他容器类型，如 `List1`、`SnocList`、`Maybe` 等。
像往常一样，一些派生函数将紧跟在 `traverseXY` 之后。例如：

```idris
sequenceList : Applicative f => List (f a) -> f (List a)
sequenceList = traverseList id
```

所有这些都需要一个新的接口，它被称为
`Traversable` 并从 *Prelude* 导出。这是
它的定义（用单引号来消除歧义）：

```idris
interface Functor t => Foldable t => Traversable' t where
  traverse' : Applicative f => (a -> f b) -> t a -> f (t b)
```

函数 `traverse` 是*Prelude* 提供的函数中最抽象和通用的函数之一。到底有多强大
只有在你的代码中一遍又一遍开始使用它才会变得清晰。然而，这将是本章剩余部分的目标，会向您展示几个多样而有趣的用例。

现在，我们将快速关注抽象程度。
函数 `traverse` 参数化不小于四个参数：容器类型 `t` (`List`, `Vect n`,
`Maybe`，仅举几例），副作用类型（`Validated e`，
`IO`、`Maybe` 等），输入元素类型 `a` 和输出元素类型 `b`。考虑到库
与 Idris 基础库导出 30 多种数据类型
具有 `Applicative` 的实现和十多个
可遍历的容器类型，实际上有数百个
副作用遍历容器的组合计算。一旦我们意识到可遍历的容器——比如应用函子——
可以在组合下闭合，这个数字会变得更大
（见练习和
本章的最后一节）。

### Traversable 定律

函数 `traverse` 必须遵守两个定律：

* `traverse (Id . f) = Id . map f`: 遍历 `Identity` 单子等同于使用 `map`.
* `traverse (MkComp . map f . g) = MkComp . map (traverse f) . traverse
  g`：在单个遍历（左侧）或两个遍历序列（右侧）中完成时，具有副作用组合的遍历必须相同。

由于`map id = id`（函子恒等律），我们可以从第一定律推导出
`traverse Id = Id`。这意味着
`traverse`不得改变容器的大小或形状
类型，也不允许改变元素的顺序。

### 练习第 1 部分

1. 有趣的是 `Traversable` 有一个 `Functor` 约束。通过根据 `traverse` 实现 `map`，证明每个
   `Traversable` 自动成为 `Functor`。

   提示：记住 `Control.Monad.Identity`。

2. 同样，通过根据 `Traverse` 实现 `foldMap` 来证明每个 `Traversable` 都是 `Foldable`。

   提示：记住 `Control.Applicative.Const`。

3. 开始一些例行程序，请为 `List1`、`Ei` 和 `Maybe` 实现 `Traversable'`。

4. 为 `List01 ne` 实现 `Traversable`：

   ```idris
   data List01 : (nonEmpty : Bool) -> Type -> Type where
     Nil  : List01 False a
     (::) : a -> List01 False a -> List01 ne a
   ```

5. 为玫瑰树实现 `Traversable`。尝试在不作弊的情况下满足完全性检查器。

   ```idris
   record Tree a where
     constructor Node
     value  : a
     forest : List (Tree a)
   ```

6. 为 `Crud i` 实现 `Traversable`：

   ```idris
   data Crud : (i : Type) -> (a : Type) -> Type where
     Create : (value : a) -> Crud i a
     Update : (id : i) -> (value : a) -> Crud i a
     Read   : (id : i) -> Crud i a
     Delete : (id : i) -> Crud i a
   ```

7. 为 `Response e i` 实现 `Traversable`：

   ```idris
   data Response : (e, i, a : Type) -> Type where
     Created : (id : i) -> (value : a) -> Response e i a
     Updated : (id : i) -> (value : a) -> Response e i a
     Found   : (values : List a) -> Response e i a
     Deleted : (id : i) -> Response e i a
     Error   : (err : e) -> Response e i a
   ```

8. 与 `Functor`、`Applicative` 和 `Foldable` 一样，`Traversable` 在组合下是封闭的。通过为
   `Comp` 和 `Product` 实现 `Traversable` 来证明这一点：

   ```idris
   record Comp (f,g : Type -> Type) (a : Type) where
     constructor MkComp
     unComp  : f (g a)

   record Product (f,g : Type -> Type) (a : Type) where
     constructor MkProduct
     fst : f a
     snd : g a
   ```

## 用状态编程

让我们回到我们的 CSV 阅读器。为了合理
错误消息，我们想用索引来标记每一行：

```idris
zipWithIndex : List a -> List (Nat, a)
```

当然，很容易想出一个临时的实现：

```idris
zipWithIndex = go 1
  where go : Nat -> List a -> List (Nat,a)
        go _ []        = []
        go n (x :: xs) = (n,x) :: go (S n) xs
```

虽然这很好，但我们仍然应该注意到
我们可能想对树、向量、非空列表等的元素做同样的事情。
再一次，我们感兴趣的是是否有一些
我们可以使用抽象形式来描述此类计算。

### Idris 中的可变引用

让我们考虑一下我们会如何做这样的事情
在命令式语言中。在那里，我们可能会定义
一个局部（可变）变量，用于跟踪当前
索引，然后在遍历列表时增加
在 `for`- 或 `while`-循环中。

在 Idris 中，没有可变状态之类的东西。
或者有吗？请记住，我们如何在早期模拟数据库连接练习中使用可变引用。在那里，我们实际上使用了一些真正可变的
状态。但是，由于访问或修改一个可变
变量不是引用透明操作，
此类操作必须在 `IO` 内执行。
除此之外，没有什么能阻止我们在我们代码中使用可变变量。必要的函数可从 *base* 库中的模块 `Data.IORef` 获得。

作为一个快速练习，尝试实现一个函数，它 - 给定 `IORef Nat` - 将值与当前值配对
索引并在之后增加索引。

下面看我将如何做到这一点：

```idris
pairWithIndexIO : IORef Nat -> a -> IO (Nat,a)
pairWithIndexIO ref va = do
  ix <- readIORef ref
  writeIORef ref (S ix)
  pure (ix,va)
```

注意，每次我们 *运行* `pairWithIndexIO ref`，
`ref` 中存储的自然数加一。
另外，查看 `pairWithIndexIO ref` 的类型：`a -> IO (Nat,a)`。
我们希望将这种副作用的计算应用于在一个列表中每个元素，这应该会导致一个包含在 `IO` 中的新列表，
因为所有这些都描述了一个单一的计算
副作用。但这 *正是* `traverse` 的作用：我们的
输入类型是 `a`，我们的输出类型是 `(Nat,a)`，我们的
容器类型为`List`，副作用类型为`IO`！

```idris
zipListWithIndexIO : IORef Nat -> List a -> IO (List (Nat,a))
zipListWithIndexIO ref = traverse (pairWithIndexIO ref)
```

现在 *这个* 真的很强大：我们可以应用相同的函数
到 *任意* 可遍历的数据结构。因此它使
将 `zipListWithIndexIO` 专门用于
仅列出：

```idris
zipWithIndexIO : Traversable t => IORef Nat -> t a -> IO (t (Nat,a))
zipWithIndexIO ref = traverse (pairWithIndexIO ref)
```

为了更取悦我们的智力，这里是
无参风格的相同函数：

```idris
zipWithIndexIO' : Traversable t => IORef Nat -> t a -> IO (t (Nat,a))
zipWithIndexIO' = traverse . pairWithIndexIO
```

现在剩下要做的就是在将其传递给 `zipWithIndexIO` 之前初始化一个新的可变变量：

```idris
zipFromZeroIO : Traversable t => t a -> IO (t (Nat,a))
zipFromZeroIO ta = newIORef 0 >>= (`zipWithIndexIO` ta)
```

很快，让我们在 REPL 上试一试：

```repl
> :exec zipFromZeroIO {t = List} ["hello", "world"] >>= printLn
[(0, "hello"), (1, "world")]
> :exec zipFromZeroIO (Just 12) >>= printLn
Just (0, 12)
> :exec zipFromZeroIO {t = Vect 2} ["hello", "world"] >>= printLn
[(0, "hello"), (1, "world")]
```

因此，对于所有可遍历的容器类型，我们解决了用索引一次性标记每个元素的问题。

### 状态单子

唉，虽然上面提出的解决方案很优雅，表现也非常好，但它仍然带有 `IO` 污渍，
如果我们已经在 `IO` 土地上就还好，否则这是不可接受的。我们不想让我们原本纯粹的函数只是为了一个简单有状态元素标记的情况就让测试和推理变得困难。

幸运的是，有一个使用可变引用的替代方法，
这使我们能够保持我们的计算纯粹和
不受污染。然而，自己的替代方案要做到这一点并不容易，而且很难弄清楚这是怎么回事，所以我会尝试慢慢介绍。
我们首先需要问自己 “有状态” 的本质是什么，否则什么是纯计算。那是两个基本成分：

1. 访问 *当前* 状态。对于纯函数，这意味着该函数应将当前状态作为其参数之一。
2. 能够将更新的状态传达给以后的有状态计算。在纯函数的情况下，这意味着该函数将返回一对值：计算的结果加上更新的状态。

这两个先决条件导致以泛型，
用于在状态上运行的纯的有状态计算的类型，输入 `st` 并生成 `a` 类型的值 ：

```idris
Stateful : (st : Type) -> (a : Type) -> Type
Stateful st a = st -> (st, a)
```

我们的用例是将元素与索引配对，
可以实现为纯粹的、有状态的计算，如下所示：

```idris
pairWithIndex' : a -> Stateful Nat (Nat,a)
pairWithIndex' v index = (S index, (index,v))
```

注意，我们如何同时增加索引，返回
增加的值作为新状态，同时配对第一个参数与原始索引。

现在，需要注意一件重要的事情：虽然 `Stateful` 是一个有用的类型别名，Idris 通常 *不会* 解析函数类型的接口实现。如果我们想围绕这种类型编写一个小型实用函数库，
因此，最好将其包装在单构造函数数据类型中，并且
使用它作为我们编写更复杂计算的构建块。因此，我们将记录 `State` 引入为
纯粹的有状态计算的包装器：

```idris
record State st a where
  constructor ST
  runST : st -> (st,a)
```

我们现在可以用 `State` 来实现 `pairWithIndex` ，如下所示：

```idris
pairWithIndex : a -> State Nat (Nat,a)
pairWithIndex v = ST $ \index => (S index, (index, v))
```

此外，我们还可以定义更多的工具函数。这里是一个用于获取当前状态而不修改它的函数（这对应于 `readIORef`）：

```idris
get : State st st
get = ST $ \s => (s,s)
```

这是另外两个，用于覆盖当前状态。这些
对应 `writeIORef` 和 `modifyIORef`：

```idris
put : st -> State st ()
put v = ST $ \_ => (v,())

modify : (st -> st) -> State st ()
modify f = ST $ \v => (f v,())
```

最后，我们可以定义除用于运行有状态计算 `runST` 之外的三个函数

```idris
runState : st -> State st a -> (st, a)
runState = flip runST

evalState : st -> State st a -> a
evalState s = snd . runState s

execState : st -> State st a -> st
execState s = fst . runState s
```

所有这些都是单独有用的，但真正的力量
`State s` 来自观察它是一个单子。
在继续之前，请花一些时间尝试自己实现 `Functor`、`Applicative` 和 `Monad` 用于 `State s`。
即使你没有成功，你也会过得更轻松了解下面的实现是如何工作的。

```idris
Functor (State st) where
  map f (ST run) = ST $ \s => let (s2,va) = run s in (s2, f va)

Applicative (State st) where
  pure v = ST $ \s => (s,v)

  ST fun <*> ST val = ST $ \s =>
    let (s2, f)  = fun s
        (s3, va) = val s2
     in (s3, f va)

Monad (State st) where
  ST val >>= f = ST $ \s =>
    let (s2, va) = val s
     in runST (f va) s2
```

这可能需要一些时间来消化，所以我们稍后稍微高级的练习时会回顾它。最需要注意的是，
我们每个状态值只使用一次。我们*必须*确保将更新后的状态传递给以后的计算，否则有关状态更新的信息就会丢失。这个可以最好在 `Applicative` 的实现中看到：初始状态 `s` 用于计算函数值，这也将返回一个更新的状态，`s2` 用于计算函数参数。这将再次返回一个更新的状态，`s3`，它连同将 `f` 应用于 `va` 的结果被传递给以后的有状态计算。

### 练习第 2 部分

本节包括两个扩展练习，目的是
其中是为了增加你对状态单子的理解。
在第一个练习中，我们将研究随机值生成，
有状态计算的经典应用。
在第二个练习中，我们将看基于状态单子的一个索引版本，它允许我们在计算过程中不仅改变状态的值以及它的 *类型*。

1. 下面是一个简单的伪随机数生成器的实现。我们称其为 *伪随机*
   数字生成器，因为这些数字看起来非常随机，但生成是可预测的。如果我们用真正的随机种子初始化一系列这样的计算，我们库的大多数用户将无法预测我们的计算结果。

   ```idris
   rnd : Bits64 -> Bits64
   rnd seed = fromInteger
            $ (437799614237992725 * cast seed) `mod` 2305843009213693951
   ```

   这里的意思是，下一个伪随机数是从上一个伪随机数计算出来的。但一旦我们考虑如何使用这些数字作为种子来计算其他类型的随机值，我们就会意识到这些只是有状态的计算。因此，我们可以将随机值生成器的别名写为有状态计算：

   ```idris
   Gen : Type -> Type
   Gen = State Bits64
   ```

   在开始之前，请注意 `rnd` 不是很强的
   伪随机数发生器。它不会在完整的 64 位区间生成值，在密码应用程序中使用也不安全 。然而对我们本章的目的来说足够了，
   。另请注意，我们可以将 `rnd` 替换为更强的
   生成器，无需对您将作为本练习的一部分实现的函数进行任何更改
   。

   1. 根据 `rnd` 实现 `bits64`。这应该返回当前状态，然后通过调用函数 `rnd`
      对其进行更新。确保状态已正确更新，否则将无法按预期运行。

      ```idris
      bits64 : Gen Bits64
      ```

      这将是我们的 *仅限* 原语的生成器，从中
      我们将推导出所有其他的。所以，
      在你继续之前， 在 REPL 中快速测试你的 `bits64` 实现：

      ```repl
      Solutions.Traverse> runState 100 bits64
      (2274787257952781382, 100)
      ```

   2. 实现 `range64` 以在 `[0,upper]` 范围内生成随机值。提示：在你的实现中使用 `bits64` 和 `mod`
      但确保处理 `mod x upper` 在 `[0,upper)` 区间生成。

      ```idris
      range64 : (upper : Bits64) -> Gen Bits64
      ```

      同样的, 实现 `interval64` 来生成区间为 `[min a b, max a b]` 的值:

      ```idris
      interval64 : (a,b : Bits64) -> Gen Bits64
      ```

      最后，为任意整数类型实现 `interval`。

      ```idris
      interval : Num n => Cast n Bits64 => (a,b : n) -> Gen n
      ```

      请注意， `interval` 不会生成给定的间隔所有可能的值
      ，只会生成`[0,2305843009213693950]` 范围内 `Bits64` 的值。

   3. 实现随机布尔值的生成器。

   4. 为 `Fin n` 实现一个生成器。您必须仔细考虑如何让这个进行类型检查并在不作弊的情况下被整体检查器接受。注意：查看函数
      `Data.Fin.natToFin`。

   5. 实现一个生成器，用于从值向量中选择一个随机元素。在您的实现中使用练习 4 中的生成器。

   6. 实现 `vect` 和 `list`。在 `list` 的情况下，第一个参数应该用于随机确定列表的长度。

      ```idris
      vect : {n : _} -> Gen a -> Gen (Vect n a)

      list : Gen Nat -> Gen a -> Gen (List a)
      ```

      使用`vect`实现工具函数`testGen` ，
      并在 REPL 测试你的生成器：

      ```idris
      testGen : Bits64 -> Gen a -> Vect 10 a
      ```

   7. 实现 `choice`.

      ```idris
      choice : {n : _} -> Vect (S n) (Gen a) -> Gen a
      ```

   8. 实现 `either`.

      ```idris
      either : Gen a -> Gen b -> Gen (Either a b)
      ```

   9. 为可打印的 ASCII 字符实现生成器。这些是 ASCII 码在区间 `[32,126]` 中的字符。提示：*Prelude* 中的函数
      `chr` 在这里很有用。

   10. 实现一个字符串生成器。提示：*Prelude* 中的函数 `pack` 可能对此有用。

       ```idris
       string : Gen Nat -> Gen Char -> Gen String
       ```

   11. 我们不应该忘记我们在 Idris 的类型中编码有趣事物的能力，因此，为了挑战，事不宜迟，实现 `hlist`（注意 `HListF` 和
       `HList`）。如果您对依赖类型比较陌生，这可能需要一点时间来消化，所以不要忘记使用孔。

       ```idris
       data HListF : (f : Type -> Type) -> (ts : List Type) -> Type where
         Nil  : HListF f []
         (::) : (x : f t) -> (xs : HLift f ts) -> HListF f (t :: ts)

       hlist : HListF Gen ts -> Gen (HList ts)
       ```

   12. 泛化 `hlist` 以与任何应用函子一起工作，而不仅仅是 `Gen`.

   如果你到了这里，请意识到我们现在如何生成大多数原语的伪随机值，以及常规的 sum- 和 product 类型。
   这是一个示例 REPL 会话：

   ```repl
   > testGen 100 $ hlist [bool, printableAscii, interval 0 127]
   [[True, ';', 5],
    [True, '^', 39],
    [False, 'o', 106],
    [True, 'k', 127],
    [False, ' ', 11],
    [False, '~', 76],
    [True, 'M', 11],
    [False, 'P', 107],
    [True, '5', 67],
    [False, '8', 9]]
   ```

   最后的评论：伪随机值生成器在基于属性的测试库中起着重要作用，如 [QuickCheck](https://hackage.haskell.org/package/QuickCheck)
   或 [Hedgehog](https://github.com/stefan-hoeck/idris2-hedgehog)。
   基于属性的测试的思想是针对大量随机生成的参数的纯函数测试预定义的*属性*，
   为 *所有* 可能的参数获得有关这些属性的有力保证。一个例子是验证
   将列表反转两次的结果等于原始列表的测试。
   虽然不需要测试可以直接证明 Idris 中的许多更简单的属性，一旦涉及函数这不再可能，因为在统一期间不会减少，
   例如外部函数调用或其他模块未公开导出的函数。

2. 虽然 `State s a` 为我们提供了一种讨论有状态计算的便捷方式，但它只允许我们改变状态的 *值* 而不是它的
   *类型*。例如，下面的函数不能封装在 `State` 中，因为状态的类型发生了变化：

   ```idris
   uncons : Vect (S n) a -> (Vect n a, a)
   uncons (x :: xs) = (xs, x)
   ```

   你的任务是提出一个新的状态类型，允许
   此类更改（有时称为 *索引* 状态数据类型）。
   这个练习的目的也是为了提高你的技能
   在类型级别表达事物，包括派生函数
   类型和接口。因此，我只会付出一点点
   指导如何去做。如果您遇到困难，请随时
   查看解决方案，但确保只查看类型
   首先。


   1. Come up with a parameterized data type for encapsulating stateful
      computations where the input and output state type can differ. It must
      be possible to wrap `uncons` in a value of this type.

   2. Implement `Functor` for your indexed state type.

   3. It is not possible to implement `Applicative` for this *indexed* state
      type (but see also exercise 2.vii).  Still, implement the necessary
      functions to use it with idom brackets.

   4. It is not possible to implement `Monad` for this indexed state
      type. Still, implement the necessary functions to use it in do blocks.

   5. Generalize the functions from exercises 3 and 4 with two new
      interfaces `IxApplicative` and `IxMonad` and provide implementations
      of these for your indexed state data type.

   6. Implement functions `get`, `put`, `modify`, `runState`, `evalState`,
      and `execState` for the indexed state data type. Make sure to adjust
      the type parameters where necessary.

   7. Show that your indexed state type is strictly more powerful than
      `State` by implementing `Applicative` and `Monad` for it.

      Hint: Keep the input and output state identical. Note also,
      that you might need to implement `join` manually if Idris
      has trouble inferring the types correctly.

   Indexed state types can be useful when we want to make sure that
   stateful computations are combined in the correct sequence, or
   that scarce resources get cleaned up properly. We might get back
   to such use cases in later examples.

## The Power of Composition

After our excursion into the realms of stateful computations, we
will go back and combine mutable state with error accumulation
to tag and read CSV lines in a single traversal. We already
defined `pairWithIndex` for tagging lines with their indices.
We also have `uncurry $ hdecode ts` for decoding single tagged lines.
We can now combine the two effects in a single computation:

```idris
tagAndDecode :  (0 ts : List Type)
             -> CSVLine (HList ts)
             => String
             -> State Nat (Validated CSVError (HList ts))
tagAndDecode ts s = uncurry (hdecode ts) <$> pairWithIndex s
```

Now, as we learned before, applicative functors are closed under
composition, and the result of `tagAndDecode` is a nesting
of two applicatives: `State Nat` and `Validated CSVError`.
The *Prelude* exports a corresponding named interface implementation
(`Prelude.Applicative.Compose`), which we can use for traversing
a list of strings with `tagAndDecode`.
Remember, that we have to provide named implementations explicitly.
Since `traverse` has the applicative functor as its
second constraint, we also need to provide the first
constraint (`Traversable`) explicitly. But this
is going to be the unnamed default implementation! To get our hands on such
a value, we can use the `%search` pragma:

```idris
readTable :  (0 ts : List Type)
          -> CSVLine (HList ts)
          => List String
          -> Validated CSVError (List $ HList ts)
readTable ts = evalState 1 . traverse @{%search} @{Compose} (tagAndDecode ts)
```

This tells Idris to use the default implementation for the
`Traversable` constraint, and `Prelude.Applicatie.Compose` for the
`Applicative` constraint.
While this syntax is not very nice, it doesn't come up too often, and
if it does, we can improve things by providing custom functions
for better readability:

```idris
traverseComp : Traversable t
             => Applicative f
             => Applicative g
             => (a -> f (g b))
             -> t a
             -> f (g (t b))
traverseComp = traverse @{%search} @{Compose}

readTable' :  (0 ts : List Type)
           -> CSVLine (HList ts)
           => List String
           -> Validated CSVError (List $ HList ts)
readTable' ts = evalState 1 . traverseComp (tagAndDecode ts)
```

Note, how this allows us to combine two computational effects
(mutable state and error accumulation) in a single list traversal.

But I am not yet done demonstrating the power of composition. As you showed
in one of the exercises, `Traversable` is also closed under composition,
so a nesting of traversables is again a traversable. Consider the following
use case: When reading a CSV file, we'd like to allow lines to be
annotated with additional information. Such annotations could be
mere comments but also some formatting instructions or other
custom data tags might be feasible.
Annotations are supposed to be separated from the rest of the
content by a single hash character (`#`).
We want to keep track of these optional annotations
so we come up with a custom data type encapsulating
this distinction:

```idris
data Line : Type -> Type where
  Annotated : String -> a -> Line a
  Clean     : a -> Line a
```

This is just another container type and we can
easily implement `Traversable` for `Line` (do this yourself as
a quick exercise):

```idris
Functor Line where
  map f (Annotated s x) = Annotated s $ f x
  map f (Clean x)       = Clean $ f x

Foldable Line where
  foldr f acc (Annotated _ x) = f x acc
  foldr f acc (Clean x)       = f x acc

Traversable Line where
  traverse f (Annotated s x) = Annotated s <$> f x
  traverse f (Clean x)       = Clean <$> f x
```

Below is a function for parsing a line and putting it in its
correct category. For simplicity, we just split the line on hashes:
If the result consists of exactly two strings, we treat the second
part as an annotation, otherwise we treat the whole line as untagged
CSV content.

```idris
readLine : String -> Line String
readLine s = case split ('#' ==) s of
  h ::: [t] => Annotated t h
  _         => Clean s
```

We are now going to implement a function for reading whole
CSV tables, keeping track of line annotations:

```idris
readCSV :  (0 ts : List Type)
        -> CSVLine (HList ts)
        => String
        -> Validated CSVError (List $ Line $ HList ts)
readCSV ts = evalState 1
           . traverse @{Compose} @{Compose} (tagAndDecode ts)
           . map readLine
           . lines
```

Let's digest this monstrosity. This is written in point-free
style, so we have to read it from end to beginning. First, we
split the whole string at line breaks, getting a list of strings
(function `Data.String.lines`). Next, we analyze each line,
keeping track of optional annotations (`map readLine`).
This gives us a value of type `List (Line String)`. Since
this is a nesting of traversables, we invoke `traverse`
with a named instance from the *Prelude*: `Prelude.Traversable.Compose`.
Idris can disambiguate this based on the types, so we can
drop the namespace prefix. But the effectful computation
we run over the list of lines results in a composition
of applicative functors, so we also need the named implementation
for compositions of applicatives in the second
constraint (again without need of an explicit
prefix, which would be `Prelude.Applicative` here).
Finally, we evaluate the stateful computation with `evalState 1`.

Honestly, I wrote all of this without verifying if it works,
so let's give it a go at the REPL. I'll provide two
example strings for this, a valid one without errors, and
an invalid one. I use *multiline string literals* here, about which
I'll talk in more detail in a later chapter. For the moment,
note that these allow us to conveniently enter string literals
with line breaks:

```idris
validInput : String
validInput = """
  f,12,-13.01#this is a comment
  t,100,0.0017
  t,1,100.8#color: red
  f,255,0.0
  f,24,1.12e17
  """

invalidInput : String
invalidInput = """
  o,12,-13.01#another comment
  t,100,0.0017
  t,1,abc
  f,256,0.0
  f,24,1.12e17
  """
```

And here's how it goes at the REPL:

```repl
Tutorial.Traverse> readCSV [Bool,Bits8,Double] validInput
Valid [Annotated "this is a comment" [False, 12, -13.01],
       Clean [True, 100, 0.0017],
       Annotated "color: red" [True, 1, 100.8],
       Clean [False, 255, 0.0],
       Clean [False, 24, 1.12e17]]

Tutorial.Traverse> readCSV [Bool,Bits8,Double] invalidInput
Invalid (Append (FieldError 1 1 "o")
  (Append (FieldError 3 3 "abc") (FieldError 4 2 "256")))
```

It is pretty amazing how we wrote dozens of lines of
code, always being guided by the type- and totality
checkers, arriving eventually at a function for parsing
properly typed CSV tables with automatic line numbering and
error accumulation, all of which just worked on first try.

### 练习第 3 部分

The *Prelude* provides three additional interfaces for
container types parameterized over *two* type parameters
such as `Either` or `Pair`: `Bifunctor`, `Bifoldable`,
and `Bitraversable`. In the following exercises we get
some hands-one experience working with these. You are
supposed to look up what functions they provide
and how to implement and use them yourself.

1. Assume we'd like to not only interpret CSV content but also the optional
   comment tags in our CSV files.  For this, we could use a data type such
   as `Tagged`:

   ```idris
   data Tagged : (tag, value : Type) -> Type where
     Tag  : tag -> value -> Tagged tag value
     Pure : value -> Tagged tag value
   ```

   Implement interfaces `Functor`, `Foldable`, and `Traversable`
   but also `Bifunctor`, `Bifoldable`, and `Bitraversable`
   for `Tagged`.

2. Show that the composition of a bifunctor with two functors such as
   `Either (List a) (Maybe b)` is again a bifunctor by defining a dedicated
   wrapper type for such compositions and writing a corresponding
   implementation of `Bifunctor`.  Likewise for `Bifoldable`/`Foldable` and
   `Bitraversable`/`Traversable`.

3. Show that the composition of a functor with a bifunctor such as `List
   (Either a b)` is again a bifunctor by defining a dedicated wrapper type
   for such compositions and writing a corresponding implementation of
   `Bifunctor`.  Likewise for `Bifoldable`/`Foldable` and
   `Bitraversable`/`Traversable`.

4. We are now going to adjust `readCSV` in such a way that it decodes
   comment tags and CSV content in a single traversal.  We need a new error
   type to include invalid tags for this:

   ```idris
   data TagError : Type where
     CE         : CSVError -> TagError
     InvalidTag : (line : Nat) -> (tag : String) -> TagError
     Append     : TagError -> TagError -> TagError

   Semigroup TagError where (<+>) = Append
   ```

   For testing, we also define a simple data type for color tags:

   ```idris
   data Color = Red | Green | Blue
   ```

   You should now implement the following functions, but
   please note that while `readColor` will need to
   access the current line number in case of an error,
   it must *not* increase it, as otherwise line numbers
   will be wrong in the invocation of `tagAndDecodeTE`.

   ```idris
   readColor : String -> State Nat (Validated TagError Color)

   readTaggedLine : String -> Tagged String String

   tagAndDecodeTE :  (0 ts : List Type)
                  -> CSVLine (HList ts)
                  => String
                  -> State Nat (Validated TagError (HList ts))
   ```

   Finally, implement `readTagged` by using the wrapper type
   from exercise 3 as well as `readColor` and `tagAndDecodeTE`
   in a call to `bitraverse`.
   The implementation will look very similar to `readCSV` but
   with some additional wrapping and unwrapping at the right
   places.

   ```idris
   readTagged :  (0 ts : List Type)
              -> CSVLine (HList ts)
              => String
              -> Validated TagError (List $ Tagged Color $ HList ts)
   ```

   Test your implementation with some example strings at the REPL.


You can find more examples for functor/bifunctor compositions
in Haskell's [bifunctors](https://hackage.haskell.org/package/bifunctors)
package.

## 结论

Interface `Traversable` and its main function `traverse` are incredibly
powerful forms of abstraction - even more so, because both `Applicative`
and `Traversable` are closed under composition. If you are interested
in additional use cases, the publication, which
introduced `Traversable` to Haskell, is a highly recommended read:
[The Essence of the Iterator Pattern](https://www.cs.ox.ac.uk/jeremy.gibbons/publications/iterator.pdf)

The *base* library provides an extended version of the
state monad in module `Control.Monad.State`. We will look
at this in more detail when we talk about monad transformers.
Please note also, that `IO` itself is implemented as a
[simple state monad](IO.md#how-io-is-implemented)
over an abstract, primitive state type: `%World`.

Here's a short summary of what we learned in this chapter:

* Function `traverse` is used to run effectful computations over container
  types without affecting their size or shape.
* We can use `IORef` as mutable references in stateful computations running
  in `IO`.
* For referentially transparent computations with "mutable" state, the
  `State` monad is extremely useful.
* Applicative functors are closed under composition, so we can run several
  effectful computations in a single traversal.
* Traversables are also closed under composition, so we can use `traverse`
  to operate on a nesting of containers.

For now, this concludes our introduction of the *Prelude*'s
higher-kinded interfaces, which started with the introduction of
`Functor`, `Applicative`, and `Monad`, before moving on to `Foldable`,
and - last but definitely not least - `Traversable`.
There's one still missing - `Alternative` - but this will
have to wait a bit longer, because we need to first make
our brains smoke with some more type-level wizardry.

<!-- vi: filetype=idris2
-->
