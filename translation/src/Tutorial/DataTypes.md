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

请记住，这些来自类型检查器：给定足够的资源，一个可证明的完全函数在有限时间内将 *总是* 返回给定类型的结果（*资源*的意思是计算资源，比如内存，或者，在递归函数情况下的堆栈空间）。

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
data Title = Mr | Mrs | Other String
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

请注意，如果我们混淆了参数的顺序，Idris 将会阻止我们这个常见的错误：
实现将不能通过行类型检查。我们可以验证这一点，通过将错误代码放入 `failing` 块中：这是缩进的代码块，在细化过程中（类型检查）会导致错误。我们可以给一部分预期的错误消息作为 failing 块的可选字符串参数。如果这不能匹配部分错误消息（或在类型检查中不会失败的整个代码块类）`failing` 块本身无法通过类型检查。下面是对类型安全有帮助的两个方向：通过 Idris 细化，我们可以证明有效代码类型检查，但拒绝无效代码：

```idris
failing "Mismatch between: String and Title"
  greetUser' : User -> String
  greetUser' (MkUser n t _) = greet n t
```

此外，对于每个记录字段，Idris 都会创建一个同名提取函数。这既可以可以用作常规函数，也可以用于通过将后缀表示法附加到变量，把记录类型用点作为分隔。
这里有两个例子，
从用户那里提取年龄：

```idris
getAgeFunction : User -> Bits8
getAgeFunction u = age u

getAgePostfix : User -> Bits8
getAgePostfix u = u.age
```

### 记录的语法糖

正如在 [intro](Intro.md) 中已经提到的，Idris是一种 *纯* 函数式编程语言。在纯函数中，
我们不允许修改全局可变状态。像这样，
如果我们想修改记录值，我们总是
创建一个 *新* 值，保留原始值不变：记录和其他 Idris 值是 *不可变的*。
虽然这个 *可能会* 对性能有轻微影响，但我们可以自由地将记录值传递给不同的函数会带来一些好处，不用担心函数会修改参数值。这些是非常强大的保证，这使得对我们的代码推理变得更加容易。

有几种方法可以修改记录，最通用的是在记录上进行模式匹配，并且
根据需要调整每个字段。例如，如果我们想要将 `User` 的年龄增加一，我们可以执行以下操作：

```idris
total
incAge : User -> User
incAge (MkUser name title age) = MkUser name title (age + 1)
```

这么简单的事情有很多代码，所以 Idris 为此提供了几种语法糖。例如，
使用 *记录* 语法，我们可以访问和更新 `age` 字段的值：

```idris
total
incAge2 : User -> User
incAge2 u = { age := u.age + 1 } u
```

赋值运算符 `:=` 为 在 `u` 中的 `age` 字段分配一个新值。请记住，这将创建一个新的 `User` 值。原本的值 `u` 不受此影响。

我们可以通过使用字段名称来访问记录字段，
作为投影函数 (`age u`; 在 REPL 中看看 `:t age`），或使用点语法：`u.age`。这个特殊语法有别于函数组合的点运算符（`(.)`）。

修改记录字段的用例如此普遍，
Idris 也为此提供了特殊的语法：

```idris
total
incAge3 : User -> User
incAge3 u = { age $= (+ 1) } u
```

在这里，我使用了 *运算符块* (`(+ 1)`) 来使代码更简洁。
作为运算符块的替代方案，
我们可以像这样使用匿名函数：

```idris
total
incAge4 : User -> User
incAge4 u = { age $= \x => x + 1 } u
```

最后，由于我们函数的参数 `u` 只是在最后被使用一次，我们可以完全放弃它，
获得以下高度简洁的版本：

```idris
total
incAge5 : User -> User
incAge5 = { age $= (+ 1) }
```

像往常一样，我们应该看看 REPL 的结果：

```repl
Tutorial.DataTypes> incAge5 drNo
MkUser "No" (Other "Dr.") 74
```

可以使用此语法来设置或更新一个或多个记录字段：

```idris
total
drNoJunior : User
drNoJunior = { name $= (++ " Jr."), title := Mr, age := 17 } drNo
```

### 元组

我在上面写了一条记录也被称为*积类型*。
当我们考虑存在于给定类型中的可能值数量的时候，这是很显而易见的。例如，考虑以下自定义记录：

```idris
record Foo where
  constructor MkFoo
  wd   : Weekday
  bool : Bool
```

`Foo` 类型的可能值有多少？答案是`7 * 2 = 14`，
因为我们可以将所有可能的 `Weekday`（总共七个）与所有可能的
`Bool`（共两个）相乘。因此，记录类型的可能值的数量是每个字段可能值的数量的 *积*。

规范的积类型是 `Pair`，可从 *Prelude* 获得：

```idris
total
weekdayAndBool : Weekday -> Bool -> Pair Weekday Bool
weekdayAndBool wd b = MkPair wd b
```

因为通过包裹在 `Pair` 或更大的元组中，从一个函数返回多个值是很常见的，Idris 提供了一些与这些一起工作的语法糖。我们可以只写 `(Weekday, Bool)` 来代替 `Pair Weekday Bool`。同样我们可以只写 `(wd, b)` （空格是可选的）来代替 `MkPair wd b`：

```idris
total
weekdayAndBool2 : Weekday -> Bool -> (Weekday, Bool)
weekdayAndBool2 wd b = (wd, b)
```

这也适用于嵌套元组：

```idris
total
triple : Pair Bool (Pair Weekday String)
triple = MkPair False (Friday, "foo")

total
triple2 : (Bool, Weekday, String)
triple2 = (False, Friday, "foo")
```

在上面的例子中，`triple2` 在
Idris 编译器中会被转换成 `triple` 的形式来使用。

我们甚至可以在模式匹配中使用元组语法：

```idris
total
bar : Bool
bar = case triple of
  (b,wd,_) => b && isWeekend wd
```

### As 模式

有时，我们想通过模式匹配来提取它上面的一个值，但仍然保留使用它的整体值在进一步的计算中：

```idris
total
baz : (Bool,Weekday,String) -> (Nat,Bool,Weekday,String)
baz t@(_,_,s) = (length s, t)
```

在 `baz` 中，变量 `t` 会 *绑定* 到整个三元组，然后被重用以构造生成的四元组。记住，
`(Nat,Bool,Weekday,String)` 只是 `Pair Nat (Bool,Weekday,String)` 的糖，而 `(length s, t)` 只是
`MkPair（length s）t` 的糖。因此，上面的实现是正确的，由类型检查器确认。

### 练习第 3 部分

1. 通过把 `UnitOfTime` 和表示时间跨度的整数配对来定义一个记录类型。再定义一个用于转换的函数来定义时间跨度的记录类型，以秒为单位表示持续时间。

2. 对时间跨度实施相等检查：两个时间跨度应该被认为是相等的，当且仅当它们对应于相同的秒数。

3.实现美观的打印时间跨度的函数：
结果字符串应显示其时间跨度的给定单位，如果单位还不是秒，再加上括号中显示的秒数。

4. 实现两个时间跨度相加的功能。如果
两个时间跨度使用不同的时间单位，使用较小的时间单位，以确保无损转换。

## 通用数据类型

有时，我们会喜欢一个概念足够笼统，不仅适用于单一类型，而且适用于所有类型。例如，我们可能不想定义整数列表、字符串列表和布尔列表，因为这会导致大量代码重复。
相反，我们希望有一个通用列表类型，根据它存储的值的类型 *参数化*。本节说明如何定义和使用泛型类型。

### Maybe

考虑解析来自用户输入的 `Weekday` 的情况。如果
字符串输入是 `"Saturday"`，一个函数的确应该返回 `Saturday`，但如果
输入是 `"sdfkl332"` 呢？我们在这里有几个选择。
例如，我们可以只返回一个默认结果
（也许是 `Sunday` ？）。但这是程序员在使用我们的库时期望行为吗？也许不吧。默默地面对无效的用户输入，继续使用默认值不是最好的选择，可能会导致很多混乱。

在命令式语言中，我们的函数可能会
抛出异常。我们可以在 Idris 中这样做（*Prelude* 中有功能 `idris_crash`
这），好吧，但这样做，我们会放弃完全性！为解析错误等常见问题付出过高的代价。

在像 Java 这样的语言中，我们的函数也可能返回一种 `null` 值（如果
未在客户端代码中正确处理，会导致可怕的 `NullPointerException` ）。我们的解决方案将很相似，但不是默默地返回 `null`，我们将在类型中显示失败的可能性！
我们定义了一个自定义的数据类型，它封装了可能的失败。在 Idris 中定义新的数据类型非常廉价（就所需的代码量而言），因此这通常是为了增加类型安全性。
这是一个如何执行此操作的示例：

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

但假设现在，我们还想从用户输入读取 `Bool` 值。我们现在必须编写一个自定义数据类型 `MaybeBool` ，还有其他任何我们想从 `String` 中读取的类型，并且转换可能会失败。

与许多其他编程语言一样，Idris 允许我们
通过使用 *通用数据类型* 来概括此行为。这是一个例子：

```idris
data Option a = Some a | None

total
readBool : String -> Option Bool
readBool "True"    = Some True
readBool "False"   = Some False
readBool _         = None
```

重要的是去 REPL 并查看类型：

```repl
Tutorial.DataTypes> :t Some
Tutorial.DataTypes.Some : a -> Option a
Tutorial.DataTypes> :t None
Tutorial.DataTypes.None : Optin a
Tutorial.DataTypes> :t Option
Tutorial.DataTypes.Option : Type -> Type
```

我们需要在这里介绍一些行话。 `Option`就是我们所说的 *类型构造函数*。它还不是饱和类型：它是从 `Type` 到 `Type` 的函数。
但是，`Option Bool` 是一种类型，`Option Weekday` 也是一种类型。
甚至 `Option (Option Bool)` 也是有效类型。
`Option`是
`Type` 类型的 *参数* 上的 *参数化* 类型构造函数。
`Some` 和 `None` 是 `Option` 的 *数据构造函数*：用于为类型 `a` 创建 `Option a` 类型值的函数。

让我们看看 `Option` 的一些其他用例。下面是安全除法运算：

```idris
total
safeDiv : Integer -> Integer -> Option Integer
safeDiv n 0 = None
safeDiv n k = Some (n `div` k)
```

面对无效输入返回某种 *null* 值的可能性是如此普遍，以至于有一种类似 `Option` 的数据类型已经在 *Prelude* 中了: `Maybe`，它的数据构造函数是 `Just` 和 `Nothing`。

了解在一个函数中返回 `Maybe Integer` 之间的区别很重要，它可能会失败，并返回 Java 等语言中的 `null`：在前一种情况下，
失败的可能性在类型中是可见的。类型检查器将迫使我们不同于 `Integer` 对待 `Maybe Integer` ：Idris 将 *不会* 让我们忘记最终处理失败的情况。
如果不这样， `null` 被静默返回而不调整
类型。程序员可能（并且经常 *会*）忘记处理 `null` 的情况，导致意外，有时
难以调试运行时异常。

### Either

虽然 `Maybe` 对于快速提供默认值非常有用
表示某种故障的值，这个值 (`Nothing`) 是
不是很丰富。它不会告诉我们*到底是什么*出错。例如，如果我们的 `Weekday`
解析功能，无效输入字符串的值知道以后可能会很有趣。就像上面的`Maybe`和`Option`，这个概念够笼统，我们可能会遇到其他类型的无效值。这是一个封装它的数据类型：

```idris
data Validated e a = Invalid e | Valid a
```

`Validated` 是一个通过两个类型参数 `e` 和 `a` 进行参数化的类型构造函数。它的数据构造函数是`Invalid`和`Valid`，
前者持有一个描述某些错误条件的值，
后者是计算成功的结果。让我们看看它的实际效果：

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
