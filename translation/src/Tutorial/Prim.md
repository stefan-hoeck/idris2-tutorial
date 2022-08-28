# 原语

到目前为止，在我们讨论的主题中，我们几乎从未讨论过 Idris 中的原始类型。它们在哪里，我们在一些计算中使用它们，但我从来没有真正解释过它们是如何工作的以及它们来自哪里，我也没有详细说明我们可以用它们做什么和不能做什么。

```idris
module Tutorial.Prim

import Data.Bits
import Data.String

%default total
```

## 原语是如何实现的

### 关于后端的简短说明

根据 [Wikipedia](https://en.wikipedia.org/wiki/Compiler)，编译器是“一种计算机程序，它将以一种编程语言（源语言）编写的计算机代码翻译成另一种语言（目标语言） ”。 Idris 编译器就是这样：一个将 Idris 编写的程序翻译成 Chez Scheme 编写的程序的程序。然后这个 Scheme 代码由 Chez Scheme 解释器解析和解释，它必须安装在我们用来运行已编译 Idris 程序的计算机上。

但这只是故事的一部分。 Idris 2 从一开始就设计为支持不同的代码生成器（所谓的 *后端*），这允许我们编写 Idris 代码以针对不同的平台，并且您的 Idris 安装附带了几个可用的附加后端。您可以指定要与 `--cg` 命令行参数一起使用的后端（`cg` 代表 *代码生成器*）。例如：

```sh
idris2 --cg racket
```

以下是标准 Idris 安装可用的后端的非全面列表（在括号中给出命令行参数中使用的名称）：

* Racket Scheme (`racket`)：这是 Scheme 编程语言的另一种方言，当 Chez Scheme
  在您的操作系统上不可用时，它很有用。
* Node.js (`node`)：这会将 Idris 程序转换为 JavaScript。
* 浏览器 (`javascript`)：另一个 JavaScript 后端，允许您编写在 Idris 的浏览器中运行的 Web 应用程序。
* RefC (`refc`)：后端将 Idris 编译为 C 代码，然后由 C 编译器进一步编译。

我计划至少在本 Idris 指南的另一部分中更详细地介绍 JavaScript 后端，因为我自己也经常使用它们。

Idris 项目还没有正式支持几个外部后端，其中包括将 Idris 代码编译为 Java 和 Python 的后端。您可以在 [Idris Wiki](https://github.com/idris-lang/Idris2/wiki/1-%5BLanguage%5D-External-backends) 上找到外部后端列表。

### Idris 原语

*原语数据类型* 是与一组 *原语函数* 一起内置到 Idris 编译器中的类型，这些函数用于对原始数据执行计算。因此，您不会在 *Prelude* 的源代码中找到原语类型或函数的定义。

这是 Idris 中的原语类型列表：

* 有符号、固定精度整数：
  * `Int8`：[-128,127] 范围内的整数
  * `Int16`：[-32768,32767] 范围内的整数
  * `Int32`：[-2147483648,2147483647] 范围内的整数
  *`Int64`：范围内的整数 [-9223372036854775808,9223372036854775807]
* 无符号、固定精度整数：
  * `Bits8`：[0,255] 范围内的整数
  * `Bits16`：[0,65535] 范围内的整数
  * `Bits32`：[0,4294967295] 范围内的整数
  * `Bits64`：[0,18446744073709551615] 范围内的整数
* `Integer`：有符号的任意精度整数。
* `Double`：双精度（64 位）浮点数。
* `Char`：一个 unicode 字符。
* `String`：Unicode 字符序列。
* `%World`：当前世界状态的符号表示。
  当我向您展示如何实现 IO 时，我们了解了这一点。
  大多数时候，您不会自己处理这种类型的值的代码。
* `Int`：这个比较特殊。它是一个固定精度的有符号整数，
   但位大小在某种程度上取决于后端和
   （也许）我们使用的平台。
   例如，如果您使用默认 Chez Scheme 后端，则 `Int` 是
   一个 64 位有符号整数，而在 JavaScript 后端出于性能原因它是一个32 位有符号整数。因此，`Int` 没有太多的保证，你应该尽可能指定使用上面列出的整数类型其中一个。

学习在编译器源代码中定义原语类型和函数的位置可能具有指导意义。此源代码可以在 [Idris 项目](https://github.com/idris-lang/Idris2) 的文件夹 `src` 中找到，原语类型是数据类型 `Core.TT.Constant` 的常量构造函数。

### 原语函数

所有对原语进行的计算都基于两种原语函数：编译器内置的（见下文）和程序员通过外部函数接口（FFI）定义的函数，我将在另一章中讨论。

内置原语函数是编译器已知的函数，其定义在 *Prelude* 中找不到。它们定义了可用于原语类型的核心函数。通常，您不会直接调用它们（尽管在大多数情况下这样做非常好），而是通过 *Prelude* 或 *base* 库导出的函数和接口。

例如，将两个八位无符号整数相加的原语函数是 `prim__add_Bits8`。您可以在 REPL 中检查其类型和行为：

```repl
Tutorial.Prim> :t prim__add_Bits8
prim__add_Bits8 : Bits8 -> Bits8 -> Bits8
Tutorial.Prim> prim__add_Bits8 12 100
112
```

如果查看 `Bits8` 的实现接口 `Num` 的源代码，您会看到加号运算符只是在内部调用 `prim__add_Bits8`。原语接口实现中的大多数其他函数也是如此。例如，除了 `%World` 之外的每个原语类型都带有原语比较函数。对于 `Bits8`，它们是：`prim__eq_Bits8`、`prim__gt_Bits8`、`prim__lt_Bits8`、`prim__gte_Bits8` 和 `prim__lte_Bits8`。请注意，这些函数不返回 `Bool`（在 Idris 中 *不是* 原语类型），而是 `Int`。因此，它们不像接口 `Eq` 和 `Comp` 中的相应运算符实现那样安全或方便。另一方面，它们不会通过转换为 `Bool` 并且因此在性能关键代码中的性能可能会稍好一些（您只能在经过一些认真的分析后才能识别）。

与原语类型一样，原语函数在编译器源代码中被列为数据类型 (`Core.TT.PrimFn`) 中的构造函数。我们将在以下部分中介绍其中的大部分内容。

### 原语的重要性

在大多数情况下，原语函数和类型对编译器是不透明的：它们必须由每个后端单独定义和实现，因此，编译器对原语值的内部结构和原语函数的内部工作一无所知。例如，在下面的递归函数中，*我们* 知道递归调用中的参数必须收敛到基本情况（除非我们使用的后端存在错误），但编译器不知道：

```idris
covering
replicateBits8' : Bits8 -> a -> List a
replicateBits8' 0 _ = []
replicateBits8' n v = v :: replicateBits8' (n - 1) v
```

在这些情况下，我们要么只满足于 *covering* 函数，要么使用 `assert_smaller` 来说服整体检查器（首选方式）：

```idris
replicateBits8 : Bits8 -> a -> List a
replicateBits8 0 _ = []
replicateBits8 n v = v :: replicateBits8 (assert_smaller n $ n - 1) v
```

我之前已经向您展示了使用 `assert_smaller` 的风险，因此我们必须格外小心，以确保新函数参数相对于基本情况确实更小。

虽然 Idris 对原语和相关函数的内部工作原理一无所知，但当输入编译时已知的值时，这些函数中的大多数在求值期间仍然会减少。例如，我们可以简单地证明对于 `Bits8`，以下等式成立：

```idris
zeroBits8 : the Bits8 0 = 255 + 1
zeroBits8 = Refl
```

由于不了解原语的内部结构或原语函数的实现，Idris 无法帮助我们证明此类函数和值的任何 *泛型* 属性。这是一个例子来证明这一点。假设我们想将一个列表包装在一个由列表长度索引的数据类型中：

```idris
data LenList : (n : Nat) -> Type -> Type where
  MkLenList : (as : List a) -> LenList (length as) a
```

当我们连接两个 `LenList` 时，应该累加长度索引。这就是列表连接影响列表长度的方式。我们可以安全地告诉伊德里斯这是真的：

```idris
0 concatLen : (xs,ys : List a) -> length xs + length ys = length (xs ++ ys)
concatLen []        ys = Refl
concatLen (x :: xs) ys = cong S $ concatLen xs ys
```

通过上述引理，我们可以实现 `LenList` 的串联：

```idris
(++) : LenList m a -> LenList n a -> LenList (m + n) a
MkLenList xs ++ MkLenList ys =
  rewrite concatLen xs ys in MkLenList (xs ++ ys)
```

字符串也是不可能的。在某些应用程序中，将字符串与其长度配对会很有用（例如，如果我们想确保字符串在解析过程中严格缩短，因此最终会被完全消耗掉），但 Idris 无法帮助我们正确处理这些事情。没有办法以安全的方式实现并证明以下引理：

```idris
0 concatLenStr : (a,b : String) -> length a + length b = length (a ++ b)
```

<!-- markdownlint-disable MD026 -->
### 相信我！
<!-- markdownlint-enable MD026 -->

为了实现 `concatLenStr`，我们必须放弃所有安全，使用强制类型的十吨破坏球：`believe_me`。这个原语函数允许我们自由地将任何类型的值强制转换为任何其他类型的值。不用说，只有当我们 *真的* 知道我们在做什么时，这才是安全的：

```idris
concatLenStr a b = believe_me $ Refl {x = length a + length b}
```

在 `x = length a + length b}` 中显式分配变量 `x` 是必要的，否则 Idris 会抱怨 *未解决的孔*：它可以在 `Refl` 构造函数中推断参数 `x` 的类型。我们可以在这里为 `x` 分配任何类型，因为无论如何我们都将结果传递给 `believe_me`，但我认为将等式的两侧之一分配给明确我们的意图。

原始类型的复杂性越高，假设它拥有最基本的属性的风险就越大。例如，我们可能会误以为浮点加法具有结合性：

```idris
0 doubleAddAssoc : (x,y,z : Double) -> x + (y + z) = (x + y) + z
doubleAddAssoc x y z = believe_me $ Refl {x = x + (y + z)}
```

好吧，你猜怎么着：那是个谎言。谎言将我们直接带入 `Void`：

```idris
Tiny : Double
Tiny = 0.0000000000000001

One : Double
One = 1.0

wrong : (0 _ : 1.0000000000000002 = 1.0) -> Void
wrong Refl impossible

boom : Void
boom = wrong (doubleAddAssoc One Tiny Tiny)
```

下面是上面代码中发生的情况：对 `doubleAddAssoc` 的调用返回一个证明 `One + (Tiny + Tiny)` 等于 `(One + Tiny) + Tiny`。但是 `One + (Tiny + Tiny)` 等于 `1.0000000000000002`，而 `(One + Tiny) + Tiny` 等于 `1.0`。因此，我们可以将我们的（错误的）证明传递给 `wrong`，因为它是正确的类型，并由此得出 `Void` 的证明。

## 使用字符串

*base* 中的模块 `Data.String` 提供了一组丰富的函数来处理字符串。所有这些都基于编译器内置的以下原语操作：

* `prim__strLength`：返回字符串的长度。
* `prim__strHead`：从字符串中提取第一个字符。
* `prim__strTail`：从字符串中删除第一个字符。
* `prim__strCons`：在字符串前面添加一个字符。
* `prim__strAppend`：追加两个字符串。
* `prim__strIndex`：从字符串中提取给定位置的字符。
* `prim__strSubstr`：提取给定位置之间的子字符串。

不用说，并非所有这些功能都是完整的。因此，Idris 必须确保在编译期间不会减少无效调用，否则编译器会崩溃。但是，如果我们通过编译和运行相应的程序来强制对部分原语函数求值，则该程序将崩溃并出现错误：

```repl
Tutorial.Prim> prim__strTail ""
prim__strTail ""
Tutorial.Prim> :exec putStrLn (prim__strTail "")
Exception in substring: 1 and 0 are not valid start/end indices for ""
```

请注意，`prim__strTail ""` 在 REPL 中没有减少，以及如果我们编译和执行程序，相同的表达式如何导致运行时异常。对 `prim__strTail` 的有效调用减少得很好，但是：

```idris
tailExample : prim__strTail "foo" = "oo"
tailExample = Refl
```

### 打包和解包

处理字符串的两个最重要的函数是 `unpack` 和 `pack`，它们将字符串转换为字符列表，以及反过来。这允许我们通过迭代或折叠字符列表来方便地实现许多字符串操作。这可能并不总是最有效的做法，但除非您计划处理大量文本，否则它们的工作和性能相当不错。

### 字符串插值

Idris 允许我们将任意字符串表达式包含在字符串文字中，方法是将它们包裹在花括号中，第一个必须用反斜杠转义。例如：

```idris
interpEx1 : Bits64 -> Bits64 -> String
interpEx1 x y = "\{show x} + \{show y} = \{show $ x + y}"
```

这是从不同类型的值组装复杂字符串的一种非常方便的方法。此外，还有接口`Interpolation`，它允许我们在插值字符串中使用值，而不必先将它们转换为字符串：

```idris
data Element = H | He | C | N | O | F | Ne

Formula : Type
Formula = List (Element,Nat)

Interpolation Element where
  interpolate H  = "H"
  interpolate He = "He"
  interpolate C  = "C"
  interpolate N  = "N"
  interpolate O  = "O"
  interpolate F  = "F"
  interpolate Ne = "Ne"

Interpolation (Element,Nat) where
  interpolate (_, 0) = ""
  interpolate (x, 1) = "\{x}"
  interpolate (x, k) = "\{x}\{show k}"

Interpolation Formula where
  interpolate = foldMap interpolate

ethanol : String
ethanol = "The formulat of ethanol is: \{[(C,2),(H,6),(O, the Nat 1)]}"
```

### 原始和多行字符串字面量

在字符串文字中，我们必须转义某些字符，如引号、反斜杠或换行符。例如：

```idris
escapeExample : String
escapeExample = "A quote: \". \nThis is on a new line.\nA backslash: \\"
```

Idris 允许我们输入原始字符串文字，无需转义引号和反斜杠，方法是在引号前后使用相同数量的井号进行包裹。例如：

```idris
rawExample : String
rawExample = #"A quote: ". A blackslash: \"#

rawExample2 : String
rawExample2 = ##"A quote: ". A blackslash: \"##
```

对于原始字符串字面量，仍然可以使用字符串插值，但开始的花括号必须以反斜杠为前缀，并且加上和用于打开关闭字符串字面量的相同数据的井号：

```idris
rawInterpolExample : String
rawInterpolExample = ##"An interpolated "string": \##{rawExample}"##
```

最后，Idris 还允许我们方便地编写多行字符串。如果我们想要原始的多行字符串字面量，这些可以用井号前缀和后缀，它们也可以与字符串插值结合使用。多行文字用三引号字符打开和关闭。缩进结束的三引号允许我们缩进整个多行文字。用于缩进的空格不会出现在结果字符串中。例如：

```idris
multiline1 : String
multiline1 = """
  And I raise my head and stare
  Into the eyes of a stranger
  I've always known that the mirror never lies
  People always turn away
  From the eyes of a stranger
  Afraid to see what hides behind the stare
  """

multiline2 : String
multiline2 = #"""
  An example for a simple expression:
  "foo" ++ "bar".
  This is reduced to "\#{"foo" ++ "bar"}".
  """#
```

请务必查看 REPL 中的示例字符串，以了解插值和原始字符串文字的效果，并将其与我们使用的语法进行比较。

### 练习第 1 部分

在这些练习中，你应该实现一堆用于消费和转换字符串的实用函数。我在这里没有给出预期的类型，因为你应该自己想出那些。

1. 为字符串实现类似于 `map`、`filter` 和 `mapMaybe` 的函数。这些的输出类型应该始终是一个字符串。

2. 为字符串实现类似于 `foldl` 和 `foldMap` 的函数。

3. 为字符串实现类似于 `traverse` 的函数。输出类型应该是一个包装的字符串。

4. 为字符串实现绑定运算符。输出类型应该再次是字符串。

## 整数

正如本章开头所列出的，Idris 提供了不同的固定精度有符号和无符号整数类型以及 `Integer`，一种任意精度的有符号整数类型。它们都带有以下原语函数（此处以 `Bits8` 为例）：

* `prim__add_Bits8`：整数加法。
* `prim__sub_Bits8`：整数减法。
* `prim__mul_Bits8`：整数乘法。
* `prim__div_Bits8`：整数除法。
* `prim__mod_Bits8`：模函数。
* `prim__shl_Bits8`：按位左移。
* `prim__shr_Bits8`：按位右移。
* `prim__and_Bits8`：按位 *与*。
* `prim__or_Bits8`：按位 *或*。
* `prim__xor_Bits8`：按位 *异或*。

通常，您可以通过接口 `Num` 中的运算符使用加法和乘法函数，通过接口 `Neg` 使用减法函数，以及除法函数 (`div`和 `mod`) 通过接口 `Integral`。位运算可通过接口 `Data.Bits.Bits` 和 `Data.Bits.FiniteBits` 获得。

对于所有整数类型，假设以下定律适用于数值运算（`x`、`y` 和 `z` 是相同原始整数类型的任意值） ：

* `x + y = y + x`：加法是可交换的。
* `x + (y + z) = (x + y) + z`：加法是结合的。
* `x + 0 = x`：零是加法的中性元素。
* `x - x = x + (-x) = 0`：`-x` 是 `x` 的加法逆。
* `x * y = y * x`：乘法是可交换的。
* `x * (y * z) = (x * y) * z`：乘法是结合的。
* `x * 1 = x`：1 是乘法的中性元素。
* `x * (y + z) = x * y + x * z`：分配律成立。
* ``y * (x `div` y) + (x `mod` y) = x``（对于 `y /= 0`）。

请注意，官方支持的后端使用 *欧几里得模数* 来计算 `mod`： For `y /= 0`, ``x `mod` y``始终是严格小于 `abs y` 的非负值，因此上面给出的定律确实成立。如果 `x` 或 `y` 是负数，这与许多其他语言所做的不同，但出于以下 [文章](https://www.microsoft. com/en-us/research/publication/division-and-modulus-for-computer-scientists/)。

### 无符号整数

无符号固定精度整数类型（`Bits8`、`Bits16`、`Bits32` 和 `Bits64`）带有所有整数接口的实现（`Num`、`Neg` 和 `Integral`）以及用于按位运算的两个接口（`Bits` 和 `FiniteBits`）。除了 `div` 和 `mod` 之外的所有函数都是总计的。通过计算余数模 `2^bitsize` 来处理溢出。例如，对于 `Bits8`，所有操作都以 256 为模计算其结果：

```repl
Main> the Bits8 255 + 1
0
Main> the Bits8 255 + 255
254
Main> the Bits8 128 * 2 + 7
7
Main> the Bits8 12 - 13
255
```

### 有符号整数

与无符号整数类型一样，有符号固定精度整数类型（`Int8`、`Int16`、`Int32` 和 `Int64`）具有以下实现所有整数接口和用于按位运算的两个接口（`Bits` 和 `FiniteBits`）。如果结果仍然超出范围，则通过计算余数模 `2^bitsize` 并添加下限（负数）来处理溢出。例如，对于 `Int8`，所有操作都以 256 为模计算结果，如果结果仍然超出范围，则减去 128：

```repl
Main> the Int8 2 * 127
-2
Main> the Int8 3 * 127
125
```

### 位运算

模块 `Data.Bits` 导出用于对整数类型执行按位运算的接口。我将展示几个关于无符号 8 位数字 (`Bits8`) 的示例，以向不熟悉按位算术的读者解释这个概念。请注意，对于无符号整数类型，这比有符号版本更容易掌握。那些必须在其位模式中包含有关数字的 *符号* 的信息，并且假设 Idris 中的有符号整数使用 [二进制补码表示](https://en.wikipedia.org/wiki/ 2%27s_complement)，这里不再赘述。

无符号 8 位二进制数在内部表示为 8 位序列（值为 0 或 1），每个位对应于 2 的幂。例如，数字 23 (= 16 + 4 + 2 + 1)表示为 `0001 0111`：

```repl
23 in binary:    0  0  0  1    0  1  1  1

Bit number:      7  6  5  4    3  2  1  0
Decimal value: 128 64 32 16    8  4  2  1
```

我们可以使用函数 `testBit` 来检查给定位置的位是否已设置：

```repl
Tutorial.Prim> testBit (the Bits8 23) 0
True
Tutorial.Prim> testBit (the Bits8 23) 1
True
Tutorial.Prim> testBit (the Bits8 23) 3
False
```

同样，我们可以使用函数 `setBit` 和 `clearBit` 在某个位置设置或取消设置位：

```repl
Tutorial.Prim> setBit (the Bits8 23) 3
31
Tutorial.Prim> clearBit (the Bits8 23) 2
19
```

还有运算符 `(.&.)`（按位 *与*）和 `(.|.)`（按位 *或*）以及用于对整数值执行布尔运算的函数 `xor`（按位 *异或*）。例如 `x .&. y` 正好设置了那些位，`x` 和 `y` 都设置了，而 `x .|. y` 设置了在 `x` 或 `y`（或两者）中设置的所有位，并且 ``x `xor` y`` 设置了那些位设置为以下两个值之一：

```repl
23 in binary:          0  0  0  1    0  1  1  1
11 in binary:          0  0  0  0    1  0  1  1

23 .&. 11 in binary:   0  0  0  0    0  0  1  1
23 .|. 11 in binary:   0  0  0  1    1  1  1  1
23 `xor` 11 in binary: 0  0  0  1    1  1  0  0
```

以下是 REPL 上的示例：

```repl
Tutorial.Prim> the Bits8 23 .&. 11
3
Tutorial.Prim> the Bits8 23 .|. 11
31
Tutorial.Prim> the Bits8 23 `xor` 11
28
```

最后，可以分别使用函数 `shiftR` 和 `shiftL` 将所有位向右或向左移动一定步数（溢出的位将被丢弃）。因此，左移可以看作是乘以 2 的幂，而右移可以看作是除以 2 的幂：

```repl
22 in binary:            0  0  0  1    0  1  1  0

22 `shiftL` 2 in binary: 0  1  0  1    1  0  0  0
22 `shiftR` 1 in binary: 0  0  0  0    1  0  1  1
```

在 REPL 试一下：

```repl
Tutorial.Prim> the Bits8 22 `shiftL` 2
88
Tutorial.Prim> the Bits8 22 `shiftR` 1
11
```

按位运算通常用于专用代码或某些高性能应用程序中。作为程序员，我们必须知道它们的存在以及它们是如何工作的。

### 整数字面量

到目前为止，我们总是需要 `Num` 的实现，以便能够对给定类型使用整数文字。然而，实际上只需要实现一个函数 `fromInteger` 将 `Integer` 转换为相关类型。正如我们将在最后一节中看到的，这样的函数甚至可以限制允许作为有效字面量的值。

例如，假设我们想定义一个数据类型来表示化学分子的电荷。这样的值可以是正值或负值，并且（理论上）几乎是任意大小：

```idris
record Charge where
  constructor MkCharge
  value : Integer
```

能够对费用求和是有意义的，但不能将它们相乘。因此，它们应该有 `Monoid` 的实现，而不是 `Num` 的实现。尽管如此，我们还是希望在编译时使用常量费用时能够方便地使用整数字面量。以下是如何执行此操作：

```idris
fromInteger : Integer -> Charge
fromInteger = MkCharge

Semigroup Charge where
  x <+> y = MkCharge $ x.value + y.value

Monoid Charge where
  neutral = 0
```

#### 可供选择的基础

除了众所周知的十进制文字外，还可以使用二进制、八进制或十六进制表示的整数文字。对于二进制、八进制和十六进制，它们必须以零为前缀，后跟 `b`、`o` 或 `x`：

```repl
Tutorial.Prim> 0b1101
13
Tutorial.Prim> 0o773
507
Tutorial.Prim> 0xffa2
65442
```

### 练习第 2 部分

1. 定义整数值的包装记录并实现 `Monoid` 以便 `(<+>)` 对应于 `(.&.)`。

   提示：查看 `Bits` 接口中可用的函数
   找到适合作为中性元素的值。

2. 定义整数值的包装记录并实现 `Monoid` 以便 `(<+>)` 对应于 `(.|.)`。

3. 使用按位运算来实现一个函数，该函数测试 `Bits64` 类型的给定值是否为偶数。

4. 将 `Bits64` 类型的值转换为二进制表示的字符串。

5. 将 `Bits64` 类型的值转换为十六进制表示的字符串。

   提示：使用 `shiftR` 和 `(.&. 15)` 访问四位的后续包。

## 精炼原语

我们通常不希望在某个上下文中允许某个类型的所有值。例如，`String` 作为 UTF-8 字符的任意序列（其中有几个甚至无法打印），在大多数情况下都过于笼统。因此，通常建议通过将值与已擦除的有效性证明配对，尽早排除无效值。

我们已经学会了如何编写优雅的谓词，用它我们可以证明我们的函数是完全的，并且我们可以从它——在理想情况下——推导出其他相关的谓词。然而，当我们在原语上定义谓词时，它们在某种程度上注定要孤立存在，除非我们提出一组原语公理（最有可能使用 `believe_me` 实现），我们可以用它来操纵我们的谓词。

### 用例：ASCII 字符串

字符串编码是一个困难的话题，因此在许多低级例程中，从一开始就排除大多数字符是有意义的。因此，假设我们希望确保我们在应用程序中接受的字符串仅包含 ASCII 字符：

```idris
isAsciiChar : Char -> Bool
isAsciiChar c = ord c <= 127

isAsciiString : String -> Bool
isAsciiString = all isAsciiChar . unpack
```

我们现在可以 *细化* 一个字符串值，方法是将其与已擦除的有效性证明配对：

```idris
record Ascii where
  constructor MkAscii
  value : String
  0 prf : isAsciiString value === True
```

现在在运行时或编译时创建 `Ascii` 类型的值，而无需首先验证包装的字符串是 *不可能* 的。有了这个，在编译时将字符串安全地包装成 `Ascii` 类型的值已经很容易了：

```idris
hello : Ascii
hello = MkAscii "Hello World!" Refl
```

然而，为此仍然使用字符串字面量会更方便，而不必牺牲安全的舒适性。为此，我们不能使用接口 `FromString`，因为它的函数 `fromString` 会强制我们转换 *任意* 字符串，即使是无效字符串。但是，我们实际上不需要实现 `FromString` 来支持字符串文字，就像我们不需要实现 `Num` 来支持整数字面量一样。我们真正需要的是一个名为 `fromString` 的函数。现在，当字符字面量字被脱糖时，它们被转换为以给定字符串值作为参数的 `fromString` 的调用。例如，文字 `"Hello"` 被脱糖为 `fromString "Hello"`。这发生在类型检查和填充（自动）隐式值之前。因此，使用已擦除的自动隐式参数定义自定义 `fromString` 函数作为有效性证明是非常好的：

```idris
fromString : (s : String) -> {auto 0 prf : isAsciiString s === True} -> Ascii
fromString s = MkAscii s prf
```

有了这个，我们可以使用（有效的）字符串文字直接得出 `Ascii` 类型的值：

```idris
hello2 : Ascii
hello2 = "Hello World!"
```

为了在运行时从未知来源的字符串中创建 `Ascii` 类型的值，我们可以使用返回某种故障类型的细化函数：

```idris
test : (b : Bool) -> Dec (b === True)
test True  = Yes Refl
test False = No absurd

ascii : String -> Maybe Ascii
ascii x = case test (isAsciiString x) of
  Yes prf   => Just $ MkAscii x prf
  No contra => Nothing
```

#### 布尔证明的缺点

对于许多用例，我们上面描述的 ASCII 字符串可以让我们走得很远。然而，这种方法的一个缺点是我们不能使用手头的证明安全地执行任何计算。

例如，我们知道连接两个 ASCII 字符串会非常好，但是为了让 Idris 相信这一点，我们必须使用 `believe_me`，否则我们将无法证明以下引理：

```idris
0 allAppend :  (f : Char -> Bool)
            -> (s1,s2 : String)
            -> (p1 : all f (unpack s1) === True)
            -> (p2 : all f (unpack s2) === True)
            -> all f (unpack (s1 ++ s2)) === True
allAppend f s1 s2 p1 p2 = believe_me $ Refl {x = True}

namespace Ascii
  export
  (++) : Ascii -> Ascii -> Ascii
  MkAscii s1 p1 ++ MkAscii s2 p2 =
    MkAscii (s1 ++ s2) (allAppend isAsciiChar s1 s2 p1 p2)
```

从给定字符串中提取子字符串的所有操作也是如此：我们必须使用 `believe_me` 来实现相应的规则。因此，找到一组合理的公理来方便地处理精炼的原语有时可能具有挑战性，而且是否需要这样的公理在很大程度上取决于手头的用例。

### 用例：净化的 HTML

假设您为注册用户之间的科学讨论编写了一个简单的 Web 应用程序。为了简单起见，我们在这里只考虑未格式化的文本输入。用户可以在文本字段中写入任意文本，然后按 Enter 键，该消息将显示给所有其他注册用户。

假设现在用户决定输入以下文本：

```html
<script>alert("Hello World!")</script>
```

好吧，它本来可以（非常）更糟。尽管如此，除非我们采取措施防止这种情况发生，否则这可能会在我们的网页中嵌入我们从未打算拥有的 JavaScript 程序！我在这里描述的是一个众所周知的安全漏洞，称为 [cross-site scripting](https://en.wikipedia.org/wiki/Cross-site_scripting)。它允许网页用户在文本字段中输入恶意 JavaScript 代码，然后这些代码将包含在页面的 HTML 结构中，并在向其他用户显示时执行。

我们想确保这不会发生在我们自己的网页上。为了保护我们免受这种攻击，我们可以例如完全禁止某些字符，例如 `'<'` 或 `'>'`（尽管这可能还不够！），但是如果我们的聊天服务是针对程序员的，这将是过度限制。另一种方法是在将某些字符呈现在页面上之前对其进行转义。

```idris
escape : String -> String
escape = concat . map esc . unpack
  where esc : Char -> String
        esc '<'  = "&lt;"
        esc '>'  = "&gt;"
        esc '"'  = "&quot;"
        esc '&'  = "&amp;"
        esc '\'' = "&apos;"
        esc c    = singleton c
```

我们现在要做的是将字符串与正确转义的证明一起存储。这是存在量化的另一种形式：“这是一个字符串，曾经存在另一个字符串，我们将其传递给 `escape` 并到达我们现在拥有的字符串”。以下是如何对此进行编码：

```idris
record Escaped where
  constructor MkEscaped
  value    : String
  0 origin : String
  0 prf    : escape origin === value
```

每当我们现在在我们的网页中嵌入一个未知来源的字符串时，我们都可以请求一个类型为 `Escaped` 的值，并且非常有力地保证我们不再容易受到跨站点脚本攻击。更好的是，还可以安全地嵌入编译时已知的字符串文字，而无需先转义它们：

```idris
namespace Escaped
  export
  fromString : (s : String) -> {auto 0 prf : escape s === s} -> Escaped
  fromString s = MkEscaped s s prf

escaped : Escaped
escaped = "Hello World!"
```

### 练习第 3 部分

在这组庞大的练习中，您将构建一个小型库，用于处理原语上的谓词。我们要牢记以下目标：

* 我们想使用命题逻辑的常用运算来组合谓词：否定、合取（逻辑 *与*）和析取（逻辑 *或*）。
* 所有谓词都应在运行时擦除。如果我们证明一些关于原语数字的东西，我们要确保不携带大量的有效性证明。
* 谓词的计算不应在运行时出现（`decide` 除外；见下文）。
* 如果谓词用于 `decide`
  的实现，则谓词的递归计算应该是尾递归的。这可能很难实现。如果您找不到给定问题的尾递归解决方案，请改用感觉最自然的方法。

关于效率的说明：为了能够在我们的谓词上运行计算，我们尝试尽快将原语值转换为代数数据类型：无符号整数将转换为 `Nat` 使用 `cast`，字符串将使用 `unpack` 转换为 `List Char`。这使我们大部分时间都可以在 `Nat` 和 `List` 上使用证明，并且可以在不借助 `believe_me` 或其他作弊手段的情况下实现此类证明。然而，原语类型相对于代数数据类型的一个优势是它们通常执行得更好。在将整数类型与 `Nat` 进行比较时，这一点尤其重要：对自然数的运算通常以 `O(n)` 时间复杂度运行，其中 `n` 是所涉及的自然数其中之一的大小，而对于 `Bits64`，例如，许多操作在常数时间内（`O(1)`）快速运行。幸运的是，Idris 编译器优化了许多自然数函数，以便在运行时使用相应的 `Integer` 操作。这样做的好处是我们仍然可以在编译时使用适当的归纳来证明关于自然数的东西，同时在运行时获得快速整数运算的好处。但是，`Nat` 上的操作确实以 `O(n)` 时间复杂度在 *编译期* 运行。因此，在大自然数上工作的证明将大大减慢编译器的速度。在本节练习的末尾讨论了解决此问题的方法。

废话不多说，开始吧！首先，您将获得以下实用程序：

```idris
-- Like `Dec` but with erased proofs. Constructors `Yes0`
-- and `No0` will be converted to constants `0` and `1` by
-- the compiler!
data Dec0 : (prop : Type) -> Type where
  Yes0 : (0 prf : prop) -> Dec0 prop
  No0  : (0 contra : prop -> Void) -> Dec0 prop

-- For interfaces with more than one parameter (`a` and `p`
-- in this example) sometimes one parameter can be determined
-- by knowing the other. For instance, if we know what `p` is,
-- we will most certainly also know what `a` is. We therefore
-- specify that proof search on `Decidable` should only be
-- based on `p` by listing `p` after a vertical bar: `| p`.
-- This is like specifing the search parameter(s) of
-- a data type with `[search p]` as was shown in the chapter
-- about predicates.
-- Specifying a single search parameter as shown here can
-- drastically help with type inference.
interface Decidable (0 a : Type) (0 p : a -> Type) | p where
  decide : (v : a) -> Dec0 (p v)

-- We often have to pass `p` explicitly in order to help Idris with
-- type inference. In such cases, it is more convenient to use
-- `decideOn pred` instead of `decide {p = pred}`.
decideOn : (0 p : a -> Type) -> Decidable a p => (v : a) -> Dec0 (p v)
decideOn _ = decide

-- Some primitive predicates can only be reasonably implemented
-- using boolean functions. This utility helps with decidability
-- on such proofs.
test0 : (b : Bool) -> Dec0 (b === True)
test0 True  = Yes0 Refl
test0 False = No0 absurd
```

我们还希望在编译时运行可判定的计算。这通常比在归纳类型上运行直接证明搜索更有效。因此，我们提出了一个谓词，证明 `Dec0` 值实际上是 `Yes0` 以及两个实用函数：

```idris
data IsYes0 : (d : Dec0 prop) -> Type where
  ItIsYes0 : IsYes0 (Yes0 prf)

0 fromYes0 : (d : Dec0 prop) -> (0 prf : IsYes0 d) => prop
fromYes0 (Yes0 x) = x
fromYes0 (No0 contra) impossible

0 safeDecideOn :  (0 p : a -> Type)
               -> Decidable a p
               => (v : a)
               -> (0 prf : IsYes0 (decideOn p v))
               => p v
safeDecideOn p v = fromYes0 $ decideOn p v
```

最后，由于我们计划主要改进原语，我们有时需要一些大锤来说服 Idris 我们知道我们在做什么：

```idris
-- only use this if you are sure that `decideOn p v`
-- will return a `Yes0`!
0 unsafeDecideOn : (0 p : a -> Type) -> Decidable a p => (v : a) -> p v
unsafeDecideOn p v = case decideOn p v of
  Yes0 prf => prf
  No0  _   =>
    assert_total $ idris_crash "Unexpected refinement failure in `unsafeRefineOn`"
```

1. 我们从等式证明开始。为 `Equal v` 实现 `Decidable`。

   提示：使用模块 `Decidable.Equality` 中的 `DecEq` 作为约束
         并确保 `v` 在运行时可用。

2. 我们希望能够否定一个谓词：

   ```idris
   data Neg : (p : a -> Type) -> a -> Type where
     IsNot : {0 p : a -> Type} -> (contra : p v -> Void) -> Neg p v
   ```

   使用合适的约束为 `Neg p` 实现 `Decidable`。

3. 我们要描述两个谓词的合取：

   ```idris
   data (&&) : (p,q : a -> Type) -> a -> Type where
     Both : {0 p,q : a -> Type} -> (prf1 : p v) -> (prf2 : q v) -> (&&) p q v
   ```

   使用合适的约束为 `(p && q)` 实现 `Decidable`。

4. 提出一个名为 `(||)` 的数据类型，用于两个谓词的析取（逻辑 *或*），并使用合适的约束实现 `Decidable`。

5. 通过实施以下命题证明 [德摩根定律](https://en.wikipedia.org/wiki/De_Morgan%27s_laws)：

   ```idris
   negOr : Neg (p || q) v -> (Neg p && Neg q) v

   andNeg : (Neg p && Neg q) v -> Neg (p || q) v

   orNeg : (Neg p || Neg q) v -> Neg (p && q) v
   ```

   德摩根的最后一个含义更难输入和证明
   因为我们需要一种方法来得出 `p v` 和 `q v` 类型的值
   并表明并非两者都可以存在。这是一种对此进行编码的方法
   （用定量 0 注释，因为我们需要访问已擦除的
   对偶）：

   ```idris
   0 negAnd :  Decidable a p
            => Decidable a q
            => Neg (p && q) v
            -> (Neg p || Neg q) v
   ```

   当你实现`negAnd`时，记住你可以自由访问
   擦除（隐式）参数，因为 `negAnd` 本身只能是
   在已删除的上下文中使用。

到目前为止，我们实现了代数描述和组合几个谓词的工具。现在是提出一些例子的时候了。作为第一个用例，我们将专注于限制自然数的有效范围。为此，我们使用以下数据类型：

```idris
-- Proof that m <= n
data (<=) : (m,n : Nat) -> Type where
  ZLTE : 0 <= n
  SLTE : m <= n -> S m <= S n
```

这类似于 `Data.Nat.LTE` 但我发现运算符符号通常更清晰。我们还可以定义和使用以下别名：

```repl
(>=) : (m,n : Nat) -> Type
m >= n = n <= m

(<) : (m,n : Nat) -> Type
m < n = S m <= n

(>) : (m,n : Nat) -> Type
m > n = n < m

LessThan : (m,n : Nat) -> Type
LessThan m = (< m)

To : (m,n : Nat) -> Type
To m = (<= m)

GreaterThan : (m,n : Nat) -> Type
GreaterThan m = (> m)

From : (m,n : Nat) -> Type
From m = (>= m)

FromTo : (lower,upper : Nat) -> Nat -> Type
FromTo l u = From l && To u

Between : (lower,upper : Nat) -> Nat -> Type
Between l u = GreaterThan l && LessThan u
```

6. 通过在 `m` 和 `n` 上进行模式匹配来得出 `m <= n` 类型的值对于较大的 `m` 值非常低效，因为这样做需要 `m`
   次迭代。但是，在擦除上下文中，我们不需要保存 `m <= n` 类型的值。我们只需要证明，这样的值来自更有效的计算。对于自然数，这样的计算是
   `compare`：尽管这是在 *Prelude*
   中实现的，其参数的模式匹配，但编译器将其优化为运行在即使对于非常大的数字也是恒定的时间。由于自然数的 `Prelude.(<=)` 是根据
   `compare` 实现的，因此它的运行效率同样高。

   因此，我们需要证明以下两个引理（使
   确保不要将 `Prelude.(<=)` 与 `Prim.(<=)` 混淆
   这些声明）：

   ```idris
   0 fromLTE : (n1,n2 : Nat) -> (n1 <= n2) === True -> n1 <= n2

   0 toLTE : (n1,n2 : Nat) -> n1 <= n2 -> (n1 <= n2) === True
   ```

   它们的定量为 0，因为它们同样低效
   正如我们上面讨论的其他计算。因此我们想要
   绝对确保它们永远不会在运行时使用！

   现在，利用 `test0` 实现 `Decidable Nat (<= n)`，
   `从LTE` 和 `到LTE`。
   同样，实现 `Decidable Nat (m <=)`，因为我们需要
   两种谓词。

   注意：您应该自己知道 `n` 必须是
   在运行时可用以及如何确保是这种情况。

7. 通过声明和实现相应的命题证明 `(<=)` 是自反和传递的。由于我们可能需要传递性证明来链接多个类型为 `(<=)`
   的值，因此也可以为此定义一个简短的运算符别名。

8. 证明从 `n > 0` 遵循 `IsSucc n`，反之亦然。

9. 声明并实现 `Bits64`
   的安全除法和模函数，方法是请求删除证明，证明分母在转换为自然数时严格为正。在模函数的情况下，返回一个精确的值，带有一个删除的证明，证明结果严格小于模数：

   ```idris
   safeMod :  (x,y : Bits64)
           -> (0 prf : cast y > 0)
           => Subset Bits64 (\v => cast v < cast y)
   ```

10. 我们将使用到目前为止定义的谓词和实用程序将 `Bits64` 类型的值转换为基数 `b` 中的数字字符串，其中 `2 <= b && b <=
    16`。为此，请实现以下骨架定义：

    ```idris
    -- this will require some help from `assert_total`
    -- and `idris_crash`.
    digit : (v : Bits64) -> (0 prf : cast v < 16) => Char

    record Base where
      constructor MkBase
      value : Bits64
      0 prf : FromTo 2 16 (cast value)

    base : Bits64 -> Maybe Base

    namespace Base
      public export
      fromInteger : (v : Integer) -> {auto 0 _ : IsJust (base $ cast v)} -> Base
    ```

    最后，使用 `safeDiv` 和 `safeMod` 实现 `digits`
    在您的实现中。这可能具有挑战性，因为您将
    必须手动转换一些证明以满足类型
    检查器。您可能还需要 `assert_smaller` 在
    递归步骤。

    ```idris
    digits : Bits64 -> Base -> String
    ```

我们现在将注意力转向字符串。我们可以限制我们接受的字符串的两种最明显的方法是限制字符集和限制它们的长度。更高级的改进可能需要字符串匹配某个模式或正则表达式。在这种情况下，我们可能会进行布尔检查或使用自定义数据类型来表示模式的不同部分，但我们不会在这里讨论这些主题。

11. 为字符上的有用谓词实现以下别名。

    提示：使用 `cast` 将字符转换为自然数，
    使用 `(<=)` 和 `InRange` 指定字符区域，
    并使用 `(||)` 组合字符区域。

    ```idris
    -- Characters <= 127
    IsAscii : Char -> Type

    -- Characters <= 255
    IsLatin : Char -> Type

    -- Characters in the interval ['A','Z']
    IsUpper : Char -> Type

    -- Characters in the interval ['a','z']
    IsLower : Char -> Type

    -- Lower or upper case characters
    IsAlpha : Char -> Type

    -- Characters in the range ['0','9']
    IsDigit : Char -> Type

    -- Digits or characters from the alphabet
    IsAlphaNum : Char -> Type

    -- Characters in the ranges [0,31] or [127,159]
    IsControl : Char -> Type

    -- An ASCII character that is not a control character
    IsPlainAscii : Char -> Type

    -- A latin character that is not a control character
    IsPlainLatin : Char -> Type
    ```

12. 这种更模块化的原语谓词方法的优势在于，我们可以安全地对谓词运行计算，并从现有的关于归纳类型（如 `Nat` 和
    `List`）的证明中获得强有力的保证。以下是此类计算和转换的一些示例，所有这些都可以在不作弊的情况下实现：

    ```idris
    0 plainToAscii : IsPlainAscii c -> IsAscii c

    0 digitToAlphaNum : IsDigit c -> IsAlphaNum c

    0 alphaToAlphaNum : IsAlpha c -> IsAlphaNum c

    0 lowerToAlpha : IsLower c -> IsAlpha c

    0 upperToAlpha : IsUpper c -> IsAlpha c

    0 lowerToAlphaNum : IsLower c -> IsAlphaNum c

    0 upperToAlphaNum : IsUpper c -> IsAlphaNum c
    ```

    以下 (`asciiToLatin`) 比较棘手。请记住
    `(<=)` 是传递的。但是，在您调用证明时
    传递性，您将无法使用直接证明搜索
    `%search` 因为搜索深度太小。你可以
    增加搜索深度，但
    改为使用 `safeDecideOn` 效率更高。

    ```idris
    0 asciiToLatin : IsAscii c -> IsLatin c

    0 plainAsciiToPlainLatin : IsPlainAscii c -> IsPlainLatin c
    ```

在我们将全部注意力转向字符串谓词之前，我们必须先介绍列表，因为我们经常将字符串视为字符列表。

13. 为 `Head` 实现 `Decidable`：

    ```idris
    data Head : (p : a -> Type) -> List a -> Type where
      AtHead : {0 p : a -> Type} -> (0 prf : p v) -> Head p (v :: vs)
    ```

14. 为 `Length` 实现 `Decidable`：

    ```idris
    data Length : (p : Nat -> Type) -> List a -> Type where
      HasLength :  {0 p : Nat -> Type}
                -> (0 prf : p (List.length vs))
                -> Length p vs
    ```

15. 以下谓词证明值列表中的所有值都满足给定谓词。我们将使用它来限制字符串中的有效字符集。

    ```idris
    data All : (p : a -> Type) -> (as : List a) -> Type where
      Nil  : All p []
      (::) :  {0 p : a -> Type}
           -> (0 h : p v)
           -> (0 t : All p vs)
           -> All p (v :: vs)
    ```

    为 `All` 实现 `Decidable`。

    对于真正的挑战，请尝试使您的
    `decide`  实现尾递归。这对JavaScript 后端上的现实世界应用程序很重要，我们可能想要精炼数千个字符的字符串的地方
    而不会在运行时堆栈溢出。为了提出尾递归实现，
    您将需要一个额外的数据类型 `AllSnoc` 来见证谓词
    适用于 `SnocList` 中的所有元素。

16. 是时候在这里结束了。 Idris 中的标识符是一系列字母数字字符，可能由下划线字符 (`_`)
    分隔。此外，所有标识符都必须以字母开头。给定这个规范，实现谓词 `IdentChar`，我们可以从中为标识符定义一个新的包装器类型：

    ```idris
    0 IdentChars : List Char -> Type

    record Identifier where
      constructor MkIdentifier
      value : String
      0 prf : IdentChars (unpack value)
    ```

    实现一个工厂方法 `identifier` 来转换运行时未知来源的字符串 ：

    ```idris
    identifier : String -> Maybe Identifier
    ```

    此外，为 `Identifier` 实现 `fromString` 并验证，
    以下是有效的标识符：

    ```idris
    testIdent : Identifier
    testIdent = "fooBar_123"
    ```

最后的评论：在决定使用什么公理以及试图使事情在运行时和编译时表现良好时，证明关于原语的东西可能具有挑战性。我正在尝试一个处理这些问题的库。它尚未完成，但您可以在 [这里](https://github.com/stefan-hoeck/idris2-prim) 看看它。

<!-- vi: filetype=idris2
-->
