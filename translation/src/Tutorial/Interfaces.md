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

2. 下面是二叉树的实现。为此类型实现接口 `Equals` 和 `Concat`。

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

* `(<=)` 具有 *自反性* 和 *传递性*。
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

* `(<+>)` 具有 *交换律*: 对于所有值 `x`、`y` 和 `z`，都有 `x <+> (y <+> z) = (x <+> y) <+>
  z`,。
* `neutral` 是 *中性元素* 与 `(<+>)` 的关系： `neutral <+> x = x <+> neutral =
  x`，适用于所有 `x`。

### `Show`

The `Show` interface is mainly used for debugging purposes, and is
supposed to display values of a given type as a string, typically closely
resembling the Idris code used to create the value. This includes the
proper wrapping of arguments in parentheses where necessary. For instance,
experiment with the output of the following function at the REPL:

```idris
showExample : Maybe (Either String (List (Maybe Integer))) -> String
showExample = show
```

在 REPL 试一下：

```repl
Tutorial.Interfaces> showExample (Just (Right [Just 12, Nothing]))
"Just (Right [Just 12, Nothing])"
```

We will learn how to implement instances of `Show` in an exercise.

### Overloaded Literals

Literal values in Idris, such as integer literals (`12001`), string
literals (`"foo bar"`), floating point literals (`12.112`), and
character literals  (`'$'`) can be overloaded. This means, that we
can create values of types other than `String` from just a string
literal. The exact workings of this has to wait for another section,
but for many common cases, it is sufficient for a value to implement
interfaces `FromString` (for using string literals), `FromChar` (for using
character literals), or `FromDouble` (for using floating point literals).
The case of integer literals is special, and will be discussed in the next
section.

Here is an example of using `FromString`. Assume, we write an application
where users can identify themselves with a username and password. Both
consist of strings of characters, so it is pretty easy to confuse and mix
up the two things, although they clearly have very different semantics.
In these cases, it is advisable to come up with new types for the two,
especially since getting these things wrong is a security concern.

Here are three example record types to do this:

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

In order to create a value of type `User`, even for testing, we'd have
to wrap all strings using the given constructors:

```idris
hock : User
hock = MkUser (MkUserName "hock") (MkPassword "not telling")
```

This is rather cumbersome, and some people might think this to be too high
a price to pay just for an increase in type safety (I'd tend to disagree).
Luckily, we can get the convenience of string literals back very easily:

```idris
FromString UserName where
  fromString = MkUserName

FromString Password where
  fromString = MkPassword

hock2 : User
hock2 = MkUser "hock" "not telling"
```

### Numeric Interfaces

The *Prelude* also exports several interfaces providing the usual arithmetic
operations. Below is a comprehensive list of the interfaces and the
functions each provides:

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

As you can see: We need to implement interface `Num` to
use integer literals for a given type. In order to use
negative integer literals like `-12`, we also have to
implement interface `Neg`.

### `Cast`

The last interface we will quickly discuss in this section is `Cast`. It
is used to convert values of one type to values of another via
function `cast`. `Cast` is special, since it is parameterized
over *two* type parameters unlike the other interfaces we looked
at so far, with only one type parameter.

So far, `Cast` is mainly used for interconversion
between primitive types in the standard libraries,
especially numeric types. When you look
at the implementations exported from the *Prelude* (for instance,
by invoking `:doc Cast` at the REPL), you'll see that there are
dozens of implementations for most pairings of primitive types.

Although `Cast` would also be useful for other conversions (for
going from `Maybe` to `List` or for going from `Either e` to `Maybe`,
for instance), the *Prelude* and
*base* seem not to introduce these consistently. For instance,
there are `Cast` implementations from going from `SnocList` to
`List` and vice versa, but not for going from `Vect n` to `List`,
or for going from `List1` to `List`, although these would
be just as feasible.

### 练习第 3 部分

These exercises are meant to make you comfortable with
implementing interfaces for your own data types, as you
will have to do so regularly when writing Idris code.

While it is immediately clear why interfaces like
`Eq`, `Ord`, or `Num` are useful, the usability of
`Semigroup` and `Monoid` may be harder to appreciate at first.
Therefore, there are several exercises where you'll implement
different instances for these.

1. Define a record type `Complex` for complex numbers, by pairing two values
   of type `Double`.  Implement interfaces `Eq`, `Num`, `Neg`, and
   `Fractional` for `Complex`.

2. Implement interface `Show` for `Complex`. Have a look at data type `Prec`
   and function `showPrec` and how these are used in the *Prelude* to
   implement instances for `Either` and `Maybe`.

   Verify the correct behavior of your implementation by wrapping
   a value of type `Complex` in a `Just` and `show` the result at
   the REPL.

3. Consider the following wrapper for optional values:

   ```idris
   record First a where
     constructor MkFirst
     value : Maybe a
   ```

   Implement interfaces `Eq`, `Ord`, `Show`, `FromString`, `FromChar`, `FromDouble`,
   `Num`, `Neg`, `Integral`, and `Fractional` for `First a`. All of these will require
   corresponding constraints on type parameter `a`. Consider implementing and
   using the following utility functions where they make sense:

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

   Note, that the type of `foldMap` is more general and not specialized
   to lists only. It works also for `Maybe`, `Either` and other container
   types we haven't looked at so far. We will learn about
   interface `Foldable` in a later section.

7. Consider record wrappers `Any` and `All` for boolean values:

   ```idris
   record Any where
     constructor MkAny
     any : Bool

   record All where
     constructor MkAll
     all : Bool
   ```

   Implement `Semigroup` and `Monoid` for `Any`, so that the result of
   `(<+>)` is `True`, if and only if at least one of the arguments is `True`.
   Make sure that `neutral` is indeed the neutral element for this operation.

   Likewise, implement `Semigroup` and `Monoid` for `All`, so that the result of
   `(<+>)` is `True`, if and only if both of the arguments are `True`.
   Make sure that `neutral` is indeed the neutral element for this operation.

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

   Given an implementation of `Num a`, implement `Semigroup (Sum a)`
   and `Monoid (Sum a)`, so that `(<+>)` corresponds to addition.

   Likewise, implement `Semigroup (Product a)` and `Monoid (Product a)`,
   so that `(<+>)` corresponds to multiplication.

   When implementing `neutral`, remember that you can use integer
   literals when working with numeric types.

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

    Note, that there are also `Semigroup` implementations for
    types with an `Ord` implementation, which will return
    the smaller or larger of two values. In case of types
    with an absolute minimum or maximum (for instance, 0 for
    natural numbers, or 0 and 255 for `Bits8`), these can even
    be extended to `Monoid`.

12. In an earlier exercise, you implemented a data type representing
    chemical elements and wrote a function for calculating their atomic
    masses. Define a new single field record type for representing atomic
    masses, and implement interfaces `Eq`, `Ord`, `Show`, `FromDouble`,
    `Semigroup`, and `Monoid` for this.

13. Use the new data type from exercise 12 to calculate the atomic mass of
    an element and compute the molecular mass of a molecule given by its
    formula.

    Hint: With a suitable utility function, you can use `foldMap`
    once again for this.

Final notes: If you are new to functional programming, make sure
to give your implementations of exercises 6 to 10 a try at the REPL.
Note, how we can implement all of these functions with a minimal amount
of code and how, as shown in exercise 11, these behaviors can be
combined in a single list traversal.

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

Note, that I did not yet tell the whole story about literal values
in this section. More details for using literals with types that
accept only a restricted set of values can be found in the
chapter about [primitives](Prim.md).

### 下一步是什么

In the [next chapter](Functions2.md), we have a closer look
at functions and their types. We will learn about named arguments,
implicit arguments, and erased arguments as well as some
constructors for implementing more complex functions.

<!-- vi: filetype=idris2
-->
