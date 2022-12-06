# 接口

函数重载——定义同名但实现不同的函数——是许多编程语言中的一个概念。 Idris 原生支持函数的重载：两个同名的函数可以定义在不同的模块或命名空间中，Idris 将尝试根据所涉及的类型消除它们之间的歧义。这是一个例子：

```idris
module Tutorial.Interfaces

%default total

namespace Bool
  export
  size : Bool -> Integer
  size True  = 1
  size False = 0

namespace Integer
  export
  size : Integer -> Integer
  size = id

namespace List
  export
  size : List a -> Integer
  size = cast . length
```

在这里，我们定义了三个不同的函数，称为 `size`，每个函数都在自己的命名空间中。我们可以通过在它们前面加上它们的命名空间来消除它们之间的歧义：

```repl
Tutorial.Interfaces> :t Bool.size
Tutorial.Interfaces.Bool.size : Bool -> Integer
```

但是，这通常不是必需的：

```idris
mean : List Integer -> Integer
mean xs = sum xs `div` size xs
```

如您所见，Idris 可以区分不同的 `size` 函数，因为 `xs` 是 `List Integer` 类型，它仅与 `List a` 的参数类型为 `List.size`。

## 接口基础

虽然如上所述的函数重载效果很好，但在某些用例中，这种形式的重载函数会导致大量代码重复。

例如，考虑一个函数 `cmp` （*compare* 的缩写，已由 *Prelude* 导出），用于描述 `String` 类型值的顺序：

```idris
cmp : String -> String -> Ordering
```

我们还希望为许多其他数据类型提供类似的函数。函数重载允许我们这样做，但 `cmp` 不是一个孤立的函数。从中，我们可以推导出 `greaterThan'`、`lessThan'`、`minimum'`、`maximum'` 等函数：

```idris
lessThan' : String -> String -> Bool
lessThan' s1 s2 = LT == cmp s1 s2

greaterThan' : String -> String -> Bool
greaterThan' s1 s2 = GT == cmp s1 s2

minimum' : String -> String -> String
minimum' s1 s2 =
  case cmp s1 s2 of
    LT => s1
    _  => s2

maximum' : String -> String -> String
maximum' s1 s2 =
  case cmp s1 s2 of
    GT => s1
    _  => s2
```

我们需要使用 `cmp` 函数为其他类型再次实现所有这些，并且大多数（如果不是全部）这些实现将与上面编写的相同。这会有很多代码重复。

解决这个问题的一种方法是使用高阶函数。例如，我们可以定义函数 `minimumBy`，它将比较函数作为其第一个参数并返回剩余两个参数中较小的一个：

```idris
minimumBy : (a -> a -> Ordering) -> a -> a -> a
minimumBy f a1 a2 =
  case f a1 a2 of
    LT => a1
    _  => a2
```

这个解决方案是高阶函数如何让我们减少代码重复的另一个证明。但是，始终需要显式传递比较函数也会变得乏味。如果我们能教 Idris 自己想出这样的功能，那就太好了。

接口正好解决了这个问题。这是一个例子：

```idris
interface Comp a where
  comp : a -> a -> Ordering

implementation Comp Bits8 where
  comp = compare

implementation Comp Bits16 where
  comp = compare
```

上面的代码定义了 *接口* `Comp` ，提供函数 `comp` 用于计算类型为 `a` 的两个值的排序，然后是 `Bits8` 和 `Bits16` 类型接口的两个 *实现*。请注意，`implementation` 关键字是可选的。

`Bits8` 和 `Bits16` 的 `comp` 实现都使用函数 `compare`，它是 *Prelude* 中类似接口的一部分，称为 `Ord`。

下一步是查看 REPL 中 `comp` 的类型：

```repl
Tutorial.Interfaces> :t comp
Tutorial.Interfaces.comp : Comp a => a -> a -> Ordering
```

`comp` 的类型签名中有趣的部分是初始的 `Comp a =>` 参数。这里，`Comp` 是类型参数 `a` 上的 *约束*。该签名可以读作：“对于任何类型 `a`，给定 `a` 的接口 `Comp` 的实现，我们可以比较 `a` 类型的两个值并返回一个 `Ordering` ”。
每当我们调用 `comp` 时，我们希望 Idris 自己得出一个 `Comp a` 类型的值，因此这里需要新的 `=>` 箭头。如果 Idris 没有推断出来，它将返回类型错误。

我们现在可以在相关函数的实现中使用`comp`。我们所要做的就是在这些派生函数前面加上一个 `Comp` 约束：

```idris
lessThan : Comp a => a -> a -> Bool
lessThan s1 s2 = LT == comp s1 s2

greaterThan : Comp a => a -> a -> Bool
greaterThan s1 s2 = GT == comp s1 s2

minimum : Comp a => a -> a -> a
minimum s1 s2 =
  case comp s1 s2 of
    LT => s1
    _  => s2

maximum : Comp a => a -> a -> a
maximum s1 s2 =
  case comp s1 s2 of
    GT => s1
    _  => s2
```

请注意，`minimum` 的定义与 `minimumBy` 的定义几乎相同。唯一的区别是，在 `minimumBy` 的情况下，我们必须将比较函数作为显式参数传递，而对于 `minimum`，它作为 `Comp` 的一部分提供实现，由 Idris 为我们传递。

因此，我们用接口 `Comp` 的实现为每种类型一劳永逸地定义了所有这些实用函数。

### 练习第 1 部分

1. 实现函数`anyLarger`，应该返回`True` 的条件为，
当且仅当值列表包含至少一个比给定的参考值更大的元素。使用接口 `Comp` 在你的实现中。

2. 实现函数`allLarger`，应该返回`True` 的条件为，
当且仅当值列表的 *只* 包含比给定的参考值更大的元素。请注意，对于空列表总是返回 true。在您的实现中使用接口 `Comp`。

3. 实现函数`maxElem`，试图提取
具有 `Comp` 实现的值列表中的最大元素。
对于 `minElem` 也是如此，它试图提取最小的元素。
请注意，在决定输出类型时必须考虑列表为空的可能性。

4. 为列表或列表等值定义一个接口 `Concat`，可以串联的字符串。提供实对于列表和字符串的实现。

5. 实现函数 `concatList` 用于连接使用 `Concat` 实现的列表中的值。
确保在您的列表中反映列表为空的可能输出类型。

## 更多关于接口的信息

在上一节中，我们了解了接口的基础知识：为什么它们有用以及如何定义和实现它们。在本节中，我们将学习一些稍微高级的概念：扩展接口、带约束的接口和默认实现。

### 扩展接口

一些接口会形成一种层次结构。例如，对于练习 4 中使用的 `Concat` 接口，可能有一个名为 `Empty` 的子接口，用于那些具有与串联相关的中性元素的类型。在这种情况下，我们将 `Concat` 的实现作为实现 `Empty` 的先决条件：

```idris
interface Concat a where
  concat : a -> a -> a

implementation Concat String where
  concat = (++)

interface Concat a => Empty a where
  empty : a

implementation Empty String where
  empty = ""
```

`Concat a => Empty a` 应读作：“`Concat` 类型 `a` 的实现是 *先决条件*，才能为 `a` 实现 `Empty` 接口”。但这也意味着，只要我们有接口 `Empty` 的实现，我们 *必须* 也有 `Concat` 的实现，并且可以调用相应的函数：

```idris
concatListE : Empty a => List a -> a
concatListE []        = empty
concatListE (x :: xs) = concat x (concatListE xs)
```

请注意，在 `concatListE` 的类型中，我们如何只使用 `Empty` 约束，以及在实现中我们如何仍然能够调用 `empty` 和 `concat`。

### 受约束的实现

有时，只有泛型类型的类型参数也实现了该接口，才能实现该接口。例如，为 `Maybe a` 实现接口 `Comp` 时，只有当类型 `a` 本身实现 `Comp` 时才有意义。我们可以使用与约束函数相同的语法来约束接口实现：

```idris
implementation Comp a => Comp (Maybe a) where
  comp Nothing  Nothing  = EQ
  comp (Just _) Nothing  = GT
  comp Nothing  (Just _) = LT
  comp (Just x) (Just y) = comp x y
```

这与扩展接口不同，尽管语法看起来非常相似。在这里，约束位于 * 类型参数 * 而不是完整类型。 `Comp (Maybe a)` 实现的最后一行比较了存储在两个 `Just` 中的值。这只有在这些值也有 `Comp` 实现的情况下才有可能。继续，让我们试试从上述实现中删除 `Comp a` 约束。学习阅读和理解 Idris 的类型错误对于修复它们很重要。

好消息是，Idris 将为我们解决所有这些限制：

```idris
maxTest : Maybe Bits8 -> Ordering
maxTest = comp (Just 12)
```

在这里，Idris 试图找到 `Comp (Maybe Bits8)` 的实现。为此，它需要 `Comp Bits8` 的实现。继续，将 `maxTest` 类型中的 `Bits8` 替换为 `Bits64`，并查看 Idris 产生的错误消息。

### 默认实现

有时，我们希望将几个相关的函数打包到一个接口中，以便程序员以最有效的方式实现每个函数，尽管它们 *可以* 相互实现。例如，考虑一个接口 `Equals` 用于比较两个值是否相等，如果两个值相等，则函数 `eq` 返回 `True` ，如果不相等则 `neq` 返回 `True`。当然，我们可以用 `eq` 来实现 `neq`，所以大多数时候在实现 `Equals` 时，我们只会实现后者。在这种情况下，我们可以在 `Equals` 的定义中给出 `neq` 的实现：

```idris
interface Equals a where
  eq : a -> a -> Bool

  neq : a -> a -> Bool
  neq a1 a2 = not (eq a1 a2)
```

如果在 `Equals` 的实现中我们只实现 `eq`，Idris 将使用 `neq` 的默认实现，如上所示：

```idris
Equals String where
  eq = (==)
```

另一方面，如果我们想为这两个函数提供显式实现，我们也可以这样做：

```idris
Equals Bool where
  eq True True   = True
  eq False False = True
  eq _ _         = False

  neq True  False = True
  neq False True  = True
  neq _ _         = False
```

### 练习第 2 部分

1. 实现接口`Equals`、`Comp`、`Concat` 和 `Empty` 用于 pairs，根据需要限制您的实现。（请注意，可以按顺序给出多个约束，例如其他函数参数：`Comp a => Comp b => Comp (a,b)`。）

2. Below is an implementation of a binary tree. Implement interfaces
   `Equals` and `Concat` for this type.

   ```idris
   data Tree : Type -> Type where
     Leaf : a -> Tree a
     Node : Tree a -> Tree a -> Tree a
   ```

## *Prelude* 中的接口

Idris *Prelude* 提供了几个接口和实现，它们在几乎所有重要的程序中都很有用。我将在这里介绍基本的。更高级的将在后面的章节中讨论。

这些接口中的大多数都带有相关的数学定律，并且假设实现遵守这些定律。这些法律也将在这里给出。

### `Eq`

可能是最常用的接口，`Eq`对应我们上面举例的接口`Equals`。代替 `eq` 和 `neq`，`Eq` 提供了两个运算符 `(==)` 和 `(/=)`比较两个相同类型的值是否相等。 *Prelude* 中定义的大多数数据类型都带有 `Eq` 的实现，每当程序员定义自己的数据类型时，`Eq` 通常是第一个他们实现的接口。

#### `Eq` 定律

我们期望以下定律适用于 `Eq` 的所有实现：

* `(==)` 具有 *自反性*：对于所有 `x`，`x == x = True`。这意味着每个值都等于它自己。

* `(==)` 具有 *交换律*：对于所有 `x` 和 `y`，`x == y = y == x`。
这意味着，传递给 `(==)` 的参数顺序无关紧要。

* `(==)` 具有 *传递性*：从 `x == y = True` 和 `y == z = True` 可以得出 `x == z = True`。

* `(/=)` 是 `(==)` 的否定：对于所有 `x` 和 `y` 都有 `x == y = not (x /= y)` 。

理论上，Idris 有能力在编译时为许多非原始类型验证这些定律。但是，出于实用主义考虑，在实现 `Eq` 时不需要这样做，因为编写这样的证明可能非常复杂。

### `Ord`

*Prelude* 中 `Comp` 的对应接口是 `Ord`。除了 `compare` 会与我们自己的 `comp` 相同之外，它还提供了比较运算符 `(>=)`、`(>)`、`(<=)` 和 `(<)`，以及工具函数 `max` 和 `min`。与 `Comp` 不同，`Ord` 扩展了 `Eq`，因此只要存在 `Ord` 约束，我们还可以访问运算符 `(= =)` 和 `(/=)` 及相关函数。

#### `Ord` 定律

我们期望以下定律适用于 `Ord` 的所有实现：

* `(<=)` is *reflexive* and *transitive*.
* `(<=)` 具有 *反对称性*：从 `x <= y = True` 和 `y <= x = True` 可以得到 `x == y = True`。
* `x <= y = y >= x`。
* `x < y = not (y <= x)`
* `x > y = not (y >= x)`
* `compare x y = EQ` => `x == y = True`
* `compare x y == GT = x > y`
* `compare x y == LT = x < y`

### `Semigroup` 和 `Monoid`

`Semigroup` 是我们示例接口 `Concat` 的附属物，运算符 `(<+>)`（也称为 *append*）对应于函数 `concat`。

同样，`Monoid` 对应 `Empty`，`neutral` 对应 `empty`。

这些是非常重要的接口，可用于将数据类型的两个或多个值组合成同一类型的单个值。示例包括但不限于数字类型的加法或乘法、数据序列的串联或计算的序列。

例如，考虑在几何应用程序中表示距离的数据类型。我们可以为此使用 `Double` ，但这不是很安全的类型。最好使用单个字段记录包装值类型 `Double`，以便为这些值提供清晰的语义：

```idris
record Distance where
  constructor MkDistance
  meters : Double
```

有一种结合两个距离的自然方法：我们将它们持有的值相加。这就产生了 `Semigroup` 的实现：

```idris
Semigroup Distance where
  x <+> y = MkDistance $ x.meters + y.meters
```

也很明显，零是此操作的中性元素：将零添加到任何值都不会影响该值。这也允许我们实现 `Monoid` ：

```idris
Monoid Distance where
  neutral = MkDistance 0
```

#### `Semigroup` 和 `Monoid` 定律

我们期望以下定律适用于 `Semigroup` 和 `Monoid` 的所有实现：

* `(<+>)` is *associative*: `x <+> (y <+> z) = (x <+> y) <+> z`, for all
  values `x`, `y`, and `z`.
* `neutral` is the *neutral element* with relation to `(<+>)`: `neutral <+>
  x = x <+> neutral = x`, for all `x`.

### `Show`

`Show` 接口主要用于调试目的，并且应该将给定类型的值显示为字符串，通常非常类似于用于创建值的 Idris 代码。这包括在必要时将参数正确包装在括号中。例如，在 REPL 中试验以下函数的输出：

```idris
showExample : Maybe (Either String (List (Maybe Integer))) -> String
showExample = show
```

在 REPL 试一下：

```repl
Tutorial.Interfaces> showExample (Just (Right [Just 12, Nothing]))
"Just (Right [Just 12, Nothing])"
```

我们将在练习中学习如何实现 `Show` 的实例。

### 字面量重载

Idris 中的字面量，例如整数字面量 (`12001`)、字符串字面量 (`"foo bar"`)、浮点字面量 (`12.112`) 和字符字面量(`'$'`) 都可以重载。这意味着，我们可以仅从字符串字面量创建 `String` 以外的类型的值。其具体工作原理必须等待另一部分，但对于许多常见情况，一个值足以实现接口 `FromString`（用于使用字符串文字面量）、`FromChar`（用于使用字符字面量）或 `FromDouble` （用于使用浮点字面量）。整数字面量的情况很特殊，将在下一节中讨论。

这是使用 `FromString` 的示例。假设我们编写了一个应用程序，用户可以在其中使用用户名和密码来识别自己。两者都由字符串组成，因此很容易混淆这两件事，尽管它们显然具有非常不同的语义。在这些情况下，建议为这两种情况提供新类型，特别是因为弄错这些东西是一个安全问题。

以下是执行此操作的三种示例记录类型：

```idris
record UserName where
  constructor MkUserName
  name : String

record Password where
  constructor MkPassword
  value : String

record User where
  constructor MkUser
  name     : UserName
  password : Password
```

为了创建 `User` 类型的值，即使是为了测试，我们也必须使用给定的构造函数包装所有字符串：

```idris
hock : User
hock = MkUser (MkUserName "hock") (MkPassword "not telling")
```

这是相当麻烦的，有些人可能认为这对于仅仅为了增加类型安全性而付出的代价太高了（我倾向于不同意）。幸运的是，我们可以很容易地恢复字符串字面量的便利性：

```idris
FromString UserName where
  fromString = MkUserName

FromString Password where
  fromString = MkPassword

hock2 : User
hock2 = MkUser "hock" "not telling"
```

### 数字接口

*Prelude* 还导出了几个提供常用算术运算的接口。下面是一个完整的接口列表和每个提供的函数：

* `Num`
  * `(+)` : Addition
  * `(*)` : Multiplication
  * `fromInteger` : Overloaded integer literals

* `Neg`
  * `negate` : Negation
  * `(-)` : Subtraction

* `Integral`
  * `div` : Integer division
  * `mod` : Modulo operation

* `Fractional`
  * `(/)` : Division
  * `recip` : Calculates the reciprocal of a value

如您所见：我们需要实现接口 `Num` 以对给定类型使用整数文字。为了使用像 `-12` 这样的负整数字面量，我们还必须实现接口 `Neg`。

### `Cast`

我们将在本节中快速讨论的最后一个接口是 `Cast`。它用于通过函数 `cast` 将一种类型的值转换为另一种类型的值。 `Cast` 是特殊的，因为它是通过 *两* 类型参数参数化的，这与我们目前看到的其他接口不同，只有一个类型参数。

到目前为止，`Cast`主要用于标准库中基本类型之间的相互转换，尤其是数值类型。当您查看从 *Prelude* 导出的实现时（例如，通过在 REPL 中调用 `:doc Cast`），您会看到几十个种原语类型的实现。

尽管 `Cast` 也可用于其他转换（用于从 `Maybe` 到 `List` 或从 `Either e` 到 `Maybe`），*Prelude* 和 *base* 似乎没有一致地引入这些。例如，从 `SnocList` 到 `List` 有 `Cast` 实现，反之亦然，但没有从 `Vect n` 到 `List`，或者从 `List1` 到 `List`，尽管这些都是可行的。

### 练习第 3 部分

这些练习旨在让您熟悉为自己的数据类型实现接口，因为您在编写 Idris 代码时必须定期这样做。

虽然很清楚为什么像 `Eq`、`Ord` 或 `Num` 这样的接口很有用，但 `Semigroup` 和 `Monoid` 的可用性一开始可能更难欣赏。因此，有几个练习可以为这些练习实现不同的实例。

1. Define a record type `Complex` for complex numbers, by pairing two values
   of type `Double`.  Implement interfaces `Eq`, `Num`, `Neg`, and
   `Fractional` for `Complex`.

2. Implement interface `Show` for `Complex`. Have a look at data type `Prec`
   and function `showPrec` and how these are used in the *Prelude* to
   implement instances for `Either` and `Maybe`.

   通过在 `Just` 和 `show` 中包装`Complex` 类型的值来实现，并在 REPL 中验证正确的行为。

3. Consider the following wrapper for optional values:

   ```idris
   record First a where
     constructor MkFirst
     value : Maybe a
   ```

   实现接口 `Eq`, `Ord`, `Show`, `FromString`, `FromChar`, `FromDouble`, `Num`、`Neg`、`Integral` 和 `Fractional` 用于 `First a`。所有这些都需要类型参数 `a` 的相应约束。考虑在有意义的地方实现并使用以下实用函数：

   ```idris
   pureFirst : a -> First a

   mapFirst : (a -> b) -> First a -> First b

   mapFirst2 : (a -> b -> c) -> First a -> First b -> First c
   ```

4. Implement interfaces `Semigroup` and `Monoid` for `First a` in such a
   way, that `(<+>)` will return the first non-nothing argument and
   `neutral` is the corresponding neutral element. There must be no
   constraints on type parameter `a` in these implementations.

5. Repeat exercises 3 and 4 for record `Last`. The `Semigroup`
   implementation should return the last non-nothing value.

   ```idris
   record Last a where
     constructor MkLast
     value : Maybe a
   ```

6. Function `foldMap` allows us to map a function returning a `Monoid` over
   a list of values and accumulate the result using `(<+>)` at the same
   time.  This is a very powerful way to accumulate the values stored in a
   list.  Use `foldMap` and `Last` to extract the last element (if any) from
   a list.

   请注意，`foldMap` 的类型更通用，不是专门用于列表的。它也适用于 `Maybe`、`Either` 和到目前为止我们还没有看过的其它容器类型。在后面的部分我们将了解接口 `Foldable` 。

7. Consider record wrappers `Any` and `All` for boolean values:

   ```idris
   record Any where
     constructor MkAny
     any : Bool

   record All where
     constructor MkAll
     all : Bool
   ```

   对 `Any` 实现 `Semigroup` 和 `Monoid`，仅当至少一个参数是 `True` 时，`(<+>)` 的结果是 `True`。确保 `neutral` 确实是此操作的中性元素。

   同样，为 `All` 实现 `Semigroup` 和 `Monoid`，当且仅当两个参数都是 `True`， `(<+>)` 的结果为 `True`，确保 `neutral` 确实是此操作的中性元素。

8. Implement functions `anyElem` and `allElems` using `foldMap` and `Any` or
   `All`, respectively:

   ```idris
   -- True, if the predicate holds for at least one element
   anyElem : (a -> Bool) -> List a -> Bool

   -- True, if the predicate holds for all elements
   allElems : (a -> Bool) -> List a -> Bool
   ```

9. Record wrappers `Sum` and `Product` are mainly used to hold numeric
   types.

   ```idris
   record Sum a where
     constructor MkSum
     value : a

   record Product a where
     constructor MkProduct
     value : a
   ```

   给定 `Num a` 的实现，实现 `Semigroup (Sum a)`
   和 `Monoid (Sum a)`，因此 `(<+>)` 对应于加法。

   同样，实现 `Semigroup (Product a)` 和 `Monoid (Product a)`，
   因此 `(<+>)` 对应于乘法。

   在实现 `neutral` 时，在处理数字类型时，可以使用整数字面量。

10. Implement `sumList` and `productList` by using `foldMap` together with
    the wrappers from Exercise 9:

    ```idris
    sumList : Num a => List a -> a

    productList : Num a => List a -> a
    ```

11. To appreciate the power and versatility of `foldMap`, after solving
    exercises 6 to 10 (or by loading `Solutions.Inderfaces` in a REPL
    session), run the following at the REPL, which will - in a single list
    traversal! - calculate the first and last element of the list as well as
    the sum and product of all values.

    ```repl
    > foldMap (\x => (pureFirst x, pureLast x, MkSum x, MkProduct x)) [3,7,4,12]
    (MkFirst (Just 3), (MkLast (Just 12), (MkSum 26, MkProduct 1008)))
    ```

    请注意，对于具有 `Ord` 实现，也有 `Semigroup` 实现的类型，它将返回两个值中的较小值或较大值。对于具有绝对最小值或最大值的类型（例如，自然数中的0，或 `Bits8` 中的 0 和 255），还可以可以被可以扩展到为 `Monoid`。

12. In an earlier exercise, you implemented a data type representing
    chemical elements and wrote a function for calculating their atomic
    masses. Define a new single field record type for representing atomic
    masses, and implement interfaces `Eq`, `Ord`, `Show`, `FromDouble`,
    `Semigroup`, and `Monoid` for this.

13. Use the new data type from exercise 12 to calculate the atomic mass of
    an element and compute the molecular mass of a molecule given by its
    formula.

    提示：使用合适的实用程序函数，您可以再次使用 `foldMap` 来实现此目的。

最后注意事项：如果您是函数式编程的新手，请确保在 REPL 中尝试您的练习 6 到 10 的实现。请注意，我们如何用最少的代码实现所有这些功能，以及如练习 11 所示，如何将这些行为组合在一个列表遍历中。

## 结论

* Interfaces allow us to implement the same function with different behavior
  for different types.
* Functions taking one or more interface implementations as arguments are
  called *constrained functions*.
* Interfaces can be organized hierarchically by *extending* other
  interfaces.
* Interfaces implementations can themselves be *constrained* requiring other
  implementations to be available.
* Interface functions can be given a *default implementation*, which can be
  overridden by implementers, for instance for reasons of efficiency.
* Certain interfaces allow us to use literal values such as string or
  integer literals for our own data types.

请注意，我还没有在本节中讲述有关字面量的全部故事。关于使用只接受一组受限值的类型的字面量的更多细节可以在关于 [原语](Prim.md) 章节中找到。

### 下一步是什么

在 [下一章](Functions2.md) 中，我们将仔细研究函数及其类型。我们将学习命名参数、隐式参数和擦除参数以及一些用于实现更复杂函数的构造函数。

<!-- vi: filetype=idris2
-->
