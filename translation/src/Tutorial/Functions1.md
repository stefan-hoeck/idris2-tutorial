# 函数第 1 部分

Idris 是一种 *函数式* 编程语言。这意味着，函数是它的主要抽象形式（与 Java 等面向对象的语言不同，其中 *objects* 和 *classes* 是抽象的主要形式）。这也意味着我们希望 Idris 能够让我们非常轻松地组合函数以创建新函数。实际上，在 Idris 中，函数是*一等*的：函数可以将其他函数作为参数，并且可以将函数作为结果返回。

我们已经在 [introduction](Intro.md) 中了解了 Idris 中顶级函数声明的基本形式，因此我们将从那里学到的内容继续。

```idris
module Tutorial.Functions1
```

## 具有多个参数的函数

让我们实现一个函数，它检查它的三个 `Integer` 参数是否形成一个 [勾股三元组](https://en.wikipedia.org/wiki/Pythagorean_triple)。我们为此使用一个新的运算符：`==`，相等运算符。

```idris
isTriple : Integer -> Integer -> Integer -> Bool
isTriple x y z = x * x + y * y == z * z
```

在讨论类型之前，让我们先在 REPL 上试一下：

```repl
Tutorial.Functions1> isTriple 1 2 3
False
Tutorial.Functions1> isTriple 3 4 5
True
```

从这个例子可以看出，多参数函数的类型包含一个参数类型的序列（也称为 *输入类型*），由函数箭头（`->`）链接起来，其中由输出类型终止（在本例中为 `Bool`）。

该实现看起来有点像一个数学方程：我们在 `=` 的左侧列出参数，并在右侧描述要使用它们执行的计算。与命令式语言中的实现相比，函数式编程语言中的函数实现通常具有更多的数学外观，命令式语言通常不是描述*要计算什么*，而是通过将算法描述为*如何*来计算它命令式语句的序列。我们稍后会看到这种命令式风格在 Idris 中也可用，但只要有可能，我们更喜欢声明式风格。

从 REPL 示例中可以看出，可以通过传递由空格分隔的参数来调用函数。除非我们作为将包含额外的空格的表达式作为函数参数进行传递，否则不需要括号。当我们仅部分应用函数时，这非常方便（见本章后面）。

请注意，与 `Integer` 或 `Bits8` 不同，`Bool` 不是 Idris 语言中内置的原语数据类型，而只是您可以自己编写的自定义数据类型.我们将在下一章了解更多关于声明新数据类型的内容。

## 函数组合

函数可以通过多种方式组合，最直接的可能是点运算符：

```idris
square : Integer -> Integer
square n = n * n

times2 : Integer -> Integer
times2 n = 2 * n

squareTimes2 : Integer -> Integer
squareTimes2 = times2 . square
```

在 REPL 试试这个！它是否符合您的预期？

我们可以在不使用点运算符的情况下实现 `squareTimes2`，如下所示：

```idris
squareTimes2' : Integer -> Integer
squareTimes2' n = times2 (square n)
```

需要注意的是，由点链接的函数，运算符会从右到左调用： `times2 . square`，等同于 `\n => times2 (square n)` ，而不是 `\n => square (times2 n)`。

我们可以方便地使用点运算符链接多个函数来编写更复杂的函数：

```idris
dotChain : Integer -> String
dotChain = reverse . show . square . square . times2 . times2
```

这将首先将参数乘以四，然后将其平方两次，然后将其转换为字符串 (`show`) 并反转结果 `String`（函数 `show` 和 `reverse` 是 Idris *Prelude* 的一部分，因此在每个 Idris 程序中都可用）。

## 高阶函数

函数可以将其他函数作为参数。这是一个非常强大的概念，我们可以很容易地为此发疯。但为了理智起见，我们将慢慢开始：

```idris
isEven : Integer -> Bool
isEven n = mod n 2 == 0

testSquare : (Integer -> Bool) -> Integer -> Bool
testSquare fun n = fun (square n)
```

首先 `isEven` 使用 `mod` 函数来检查一个整数是否可以被 2 整除。但有趣的函数是 `testSquare`。它有两个参数：第一个参数的类型是 *从 `Integer` 到 `Bool` 的函数*，第二个参数是 `Integer` 类型。在传递给应用第一个参数之前，先把第二个参数进行平方计算。再一次，在 REPL 上试一试：

```repl
Tutorial.Functions1> testSquare isEven 12
True
```

花点时间了解这里发生了什么。我们将函数 `isEven` 作为参数传递给 `testSquare`。第二个参数是一个整数，它首先会被平方，然后传递给 `isEven`。虽然这不是很有趣，但我们会看到很多将函数作为参数传递给其他函数的用例。

我在上面说过，我们很容易发疯。例如，考虑以下示例：

```idris
twice : (Integer -> Integer) -> Integer -> Integer
twice f n = f (f n)
```

在 REPL 试一下：

```repl
Tutorial.Functions1> twice square 2
16
Tutorial.Functions1> (twice . twice) square 2
65536
Tutorial.Functions1> (twice . twice . twice . twice) square 2
*** huge number ***
```

您可能会对这种行为感到惊讶，因此我们将尝试对其进行分解。以下两个表达式的行为相同：

```idris
expr1 : Integer -> Integer
expr1 = (twice . twice . twice . twice) square

expr2 : Integer -> Integer
expr2 = twice (twice (twice (twice square)))
```

因此，`square` 将其参数提升到 2 次方，` 两次 square` 将其提升到 4 次方（通过连续调用 `square` 两次），` twice (twice square)` 将其提升到其 16 次方（通过连续调用 `twice square` 两次），依此类推，直到 `twice (twice (twice (twice square))))` 将其提高到 65536 次方，从而产生了令人印象深刻的巨大结果。

## 柯里化

一旦我们开始使用高阶函数，偏函数应用的概念（在数学家和逻辑学家 Haskell Curry 之后也称为 *柯里化*）变得非常重要。

在 REPL 会话中加载此文件并尝试以下操作：

```repl
Tutorial.Functions1> :t testSquare isEven
testSquare isEven : Integer -> Bool
Tutorial.Functions1> :t isTriple 1
isTriple 1 : Integer -> Integer -> Bool
Tutorial.Functions1> :t isTriple 1 2
isTriple 1 2 : Integer -> Bool
```

注意，我们如何在 Idris 中部分应用多参函数，并且返回一个新函数。例如， `isTriple 1` 会将参数 `1` 应用于函数 `isTriple` 并因此返回一个新函数，类型为为 `Integer -> Integer -> Bool`。我们甚至可以使用这种部分应用函数的结果作为一个新的顶级定义：

```idris
partialExample : Integer -> Bool
partialExample = isTriple 3 4
```

在 REPL 试一下：

```repl
Tutorial.Functions1> partialExample 5
True
```

我们已经在上面的 `twice` 示例中使用了偏函数的应用程序，只需很少的代码即可获得一些令人印象深刻的结果。

## 匿名函数

有时我们想将一个小的自定义函数传递给一个高阶函数，而无需编写顶层定义。例如，在下面的示例中，函数 `someTest` 非常具体，一般来说可能不是很有用，但我们仍然希望将它传递给高阶函数 `testSquare`：

```idris
someTest : Integer -> Bool
someTest n = n >= 3 || n <= 10
```

下面将展示如何将其传递给 `testSquare`：

```repl
Tutorial.Functions1> testSquare someTest 100
True
```

我们也可以使用匿名函数，而不用定义和使用 `someTest`：

```repl
Tutorial.Functions1> testSquare (\n => n >= 3 || n <= 10) 100
True
```

匿名函数有时也称为 *lambdas*（来自[λ演算](https://en.wikipedia.org/wiki/Lambda_calculus)),并且选择了反斜杠，因为它类似于希腊语
字母 * λ*。 `\n =>` 语法引入了一个新的参数为 `n` 的匿名函数，实现位于函数箭头的右侧。像其他顶级函数一样，lambda 可以有多个参数，并以逗号分隔：`\x,y => x * x + y`。当我们将 lambdas 作为参数传递给高阶函数时，它们通常需要用括号括起来或由美元运算符 `($)` 分开（请参阅下一节）。

请注意，在 lambda 中，参数不使用类型进行注释，因此 Idris 必须能够从当前上下文中推断出它们。

## 操作符

在 Idris 中，`.`、`*` 或 `+` 等中缀运算符并未内置于语言中，而只是常规的 Idris 函数对应的中缀符号。当我们使用非中缀表示法的运算符时，我们必须将它们包裹在括号中。

举个例子，让我们为类型为 `Bits8 -> Bits8` 的函数自定义操作符：

```idris
infixr 4 >>>

(>>>) : (Bits8 -> Bits8) -> (Bits8 -> Bits8) -> Bits8 -> Bits8
f1 >>> f2 = f2 . f1

foo : Bits8 -> Bits8
foo n = 2 * n + 3

test : Bits8 -> Bits8
test = foo >>> foo >>> foo >>> foo
```

除了声明和定义操作符本身，我们还必须指定它的固定性：`infixr 4 >>>` 表示，`(>>>)` 关联到右边（意思是，那个
`f >>> g >>> h` 将被解释为 `f >>> (g >>> h)`)优先级为 `4`。你也可以在 REPL 中 看看 *Prelude* 导出的运算符的固定性：

```repl
Tutorial.Functions1> :doc (.)
Prelude.. : (b -> c) -> (a -> b) -> a -> c
  Function composition.
  Totality: total
  Fixity Declaration: infixr operator, level 9
```

当您在表达式中混合使用中缀运算符时，具有较高优先级的运算符绑定得更紧密。例如，`(+)` 的优先级为 8，而 `(*)` 的优先级为 9。因此，`a * b + c ` 与 `(a * b) + c` 相同，而不是 `a * (b + c)`。

### 操作符块

运算符符可以像常规函数一样被部分应用。在这种情况下，整个表达式必须用括号括起来，称为 * 运算符块 *。这里有两个例子：

```repl
Tutorial.Functions1> testSquare (< 10) 5
False
Tutorial.Functions1> testSquare (10 <) 5
True
```

如您所见，`(< 10)`和 `(10 <)`。第一个测试，它的参数为是否小于10，第二，参数是否大于10。

运算符部分不起作用的一个例外是使用 *minus* 运算符 `(-)`。下面是一个例子来证明这一点：

```idris
applyToTen : (Integer -> Integer) -> Integer
applyToTen f = f 10
```

这只是一个将数字 10 应用于其函数参数的高阶函数。这在以下示例中非常有效：

```repl
Tutorial.Functions1> applyToTen (* 2)
20
```

但是，如果我们想从 10 中减去 5，以下将失败：

```repl
Tutorial.Functions1> applyToTen (- 5)
Error: Can't find an implementation for Num (Integer -> Integer).

(Interactive):1:12--1:17
 1 | applyToTen (- 5)
```

这里的问题是，Idris 将 `- 5` 视为整数字面量而不是运算符块。在这种特殊情况下，我们因此必须使用匿名函数：

```repl
Tutorial.Functions1> applyToTen (\x => x - 5)
5
```

### 非运算符的中缀表示法

在 Idris 中，可以对常规双参数函数使用中缀表示法，方法是将它们包装在反引号中。甚至可以为这些定义优先级（固定性）并在运算符块中使用它们，就像常规运算符一样：

```idris
infixl 8 `plus`

infixl 9 `mult`

plus : Integer -> Integer -> Integer
plus = (+)

mult : Integer -> Integer -> Integer
mult = (*)

arithTest : Integer
arithTest = 5 `plus` 10 `mult` 12

arithTest' : Integer
arithTest' = 5 + 10 * 12
```

### *Prelude* 导出的运算符

以下是 *Prelude* 导出的重要运算符列表。其中大多数具有 * 约束 *，也就是说它们仅适用于实现了某个 * 接口 * 的类型。现在不要担心这个。我们将在适当的时候了解接口，运算符会按照直觉行事。例如，加法和乘法适用于所有数字类型，比较运算符适用于 *Prelude* 中的几乎所有类型，但函数除外。

* `(.)`：函数组合

* `(+)`：加法

* `(*)`：乘法

* `(-)`：减法

* `(/)`：除法

* `(==)` ：判断两个值是否相等

* `(/=)` ：如果两个值不相等则结果为真

* `(<=)`、`(>=)`、`(<)` 和 `(>)` ：比较运算符

* `($)`：函数应用


上面最特别的是最后一个。它的优先级为 0，所有其他运算符都比他绑定得更紧密。因此可以使用它来减少所需的括号数量。例如，不写 `isTriple 3 4 (2 + 3 * 1)` 我们可以写成 `isTriple 3 4 $ 2 + 3 * 1`，这完全一样。有时，这有助于提高可读性，虽然有时并不会。要记住的重要一点是 `fun $ x y` 与 `fun (x y)` 相同。

## 练习

1. 通过使用点运算符并删除第二个参数重新实现函数 `testSquare` 和 `twice`（查看 `squareTimes2` 的实现应该可以让你更加了解）。这种编写函数实现的高度简洁的方式有时被称为*无值风格*，并且通常是编写小型实用函数的首选方式。


2. 通过组合上面的函数 `isEven` 和 `not`（来自 Idris *Prelude*）来声明和实现函数 `isOdd`。使用无值风格。


3. 声明并实现函数 `isSquareOf`，检查它的第一个 `Integer` 参数是否是第二个参数的平方。


4. 声明并实现函数 `isSmall`，检查其 `Integer` 参数是否小于或等于 100。在你的实现中使用比较运算符 `<=` 或 `>=` 之一。


5. 声明并实现函数 `absIsSmall`，检查其 `Integer` 参数的绝对值是否小于等于100。在你的实现中使用函数 `isSmall` 和 `abs `（来自 Idris *Prelude*），最好是无值风格的。


6. 在这个稍微扩展的练习中，我们将实现一些实用程序来处理 `Integer` 谓词（从 `Integer` 到 `Bool` 的函数）。实现以下高阶函数（在您的实现中使用布尔运算符 `&&`、`||` 和函数 `not`）：


   ```idris
   -- return true, if and only if both predicates hold
   and : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool

   -- return true, if and only if at least one predicate holds
   or : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool

   -- return true, if the predicate does not hold
   negate : (Integer -> Bool) -> Integer -> Bool
   ```

   完成这个练习后，在 REPL 中试一试。在下面的例子中，我们通过用反引号包裹来使用两参数函数 `and` 的中缀表示法的
。这只是一种语法糖，使某些功能应用程序更具可读性：

   ```repl
   Tutorial.Functions1> negate (isSmall `and` isOdd) 73
   False
   ```

7. 如上所述，Idris 允许我们定义自己的中缀运算符。更好的是，Idris 支持函数名的*重载*，即两个函数或运算符可以有相同的名称，但类型和实现不同。 Idris 将使用类型来区分同名的运算符和函数。


   这允许我们重新实现函数 `and`、`or` 和 `negate`，在练习 6 中，使用布尔代数中现有的运算符和函数：

   ```idris
   -- return true, if and only if both predicates hold
   (&&) : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool
   x && y = and x y

   -- return true, if and only if at least one predicate holds
   (||) : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool

   -- return true, if the predicate does not hold
   not : (Integer -> Bool) -> Integer -> Bool
   ```

   实现另外两个函数并在 REPL 上测试它们：

   ```repl
   Tutorial.Functions1> not (isSmall && isOdd) 73
   False
   ```

## 结论

我们在本章中学到了什么：

* Idris 中的函数可以接受任意数量的参数，由函数类型中的 `->` 分隔。

* 函数可以依次使用点运算符进行组合，这会产生高度简洁的代码。

* 可以通过传递更少的函数来偏应用函数，参数少于函数的预期。结果是一个新的函数，预期传入剩下的参数。这种技术被称为*柯里化*。

* 函数可以作为参数传递给其他函数，
允许我们轻松组合小型程序单元来创建
更复杂的行为。

* 我们可以将匿名函数 (*lambdas*) 传递给高阶函数，如果编写相应的顶层函数太繁琐。

* Idris 允许我们定义自己的中缀运算符。这些必须写在括号中，除非它们被声明
中缀表示法。

* 也可以部分应用中缀运算符。这些*运算符块*必须用括号括起来，并且用作运算符的第一个或第二个参数被确定。

* Idris 支持名称重载：函数可以具有相同的名称，但拥有不同的实现。Idris 将根据所涉及的类型决定使用哪个函数。

请注意，模块中的函数和运算符名称必须是唯一的。为了定义两个具有相同名称的函数，它们必须在不同的模块中声明。如果 Idris 无法决定使用这两个函数中的哪一个，我们可以通过在函数前面加上其 *命名空间* 的（部分）前缀来帮助名称解析：

```repl
Tutorial.Functions1> :t Prelude.not
Prelude.not : Bool -> Bool
Tutorial.Functions1> :t Functions1.not
Tutorial.Functions1.not : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool
```

### 下一步是什么

在 [下一节](DataTypes.md) 中，我们将学习如何定义我们自己的数据类型以及如何构造和解构这些新类型的值。我们还将学习泛型类型和函数。

<!-- vi: filetype=idris2
-->
