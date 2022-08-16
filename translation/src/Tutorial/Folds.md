# 递归和折叠

在本章中，我们将仔细研究我们通常使用 *容器类型* 执行的计算：参数化数据类型，如 `List`、`Maybe` 或 `Identity`，保存参数类型的零个或多个值。其中许多函数本质上是递归的，因此我们首先讨论一般的递归，特别是尾递归作为一种重要的优化技术。这部分中的大多数递归函数将描述列表上的纯迭代。

它是递归函数，其完全性很难确定，因此我们接下来将快速查看完全性检查器并了解它何时会拒绝接受一个函数作为完全函数以及如何处理。

最后，我们将从第一部分开始寻找递归函数中的常见模式，并最终引入一个用于消费容器类型的新接口：接口 `Foldable`。

```idris
module Tutorial.Folds

import Data.List1
import Data.Maybe
import Data.Vect
import Debug.Trace

%default total
```

## 递归

在本节中，我们将仔细研究一般的递归，特别是尾递归。

递归函数是函数，它们调用自己来重复任务或计算，直到某个中止条件（称为 *基本情况*）成立。请注意，它是递归函数，因此很难验证完全性：非递归函数，即 *全覆盖*（它们涵盖了模式匹配中的所有可能情况）如果它们只调用其他函数，它们就会自动为完全的。

这是一个递归函数的例子：它生成一个给定长度的列表，用相同的值填充它：

```idris
replicateList : Nat -> a -> List a
replicateList 0     _ = []
replicateList (S k) x = x :: replicateList k x
```

正如你所看到的（这个模块在顶部有 `%default total` pragma），这个函数可以证明是完全的。 Idris 验证 `Nat` 参数在每次递归调用中 *严格缩小*，因此，函数 *肯定会* 最终结束。当然，我们可以对 `Vect` 做同样的事情，我们甚至可以证明结果向量的长度与给定的自然数匹配：

```idris
replicateVect : (n : Nat) -> a -> Vect n a
replicateVect 0     _ = []
replicateVect (S k) x = x :: replicateVect k x
```

虽然我们经常使用递归来 *创建* 数据类型的值，例如 `List` 或 `Vect`，当我们 *使用* 此类值时，我们也会使用递归，例如，这是一个计算列表长度的函数：

```idris
len : List a -> Nat
len []        = 0
len (_ :: xs) = 1 + len xs
```

同样，Idris 可以验证 `len` 是完全的，因为我们在递归情况下传递的列表严格小于原始列表参数。

但是什么时候递归函数是非全部的？这是一个示例：以下函数创建一系列值，直到给定的生成函数 (`gen`) 返回 `Nothing`。请注意，我们如何使用 *状态* 值（通用类型 `s`）并使用 `gen` 来计算一个值以及下一个状态：

```idris
covering
unfold : (gen : s -> Maybe (s,a)) -> s -> List a
unfold gen vs = case gen vs of
  Just (vs',va) => va :: unfold gen vs'
  Nothing       => []
```

使用 `unfold`，Idris 无法验证其任何论点是否收敛于基本情况。因此，它理所当然地拒绝接受 `unfold` 是完全的。事实上，下面的函数会生成一个无限列表（所以请不要尝试在 REPL 中检查它，因为这样做会消耗您计算机的所有内存）：

```idris
fiboHelper : (Nat,Nat) -> ((Nat,Nat),Nat)
fiboHelper (f0,f1) = ((f1, f0 + f1), f0)

covering
fibonacci : List Nat
fibonacci = unfold (Just . fiboHelper) (1,1)
```

为了安全地创建一个（有限）斐波那契数列，我们需要确保生成该序列的函数将在有限步数后停止，例如通过限制列表的长度：

```idris
unfoldTot : Nat -> (gen : s -> Maybe (s,a)) -> s -> List a
unfoldTot 0     _   _  = []
unfoldTot (S k) gen vs = case gen vs of
  Just (vs',va) => va :: unfoldTot k gen vs'
  Nothing       => []

fibonacciN : Nat -> List Nat
fibonacciN n = unfoldTot n (Just . fiboHelper) (1,1)
```

### 调用栈

为了演示尾递归是什么，我们需要以下 `main` 函数：

```idris
main : IO ()
main = printLn . len $ replicateList 10000 10
```

如果您的系统上安装了 [Node.js](https://nodejs.org/en/)，您可以尝试以下实验。使用 Idris 的 *Node.js* 后端而不是默认的 *Chez Scheme* 后端编译并运行此模块，并使用 Node.js 二进制文件运行生成的 JavaScript 源文件：

```sh
idris2 --cg node -o test.js --find-ipkg -src/Tutorial/Folds.md
node build/exec/test.js
```

Node.js 将失败并显示以下错误消息和冗长的堆栈跟踪：`RangeError: Maximum call stack size exceeded`。这里发生了什么？ `main` 怎么会失败并出现异常，尽管它可以证明是完全的？

首先，记住一个函数是完全的意味着它最终会在有限的时间内产生一个给定类型的值，*给定足够的资源，比如计算机内存*。在这里，`main` 没有获得足够的资源，因为 Node.js 在其调用堆栈上的大小限制非常小。 *调用堆栈* 可以被认为是一个堆栈数据结构（先进后出），其中放置了嵌套的函数调用。在递归函数的情况下，堆栈大小随着每个递归函数调用而增加一。对于我们的 `main` 函数，我们创建并使用长度为 10'000 的列表，因此调用堆栈将在调用之前至少保存 10'000 个函数调用，并且堆栈的大小再次减小.这远远超出了 Node.js 的堆栈大小限制，因此出现了溢出错误。

现在，在我们研究如何规避此问题的解决方案之前，请注意，在使用 Idris 的 JavaScript 后端时，这是一个非常严重且限制性的错误来源。在 Idris 中，由于无法访问 `for` 或 `while` 循环等控制结构，我们 *总是* 必须求助于递归来描述迭代计算。幸运的是（或者我应该说“不幸”，否则这个问题已经得到了严肃的解决），Scheme 后端没有这个问题，因为它们的堆栈大小限制要大得多，并且它们在内部执行各种优化以防止调用堆栈溢出。

### 尾递归

如果所有递归调用都发生在 *尾部位置* 处，则称递归函数为 *尾递归*：（子）表达式中的最后一个函数调用。例如，以下版本的 `len` 是尾递归的：

```idris
lenOnto : Nat -> List a -> Nat
lenOnto k []        = k
lenOnto k (_ :: xs) = lenOnto (k + 1) xs
```

将此与上面定义的 `len` 进行比较：最后一个函数调用是对运算符 `(+)` 的调用，递归调用发生在它的一个参数中：

```repl
len (_ :: xs) = 1 + len xs
```

我们可以使用 `lenOnto` 作为实用程序来实现 `len` 的尾递归版本，而无需额外的 `Nat` 参数：

```idris
lenTR : List a -> Nat
lenTR = lenOnto 0
```

这是编写尾递归函数时的常见模式：我们通常添加一个额外的函数参数来累积中间结果，然后在每次递归调用时显式传递。例如，这里是 `replicateList` 的尾递归版本：

```idris
replicateListTR : Nat -> a -> List a
replicateListTR n v = go Nil n
  where go : List a -> Nat -> List a
        go xs 0     = xs
        go xs (S k) = go (v :: xs) k
```

尾递归函数的一大优点是，它们可以通过 Idris 编译器轻松转换为高效的命令式循环，因此是 *堆栈安全* 的：递归函数调用 *不会* 添加到调用堆栈，从而避免了可怕的堆栈溢出错误。

```idris
main1 : IO ()
main1 = printLn . lenTR $ replicateListTR 10000 10
```

我们可以使用 *Node.js* 后端再次运行 `main1`。这一次，我们使用稍有不同的语法来执行除 `main` 以外的函数（请记住：美元前缀仅用于将终端命令与其输出区分开来。它不是您在终端会话输入的命令的一部分。）：

```sh
$ idris2 --cg node --exec main1 --find-ipkg src/Tutorial/Folds.md
10000
```

如您所见，这次计算完成并没有溢出调用堆栈。

尾递归函数允许由（可能是嵌套的）模式匹配组成，在几个分支的尾位置进行递归调用。这是一个例子：

```idris
countTR : (a -> Bool) -> List a -> Nat
countTR p = go 0
  where go : Nat -> List a -> Nat
        go k []        = k
        go k (x :: xs) = case p x of
          True  => go (S k) xs
          False => go k xs
```

请注意，`go` 的每次调用如何在其 case 表达式的分支中处于尾部位置。

### 相互递归

有时可以方便地实现几个相关的函数，它们以递归方式相互调用。在 Idris 中，与许多其他编程语言不同，函数必须在源文件中声明 *之后* 才能被其他函数调用，因为通常函数的实现必须在类型检查期间可用（因为 Idris 有依赖类型）。有两种方法可以解决这个问题，它们实际上会在编译器中产生相同的内部表示。我们的第一个选择是先写下函数的声明，然后是实现。这是一个愚蠢的例子：

```idris
even : Nat -> Bool

odd : Nat -> Bool

even 0     = True
even (S k) = odd k

odd 0     = False
odd (S k) = even k
```

如您所见，函数 `even` 被允许在其实现中调用函数 `odd`，因为 `odd` 已经被声明（但尚未实现）。

如果你和我一样，想保持声明和实现彼此相邻，你可以引入一个 `mutual` 块，它具有相同的效果。与其他代码块一样，`mutual` 块中的函数必须全部缩进相同数量的空格：

```idris
mutual
  even' : Nat -> Bool
  even' 0     = True
  even' (S k) = odd' k

  odd' : Nat -> Bool
  odd' 0     = False
  odd' (S k) = even' k
```

就像单个递归函数一样，如果所有递归调用都发生在尾部位置，则可以将相互递归函数优化为命令式循环。函数 `even` 和 `odd` 就是这种情况，可以在 *Node.js* 后端再次验证：

```idris
main2 : IO ()
main2 =  printLn (even 100000)
      >> printLn (odd 100000)
```

```sh
$ idris2 --cg node --exec main2 --find-ipkg src/Tutorial/Folds.md
True
False
```

### 最后的言论

在本节中，我们了解了递归和完全性检查的几个重要方面，总结如下：

* 在纯函数式编程中，递归是实现迭代过程的方式。

* 递归函数通过完全性检查器的条件为，如果它可以验证每个递归函数调用中的参数之一严格变小。

* 任意递归可能会导致堆栈大小限制较小的后端出现堆栈溢出异常。

* Idris 的 JavaScript 后端执行相互尾调用优化：尾递归函数被转换为堆栈安全的命令式循环。

请注意，并非您在野外遇到的所有 Idris 后端都会执行尾调用优化。请检查相应的文档。

还要注意，核心库中的大多数递归函数（*prelude* 和 *base*）还没有使用尾递归。这有一个重要原因：在许多情况下，非尾递归函数更容易在编译时证明中使用，因为它们比尾递归对应物更自然地统一。编译时证明是 Idris 编程的一个重要方面（我们将在后面的章节中看到），因此在运行时表现良好和编译时表现良好之间需要做出折衷。最终，要走的路可能是为大多数递归函数提供两种实现，使用 *转换规则* 告诉编译器在运行时使用优化版本，只要程序员在其代码中使用非优化版本。例如，已经为函数 `pack` 和 `unpack` 编写了这样的转换规则（它们在运行时使用 `fastPack` 和 `fastUnpack`；参见[以下源文件](https://github.com/idris-lang/Idris2/blob/main/libs/prelude/Prelude/Types.idr)中的相应规则。

### 练习第 1 部分

在这些练习中，您将实现几个递归函数。确保尽可能使用尾递归，并快速验证 REPL 中所有函数的正确行为。

1. 实现函数 `anyList` 和 `allList`，如果列表中的任何元素（或 `allList` 的所有元素）满足给定谓词：

   ```idris
   anyList : (a -> Bool) -> List a -> Bool

   allList : (a -> Bool) -> List a -> Bool
   ```

2. 实现函数 `findList`，它返回满足给定谓词的第一个值（如果有）：

   ```idris
   findList : (a -> Bool) -> List a -> Maybe a
   ```

3. 实现函数 `collectList`，它返回第一个值（如果有），给定函数为此返回一个 `Just`：

   ```idris
   collectList : (a -> Maybe b) -> List a -> Maybe b
   ```

   根据 `collectList` 实现 `lookupList`：

   ```idris
   lookupList : Eq a => a -> List (a,b) -> Maybe b
   ```

4. 对于像 `map` 或 `filter` 这样的函数，它们必须在不影响元素顺序的情况下循环遍历列表，因此很难编写尾递归实现。最安全的方法是使用
   `SnocList`（一种 *反转* 类型的列表，从头到尾而不是从尾到头构建）来累积中间结果。它的两个构造函数是 `Lin` 和
   `(:<)`（称为 *snoc* 运算符）。模块 `Data.SnocList` 导出两个尾递归运算符，称为 *fish* 和 *chips*
   (`(<><)` 和 `(<>>)`) 用于从 `SnocList` 到 `List`
   ，反之亦然。在继续练习之前，请查看所有新数据构造函数和运算符的类型。

   为 `List` 实现 `map` 的尾递归版本
   通过使用 `SnocList` 重新组装映射列表。然后使用
   带有 `Nil` 参数的 *chips* 运算符
   最后将 `SnocList` 转换回 `List`。

   ```idris
   mapTR : (a -> b) -> List a -> List b
   ```

5. 实现 `filter` 的尾递归版本，它只将那些值保存在列表中，满足给定的谓词。使用练习 4 中描述的相同技术。

   ```idris
   filterTR : (a -> Bool) -> List a -> List a
   ```

6. 实现 `mapMaybe` 的尾递归版本，它只将这些值保存在列表中，给定函数参数返回 `Just`：

   ```idris
   mapMaybeTR : (a -> Maybe b) -> List a -> List b
   ```

   根据 `mapMaybeTR` 实现 `catMaybesTR`：

   ```idris
   catMaybesTR : List (Maybe a) -> List a
   ```

7. 实现列表连接的尾递归版本：

   ```idris
   concatTR : List a -> List a -> List a
   ```

8. 为 `List` 实现 *bind* 和 `join` 的尾递归版本：

   ```idris
   bindTR : List a -> (a -> List b) -> List b

   joinTR : List (List a) -> List a
   ```

## 关于完全性检查的一些注意事项

Idris 中的完全性检查器验证递归调用中的至少一个（可能已删除！）参数收敛于基本情况。例如，对于自然数，如果基本情况为零（对应于数据构造函数 `Z`），我们在 `S k` 上进行模式匹配后继续 `k` , Idris 可以从 `Nat` 的构造函数派生，即 `k` 严格小于 `S k`，因此递归调用必须收敛于基本情况。当对列表进行模式匹配并仅在递归调用中继续其尾部时，使用完全相同的推理。

虽然这在许多情况下都有效，但并不总是按预期进行。下面，我将向您展示几个完全性检查失败的示例，尽管 *我们* 知道，所讨论的函数肯定是完全的。

### 案例 1：在原语上递归

Idris 对原语数据类型的内部结构一无所知。因此，以下函数虽然显然是完全的，但不会被完全性检查器接受：

```idris
covering
replicatePrim : Bits32 -> a -> List a
replicatePrim 0 v = []
replicatePrim x v = v :: replicatePrim (x - 1) v
```

与自然数 (`Nat`) 不同，自然数被定义为归纳数据类型并且仅在编译期间转换为整数原语，Idris 无法判断 `x - 1` 严格小于比 `x`，因此它无法验证这必须收敛到基本情况。 （原因是 `x - 1` 是根据原始函数 `prim__sub_Bits32` 实现的，它内置在编译器中，必须由每个后端单独实现。完全性检查器知道Idris 中定义的数据类型、构造函数和函数，但与后端实现的（原语）函数和外部函数无关。虽然理论上也可以为原语函数和外部函数定义和使用定律，但这还没有完成对于他们中的大多数情况。）

由于非完全性具有高度传染性（所有调用偏函数的函数本身都被完全性检查器认为是部分的），所以有实用函数 `assert_smaller`，我们可以使用它来说服完全性检查器并我们仍然使用 `total` 关键字注释函数：

```idris
replicatePrim' : Bits32 -> a -> List a
replicatePrim' 0 v = []
replicatePrim' x v = v :: replicatePrim' (assert_smaller x $ x - 1) v
```

但是请注意，每当您使用 `assert_smaller` 来使完全性检查器静音时，证明完全性的重任就落在了您的肩上。不这样做可能会导致任意和不可预测的程序行为（这是大多数其他编程语言的默认设置）。

#### Ex Falso Quodlibet

下面 - 作为演示 - 是 `Void` 的简单证明。 `Void`是*无人居住的类型*：没有值的类型。 *证明 `Void`* 意味着，我们实现了一个被完全性检查器接受的函数，它返回一个类型为 `Void` 的值，尽管这应该是不可能的，因为没有这样的值.这样做可以让我们完全禁用类型系统以及它提供的所有保证。这是代码及其可怕的后果：

```idris
-- 为了证明 `Void`，我们只是永远循环，使用
-- `assert_smaller` 使完全性检查器静音。
proofOfVoid : Bits8 -> Void
proofOfVoid n = proofOfVoid (assert_smaller n n)

-- 从 `Void` 类型的值开始，任何东西都会出现！
-- 这个函数是安全和完全的，因为没有
-- `Void` 类型的值！
exFalsoQuodlibet : Void -> a
exFalsoQuodlibet _ impossible

-- 通过将我们的无效证明传递给 `exFalsoQuodlibet`
--（由*Prelude*以`void`的名义导出），我们
-- 可以将任何值强制转换为任何其他类型的值。
-- 这使得类型检查完全没用，因为
-- 我们可以在不同的值之间自由转换
-- 类型。
coerce : a -> b
coerce _ = exFalsoQuodlibet (proofOfVoid 0)

-- 最后，我们用一个数字调用 `putStrLn`
-- 而不是一个字符串。 `coerce` 允许我们这样做。
pain : IO ()
pain = putStrLn $ coerce 0
```

请花点时间惊叹于可证明的完全函数 `coerce`：它声称将 *any* 值转换为 *any* 其他类型的值。而且它是完全安全的，因为它在实现中只使用了完全函数。问题是 - 当然 - `proofOfVoid` 永远不应该是一个完全的函数。

在 `pain` 中，我们使用 `coerce` 从整数变出一个字符串。最后，我们得到了我们应得的：程序因错误而崩溃。尽管情况可能会更糟，但定位此类错误的来源仍然非常耗时且令人讨厌。

```sh
$ idris2 --cg node --exec pain --find-ipkg src/Tutorial/Folds.md
ERROR: No clauses
```

因此，通过 `assert_smaller` 的一次轻率放置，我们在我们的纯代码库中造成了严重破坏，一举牺牲了完全性和类型安全性。因此：使用风险自负！

注意：我不希望你理解上面代码中所有的黑魔法。我将在适当的时候在另一章中解释细节。

第二注：*Ex falso quodlibet*，也称为[爆炸原理](https://en.wikipedia.org/wiki/Principle_of_explosion) 是经典逻辑中的一条定律：从矛盾中，任何陈述都可以被证明。在我们的例子中，矛盾在于我们对 `Void` 的证明：声称我们编写了一个产生这样一个值的完全函数，尽管 `Void` 是一种无人居住的类型。您可以通过在 REPL 中使用 `:doc Void` 检查 `Void` 来验证这一点：它没有数据构造函数。

### 案例 2：通过函数调用进行递归

下面是 [*玫瑰树*](https://en.wikipedia.org/wiki/Rose_tree) 的实现。玫瑰树可以表示计算机算法中的搜索路径，例如在图论中。

```idris
record Tree a where
  constructor Node
  value  : a
  forest : List (Tree a)

Forest : Type -> Type
Forest = List . Tree
```

我们可以尝试计算这样一棵树的大小，如下所示：

```idris
covering
size : Tree a -> Nat
size (Node _ forest) = S . sum $ map size forest
```

在上面的代码中，递归调用发生在 `map` 中。 *我们* 知道我们在递归调用中只使用子树（因为我们知道 `map` 是如何为 `List` 实现的），但 Idris 不知道这一点（教一个完全性检查器如何自己解决这个问题似乎是一个开放的研究问题）。所以它会拒绝接受这个函数是完全的。

有两种方法可以处理上述情况。如果我们不介意编写一些其他不需要的样板代码，我们可以使用显式递归。事实上，由于我们也经常使用搜索 *森林*，因此这是这里的首选方式。

```idris
mutual
  treeSize : Tree a -> Nat
  treeSize (Node _ forest) = S $ forestSize forest

  forestSize : Forest a -> Nat
  forestSize []        = 0
  forestSize (x :: xs) = treeSize x + forestSize xs
```

在上面的例子中，Idris 可以验证我们不会在它背后炸毁我们的树，因为我们清楚地知道每个递归步骤中发生的事情。这是解决此问题的安全、可取的方法，特别是如果您不熟悉语言和完全性检查。

但是，有时上面提出的解决方案写起来太麻烦了。例如，这里是玫瑰树的 `Show` 的实现：

```idris
Show a => Show (Tree a) where
  showPrec p (Node v ts) =
    assert_total $ showCon p "Node" (showArg v ++ showArg ts)
```

在这种情况下，我们必须为树列表手动重新实现 `Show`：这是一项乏味的任务——而且它本身很容易出错。相反，我们求助于使用强大的完全性检查大锤：`assert_total`。不用说，这会带来与 `assert_smaller` 相同的风险，所以要非常小心。

### 练习第 2 部分

以可证明的完整方式实现以下功能，而不会“作弊”。注意：没有必要以尾递归的方式实现这些。

<!-- textlint-disable terminology -->
1. 实现玫瑰树上的函数 `depth`。这个
   应该从当前节点到最远的子节点返回最大数量的 `Node` 构造函数。
   例如，当前节点在深度一，
   它的所有深度为二直接子节点，它们的
   深度三的直接子节点，依此类推。
<!-- textlint-enable -->

2. 为玫瑰树实现接口 `Eq`。

3. 为玫瑰树实现接口 `Functor`。

4. 为了它的乐趣：为玫瑰树实现接口`Show`。

5. 为了不忘记如何使用依赖类型进行编程，请实现函数 `treeToVect` 以将玫瑰树转换为正确大小的向量。

   提示：确保遵循与`treeSize` 的实现中相同的递归方案。否则，这可能是很难工作。

## Foldable 接口

当回顾我们在递归部分解决的所有练习时，列表中的大多数尾递归函数都遵循以下模式：从头到尾迭代所有列表元素，同时传递一些状态以累积中间结果。在列表的末尾，返回最终状态或使用附加函数调用对其进行转换。

### 左折叠

This is functional programming, and we'd like to abstract
over such reoccurring patterns. In order to tail recursively
iterate over a list, all we need is an accumulator function
and some initial state. But what should be the type of
the accumulator? Well, it combines the current state
with the list's next element and returns an updated
state: `state -> elem -> state`. Surely, we can come
up with a higher-order function to encapsulate this
behavior:

```idris
leftFold : (acc : state -> el -> state) -> (st : state) -> List el -> state
leftFold _   st []        = st
leftFold acc st (x :: xs) = leftFold acc (acc st x) xs
```

We call this function a *left fold*, as it iterates over
the list from left to right (head to tail), collapsing (or
*folding*) the list until just a single value remains.
This new value might still be a list or other container type,
but the original list has been consumed from head to tail.
Note how `leftFold` is tail recursive, and therefore all
functions implemented in terms of `leftFold` are
tail recursive (and thus, stack safe!) as well.

Here are a few examples:

```idris
sumLF : Num a => List a -> a
sumLF = leftFold (+) 0

reverseLF : List a -> List a
reverseLF = leftFold (flip (::)) Nil

-- this is more natural than `reverseLF`!
toSnocListLF : List a -> SnocList a
toSnocListLF = leftFold (:<) Lin
```

### Right Folds

The example functions we implemented in terms of `leftFold` had
to always completely traverse the whole list, as every single
element was required to compute the result. This is not always
necessary, however. For instance, if you look at `findList` from
the exercises, we could abort iterating over the list as soon
as our search was successful. It is *not* possible to implement
this more efficient behavior in terms of `leftFold`: There,
the result will only be returned when our pattern match reaches
the `Nil` case.

Interestingly, there is another, non-tail recursive fold, which
reflects the list structure more naturally, we can use for
breaking out early from an iteration. We call this a
*right fold*. Here is its implementation:

```idris
rightFold : (acc : el -> state -> state) -> state -> List el -> state
rightFold acc st []        = st
rightFold acc st (x :: xs) = acc x (rightFold acc st xs)
```

Now, it might not immediately be obvious how this differs from `leftFold`.
In order to see this, we will have to talk about lazy evaluation
first.

#### Lazy Evaluation in Idris

For some computations, it is not necessary to evaluate all function
arguments in order to return a result. For instance, consider
boolean operator `(&&)`: If the first argument evaluates to `False`,
we already know that the result is `False` without even looking at
the second argument. In such a case, we don't want to unnecessarily evaluate
the second argument, as this might include a lengthy computation.

Consider the following REPL session:

```repl
Tutorial.Folds> False && (length [1..10000000000] > 100)
False
```

If the second argument were evaluated, this computation would most
certainly blow up your computer's memory, or at least take a very long
time to run to completion. However, in this case, the result `False` is
printed immediately. If you look at the type of `(&&)`, you'll see
the following:

```repl
Tutorial.Folds> :t (&&)
Prelude.&& : Bool -> Lazy Bool -> Bool
```

As you can see, the second argument is wrapped in a `Lazy` type
constructor. This is a built-in type, and the details are handled
by Idris automatically most of the time. For instance, when passing
arguments to `(&&)`, we don't have to manually wrap the values in
some data constructor.
A lazy function argument will only be evaluated at the moment it
is *required* in the function's implementation, for instance,
because it is being pattern matched on, or it is being passed
as a strict argument to another function. In the implementation
of `(&&)`, the pattern match happens
on the first argument, so the second will only be evaluated if
the first argument is `True` and the second is returned as the function's
(strict) result.

There are two utility functions for working with lazy evaluation:
Function `delay` wraps a value in the `Lazy` data type. Note, that
the argument of `lazy` is strict, so the following might take
several seconds to print its result:

```repl
Tutorial.Folds> False && (delay $ length [1..10000] > 100)
False
```

In addition, there is function `force`, which forces evaluation
of a `Lazy` value.

#### Lazy Evaluation and Right Folds

We will now learn how to make use of `rightFold` and lazy evaluation
to implement folds, which can break out from iteration early.
Note, that in the implementation of `rightFold` the result of
folding over the remainder of the list is passed as an argument
to the accumulator (instead of the result of invoking the accumulator
being used in the recursive call):

```repl
rightFold acc st (x :: xs) = acc x (rightFold acc st xs)
```

If the second argument of `acc` were lazily evaluated, it would be possible
to abort the computation of `acc`'s result without having to iterate
till the end of the list:

```idris
foldHead : List a -> Maybe a
foldHead = force . rightFold first Nothing
  where first : a -> Lazy (Maybe a) -> Lazy (Maybe a)
        first v _ = Just v
```

Note, how Idris takes care of the bookkeeping of laziness most of the time. (It
doesn't handle the curried invocation of `rightFold` correctly, though, so we
either must pass on the list argument of `foldHead` explicitly, or compose
the curried function with `force` to get the types right.)

In order to verify that this works correctly, we need a debugging utility
called `trace` from module `Debug.Trace`. This "function" allows us to
print debugging messages to the console at certain points in our pure
code. Please note, that this is for debugging purposes only and should
never be left lying around in production code, as, strictly speaking,
printing stuff to the console breaks referential transparency.

Here is an adjusted version of `foldHead`, which prints "folded" to
standard output every time utility function `first` is being invoked:

```idris
foldHeadTraced : List a -> Maybe a
foldHeadTraced = force . rightFold first Nothing
  where first : a -> Lazy (Maybe a) -> Lazy (Maybe a)
        first v _ = trace "folded" (Just v)
```

In order to test this at the REPL, we need to know that `trace` uses `unsafePerformIO`
internally and therefore will not reduce during evaluation. We have to
resort to the `:exec` command to see this in action at the REPL:

```repl
Tutorial.Folds> :exec printLn $ foldHeadTraced [1..10]
folded
Just 1
```

As you can see, although the list holds ten elements, `first` is only called
once resulting in a considerable increase of efficiency.

Let's see what happens, if we change the implementation of `first` to
use strict evaluation:

```idris
foldHeadTracedStrict : List a -> Maybe a
foldHeadTracedStrict = rightFold first Nothing
  where first : a -> Maybe a -> Maybe a
        first v _ = trace "folded" (Just v)
```

Although we don't use the second argument in the implementation of `first`,
it is still being evaluated before evaluating the body of `first`, because
Idris - unlike Haskell! - defaults to use strict semantics. Here's how this
behaves at the REPL:

```repl
Tutorial.Folds> :exec printLn $ foldHeadTracedStrict [1..10]
folded
folded
folded
folded
folded
folded
folded
folded
folded
folded
Just 1
```

While this technique can sometimes lead to very elegant code, always
remember that `rightFold` is not stack safe in the general case. So,
unless your accumulator is not guaranteed to return a result after
not too many iterations, consider implementing your function
tail recursively with an explicit pattern match. Your code will be
slightly more verbose, but with the guaranteed benefit of stack safety.

### Folds and Monoids

Left and right folds share a common pattern: In both cases, we start
with an initial *state* value and use an accumulator function for
combining the current state with the current element. This principle
of *combining values* after starting from an *initial value* lies
at the heart of an interface we've already learned about: `Monoid`.
It therefore makes sense to fold a list over a monoid:

```idris
foldMapList : Monoid m => (a -> m) -> List a -> m
foldMapList f = leftFold (\vm,va => vm <+> f va) neutral
```

Note how, with `foldMapList`, we no longer need to pass an accumulator
function. All we need is a conversion from the element type to
a type with an implementation of `Monoid`. As we have already seen
in the chapter about [interfaces](Interfaces.md), there are *many*
monoids in functional programming, and therefore, `foldMapList` is
an incredibly useful function.

We could make this even shorter: If the elements in our list already
are of a type with a monoid implementation, we don't even need a
conversion function to collapse the list:

```idris
concatList : Monoid m => List m -> m
concatList = foldMapList id
```

### Stop Using `List` for Everything

And here we are, finally, looking at a large pile of utility functions
all dealing in some way with the concept of collapsing (or folding)
a list of values into a single result. But all of these folding functions
are just as useful when working with vectors, with non-empty lists, with
rose trees, even with single-value containers like `Maybe`, `Either e`,
or `Identity`. Heck, for the sake of completeness, they are even useful
when working with zero-value containers like `Control.Applicative.Const e`!
And since there are so many of these functions, we'd better look out for
an essential set of them in terms of which we can implement all
the others, and wrap up the whole bunch in an interface. This interface
is called `Foldable`, and is available from the `Prelude`. When you
look at its definition in the REPL (`:doc Foldable`), you'll see that
it consists of six essential functions:

* `foldr`, for folds from the right
* `foldl`, for folds from the left
* `null`, for testing if the container is empty or not
* `foldM`, for effectful folds in a monad
* `toList`, for converting the container to a list of values
* `foldMap`, for folding over a monoid

For a minimal implementation of `Foldable`, it is sufficient to only
implement `foldr`. However, consider implementing all six functions
manually, because folds over container types are often performance
critical operations, and each of them should be optimized accordingly.
For instance, implementing `toList` in terms of `foldr` for `List`
just makes no sense, as this is a non-tail recursive function
running in linear time complexity, while a hand-written implementation
can just return its argument without any modifications.

### 练习第 3 部分

In these exercises, you are going to implement `Foldable`
for different data types. Make sure to try and manually
implement all six functions of the interface.

1. Implement `Foldable` for `Crud i`:

   ```idris
   data Crud : (i : Type) -> (a : Type) -> Type where
     Create : (value : a) -> Crud i a
     Update : (id : i) -> (value : a) -> Crud i a
     Read   : (id : i) -> Crud i a
     Delete : (id : i) -> Crud i a
   ```

2. Implement `Foldable` for `Response e i`:

   ```idris
   data Response : (e, i, a : Type) -> Type where
     Created : (id : i) -> (value : a) -> Response e i a
     Updated : (id : i) -> (value : a) -> Response e i a
     Found   : (values : List a) -> Response e i a
     Deleted : (id : i) -> Response e i a
     Error   : (err : e) -> Response e i a
   ```

3. Implement `Foldable` for `List01`. Use tail recursion in the
   implementations of `toList`, `foldMap`, and `foldl`.

   ```idris
   data List01 : (nonEmpty : Bool) -> Type -> Type where
     Nil  : List01 False a
     (::) : a -> List01 False a -> List01 ne a
   ```

4. Implement `Foldable` for `Tree`. There is no need to use tail recursion
   in your implementations, but your functions must be accepted by the
   totality checker, and you are not allowed to cheat by using
   `assert_smaller` or `assert_total`.

   Hint: You can test the correct behavior of your implementations
   by running the same folds on the result of `treeToVect` and
   verify that the outcome is the same.

5. Like `Functor` and `Applicative`, `Foldable` composes: The product and
   composition of two foldable container types are again foldable container
   types. Proof this by implementing `Foldable` for `Comp` and `Product`:

   ```idris
   record Comp (f,g : Type -> Type) (a : Type) where
     constructor MkComp
     unComp  : f (g a)

   record Product (f,g : Type -> Type) (a : Type) where
     constructor MkProduct
     fst : f a
     snd : g a
   ```

## 结论

We learned a lot about recursion, totality checking, and folds
in this chapter, all of which are important concepts in pure
functional programming in general. Wrapping one's head
around recursion takes time and experience. Therefore - as
usual - try to solve as many exercises as you can.

In the next chapter, we are taking the concept of iterating
over container types one step further and look at
effectful data traversals.

<!-- vi: filetype=idris2
-->
