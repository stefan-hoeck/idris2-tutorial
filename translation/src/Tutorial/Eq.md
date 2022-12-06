# 命题等式

在 [上一章](DPair.md) 中，我们了解了如何使用依赖对和记录来计算 *类型*，这些值仅在运行时通过对这些值进行模式匹配而已知。现在，我们将研究如何将值之间的关系或 *契约* 描述为类型，以及如何使用这些类型的值作为契约持有的证明。

```idris
module Tutorial.Eq

import Data.Either
import Data.HList
import Data.Vect
import Data.String

%default total
```

## 等式作为一种类型

想象一下，我们想要连接两个 CSV 文件的内容，我们将这两个文件作为表连同它们的模式一起存储在磁盘上，如我们关于依赖对的讨论中所示：

```idris
data ColType = I64 | Str | Boolean | Float

Schema : Type
Schema = List ColType

IdrisType : ColType -> Type
IdrisType I64     = Int64
IdrisType Str     = String
IdrisType Boolean = Bool
IdrisType Float   = Double

Row : Schema -> Type
Row = HList . map IdrisType

record Table where
  constructor MkTable
  schema : Schema
  size   : Nat
  rows   : Vect size (Row schema)

concatTables1 : Table -> Table -> Maybe Table
```

我们将无法通过附加两个行向量来实现 `concatTables`，除非我们能够以某种方式验证两个模式是否相同。 “好吧，”我听到你说，“这应该不是什么大问题！只需为 `ColType` 实现 `Eq`”。让我们试一试：

```idris
Eq ColType where
  I64     == I64     = True
  Str     == Str     = True
  Boolean == Boolean = True
  Float   == Float   = True
  _       == _       = False

concatTables1 (MkTable s1 m rs1) (MkTable s2 n rs2) = case s1 == s2 of
  True  => ?what_now
  False => Nothing
```

不知何故，这似乎不起作用。如果我们检查孔 `what_now` 的上下文，Idris 仍然认为 `s1` 和 `s2` 是不同的，如果我们继续调用 `Vect.( ++)` ，在 `True` 的情况下，Idris 将响应类型错误。

```repl
Tutorial.Relations> :t what_now
   m : Nat
   s1 : List ColType
   rs1 : Vect m (HList (map IdrisType s1))
   n : Nat
   s2 : List ColType
   rs2 : Vect n (HList (map IdrisType s2))
------------------------------
what_now : Maybe Table
```

问题是，Idris 没有理由统一这两个值，即使 `(==)` 返回 `True` 因为 `(==)` 的结果除了类型为 `Bool` 之外没有其他信息。 *我们* 认为，如果这是 `True` 那么两个值应该是相同的，但 Idris 不相信。事实上，就类型检查器而言，以下 `Eq ColType` 的实现会非常好：

```repl
Eq ColType where
  _       == _       = True
```

所以伊德里斯不信任我们是对的。您可能希望它检查 `(==)` 的实现并自行弄清楚 `True` 结果的含义，但这并不是这些事情通常的工作方式，因为大多数时候，要检查的计算路径的数量会太大。因此，Idris 能够在统一期间求值函数，但它不会为我们从函数结果中追溯有关函数参数的信息。但是，我们可以手动执行此操作，稍后我们将看到。

### 相等 schemata 的类型

上面描述的问题类似于我们在谈到[singleton types](DPair.md#erased-existentials)的好处时看到的：类型不够精确。我们现在要做的是，我们将针对不同的用例再次重复：我们对索引数据类型中的值之间的契约进行编码：

```idris
data SameSchema : (s1 : Schema) -> (s2 : Schema) -> Type where
  Same : SameSchema s s
```

首先，请注意 `SameSchema` 是通过两个 `Schema` 类型的值索引的类型族。但还要注意，唯一的构造函数限制了我们允许 `s1` 和 `s2` 的值：两个索引 *必须* 相同。

为什么这很有用？好吧，假设我们有一个检查两个 schemata 是否相等的函数，它会尝试返回一个类型为 `SameSchema s1 s2` 的值：

```idris
sameSchema : (s1, s2 : Schema) -> Maybe (SameSchema s1 s2)
```

然后我们可以使用这个函数来实现 `concatTables`：

```idris
concatTables : Table -> Table -> Maybe Table
concatTables (MkTable s1 m rs1) (MkTable s2 n rs2) = case sameSchema s1 s2 of
  Just Same => Just $ MkTable s1 _ (rs1 ++ rs2)
  Nothing   => Nothing
```

有效！这里发生了什么？好吧，让我们检查一下所涉及的类型：

```idris
concatTables2 : Table -> Table -> Maybe Table
concatTables2 (MkTable s1 m rs1) (MkTable s2 n rs2) = case sameSchema s1 s2 of
  Just Same => ?almost_there
  Nothing   => Nothing
```

在 REPL 中，我们得到 `almost_there` 的以下上下文：

```repl
Tutorial.Relations> :t almost_there
   m : Nat
   s2 : List ColType
   rs1 : Vect m (HList (map IdrisType s2))
   n : Nat
   rs2 : Vect n (HList (map IdrisType s2))
   s1 : List ColType
------------------------------
almost_there : Maybe Table
```

看看，`rs1` 和 `rs2` 的类型是怎么统一的？值 `Same`，作为 `sameSchema s1 s2` 的结果， `s1` 和 `s2` 是实际上相同的 *见证*，因为这是我们在 `Same` 的定义中指定的。

剩下要做的就是实现`sameSchema`。为此，我们将编写另一种数据类型，用于指定 `ColType` 类型的两个值何时相同：

```idris
data SameColType : (c1, c2 : ColType) -> Type where
  SameCT : SameColType c1 c1
```

我们现在可以定义几个工具函数。首先，用于确定两个列类型是否相同：

```idris
sameColType : (c1, c2 : ColType) -> Maybe (SameColType c1 c2)
sameColType I64     I64     = Just SameCT
sameColType Str     Str     = Just SameCT
sameColType Boolean Boolean = Just SameCT
sameColType Float   Float   = Just SameCT
sameColType _ _             = Nothing
```

这将说服 Idris，因为在每个模式匹配中，返回类型将根据我们匹配的值进行调整。例如，在第一行，输出类型是 `Maybe (SameColType I64 I64)`，因为您可以自己通过插入一个孔并在 REPL 中检查其类型来轻松验证。

我们将需要两个额外的实用程序： 用于为 nil 和 cons 情况创建 `SameSchema` 类型值的函数。请注意，实现是多么微不足道。尽管如此，我们还是经常不得不快速写出这么小的证明（我将在下一节解释，为什么我称它们为 *证明*），然后用来让类型检查器相信我们已经采取的一些事实是理所当然但 Idris 不知道的。

```idris
sameNil : SameSchema [] []
sameNil = Same

sameCons :  SameColType c1 c2
         -> SameSchema s1 s2
         -> SameSchema (c1 :: s1) (c2 :: s2)
sameCons SameCT Same = Same
```

像往常一样，它可以通过将 `sameCons` 的右侧替换为一个孔并在 REPL 中检查其类型和上下文来帮助理解发生了什么。左侧存在值 `SameCT` 和 `Same` 迫使 Idris 统一 `c1` 和 `c2` 以及 `s1 ` 和 `s2`，紧接着是 `c1 :: s1` 和 `c2 :: s2` 的统一。有了这些，我们终于可以实现`sameSchema`：

```idris
sameSchema []        []        = Just sameNil
sameSchema (x :: xs) (y :: ys) =
  [| sameCons (sameColType x y) (sameSchema xs ys) |]
sameSchema (x :: xs) []        = Nothing
sameSchema []        (x :: xs) = Nothing
```

我们在这里描述的是一种比接口 `Eq` 和 `(==)` 运算符提供的更强大的相等形式：类型检查器在尝试时接受的值相等统一类型级索引。这也称为 *命题等式*：我们将在下面看到，我们可以将类型视为数学 *命题*，这些类型的值是这些命题所持有的 *证明* .

### `Equal` 类型

命题等式是一个基本概念，以至于 *Prelude* 已经为此导出了一个通用数据类型：`Equal`，以及它唯一的数据构造函数 `Refl`。此外，还有一个用于表达命题相等的内置运算符，它被脱糖为 `Equal`：`(=)`。这有时会导致一些混淆，因为等号也用于*相等定义*：在函数实现中描述左侧和右侧被定义为相等。如果您想从定义相等中消除命题的歧义，您还可以使用运算符 `(===)` 来表示前者。

这是 `concatTables` 的另一个实现：

```idris
eqColType : (c1,c2 : ColType) -> Maybe (c1 = c2)
eqColType I64     I64     = Just Refl
eqColType Str     Str     = Just Refl
eqColType Boolean Boolean = Just Refl
eqColType Float   Float   = Just Refl
eqColType _ _             = Nothing

eqCons :  {0 c1,c2 : a}
       -> {0 s1,s2 : List a}
       -> c1 = c2 -> s1 = s2 ->  c1 :: s1 = c2 :: s2
eqCons Refl Refl = Refl

eqSchema : (s1,s2 : Schema) -> Maybe (s1 = s2)
eqSchema []        []        = Just Refl
eqSchema (x :: xs) (y :: ys) = [| eqCons (eqColType x y) (eqSchema xs ys) |]
eqSchema (x :: xs) []        = Nothing
eqSchema []        (x :: xs) = Nothing

concatTables3 : Table -> Table -> Maybe Table
concatTables3 (MkTable s1 m rs1) (MkTable s2 n rs2) = case eqSchema s1 s2 of
  Just Refl => Just $ MkTable _ _ (rs1 ++ rs2)
  Nothing   => Nothing
```

### 练习第 1 部分

在接下来的练习中，您将实现等式证明的一些非常基本的属性。您必须自己提出函数的类型，因为实现将非常简单。

注意：如果您不记得术语“自反”、“对称”和“传递”的含义，请快速阅读关于等价关系的内容 [此处](https://en.wikipedia.org/wiki/Equivalence_relation)。

1. Show that `SameColType` is a reflexive relation.


2. Show that `SameColType` is a symmetric relation.


3. Show that `SameColType` is a transitive relation.


4. Let `f` be a function of type `ColType -> a` for an
   arbitrary type `a`. Show that from a value of type
   `SameColType c1 c2` follows that `f c1` and `f c2` are equal.


对于 `(=)`，上述属性可从 *Prelude* 作为函数 `sym`、`trans` 和 `cong` 获得.自反性来自数据构造函数 `Refl` 本身。

5. Implement a function for verifying that two natural
   numbers are identical. Try using `cong` in your
   implementation.


6. Use the function from exercise 5 for zipping two
   `Table`s if they have the same number of rows.


   提示：使用 `Vect.zipWith`。您将需要为此实现
   自定义函数 `appRows`，因为使用 `HList.(++)` 时 Idris 将
   不会自动确定类型何时统一 ：

   ```idris
   appRows : {ts1 : _} -> Row ts1 -> Row ts2 -> Row (ts1 ++ ts2)
   ```

稍后我们将学习如何使用 *重写规则* 来规避编写自定义函数的需要，例如 `appRows` ，并在 `zipWith` 中直接使用 `(++)` 。

## 程序作为证明

数学家 *Haskell Curry* 和逻辑学家 *William Alvin Howard* 的著名观察得出的结论是，我们可以在具有足够丰富类型的编程语言中查看 *类型*系统作为一个数学命题和一个计算这种类型的*值*的完全程序作为命题成立的证明。这也称为 [Curry-Howard 同构](https://en.wikipedia.org/wiki/Curry%E2%80%93Howard_correspondence)。

例如，这里有一个简单的证明，证明一加一等于二：

```idris
onePlusOne : the Nat 1 + 1 = 2
onePlusOne = Refl
```

上面的证明是微不足道的，因为 Idris 通过统一解决了这个问题。但是我们已经在练习中陈述了一些更有趣的事情。例如 `SameColType` 的对称性和传递性：

```idris
sctSymmetric : SameColType c1 c2 -> SameColType c2 c1
sctSymmetric SameCT = SameCT

sctTransitive : SameColType c1 c2 -> SameColType c2 c3 -> SameColType c1 c3
sctTransitive SameCT SameCT = SameCT
```

请注意，单独的类型不是证明。例如，我们可以自由地说一加一等于三：

```idris
onePlusOneWrong : the Nat 1 + 1 = 3
```

然而，我们将很难以可证明的整体方式实现这一点。我们说：“类型 `the Nat 1 + 1 = 3` 是 *uninhabited*”，意思是这个类型没有值。

### 当证明取代测试时

我们将看到几个不同的编译时证明用例，一个非常直接的用例是通过证明我们的函数的一些属性来证明我们的函数行为应该如此。例如，这里有一个命题，列表上的 `map` 不会改变列表中元素的数量：

```idris
mapListLength : (f : a -> b) -> (as : List a) -> length as = length (map f as)
```

将此视为一个普遍量化的陈述：对于从 `a` 到 `b` 的所有函数 `f` 以及所有包含 `as` 类型值的列表 `a`，`map f as`的长度与原始列表的长度相同。

我们可以通过在 `as` 上进行模式匹配来实现 `mapListLength`。 `Nil` 的情况很简单：Idris 通过统一解决了这个问题。它知道输入列表的值 (`Nil`)，并且由于 `map` 也是通过对输入的模式匹配实现的，因此立即得出结果将为 `Nil ` ，所以：

```idris
mapListLength f []        = Refl
```

`cons` 的情况比较复杂，我们将逐步进行。首先，请注意，我们可以通过递归证明映射在尾部的长度将保持不变：


```repl
mapListLength f (x :: xs) = case mapListLength f xs of
  prf => ?mll1
```

让我们检查一下我们在这里拥有的类型和上下文：

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

所以，我们有一个类型 `length xs = length (map f xs)` 的证明，并且从 `map` 的实现 Idris 得出结论，我们真正要寻找的是类型的结果`S (length xs) = S (length (map f xs))`。这正是 *Prelude* 中的函数 `cong` 的用途（“cong”是 *congruence* 的缩写）。因此，我们可以像这样简洁地实现 *cons* 案例：

```idris
mapListLength f (x :: xs) = cong S $ mapListLength f xs
```

请花点时间欣赏一下我们在这里取得的成就：数学意义上的 *证明*，我们的函数不会影响列表的长度。我们不再需要单元测试或类似程序来验证这一点。

在我们继续之前，请注意一件重要的事情：在我们的 case 表达式中，我们使用 *变量* 来表示递归调用的结果：

```repl
mapListLength f (x :: xs) = case mapListLength f xs of
  prf => cong S prf
```

在这里，我们不希望这两个长度统一，因为我们需要在调用 `cong` 时加以区分。因此：如果您需要 `x = y` 类型的证明来统一两个变量，请在模式匹配中使用 `Refl` 数据构造函数。另一方面，如果您需要对这样的证明进行进一步的计算，请使用变量，并且左侧和右侧将保持不同。

这是上一章的另一个例子：我们想证明解析和打印列类型的行为是正确的。一般来说，编写关于解析器的证明可能非常困难，但在这里可以仅通过模式匹配来完成：

```idris
showColType : ColType -> String
showColType I64      = "i64"
showColType Str      = "str"
showColType Boolean  = "boolean"
showColType Float    = "float"

readColType : String -> Maybe ColType
readColType "i64"      = Just I64
readColType "str"      = Just Str
readColType "boolean"  = Just Boolean
readColType "float"    = Just Float
readColType s          = Nothing

showReadColType : (c : ColType) -> readColType (showColType c) = Just c
showReadColType I64     = Refl
showReadColType Str     = Refl
showReadColType Boolean = Refl
showReadColType Float   = Refl
```

这样简单的证明给了我们快速但有力的保证，我们没有犯任何愚蠢的错误。

到目前为止，我们看到的示例非常容易实现。一般来说，情况并非如此，我们将不得不学习一些额外的技术来证明我们程序的有趣之处。但是，当我们将 Idris 用作通用编程语言而不是用作证明助手时，我们可以自由选择代码的某些方面是否需要这种强有力的保证。

### 注意事项：函数类型中的小写标识符

在写下我们上面所做的证明类型时，必须非常小心不要落入以下陷阱：通常，Idris 会将函数类型中的小写标识符视为类型参数（已删除的隐式参数）。例如，这里尝试证明 `Maybe` 的恒等函子定律：

```idris
mapMaybeId1 : (ma : Maybe a) -> map Prelude.id ma = ma
mapMaybeId1 Nothing  = Refl
mapMaybeId1 (Just x) = ?mapMaybeId1_rhs
```

您将无法实现 `Just` 案例，因为 Idris 将 `id` 视为隐式参数，这在检查 `mapMaybeId1_rhs` 的上下文时很容易看出：

```repl
Tutorial.Relations> :t mapMaybeId1_rhs
 0 a : Type
 0 id : a -> a
   x : a
------------------------------
mapMaybeId1_rhs : Just (id x) = Just x
```

如您所见，`id` 是 `a -> a` 类型的已擦除参数。事实上，在对该模块进行类型检查时，Idris 会发出警告，指出参数 `id` 正在隐藏现有函数：

```repl
警告：我们即将隐式绑定以下小写名称。
您可能无意中隐藏了相关的全局定义：
  id 正在影响 Prelude.Basics.id
```

`map` 的情况并非如此：由于我们将参数显式传递给 `map`，Idris 将其视为函数名而不是隐式参数。

您在这里有几个选择。例如，您可以使用大写标识符，因为这些标识符永远不会被视为隐式参数：

```idris
Id : a -> a
Id = id

mapMaybeId2 : (ma : Maybe a) -> map Id ma = ma
mapMaybeId2 Nothing  = Refl
mapMaybeId2 (Just x) = Refl
```

作为替代方案 - 这是处理这种情况的首选方式 - 您可以在 `id` 前加上其命名空间的一部分，这将立即解决问题：

```idris
mapMaybeId : (ma : Maybe a) -> map Prelude.id ma = ma
mapMaybeId Nothing  = Refl
mapMaybeId (Just x) = Refl
```

注意：如果您在编辑器中打开了语义突出显示（例如，通过使用 [idris2-lsp 插件](https://github.com/idris-community/idris2-lsp)），您会注意到 `mapMaybeId1` 中的 `map` 和 `id` 以不同的方式突出显示：`map` 作为函数名称，`id` 作为绑定变量。

### 练习第 2 部分

在这些练习中，您将证明小函数的几个简单属性。在编写证明时，更重要的是利用漏洞来弄清楚 Idris 下一步对你的期望。使用提供给您的工具，而不是试图在黑暗中找到自己的方式！

1. Proof that `map id` on an `Either e` returns the value unmodified.


2. Proof that `map id` on a list returns the list unmodified.


3. Proof that complementing a strand of a nucleobase
   (see the [previous chapter](DPair.md#use-case-nucleic-acids))
   twice leads to the original strand.


   提示：首先对单碱基进行证明，然后在核酸序列的实现中使用 *Prelude* 中的`cong2`。

4. Implement function `replaceVect`:


   ```idris
   replaceVect : (ix : Fin n) -> a -> Vect n a -> Vect n a
   ```

   现在证明，在替换向量中的元素之后
   使用 `replaceAt` 访问相同的元素
   `index` 将返回我们刚刚添加的值。

5. Implement function `insertVect`:


   ```idris
   insertVect : (ix : Fin (S n)) -> a -> Vect n a -> Vect (S n) a
   ```

   使用与练习 4 中类似的证明来证明
   行为正确。

注意：函数 `replaceVect` 和 `insertVect` 可从 `Data.Vect` 作为 `replaceAt` 和 `insertAt` 获得。

## 进入虚空

还记得上面的函数 `onePlusOneWrong` 吗？这绝对是一个错误的说法：一加一不等于三。有时，我们想准确地表达这一点：某个陈述是错误的并且不成立。考虑一下在 Idris 中证明一个陈述意味着什么：这样一个陈述（或命题）是一种类型，并且该陈述的证明是这种类型的一个值或表达式：该类型被称为 *有人居住的*。如果陈述不正确，则不能有给定类型的值。我们说，给定的类型是 *无人居住的*。如果我们仍然设法获得一个无人居住类型的值，这是一个逻辑矛盾，因此，任何事情都会随之而来（记住 [ex falso quodlibet](https://en.wikipedia.org/wiki/Principle_of_explosion)） .

所以这就是如何表达一个命题不成立：我们声明如果它 *会* 成立，这将导致矛盾。在 Idris 中表达矛盾最自然的方式是返回一个 `Void` 类型的值：

```idris
onePlusOneWrongProvably : the Nat 1 + 1 = 3 -> Void
onePlusOneWrongProvably Refl impossible
```

看看这是如何证明给定类型的完整实现：从 `1 + 1 = 3` 到 `Void` 的函数。我们通过模式匹配来实现这一点，并且只有一个构造函数可以匹配，这导致了一种不可能的情况。

我们还可以使用相互矛盾的陈述来证明其他此类陈述。例如，这是一个证明，如果两个列表的长度不同，那么这两个列表也不可能相同：

```idris
notSameLength1 : (List.length as = length bs -> Void) -> as = bs -> Void
notSameLength1 f prf = f (cong length prf)
```

这写起来很麻烦，读起来也很难，所以 prelude 中有函数`Not` 可以更自然地表达同样的事情：

```idris
notSameLength : Not (List.length as = length bs) -> Not (as = bs)
notSameLength f prf = f (cong length prf)
```

实际上，这只是 `cong` 对偶的一个特殊版本：如果从 `a = b` 遵循 `f a = f b`，那么从 `not (f a = f b)` 遵循 `not (a = b)`：

```idris
contraCong : {0 f : _} -> Not (f a = f b) -> Not (a = b)
contraCong fun = fun . cong f
```

### `Uninhabited` 接口

*Prelude* 中有一个接口用于无人居住类型：`Uninhabited`，其唯一函数是`uninhabited`。在 REPL 中查看它的文档。您会看到，已经有大量可用的实现，其中许多涉及数据类型 `Equal`。

我们可以使用 `Uninhabited`，例如表示空模式不等于非空模式：

```idris
Uninhabited (SameSchema [] (h :: t)) where
  uninhabited Same impossible

Uninhabited (SameSchema (h :: t) []) where
  uninhabited Same impossible
```

有一个相关的函数你需要知道：`absurd`，它结合了`uninhabited`和`void`：

```repl
Tutorial.Eq> :printdef absurd
Prelude.absurd : Uninhabited t => t -> a
absurd h = void (uninhabited h)
```

### 可判定等式

当我们实现 `sameColType` 时，我们得到了两个列类型确实相同的证据，由此我们可以确定两个模式是否相同。这些类型保证我们不会产生任何误报：如果我们产生一个类型为 `SameSchema s1 s2` 的值，我们就有证据证明 `s1` 和 `s2` 确实是完全相同的。但是，`sameColType` 和 `sameSchema` 理论上仍然可以通过返回 `Nothing` 来产生假阴性，尽管这两个值是相同的。例如，我们可以实现 `sameColType`，使其始终返回 `Nothing`。这将与类型一致，但绝对不是我们想要的。因此，为了获得更强有力的保证，我们想要做以下事情：我们要么想要返回两个模式相同的证明，要么返回两个模式不同的证明。 （记住 `Not a` 是 `a -> Void` 的别名）。

我们将持有或导致矛盾的属性称为 *可判定属性*，而 *Prelude* 导出数据类型 `Dec prop`，它封装了这种区别。

这是为 `ColType` 编码的一种方法：

```idris
decSameColType :  (c1,c2 : ColType) -> Dec (SameColType c1 c2)
decSameColType I64 I64         = Yes SameCT
decSameColType I64 Str         = No $ \case SameCT impossible
decSameColType I64 Boolean     = No $ \case SameCT impossible
decSameColType I64 Float       = No $ \case SameCT impossible

decSameColType Str I64         = No $ \case SameCT impossible
decSameColType Str Str         = Yes SameCT
decSameColType Str Boolean     = No $ \case SameCT impossible
decSameColType Str Float       = No $ \case SameCT impossible

decSameColType Boolean I64     = No $ \case SameCT impossible
decSameColType Boolean Str     = No $ \case SameCT impossible
decSameColType Boolean Boolean = Yes SameCT
decSameColType Boolean Float   = No $ \case SameCT impossible

decSameColType Float I64       = No $ \case SameCT impossible
decSameColType Float Str       = No $ \case SameCT impossible
decSameColType Float Boolean   = No $ \case SameCT impossible
decSameColType Float Float     = Yes SameCT
```

首先，请注意我们如何直接在单个参数 lambda 中使用模式匹配。这有时被称为 *lambda case* 风格，以 Haskell 编程语言的扩展命名。如果我们在模式匹配中使用 `SameCT` 构造函数，Idris 将被迫尝试将 `Float` 与 `I64` 统一起来。这是不可能的，所以整个案例是不可能的。

然而，这实现起来相当麻烦。为了让 Idris 相信我们没有遗漏任何一个案例，没有办法明确地处理每个可能的构造函数配对。然而，我们 *必须* 得到更强的保证：我们不能再创建误报 *或* 误报，因此 `decSameColType` 可证明是正确的。

对模式做同样的事情需要一些实用函数，我们可以通过放置一些孔来找出它们的类型：

```idris
decSameSchema' :  (s1, s2 : Schema) -> Dec (SameSchema s1 s2)
decSameSchema' []        []        = Yes Same
decSameSchema' []        (y :: ys) = No ?decss1
decSameSchema' (x :: xs) []        = No ?decss2
decSameSchema' (x :: xs) (y :: ys) = case decSameColType x y of
  Yes SameCT => case decSameSchema' xs ys of
    Yes Same => Yes Same
    No  contra => No $ \prf => ?decss3
  No  contra => No $ \prf => ?decss4
```

前两种情况并不难。 `decss1` 的类型是 `SameSchema [] (y :: ys) -> Void`，您可以在 REPL 轻松验证。但这只是 `uninhabited`，专门用于 `SameSchema [] (y :: ys)`，我们已经在上面进一步实现了这一点。 `decss2` 也是如此。

其他两种情况比较难，所以我已经尽可能多地填写了。我们知道我们想要返回一个 `No`，如果可以证明正面或反面是不同的。 `No` 包含一个函数，所以我已经添加了一个 lambda，只为返回值留了一个洞。以下是 `decss3` 的类型和更重要的上下文：

```repl
Tutorial.Relations> :t decss3
   y : ColType
   xs : List ColType
   ys : List ColType
   x : ColType
   contra : SameSchema xs ys -> Void
   prf : SameSchema (y :: xs) (y :: ys)
------------------------------
decss3 : Void
```

`contra` 和 `prf` 的类型是我们这里需要的：如果 `xs` 和 `ys` 是不同的，那么 `y :: xs` 和 `y :: ys` 也必须不同。这是以下语句的对置：如果 `x :: xs` 与 `y :: ys` 相同，则 `xs` 和 `ys` 也一样。因此，我们必须实现一个引理，证明 *cons* 构造函数是 [*injective*](https://en.wikipedia.org/wiki/Injective_function)：

```idris
consInjective :  SameSchema (c1 :: cs1) (c2 :: cs2)
              -> (SameColType c1 c2, SameSchema cs1 cs2)
consInjective Same = (SameCT, Same)
```

我们现在可以将 `prf` 传递给 `consInjective` 以提取 `SameSchema xs ys` 类型的值，然后我们将其传递给 `contra` 以便获取类型 `Void` 的所需值。有了这些观察和实用程序，我们现在可以实现 `decSameSchema`：

```idris
decSameSchema :  (s1, s2 : Schema) -> Dec (SameSchema s1 s2)
decSameSchema []        []        = Yes Same
decSameSchema []        (y :: ys) = No absurd
decSameSchema (x :: xs) []        = No absurd
decSameSchema (x :: xs) (y :: ys) = case decSameColType x y of
  Yes SameCT => case decSameSchema xs ys of
    Yes Same   => Yes Same
    No  contra => No $ contra . snd . consInjective
  No  contra => No $ contra . fst . consInjective
```

有一个名为 `DecEq` 的接口由模块 `Decidable.Equality` 导出，用于我们可以为命题相等性实现决策过程的类型。我们可以实现它来确定两个值是否相等。

### 练习第 3 部分

1. Show that there can be no non-empty vector of `Void`
   by writing a corresponding implementation of uninhabited


2. Generalize exercise 1 for all uninhabited element types.


3. Show that if `a = b` cannot hold, then `b = a` cannot hold
   either.


4. Show that if `a = b` holds, and `b = c` cannot hold, then
   `a = c` cannot hold either.


5. Implement `Uninhabited` for `Crud i a`. Try to be
   as general as possible.


   ```idris
   data Crud : (i : Type) -> (a : Type) -> Type where
     Create : (value : a) -> Crud i a
     Update : (id : i) -> (value : a) -> Crud i a
     Read   : (id : i) -> Crud i a
     Delete : (id : i) -> Crud i a
   ```

6. Implement `DecEq` for `ColType`.


7. Implementations such as the one from exercise 6 are cumbersome
   to write as they require a quadratic number of pattern matches
   with relation to the number of data constructors. Here is a
   trick how to make this more bearable.


   1. Implement a function `ctNat`, which assigns every value
      of type `ColType` a unique natural number.


   2. Proof that `ctNat` is injective.
      Hint: You will need to pattern match on the `ColType`
      values, but four matches should be enough to satisfy the
      coverage checker.


   3. In your implementation of `DecEq` for `ColType`,
      use `decEq` on the result of applying both column
      types to `ctNat`, thus reducing it to only two lines of
      code.


   我们稍后会讨论 `with` 规则：
   依赖模式匹配，让我们学习一些东西
   通过执行关于函数参数的形状
   对它们进行计算。这些将允许我们使用
   与此处所示类似的技术来实现 `DecEq`
   只需要 `n` 模式匹配
   对于具有 `n` 数据构造函数的任意和类型。

## 重写规则

命题等式的最重要用例之一是替换或 *重写* 现有类型，否则 Idris 无法自动统一这些类型。例如，以下是没有问题的： Idris 知道 `0 + n` 等于 `n`，因为自然数上的 `plus` 是通过第一个参数的模式匹配实现的.因此，这两个向量长度可以很好地统一。

```idris
leftZero :  List (Vect n Nat)
         -> List (Vect (0 + n) Nat)
         -> List (Vect n Nat)
leftZero = (++)
```

但是，下面的示例无法轻松实现（尝试 id！），因为 Idris 无法自行确定这两个长度是否统一。

```idris
rightZero' :  List (Vect n Nat)
           -> List (Vect (n + 0) Nat)
           -> List (Vect n Nat)
```

可能是我们第一次意识到，Idris 对算术定律知之甚少。Idris 能够统一值

* all values in a computation are known at compile time

* one expression follows directly from the other due
  to the pattern matches used in a function's implementation.


在表达式 `n + 0` 中，并非所有值都是已知的（`n` 是一个变量），并且 `(+)` 是通过第一个参数的模式匹配来实现的，我们在这里一无所知。

但是，我们可以教 Idris 。如果我们可以证明这两个表达式是等价的，我们可以用一个表达式替换另一个表达式，从而使两者再次统一。这是一个引理及其证明，对于所有自然数 `n`，`n + 0` 等于 `n`。

```idris
addZeroRight : (n : Nat) -> n + 0 = n
addZeroRight 0     = Refl
addZeroRight (S k) = cong S $ addZeroRight k
```

请注意，基本情况是多么微不足道：由于没有剩余变量，Idris 可以立即计算出 `0 + 0 = 0`。在递归的情况下，将 `cong S` 替换为一个孔并查看其类型和上下文以确定如何进行可能是有益的。

*Prelude* 导出函数 `replace` 用于根据等式证明将一个变量中的一个变量替换为另一个变量。在查看下面的示例之前，请务必先检查其类型：

```idris
replaceVect : Vect (n + 0) a -> Vect n a
replaceVect as = replace {p = \k => Vect k a} (addZeroRight n) as
```

如您所见，我们将 `p x` 类型的值 *替换* 为 `p y` 类型的值，基于 `x = y` 的证明, 其中 `p` 是从某种类型 `t` 到 `Type` 的函数，而 `x` 和 `y` 是类型 `t` 的值。在我们的 `replaceVect` 示例中，`t` 等于 `Nat`，`x` 等于 `n + 0`，`y` 等于 `n`，`p` 等于 `\k => Vect k a`。

直接使用 `replace` 不是很方便，因为 Idris 往往无法自行推断出 `p` 的值。实际上，我们必须在 `replaceVect` 中明确给出它的类型。因此，Idris 为此类 *重写规则* 提供了特殊语法，这将减少对 `replace` 的调用，并为我们填写所有详细信息。这是 `replaceVect` 的实现，带有重写规则：

```idris
rewriteVect : Vect (n + 0) a -> Vect n a
rewriteVect as = rewrite sym (addZeroRight n) in as
```

混淆的一个来源是 *rewrite* 使用相反的相等性证明：给定 `y = x` 它将 `p x` 替换为 `p y` .因此需要在我们上面的实现中调用 `sym`。

### 用例：反转向量

当我们执行有趣的类型级计算时，通常需要重写规则。例如，我们已经看到了许多在 `Vect` 上运行的函数的有趣示例，这使我们能够跟踪所涉及向量的确切长度，但是到目前为止我们的讨论中缺少一个关键函数，并且有充分的理由：函数 `reverse`。这是一个可能的实现，这就是 `reverse` 对列表的实现方式：


```repl
revOnto' : Vect m a -> Vect n a -> Vect (m + n) a
revOnto' xs []        = xs
revOnto' xs (x :: ys) = revOnto' (x :: xs) ys


reverseVect' : Vect n a -> Vect n a
reverseVect' = revOnto' []
```

As you might have guessed, this will not compile as the
length indices in the two clauses of `revOnto'` do
not unify.

*nil* 情况是我们在上面已经看到的情况：这里 `n` 为零，因为第二个向量是空的，所以我们必须再次说服 Idris `m + 0 = m`：

```idris
revOnto : Vect m a -> Vect n a -> Vect (m + n) a
revOnto xs [] = rewrite addZeroRight m in xs
```

第二种情况更复杂。这里，Idris 无法统一 `S (m + len)` 和 `m + S len`，其中 `len` 是 `ys` 的长度，第二个向量的尾部。模块 `Data.Nat` 提供了许多关于自然数算术运算的证明，其中之一是 `plusSuccRightSucc`。这是它的类型：

```repl
Tutorial.Eq> :t plusSuccRightSucc
Data.Nat.plusSuccRightSucc :  (left : Nat)
                           -> (right : Nat)
                           -> S (left + right) = left + S right
```

In our case, we want to replace `S (m + len)` with `m + S len`,
so we will need the version with arguments flipped. However, there
is one more obstacle: We need to invoke `plusSuccRightSucc`
with the length of `ys`, which is not given as an implicit
function argument of `revOnto`. We therefore need to pattern
match on `n` (the length of the second vector), in order to
bind the length of the tail to a variable. Remember, that we
are allowed to pattern match on an erased argument only if
the constructor used follows from a match on another, unerased,
argument (`ys` in this case). Here's the implementation of the
second case:

```idris
revOnto {n = S len} xs (x :: ys) =
  rewrite sym (plusSuccRightSucc m len) in revOnto (x :: xs) ys
```

我从我自己的经验中知道，起初这可能会让人非常困惑。如果您将 Idris 用作通用编程语言而不是证明助手，您可能不必经常使用重写规则。尽管如此，重要的是要知道它们的存在，因为它们允许我们向 Idris 教授复杂的等价性。

### 关于擦除的说明

`Unit`、`Equal` 或 `SameSchema` 等单值数据类型没有运行时相关性，因为这些类型的值始终相同。因此，我们始终可以将它们用作已擦除的函数参数，同时仍然能够对这些值进行模式匹配。例如，当您查看 `replace` 的类型时，您会看到等式证明是一个已删除的参数。这允许我们运行任意复杂的计算来生成这样的值，而不必担心这些计算会减慢编译的 Idris 程序。

### 练习第 4 部分

1. Implement `plusSuccRightSucc` yourself.


2. Proof that `minus n n` equals zero for all natural numbers `n`.


3. Proof that `minus n 0` equals n for all natural numbers `n`


4. Proof that `n * 1 = n` and `1 * n = n`
   for all natural numbers `n`.


5. Proof that addition of natural numbers is
   commutative.


6. Implement a tail-recursive version of `map` for vectors.


7. Proof the following proposition:


   ```idris
   mapAppend :  (f : a -> b)
             -> (xs : List a)
             -> (ys : List a)
             -> map f (xs ++ ys) = map f xs ++ map f ys
   ```

8. Use the proof from exercise 7 to implement again a function
   for  zipping two `Table`s, this time using a rewrite rule
   plus `Data.HList.(++)` instead of custom function `appRows`.


## 结论

*类型作为命题，值作为证明* 的概念是编写可证明正确的程序的非常强大的工具。因此，我们将花更多时间定义数据类型来描述值之间的协议，并将这些类型的值作为合约持有的证据。这将允许我们为我们的函数描述必要的前置条件和后置条件，从而减少返回 `Maybe` 或其他故障类型的需要，因为由于输入受限，我们的函数不能再失败。

<!-- vi: filetype=idris2
-->
