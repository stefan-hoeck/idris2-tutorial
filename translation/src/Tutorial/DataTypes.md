# 代数数据类型

在[上一章](Functions1.md)中，我们学会了如何编写自己的函数并组合他们来创建更复杂的函数。同等重要的是定义我们自己的数据类型并使用它们作为参数和函数结果。

这是一个冗长的章节，信息密集。
如果您不熟悉 Idris 和函数式编程，请一定要慢慢来，用例子做实验，并可能想出你自己的示例。确保尝试并解决*所有*练习。练习题的答案可以在 [这里](../Solutions/DataTypes.idr) 找到。

```idris
module Tutorial.DataTypes
```

## 枚举

让我们从一个星期几的数据类型开始
例子。

```idris
data Weekday = Monday
             | Tuesday
             | Wednesday
             | Thursday
             | Friday
             | Saturday
             | Sunday
```

上面的声明定义了一个新的 *类型* (`Weekday`) 和
该类型给定的几个*值*(`Monday` 到 `Sunday`)。继续，并在 REPL 上验证这一点：

```repl
Tutorial.DataTypes> :t Monday
Tutorial.DataTypes.Monday : Weekday
Tutorial.DataTypes> :t Weekday
Tutorial.DataTypes.Weekday : Type
```

所以，`Monday` 是 `Weekday` 类型，而 `Weekday` 本身是 `Type` 类型。

需要注意的是，`Weekday` 类型的值只能是上面列出的值之一。在需要 `Weekday` 的地方使用其他任何值都会产生一个*类型错误*。

### 模式匹配

为了使用我们的新数据类型作为函数参数，我们需要了解函数式编程语言中的一个重要概念：模式匹配。让我们实现一个函数，它计算一个星期几的后继：

```idris
total
next : Weekday -> Weekday
next Monday    = Tuesday
next Tuesday   = Wednesday
next Wednesday = Thursday
next Thursday  = Friday
next Friday    = Saturday
next Saturday  = Sunday
next Sunday    = Monday
```

为了检查 `Weekday` 参数，我们匹配
不同的可能值并为每个值返回一个结果。
这是一个非常强大的概念，因为它允许我们匹配并从深度嵌套的数据结构中提取值。从上到下检查模式匹配中的不同情况
，每个都与当前函数参数进行比较。一旦找到匹配的模式，该模式右侧的计算是被求值。后面的模式将被忽略。

例如，如果我们使用参数 `Thursday` 调用 `next`，前三个模式（`Monaday`、`Tuesday` 和 `Wednesday`）将根据参数进行检查，但它们不匹配。第四个模式是匹配的，结果 `Friday` 被返回。然后忽略后面的模式，即使它们还会匹配输入（这与任意模式有关，我们稍后会谈到）。

上面的函数可以证明是完全的。Idris 知道
`Weekday` 类型的可能值，因此可以计算
我们的模式匹配涵盖了所有可能的情况。我们可以使用 `total` 关键字注释函数，如果 Idris 无法验证函数的完全性，会得到一个类型错误。 （继续，并尝试删除其中一个 `next` 中的子句来了解错误是如何产生的，并且可以看看来自覆盖性检查器的错误消息长什么样。）

请记住，这些来自类型检查器：给定足够的资源，一个可证明的完全函数在有限时间内将 * 总是 * 返回给定类型的结果（*资源*的意思是计算资源，比如内存，或者，在递归函数情况下的堆栈空间）。

### 任意模式

有时比较实用的是只匹配一个可能子集的值，并收集剩余的可能性到任意模式中：

```idris
total
isWeekend : Weekday -> Bool
isWeekend Saturday = True
isWeekend Sunday   = True
isWeekend _        = False
```

如果参数不等于 `Saturday` 或 `Sunday`，仅调用具有任意模式的最后一行。记住：模式匹配中的模式匹配
从上到下的输入和第一个匹配决定将采用右侧的哪条路径。

我们可以使用任意模式来实现等式测试
`Weekday`（我们还不会为此使用 `==` 运算符；这将必须等到我们了解*接口*以后）：

```idris
total
eqWeekday : Weekday -> Weekday -> Bool
eqWeekday Monday Monday        = True
eqWeekday Tuesday Tuesday      = True
eqWeekday Wednesday Wednesday  = True
eqWeekday Thursday Thursday    = True
eqWeekday Friday Friday        = True
eqWeekday Saturday Saturday    = True
eqWeekday Sunday Sunday        = True
eqWeekday _ _                  = False
```

### Prelude 中的枚举类型

`Weekday` 等数据类型由有限集组成
的值有时称为 * 枚举 *。Idris 的
*Prelude* 为我们定义了一些常见的枚举，例如 `Bool` 和 `Ordering`。与 `Weekday` 一样，我们可以在实现函数时使用模式匹配在这些类型上：

```idris
-- this is how `not` is implemented in the *Prelude*
total
negate : Bool -> Bool
negate False = True
negate True  = False
```

`Ordering` 数据类型描述了两个值之间的顺序关系。例如：

```idris
total
compareBool : Bool -> Bool -> Ordering
compareBool False False = EQ
compareBool False True  = LT
compareBool True True   = EQ
compareBool True False  = GT
```

这里，`LT` 表示第一个参数是*小于*
第二个，`EQ`表示两个参数是*相等*
， `GT` 表示第一个参数是 * 大于 *
第二个。

### Case 表达式

有时我们需要对参数执行计算并希望对结果进行模式匹配。这种情况下我们可以使用*case 表达式*：

```idris
-- returns the larger of the two arguments
total
maxBits8 : Bits8 -> Bits8 -> Bits8
maxBits8 x y =
  case compare x y of
    LT => y
    _  => x
```

case 表达式的第一行 (`case compare x y of`)将使用参数 `x` 和 `y` 调用函数`compare`。后面的（缩进）行，我们对结果进行模式匹配。这是 `Ordering` 类型，所以我们期望结果是三个构造函数 `LT`、`EQ` 或 `GT` 之一。在第一行，我们明确地处理 `LT` 的情况，而其他两种情况下划线作为任意模式处理。

请注意，缩进在这里很重要：整个 Case 块必须缩进（如果它从新行开始），并且不同的 Case 也必须缩进相同数量的空格。

函数 `compare` 对许多数据类型进行了重载。当我们谈论接口时，我们将了解它是如何工作的。

#### If Then Else

使用 `Bool` 时，可以使用模式匹配的替代方法，同时也是大多数编程语言的共同点：

```idris
total
maxBits8' : Bits8 -> Bits8 -> Bits8
maxBits8' x y = if compare x y == LT then y else x
```

请注意，`if then else` 表达式总是返回一个值。因此，不能删除 `else` 分支。这是和典型的命令式语言中的行为所不同的，其中 `if` 是可能产生副作用的声明。

### 命名约定：标识符

虽然我们可以自由使用小写和大写标识符
函数名，但是类型和数据构造函数必须大写标识符，以免混淆 Idris（运算符也可以）。例如，以下数据定义无效，并且 Idris会抱怨它需要大写的标识符：

```repl
data foo = bar | baz
```

类似的数据定义（如记录与和类型）也是如此（两者都将在下面解释）：

```repl
-- not valid Idris
record Foo where
  constructor mkfoo
```

另一方面，我们通常使用小写的函数标识符名称，除非我们计划主要在类型检查期间使用它们（之后会有更多关于这个的讨论）。然而，这不是 Idris 强制执行的，所以如果你在首选大写标识符的地方，请随意使用他们：

```idris
foo : Bits32 -> Bits32
foo = (* 2)

Bar : Bits32 -> Bits32
Bar = foo
```

### 练习第 1 部分

1. 使用模式匹配来实现您自己版本的布尔运算符 `(&&)` 和 `(||)` ，分别调用 `and` 和 `or`。

   注意：解决此问题的一种方法是枚举两个布尔值的所有四种可能组合值并给出每个结果。然而，有一种更短、更聪明的方式，两个函数每个只需要两个模式匹配。

2. 定义您自己的数据类型来表示不同的时间单位（秒、分钟、小时、天、周），并实现以下函数以使用不同的单位在时间跨度之间进行转换。提示：当从秒到一些更大的单位（如小时）时，使用整数除法（`div`）。

   ```idris
   data UnitOfTime = Second -- add additional values

   -- calculate the number of seconds from a
   -- number of steps in the given unit of time
   total
   toSeconds : UnitOfTime -> Integer -> Integer

   -- Given a number of seconds, calculate the
   -- number of steps in the given unit of time
   total
   fromSeconds : UnitOfTime -> Integer -> Integer

   -- convert the number of steps in a given unit of time
   -- to the number of steps in another unit of time.
   -- use `fromSeconds` and `toSeconds` in your implementation
   total
   convert : UnitOfTime -> Integer -> UnitOfTime -> Integer
   ```

3. 定义用于表示化学元素子集的数据类型：氢 (H)、碳 (C)、氮 (N)、氧 (O) 和氟 (F)。

   声明并实现函数 `atomicMass`，它对每个元素返回以道尔顿为单位的原子质量：

   ```repl
   Hydrogen : 1.008
   Carbon : 12.011
   Nitrogen : 14.007
   Oxygen : 15.999
   Fluorine : 18.9984
   ```

## 和类型

假设我们想写一些 web 表单，我们的 Web 应用程序用户可以决定他们喜欢如何处理。我们让他们在两个常见的预定义之间进行选择地址形式（先生和夫人），但也允许他们决定一个定制的表格。可能的
选择可以封装在 Idris 数据类型中：

```idris
数据标题 = 先生 |夫人 |其他字符串
```

这看起来几乎像一个枚举类型，除了
有一个新东西，叫做*数据构造函数*，
它接受一个 `String` 参数（实际上，值
在枚举中也称为（空）数据构造函数）。
如果我们检查 REPL 中的类型，我们会了解到以下内容：

```repl
Tutorial.DataTypes> :t Mr
Tutorial.DataTypes.Mr : Title
Tutorial.DataTypes> :t Other
Tutorial.DataTypes.Other : String -> Title
```

所以，`Other` 是从 `String` 到 `Title` 的 *函数*。这意味着，我们可以传递给 `Other` 一个 `String` 参数并得到结果 `Title`：

```idris
total
dr : Title
dr = Other "Dr."
```

同样，`Title` 类型的值只能包含一个
在上面列出的三个选择中的一个，再一次，我们可以使用模式匹配来实现函数
在 `Title` 数据类型上以可证明的全部方式：

```idris
total
showTitle : Title -> String
showTitle Mr        = "Mr."
showTitle Mrs       = "Mrs."
showTitle (Other x) = x
```

注意，在最后一个模式匹配中，存储在 `Other` 数据构造函数中字符串值被 *绑定* 到局部变量 `x`。此外，`Other x` 模式必须用括号括起来，否则 Idris 会认为 `Other` 和 `x` 是不同的函数参数。

这是从数据构造函数中提取值的通用方式。我们可以使用 `showTitle` 来实现创建礼貌问候的函数：

```idris
total
greet : Title -> String -> String
greet t name = "Hello, " ++ showTitle t ++ " " ++ name ++ "!"
```

在 `greet` 的实现中，我们使用字符串字面量和字符串连接运算符 `(++)` 从各个部分组装问候语。

在 REPL 中：

```repl
Tutorial.DataTypes> greet dr "HÃ¶ck"
"Hello, Dr. HÃ¶ck!"
Tutorial.DataTypes> greet Mrs "Smith"
"Hello, Mrs. Smith!"
```

像 `Title` 这样的数据类型被称为 *和类型* 因为它们由不同部分的和组成：`Title` 类型的值是 `Mr`、`Mrs` 或包裹在 `Other` 中的 `String`。

这是 sum 类型的另一个（大大简化的）示例。
假设我们在 Web 应用程序中允许两种形式的身份验证：
通过输入用户名和密码（我们将使用
此处为无符号 64 位整数），或通过提供用户名加上一个（非常复杂的）密钥。
这是封装此用例的数据类型：

```idris
data Credentials = Password String Bits64 | Key String String
```

作为一个非常原始的登录函数的例子，我们可以硬编码一些已知的凭据：

```idris
total
login : Credentials -> String
login (Password "Anderson" 6665443) = greet Mr "Anderson"
login (Key "Y" "xyz")               = greet (Other "Agent") "Y"
login _                             = "Access denied!"
```

从上面的例子中可以看出，我们也可以通过使用整数和字符串字面量的原始值进行模式匹配字。在 REPL 中试一试 `login`：

```repl
Tutorial.DataTypes> login (Password "Anderson" 6665443)
"Hello, Mr. Anderson!"
Tutorial.DataTypes> login (Key "Y" "xyz")
"Hello, Agent Y!"
Tutorial.DataTypes> login (Key "Y" "foo")
"Access denied!"
```

### 练习第 2 部分

1. 为 `Title` 实现相等测试（您可以使用相等运算符 `(==)` 比较两个 `String`）：

   ```idris
   total
   eqTitle : Title -> Title -> Bool
   ```

2. 对于 `Title`，实现一个简单的测试来检查是否正在使用自定义标题：

   ```idris
   total
   isOther : Title -> Bool
   ```

3. 鉴于我们简单的 `Credentials` 类型，身份验证失败的三种方式：

   * 使用了未知的用户名。
   * 给定的密码与与用户名关联的密码不匹配。
   * 使用了无效的密钥。

   将这三种可能性封装在叫做 `LoginError` 的和类型中，但请确保不要泄露任何机密信息：无效的用户名应存储相应的错误值，但不应该存储无效的密码或密钥。

4. 实现函数 `showError : LoginError -> String`，可用于向尝试登录我们的 Web 应用程序失败的用户显示错误消息。

## 记录

将几个值组合在一起作为一个逻辑单元通常很有用。例如，在我们的 Web 应用程序中，我们可能想要对用户的信息进行分组
在单一数据类型中。这种数据类型通常被称为 *积类型*（见下文解释）。最常见和最方便义方式是通过 `record` 构造进行定义：

```idris
record User where
  constructor MkUser
  name  : String
  title : Title
  age   : Bits8
```

上面的声明创建了一个名为 `User` 的新 *类型*，和一个名为 `MkUser` 的新 *数据构造函数*。照常，看看他们在 REPL 中的类型：

```repl
Tutorial.DataTypes> :t User
Tutorial.DataTypes.User : Type
Tutorial.DataTypes> :t MkUser
Tutorial.DataTypes.MkUser : String -> Title -> Bits8 -> User
```

我们可以使用 `MkUser` （这会从
`String` 到 `Title` 到 `Bits8` 到 `User`）
创建 `User` 类型的值：

```idris
total
agentY : User
agentY = MkUser "Y" (Other "Agent") 51

total
drNo : User
drNo = MkUser "No" dr 73
```

我们还可以使用模式匹配从 `User` 提取值（它们可以再次绑定到局部变量）：

```idris
total
greetUser : User -> String
greetUser (MkUser n t _) = greet t n
```

在上面的示例中，`name` 和 `title` 字段
绑定到两个新的局部变量（分别为 `n` 和 `t`），
然后可以在 `greetUser` 的右侧实现使用
。对于 `age` 字段，在右侧未使用，我们可以使用下划线作为任意模式。

Note, how Idris will prevent us from making
a common mistake: If we confuse the order of arguments, the
implementation will no longer type check. We can verify this
by putting the erroneous code in a `failing` block: This
is an indented code block, which will lead to an error
during elaboration (type checking). We can give part
of the expected error message as an optional string argument to
a failing block. If this does not match part of
the error message (or the whole code block does not fail
to type check) the `failing` block itself fails to type
check. This is a useful tool to demonstrate that type
safety works in two directions: We can show that valid
code type checks but also that invalid code is rejected
by the Idris elaborator:

```idris
failing "Mismatch between: String and Title"
  greetUser' : User -> String
  greetUser' (MkUser n t _) = greet n t
```

In addition, for every record field, Idris creates an
extractor function of the same name. This can either
be used as a regular function, or it can be used in
postfix notation by appending it to a variable of
the record type separated by a dot. Here are two examples
for extracting the age from a user:

```idris
getAgeFunction : User -> Bits8
getAgeFunction u = age u

getAgePostfix : User -> Bits8
getAgePostfix u = u.age
```

### Syntactic Sugar for Records

As was already mentioned in the [intro](Intro.md), Idris
is a *pure* functional programming language. In pure functions,
we are not allowed to modify global mutable state. As such,
if we want to modify a record value, we will always
create a *new* value with the original value remaining
unchanged: Records and other Idris values are *immutable*.
While this *can* have a slight impact on performance, it has
the benefit that we can freely pass a record value to
different functions, without fear of the functions modifying
the value by in-place mutation. These are, again, very strong
guarantees, which makes it drastically easier to reason
about our code.

There are several ways to modify a record, the most
general being to pattern match on the record and
adjust each field as desired. If, for instance, we'd like
to increase the age of a `User` by one, we could do the following:

```idris
total
incAge : User -> User
incAge (MkUser name title age) = MkUser name title (age + 1)
```

That's a lot of code for such a simple thing, so Idris offers
several syntactic conveniences for this. For instance,
using *record* syntax, we can just access and update the `age`
field of a value:

```idris
total
incAge2 : User -> User
incAge2 u = { age := u.age + 1 } u
```

Assignment operator `:=` assigns a new value to the `age` field
in `u`. Remember, that this will create a new `User` value. The original
value `u` remains unaffected by this.

We can access a record field, either by using the field name
as a projection function (`age u`; also have a look at `:t age`
in the REPL), or by using dot syntax: `u.age`. This is special
syntax and *not* related to the dot operator for function
composition (`(.)`).

The use case of modifying a record field is so common
that Idris provides special syntax for this as well:

```idris
total
incAge3 : User -> User
incAge3 u = { age $= (+ 1) } u
```

Here, I used an *operator section* (`(+ 1)`) to make
the code more concise.
As an alternative to an operator section,
we could have used an anonymous function like so:

```idris
total
incAge4 : User -> User
incAge4 u = { age $= \x => x + 1 } u
```

Finally, since our function's argument `u` is only used
once at the very end, we can drop it altogether,
to get the following, highly concise version:

```idris
total
incAge5 : User -> User
incAge5 = { age $= (+ 1) }
```

As usual, we should have a look at the result at the REPL:

```repl
Tutorial.DataTypes> incAge5 drNo
MkUser "No" (Other "Dr.") 74
```

It is possible to use this syntax to set and/or update
several record fields at once:

```idris
total
drNoJunior : User
drNoJunior = { name $= (++ " Jr."), title := Mr, age := 17 } drNo
```

### Tuples

I wrote above that a record is also called a *product type*.
This is quite obvious when we consider the number
of possible values inhabiting a given type. For instance, consider
the following custom record:

```idris
record Foo where
  constructor MkFoo
  wd   : Weekday
  bool : Bool
```

How many possible values of type `Foo` are there? The answer is `7 * 2 = 14`,
as we can pair every possible `Weekday` (seven in total) with every possible
`Bool` (two in total). So, the number of possible values of a record type
is the *product* of the number of possible values for each field.

The canonical product type is the `Pair`, which is available from the *Prelude*:

```idris
total
weekdayAndBool : Weekday -> Bool -> Pair Weekday Bool
weekdayAndBool wd b = MkPair wd b
```

Since it is quite common to return several values from a function
wrapped in a `Pair` or larger tuple, Idris provides some syntactic
sugar for working with these. Instead of `Pair Weekday Bool`, we
can just write `(Weekday, Bool)`. Likewise, instead of `MkPair wd b`,
we can just write `(wd, b)` (the space is optional):

```idris
total
weekdayAndBool2 : Weekday -> Bool -> (Weekday, Bool)
weekdayAndBool2 wd b = (wd, b)
```

This works also for nested tuples:

```idris
total
triple : Pair Bool (Pair Weekday String)
triple = MkPair False (Friday, "foo")

total
triple2 : (Bool, Weekday, String)
triple2 = (False, Friday, "foo")
```

In the example above, `triple2` is converted to the form
used in `triple` by the Idris compiler.

We can even use tuple syntax in pattern matches:

```idris
total
bar : Bool
bar = case triple of
  (b,wd,_) => b && isWeekend wd
```

### As Patterns

Sometimes, we'd like to take apart a value by pattern matching
on it but still retain the value as a whole for using it
in further computations:

```idris
total
baz : (Bool,Weekday,String) -> (Nat,Bool,Weekday,String)
baz t@(_,_,s) = (length s, t)
```

In `baz`, variable `t` is *bound* to the triple as a whole, which
is then reused to construct the resulting quadruple. Remember,
that `(Nat,Bool,Weekday,String)` is just sugar for
`Pair Nat (Bool,Weekday,String)`, and `(length s, t)` is just
sugar for `MkPair (length s) t`. Hence, the implementation above
is correct as is confirmed by the type checker.

### Exercises part 3

1. Define a record type for time spans by pairing a `UnitOfTime`
with an integer representing the duration of the time span in
the given unit of time. Define also a function for converting
a time span to an `Integer` representing the duration in seconds.

2. Implement an equality check for time spans: Two time spans
should be considered equal, if and only if they correspond to
the same number of seconds.

3. Implement a function for pretty printing time spans:
The resulting string should display the time span in its
given unit, plus show the number of seconds in parentheses,
if the unit is not already seconds.

4. Implement a function for adding two time spans. If the
two time spans use different units of time, use the smaller
unit of time to ensure a lossless conversion.

## Generic Data Types

Sometimes, a concept is general enough that we'd like
to apply it not only to a single type, but to all
kinds of types. For instance, we might not want to define
data types for lists of integers, lists of strings, and lists
of booleans, as this would lead to a lot of code duplication.
Instead, we'd like to have a single generic list type *parameterized*
by the type of values it stores. This section explains how
to define and use generic types.

### Maybe

Consider the case of parsing
a `Weekday` from user input. Surely, such
a function should return `Saturday`, if the
string input was `"Saturday"`, but what if the
input was `"sdfkl332"`? We have several options here.
For instance, we could just return a default result
(`Sunday` perhaps?). But is this the behavior
programmers expect when using our library? Maybe not. To silently
continue with a default value in the face of invalid user input
is hardly ever the best choice and may lead to a lot of
confusion.

In an imperative language, our function would probably
throw an exception. We could do this in Idris as
well (there is function `idris_crash` in the *Prelude* for
this), but doing so, we would abandon totality! A high
price to pay for such a common thing as a parsing error.

In languages like Java, our function might also return some
kind of `null` value (leading to the dreaded `NullPointerException`s if
not handled properly in client code). Our solution will
be similar, but instead of silently returning `null`,
we will make the possibility of failure visible in the types!
We define a custom data type, which encapsulates the possibility
of failure. Defining new data types in Idris is very cheap
(in terms of the amount of code needed), therefore this is
often the way to go in order to increase type safety.
Here's an example how to do this:

```idris
data MaybeWeekday = WD Weekday | NoWeekday

total
readWeekday : String -> MaybeWeekday
readWeekday "Monday"    = WD Monday
readWeekday "Tuesday"   = WD Tuesday
readWeekday "Wednesday" = WD Wednesday
readWeekday "Thursday"  = WD Thursday
readWeekday "Friday"    = WD Friday
readWeekday "Saturday"  = WD Saturday
readWeekday "Sunday"    = WD Sunday
readWeekday _           = NoWeekday
```

But assume now, we'd also like to read `Bool` values from
user input. We'd now have to write a custom data type
`MaybeBool` and so on for all types we'd like to read
from `String`, and the conversion of which might fail.

Idris, like many other programming languages, allows us
to generalize this behavior by using *generic data
types*. Here's an example:

```idris
data Option a = Some a | None

total
readBool : String -> Option Bool
readBool "True"    = Some True
readBool "False"   = Some False
readBool _         = None
```

It is important to go to the REPL and look at the types:

```repl
Tutorial.DataTypes> :t Some
Tutorial.DataTypes.Some : a -> Option a
Tutorial.DataTypes> :t None
Tutorial.DataTypes.None : Optin a
Tutorial.DataTypes> :t Option
Tutorial.DataTypes.Option : Type -> Type
```

We need to introduce some jargon here. `Option` is what we call
a *type constructor*. It is not yet a saturated type: It is
a function from `Type` to `Type`.
However, `Option Bool` is a type, as is `Option Weekday`.
Even `Option (Option Bool)` is a valid type. `Option` is
a type constructor *parameterized* over a *parameter* of type `Type`.
`Some` and `None` are `Option`s *data constructors*: The functions
used to create values of type `Option a` for a type `a`.

Let's see some other use cases for `Option`. Below is a safe
division operation:

```idris
total
safeDiv : Integer -> Integer -> Option Integer
safeDiv n 0 = None
safeDiv n k = Some (n `div` k)
```

The possibility of returning some kind of *null* value in the
face of invalid input is so common, that there is a data type
like `Option` already in the *Prelude*: `Maybe`, with
data constructors `Just` and `Nothing`.

It is important to understand the difference between returning `Maybe Integer`
in a function, which might fail, and returning
`null` in languages like Java: In the former case, the
possibility of failure is visible in the types. The type checker
will force us to treat `Maybe Integer` differently than
`Integer`: Idris will *not* allow us to forget to
eventually handle the failure case.
Not so, if `null` is silently returned without adjusting the
types. Programmers may (and often *will*) forget to handle the
`null` case, leading to unexpected and sometimes
hard to debug runtime exceptions.

### Either

While `Maybe` is very useful to quickly provide a default
value to signal some kind of failure, this value (`Nothing`) is
not very informative. It will not tell us *what exactly*
went wrong. For instance, in case of our `Weekday`
reading function, it might be interesting later on to know
the value of the invalid input string. And just like with
`Maybe` and `Option` above, this concept is general enough
that we might encounter other types of invalid values.
Here's a data type to encapsulate this:

```idris
data Validated e a = Invalid e | Valid a
```

`Validated` is a type constructor parameterized over two
type parameters `e` and `a`. It's data constructors
are `Invalid` and `Valid`,
the former holding a value describing some error condition,
the latter the result in case of a successful computation.
Let's see this in action:

```idris
total
readWeekdayV : String -> Validated String Weekday
readWeekdayV "Monday"    = Valid Monday
readWeekdayV "Tuesday"   = Valid Tuesday
readWeekdayV "Wednesday" = Valid Wednesday
readWeekdayV "Thursday"  = Valid Thursday
readWeekdayV "Friday"    = Valid Friday
readWeekdayV "Saturday"  = Valid Saturday
readWeekdayV "Sunday"    = Valid Sunday
readWeekdayV s           = Invalid ("Not a weekday: " ++ s)
```

Again, this is such a general concept that a data type
similar to `Validated` is already available from the
*Prelude*: `Either` with data constructors `Left` and `Right`.
It is very common for functions to encapsulate the possibility
of failure by returning an `Either err val`, where `err`
is the error type and `val` is the desired return type. This
is the type safe (and total!) alternative to throwing a catchable
exception in an imperative language.

Note, however, that the semantics of `Either` are not always "`Left` is
an error and `Right` a success". A function returning an `Either` just
means that it can have to different types of results, each of which
are *tagged* with the corresponding data constructor.

### List

One of the most important data structures in pure functional
programming is the singly linked list. Here is its definition
(called `Seq` in order for it not to collide with `List`,
which is of course already available from the Prelude):

```idris
data Seq a = Nil | (::) a (Seq a)
```

This calls for some explanations. `Seq` consists of two *data constructors*:
`Nil` (representing an empty sequence of values) and `(::)` (also
called the *cons operator*), which prepends a new value of type `a` to
an already existing list of values of the same type. As you can see,
we can also use operators as data constructors, but please do not overuse
this. Use clear names for your functions and data constructors and only
introduce new operators when it truly helps readability!

Here is an example of how to use the `List` constructors
(I use `List` here, as this is what you should use in your own code):

```idris
total
ints : List Int64
ints = 1 :: 2 :: -3 :: Nil
```

However, there is a more concise way of writing the above. Idris
accepts special syntax for constructing data types consisting
exactly of the two constructors `Nil` and `(::)`:

```idris
total
ints2 : List Int64
ints2 = [1, 2, -3]

total
ints3 : List Int64
ints3 = []
```

The two definitions `ints` and `ints2`
are treated identically by the compiler.
Note, that list syntax can also be used in pattern matches.

There is another thing that's special about
`Seq` and `List`: Each of them is defined
in terms of itself (the cons operator accepts a value
and another `Seq` as arguments). We call such data types
*recursive* data types, and their recursive nature means, that in order to
decompose or consume them, we typically require recursive
functions. In an imperative language, we might use a for loop or
similar construct to iterate over the values of a `List` or a `Seq`,
but these things do not exist in a language without in-place
mutation. Here's how to sum a list of integers:

```idris
total
intSum : List Integer -> Integer
intSum Nil       = 0
intSum (n :: ns) = n + intSum ns
```

Recursive functions can be hard to grasp at first, so I'll break
this down a bit. If we invoke `intSum` with the empty list,
the first pattern matches and the function returns zero immediately.
If, however, we invoke `intSum` with a non-empty list - `[7,5,9]`
for instance - the following happens:

1. The second pattern matches and splits the list into two parts: Its head
   (`7`) is bound to variable `n` and its tail (`[5,9]`) is bound to `ns`:

   ```repl
   7 + intSum [5,9]
   ```
2. In a second invocation, `intSum` is called with a new list: `[5,9]`.  The
   second pattern matches and `n` is bound to `5` and `ns` is bound to
   `[9]`:

   ```repl
   7 + (5 + intSum [9])
   ```

3. In a third invocation `intSum` is called with list `[9]`.  The second
   pattern matches and `n` is bound to `9` and `ns` is bound to `[]`:

   ```repl
   7 + (5 + (9 + intSum [])
   ```

4. In a fourth invocation, `intSum` is called with list `[]` and returns `0`
   immediately:

   ```repl
   7 + (5 + (9 + 0)
   ```

5. In the third invocation, `9` and `0` are added and `9` is returned:

   ```repl
   7 + (5 + 9)
   ```

6. In the second invocation, `5` and `9` are added and `14` is returned:

   ```repl
   7 + 14
   ```

7. Finally, our initial invocation of `intSum` adds `7` and `14` and returns
   `21`.

Thus, the recursive implementation of `intSum` leads to a sequence of
nested calls to `intSum`, which terminates once the argument is the
empty list.

### Generic Functions

In order to fully appreciate the versatility that comes with
generic data types, we also need to talk about generic functions.
Like generic types, these are parameterized over one or more
type parameters.

Consider for instance the case of breaking out of the
`Option` data type. In case of a `Some`, we'd like to return
the stored value, while for the `None` case we provide
a default value. Here's how to do this, specialized to
`Integer`s:

```idris
total
integerFromOption : Integer -> Option Integer -> Integer
integerFromOption _ (Some y) = y
integerFromOption x None     = x
```

It's pretty obvious that this, again, is not general enough.
Surely, we'd also like to break out of `Option Bool` or
`Option String` in a similar fashion. That's exactly
what the generic function `fromOption` does:

```idris
total
fromOption : a -> Option a -> a
fromOption _ (Some y) = y
fromOption x None     = x
```

The lower-case `a` is again a *type parameter*. You can read
the type signature as follows: "For any type `a`, given a *value*
of type `a`, and an `Option a`, we can return a value of
type `a`." Note, that `fromOption` knows nothing else about
`a`, other than it being a type. It is therefore not possible,
to conjure a value of type `a` out of thin air. We *must* have
a value available to deal with the `None` case.

The pendant to `fromOption` for `Maybe` is called `fromMaybe`
and is available from module `Data.Maybe` from the *base* library.

Sometimes, `fromOption` is not general enough. Assume we'd like to
print the value of a freshly parsed `Bool`, giving some generic
error message in case of a `None`. We can't use `fromOption`
for this, as we have an `Option Bool` and we'd like to
return a `String`. Here's how to do this:

```idris
total
option : b -> (a -> b) -> Option a -> b
option _ f (Some y) = f y
option x _ None     = x

total
handleBool : Option Bool -> String
handleBool = option "Not a boolean value." show
```

Function `option` is parameterized over *two* type parameters:
`a` represents the type of values stored in the `Option`,
while `b` is the return type. In case of a `Just`, we need
a way to convert the stored `a` to a `b`, an that's done
using the function argument of type `a -> b`.

In Idris, lower-case identifiers in function types are
treated as *type parameters*, while upper-case identifiers
are treated as types or type constructors that must
be in scope.

### Exercises part 4

If this is your first time programming in a purely
functional language, the exercises below are *very*
important. Do not skip any of them! Take your time and
work through them all. In most cases,
the types should be enough to explain what's going
on, even though they might appear cryptic in the
beginning. Otherwise, have a look at the comments (if any)
of each exercise.

Remember, that lower-case identifiers in a function
signature are treated as type parameters.

1. Implement the following generic functions for `Maybe`:

   ```idris
   -- make sure to map a `Just` to a `Just`.
   total
   mapMaybe : (a -> b) -> Maybe a -> Maybe b

   -- Example: `appMaybe (Just (+2)) (Just 20) = Just 22`
   total
   appMaybe : Maybe (a -> b) -> Maybe a -> Maybe b

   -- Example: `bindMaybe (Just 12) Just = Just 12`
   total
   bindMaybe : Maybe a -> (a -> Maybe b) -> Maybe b

   -- keep the value in a `Just` only if the given predicate holds
   total
   filterMaybe : (a -> Bool) -> Maybe a -> Maybe a

   -- keep the first value that is not a `Nothing` (if any)
   total
   first : Maybe a -> Maybe a -> Maybe a

   -- keep the last value that is not a `Nothing` (if any)
   total
   last : Maybe a -> Maybe a -> Maybe a

   -- this is another general way to extract a value from a `Maybe`.
   -- Make sure the following holds:
   -- `foldMaybe (+) 5 Nothing = 5`
   -- `foldMaybe (+) 5 (Just 12) = 17`
   total
   foldMaybe : (acc -> el -> acc) -> acc -> Maybe el -> acc
   ```

2. Implement the following generic functions for `Either`:

   ```idris
   total
   mapEither : (a -> b) -> Either e a -> Either e b

   -- In case of both `Either`s being `Left`s, keep the
   -- value stored in the first `Left`.
   total
   appEither : Either e (a -> b) -> Either e a -> Either e b

   total
   bindEither : Either e a -> (a -> Either e b) -> Either e b

   -- Keep the first value that is not a `Left`
   -- If both `Either`s are `Left`s, use the given accumulator
   -- for the error values
   total
   firstEither : (e -> e -> e) -> Either e a -> Either e a -> Either e a

   -- Keep the last value that is not a `Left`
   -- If both `Either`s are `Left`s, use the given accumulator
   -- for the error values
   total
   lastEither : (e -> e -> e) -> Either e a -> Either e a -> Either e a

   total
   fromEither : (e -> c) -> (a -> c) -> Either e a -> c
   ```

3. Implement the following generic functions for `List`:

   ```idris
   total
   mapList : (a -> b) -> List a -> List b

   total
   filterList : (a -> Bool) -> List a -> List a

   -- return the first value of a list, if it is non-empty
   total
   headMaybe : List a -> Maybe a

   -- return everything but the first value of a list, if it is non-empty
   total
   tailMaybe : List a -> Maybe (List a)

   -- return the last value of a list, if it is non-empty
   total
   lastMaybe : List a -> Maybe a

   -- return everything but the last value of a list,
   -- if it is non-empty
   total
   initMaybe : List a -> Maybe (List a)

   -- accumulate the values in a list using the given
   -- accumulator function and initial value
   --
   -- Examples:
   -- `foldList (+) 10 [1,2,7] = 20`
   -- `foldList String.(++) "" ["Hello","World"] = "HelloWorld"`
   -- `foldList last Nothing (mapList Just [1,2,3]) = Just 3`
   total
   foldList : (acc -> el -> acc) -> acc -> List el -> acc
   ```

4. Assume we store user data for our web application in the following
   record:

   ```idris
   record Client where
     constructor MkClient
     name          : String
     title         : Title
     age           : Bits8
     passwordOrKey : Either Bits64 String
   ```

   Using `LoginError` from an earlier exercise,
   implement function `login`, which, given a list of `Client`s
   plus a value of type `Credentials` will return either a `LoginError`
   in case no valid credentials where provided, or the first `Client`
   for whom the credentials match.

5. Using your data type for chemical elements from an earlier exercise,
   implement a function for calculating the molar mass of a molecular
   formula.

   Use a list of elements each paired with its count
   (a natural number) for representing formulae. For
   instance:

   ```idris
   ethanol : List (Element,Nat)
   ethanol = [(C,2),(H,6),(O,1)]
   ```

   Hint: You can use function `cast` to convert a natural
   number to a `Double`.

## Alternative Syntax for Data Definitions

While the examples in the section about parameterized
data types are short and concise, there is a slightly
more verbose but much more general form for writing such
definitions, which makes it much clearer what's going on.
In my opinion, this more general form should be preferred
in all but the most simple data definitions.

Here are the definitions of `Option`, `Validated`, and `Seq` again,
using this more general form (I put them in their own *namespace*,
so Idris will not complain about identical names in
the same source file):

```idris
-- GADT is an acronym for "generalized algebraic data type"
namespace GADT
  data Option : Type -> Type where
    Some : a -> Option a
    None : Option a

  data Validated : Type -> Type -> Type where
    Invalid : e -> Validated e a
    Valid   : a -> Validated e a

  data Seq : Type -> Type where
    Nil  : Seq a
    (::) : a -> GADT.Seq a -> Seq a
```

Here, `Option` is clearly declared as a type constructor
(a function of type `Type -> Type`), while `Some`
is a generic function of type `a -> Option a` (where `a` is
a *type parameter*)
and `None` is a nullary generic function of type `Option a`
(`a` again being a type parameter).
Likewise for `Validated` and `Seq`. Note, that in case
of `Seq` we had to disambiguate between the different
`Seq` definitions in the recursive case. Since we will
usually not define several data types with the same name in
a source file, this is not necessary most of the time.

## 结论

We covered a lot of ground in this chapter,
so I'll summarize the most important points below:

* Enumerations are data types consisting of a finite
number of possible *values*.

* Sum types are data types with more than one data
constructor, where each constructor describes a
*choice* that can be made.

* Product types are data types with a single constructor
used to group several values of possibly different types.

* We use pattern matching to deconstruct immutable
values in Idris. The possible patterns correspond to
a data type's data constructors.

* We can *bind* variables to values in a pattern or
use an underscore as a placeholder for a value that's
not needed on the right hand side of an implementation.

* We can pattern match on an intermediary result by introducing
a *case block*.

* The preferred way to define new product types is
to define them as *records*, since these come with
additional syntactic conveniences for setting and
modifying individual *record fields*.

* Generic types and functions allow us generalize
certain concepts and make them available for many
types by using *type parameters* instead of
concrete types in function and type signatures.

* Common concepts like *nullary values* (`Maybe`),
computations that might fail with some error
condition (`Either`), and handling collections
of values of the same type at once (`List`) are
example use cases of generic types and functions
already provided by the *Prelude*.

## 下一步是什么

In the [next section](Interfaces.md), we will introduce
*interfaces*, another approach to *function overloading*.

<!-- vi: filetype=idris2
-->
