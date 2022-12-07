# 函数第 2 部分

到目前为止，我们了解了 Idris 语言的核心特性，它与其他几种纯的强类型编程语言（如 Haskell）有共同之处：（高阶）函数、代数数据类型、模式匹配、参数多态性（泛型类型和函数）和临时多态性（接口和约束函数）。

在本章中，我们开始真正剖析 Idris 函数及其类型。我们了解隐式参数、命名参数以及擦除和定量。但首先，我们将看看 `let` 绑定和 `where` 块，它们可以帮助我们实现过于复杂而无法在一行代码中放置的函数。让我们开始吧！

```idris
module Tutorial.Functions2

%default total
```

## Let 绑定和局部定义

到目前为止，我们看到的函数非常简单，可以通过模式匹配直接实现，而不需要额外的辅助函数或变量。情况并非总是如此，并且有两个重要的语言结构用于引入和重用新的局部变量和函数。我们将在两个案例研究中研究这些。

### 用例 1：算术平均值和标准差

在此示例中，我们要计算浮点值列表的算术平均值和标准差。我们需要考虑几件事。

首先，我们需要一个函数来计算数值列表的总和。 *Prelude* 为此导出函数 `sum`：

```repl
Main> :t sum
Prelude.sum : Num a => Foldable t => t a -> a
```

这 - 当然 - 类似于 [上一节](Interfaces.md) 的练习 10 中的 `sumList`，但推广到具有 `Foldable` 实现的所有容器类型。我们将在后面的部分了解接口 `Foldable`。

为了也可以计算方差，我们需要将列表中的每个值转换为一个新值，因为我们必须从列表中的每个值中减去平均值并将结果平方。在上一节的练习中，我们为此定义了函数 `mapList`。 *Prelude* - 当然 - 已经导出了一个名为 `map` 的类似函数，它同样更通用并且也像我们的 `mapMaybe` 用于 `Maybe]` 和 `mapEither` 用于 `Either e`。这是它的类型：

```repl
Main> :t map
Prelude.map : Functor f => (a -> b) -> f a -> f b
```

接口 `Functor` 是另一个我们将在后面讨论的接口。

最后，我们需要一种计算值列表长度的方法。我们为此使用函数 `length`：

```repl
Main> :t List.length
Prelude.List.length : List a -> Nat
```

这里，`Nat` 是自然数的类型（无界、无符号整数）。 `Nat` 实际上不是原语数据类型，而是在 *Prelude* 中使用数据构造函数 `Z: Nat` （为零）和 `S ： Nat -> Nat`（后继）定义的和类型 。以这种方式定义自然数似乎效率极低，但 Idris 编译器会特别处理这些类型和其他几个 *类数字* 类型，并在代码生成期间将它们替换为原语整数。

我们现在已经准备好执行 `mean` 了。由于这是 Idris，并且我们关心清晰的语义，我们将快速定义自定义记录类型，而不是仅仅返回 `Double` 的元组。这样就更清楚了，哪个浮点数对应哪个统计实体：

```idris
square : Double -> Double
square n = n * n

record Stats where
  constructor MkStats
  mean      : Double
  variance  : Double
  deviation : Double

stats : List Double -> Stats
stats xs =
  let len      := cast (length xs)
      mean     := sum xs / len
      variance := sum (map (\x => square (x - mean)) xs) / len
   in MkStats mean variance (sqrt variance)
```

像往常一样，我们首先在 REPL 上尝试一下：

```repl
Tutorial.Functions2> stats [2,4,4,4,5,5,7,9]
MkStats 5.0 4.0 2.0
```

似乎有效，所以让我们一步一步消化这个。我们引入了几个新的局部变量（`len`、`mean` 和 `variance`），它们都将在余下的实现中多次使用。为此，我们使用 `let` 绑定。这包括 `let` 关键字，后跟一个或多个变量赋值，然后是最终表达式，它必须以 `in` 为前缀。请注意，空格同样很重要：我们需要正确对齐三个变量名。继续，试试如果删除 `mean` 或 `variance` 前面的空格会发生什么。另请注意，赋值运算符 `:=` 的对齐方式是可选的。我这样做是因为我认为它有助于提高可读性。

让我们快速看看不同的变量及其类型。 `len` 是转换为 `Double` 的列表的长度，因为这是稍后需要的，我们将 `Double` 类型的其他值除以长度。 Idris 对此非常严格：我们不允许在没有显式转换的情况下混合数字类型。请注意，在这种情况下，Idris 能够从周围的上下文 *推断* `len` 的类型。 `mean` 很简单：我们 `sum` 将存储在列表中的值相加并除以列表的长度。 `variance` 是三个中涉及最多的一个：我们使用匿名函数将列表中的每个项目映射到一个新值，以减去均值并平方结果。然后我们将新项相加并再次除以值的数量。

### 用例 2：模拟一个简单的 Web 服务器

在第二个用例中，我们将编写一个稍大的应用程序。这应该让您了解如何围绕您想要实现的某些业务逻辑设计数据类型和功能。

假设我们运行一个音乐流网络服务器，用户可以在其中购买整张专辑并在线收听。我们想模拟一个用户连接到服务器并访问他们购买的一张专辑。

我们首先定义了一堆记录类型：

```idris
record Artist where
  constructor MkArtist
  name : String

record Album where
  constructor MkAlbum
  name   : String
  artist : Artist

record Email where
  constructor MkEmail
  value : String

record Password where
  constructor MkPassword
  value : String

record User where
  constructor MkUser
  name     : String
  email    : Email
  password : Password
  albums   : List Album
```

其中大部分应该是不言自明的。但是请注意，在某些情况下（`Email`、`Artist`、`Password`）我们将单个值包装在新的记录类型中。当然，我们 *可以* 使用未包装的 `String` 类型，但我们最终会得到许多 `String` 字段，这很难消除歧义。为了不将电子邮件字符串与密码字符串混淆，因此将它们都包装在新的记录类型中会有所帮助，以大大提高类型安全性，但代价是必须重新实现某些接口。 *Prelude* 中的实用函数 `on` 对此非常有用。不要忘记在 REPL 中检查它的类型，并尝试了解这里发生了什么。

```idris
Eq Artist where (==) = (==) `on` name

Eq Email where (==) = (==) `on` value

Eq Password where (==) = (==) `on` value

Eq Album where (==) = (==) `on` \a => (a.name, a.artist)
```

在 `Album` 的情况下，我们将记录的两个字段包装在 `Pair` 中，它已经附带了 `Eq` 的实现。这让我们可以再次使用`on`函数，非常方便。

接下来，我们必须定义代表服务器请求和响应的数据类型：

```idris
record Credentials where
  constructor MkCredentials
  email    : Email
  password : Password

record Request where
  constructor MkRequest
  credentials : Credentials
  album       : Album

data Response : Type where
  UnknownUser     : Email -> Response
  InvalidPassword : Response
  AccessDenied    : Email -> Album -> Response
  Success         : Album -> Response
```

对于服务器响应，我们使用自定义 sum 类型来编码客户端请求的可能结果。在实践中，`Success` 案例会返回某种连接来启动实际的专辑流，但我们只是包装我们找到的专辑来模拟这种行为。

我们现在可以继续模拟在服务器上对请求的处理。为了模拟我们的用户数据库，一个简单的用户列表就可以了。这是我们要实现的函数的类型：

```idris
DB : Type
DB = List User

handleRequest : DB -> Request -> Response
```

请注意，我们如何为 `List User` 定义一个称为 `DB` 的短别名。这通常有助于使冗长的类型签名更具可读性并在给定的上下文中传达类型的含义。但是，这将 *不会* 引入新类型，也不会增加类型安全性：`DB` 只是 `List User` 的一个 *身份*，并且作为这样，类型为 `DB` 的值可以在需要 `List User` 的任何地方使用，反之亦然。因此，在更复杂的程序中，通常最好通过将值包装在单字段记录中来定义新类型。

实现将按如下进行：它将首先尝试在数据库中通过电子邮件地址查找 `User`。如果成功，它会将提供的密码与用户的实际密码进行比较。如果两者匹配，它将在用户的专辑列表中查找请求的专辑。如果所有这些步骤都成功，结果将是 `Album` 包裹在 `Success` 中。如果任何步骤失败，结果将准确描述问题所在。

这是一个可能的实现：

```idris
handleRequest db (MkRequest (MkCredentials email pw) album) =
  case lookupUser db of
    Just (MkUser _ _ password albums)  =>
      if password == pw then lookupAlbum albums else InvalidPassword

    Nothing => UnknownUser email

  where lookupUser : List User -> Maybe User
        lookupUser []        = Nothing
        lookupUser (x :: xs) =
          if x.email == email then Just x else lookupUser xs

        lookupAlbum : List Album -> Response
        lookupAlbum []        = AccessDenied email album
        lookupAlbum (x :: xs) =
          if x == album then Success album else lookupAlbum xs
```

我想在这个例子中指出几件事。首先，请注意我们如何在单个模式匹配中从嵌套记录中提取值。其次，我们在 `where` 块中定义了两个 *局部* 函数：`lookupUser` 和 `lookupAlbum`。这两者都可以访问作用域内的所有变量。例如，`lookupUser` 在实现的第一行中使用来自模式匹配的 `album` 变量。同样，`lookupAlbum` 使用 `album` 变量。

`where` 块引入了新的局部定义，只能从作用域和稍后在同一 `where` 块中定义的其他函数访问。这些需要以相同数量的空格输入和缩进。

局部定义也可以通过使用 `let` 关键字在函数实现 *之前* 引入。 `let` 的这种用法不要与上面描述的 *let bindings* 混淆，后者用于绑定和重用中间计算的结果。下面是我们如何使用 `let` 关键字引入的本地定义来实现 `handleRequest`。同样，所有定义都必须正确输入和缩进：

```idris
handleRequest' : DB -> Request -> Response
handleRequest' db (MkRequest (MkCredentials email pw) album) =
  let lookupUser : List User -> Maybe User
      lookupUser []        = Nothing
      lookupUser (x :: xs) =
        if x.email == email then Just x else lookupUser xs

      lookupAlbum : List Album -> Response
      lookupAlbum []        = AccessDenied email album
      lookupAlbum (x :: xs) =
        if x == album then Success album else lookupAlbum xs

   in case lookupUser db of
        Just (MkUser _ _ password albums)  =>
          if password == pw then lookupAlbum albums else InvalidPassword

        Nothing => UnknownUser email
```

### 练习

本节中的练习旨在增加您编写纯函数式代码的经验。在某些情况下，使用 `let` 表达式或 `where` 块可能很有用，但这并不总是必需的。

练习 3 同样至关重要。 `traverseList` 是更通用的 `traverse` 的专用版本，是 *Prelude* 中最强大和最通用的功能之一（查看它的类型！）。

1. *base* 中的 `Data.List` 模块导出函数 `find` 和 `elem`。检查它们的类型并在 `handleRequest` 的实现中使用它们。这应该可以让您完全摆脱 `where` 块。


2. 定义枚举类型，列出 DNA 链中出现的四个 [核碱基](https://en.wikipedia.org/wiki/Nucleobase)。还为核碱基列表定义类型别名 `DNA`。声明并实现函数 `readBase` 用于将单个字符（类型 `Char`）转换为核碱基。您可以在实现中使用字符文字，如下所示：`'A'`、`'a'`。请注意，此函数可能会失败，因此请相应地调整结果类型。


3. 实现以下函数，该函数尝试使用函数转换列表中的所有值，这可能会失败。结果应该是 `Just` 以未修改的顺序保存转换值的列表，当且仅当每次转换都成功时。


   ```idris
   traverseList : (a -> Maybe b) -> List a -> Maybe (List b)
   ```

   您可以通过下面的测试验证该函数是否正确运行：`traverseList Just [1,2,3] = Just [1,2,3]`。

4. 使用练习 2 和 3 中定义的函数和类型实现函数 `readDNA : String -> Maybe DNA`。您还需要 *Prelude* 中的函数 `unpack`。


5. 实现函数 `complement : DNA -> DNA` 来计算一条 DNA 链的补码。


## 关于函数参数的真相

到目前为止，当我们定义一个顶级函数时，它看起来像下面这样：

```idris
zipEitherWith : (a -> b -> c) -> Either e a -> Either e b -> Either e c
zipEitherWith f (Right va) (Right vb) = Right (f va vb)
zipEitherWith f (Left e)   _          = Left e
zipEitherWith f _          (Left e)   = Left e
```

函数 `zipEitherWith` 是一个通用的高阶函数，通过二进制函数将两个 `Either` 中存储的值组合在一起。如果任一 `Either` 类型参数是 `Left`，则结果也是 `Left`。

这是一个 *泛型函数*，带有 *类型参数* `a`、`b`、`c` 和 `e`。但是，`zipEitherWith` 有一个更详细的类型，当在 REPL 中输入 `:ti zipEitherWith`（这里的 `i` 告诉 Idris 包含 `implicit` 参数）时。你会得到一个类似这样的类型：

```idris
zipEitherWith' :  {0 a : Type}
               -> {0 b : Type}
               -> {0 c : Type}
               -> {0 e : Type}
               -> (a -> b -> c)
               -> Either e a
               -> Either e b
               -> Either e c
```

为了理解这里发生了什么，我们将不得不讨论命名参数、隐式参数和定量。

### 命名参数

在函数类型中，我们可以给每个参数一个名称。像这样：

```idris
fromMaybe : (deflt : a) -> (ma : Maybe a) -> a
fromMaybe deflt Nothing = deflt
fromMaybe _    (Just x) = x
```

这里，第一个参数的名称是 `deflt`，第二个参数是 `ma`。这些名称可以在函数的实现中重复使用，就像 `deflt` 所做的那样，但这不是强制性的：我们可以在实现中自由使用不同的名称。我们选择命名参数有几个原因：它可以用作文档，但它也允许我们在使用以下语法时以任意顺序将参数传递给函数：

```idris
extractBool : Maybe Bool -> Bool
extractBool v = fromMaybe { ma = v, deflt = False }
```

甚至 ：

```idris
extractBool2 : Maybe Bool -> Bool
extractBool2 = fromMaybe { deflt = False }
```

记录构造函数中的参数根据字段名称自动命名：

```idris
record Dragon where
  constructor MkDragon
  name      : String
  strength  : Nat
  hitPoints : Int16

gorgar : Dragon
gorgar = MkDragon { strength = 150, name = "Gorgar", hitPoints = 10000 }
```

对于上述用例，命名参数只是一种方便且完全可选的。但是，Idris 是一种 *依赖类型* 编程语言：类型可以根据值计算并取决于值。例如，函数的 *结果类型* 可以 *取决于* 其参数之一的 *值*。这是一个人为的例子：

```idris
IntOrString : Bool -> Type
IntOrString True  = Integer
IntOrString False = String

intOrString : (v : Bool) -> IntOrString v
intOrString False = "I'm a String"
intOrString True  = 1000
```

如果您第一次看到这样的事情，可能很难理解这里发生了什么。首先，函数 `IntOrString` 从 `Bool` 值计算 `Type`：如果参数是 `True`，则返回类型 `Integer`，如果参数为 `False`，则返回 `String`。我们使用 `intOrString` 来根据其布尔参数 `v` 计算函数 的返回类型： 如果 `v` 为 `True`，则返回类型为（根据`IntOrString True = Integer`）`Integer`，否则为`String`。

注意，在 `intOrString` 的类型签名中，我们 *必须* 给 `Bool` 类型的参数命名 (`v`) 以便在结果类型 `IntOrString v` 中引用它。

此时您可能想知道，为什么这很有用，以及为什么我们要定义一个具有如此奇怪类型的函数。我们会在适当的时候看到很多非常有用的例子！现在，可以这么说，为了表达依赖函数类型，我们至少需要命名函数的一些参数，并在其他参数的类型中通过名称引用它们。

### 隐式参数

隐式参数也是参数，编译器应该自动为我们推断和填充其值。例如，在下面的函数签名中，我们希望编译器从其他参数的类型中自动推断类型参数 `a` 的值（暂时忽略定量 0；我将在下一小节）：

```idris
maybeToEither : {0 a : Type} -> Maybe a -> Either String a
maybeToEither Nothing  = Left "Nope"
maybeToEither (Just x) = Right x

-- Please remember, that the above is
-- equivalent to the following:
maybeToEither' : Maybe a -> Either String a
maybeToEither' Nothing  = Left "Nope"
maybeToEither' (Just x) = Right x
```

如您所见，隐式参数包含在花括号中，与显式命名参数不同，后者包含在括号中。推断隐含参数的值并不总是可能的。例如，如果我们在 REPL 中输入以下内容，Idris 将失败并出现错误：

```repl
Tutorial.Functions2> show (maybeToEither Nothing)
Error: Can't find an implementation for Show (Either String ?a).
```

Idris 在不知道 `a` 实际上是什么的情况下无法找到 `Show (Either String a)` 的实现。注意类型参数前面的问号：`?a`。如果发生这种情况，有几种方法可以帮助类型检查器。例如，我们可以为隐式参数显式传递一个值。这是执行此操作的语法：

```repl
Tutorial.Functions2> show (maybeToEither {a = Int8} Nothing)
"Left "Nope""
```

如您所见，我们对显式命名参数使用与上面所示相同的语法，并且可以混合使用两种形式的参数传递。

我们还可以使用 *Prelude* 中的实用函数 `the` 指定整个表达式的类型：

```repl
Tutorial.Functions2> show (the (Either String Int8) (maybeToEither Nothing))
"Left "Nope""
```

查看 `the` 的类型很有启发性：

```repl
Tutorial.Functions2> :ti the
Prelude.the : (0 a : Type) -> a -> a
```

将此与恒等函数 `id` 进行比较：

```repl
Tutorial.Functions2> :ti id
Prelude.id : {0 a : Type} -> a -> a
```

两者之间的唯一区别：在 `the` 的情况下，类型参数 `a` 是 *显式* 参数，而在 `id` 的情况下，它是一个 *隐式* 参数。尽管这两个函数具有几乎相同的类型（和实现！），但它们的用途却截然不同：`the` 用于帮助类型推断，而 `id` 用于我们想要的任何时候返回一个参数而不修改它（在高阶函数存在的情况下，这种情况经常发生）。

上面显示的两种改进类型推断的方法都经常使用，并且 Idris 程序员必须理解。

### 多重性

最后，我们需要谈谈在本节的几个类型签名中出现的零多重性。 Idris 2 与其前身 Idris 1 不同，它基于称为 *定量类型理论* (QTT) 的核心语言：Idris 2 中的每个变量都与三种可能的多重性之一相关联：

* `0` ，表示变量在运行时被 *擦除*。

* `1` ，表示变量在运行时 *正好使用一次* 。

* *无限制*（默认），表示在运行时使用变量任意次数。

我们不会在这里讨论三者中最复杂的，多重性 `1`。然而，我们经常对多重性 `0` 感兴趣：具有多重性 `0` 的变量仅在 *编译时* 相关。它不会在运行时出现，并且这样一个变量的计算永远不会影响程序的运行时性能。

在 `maybeToEither` 的类型签名中，我们看到类型参数 `a` 具有多重性 `0`，因此将被擦除并且仅在编译时相关，而 `Maybe a ` 参数具有 *无限制* 多重性。

也可以用多重性注释显式参数，在这种情况下，同样参数必须放在括号中。例如，再次查看 `the` 的类型签名。

### 下划线

通常希望只编写必要的代码，让 Idris 解决剩下的问题。我们已经了解了这样一种情况：任意模式。如果模式匹配中的变量未在右侧使用，我们不能直接删除它，因为这会使 Idris 无法使用，但我们可以使用下划线作为一个占位符，表明我们计划删除几个参数中的哪一个：

```idris
isRight : Either a b -> Bool
isRight (Right _) = True
isRight _         = False
```

但是当我们查看 `isRight` 的类型签名时，我们会注意到类型参数 `a` 和 `b` 也只使用一次，因此它们并不重要.让我们摆脱它们：

```idris
isRight' : Either _ _ -> Bool
isRight' (Right _) = True
isRight' _         = False
```

在 `zipEitherWith` 的详细类型签名中，对 Idris 来说，隐式参数的类型应该是 `Type`。毕竟，它们后来都应用于 `Either` 类型构造函数，它的类型为 `Type -> Type -> Type`。让我们摆脱它们：

```idris
zipEitherWith'' :  {0 a : _}
                -> {0 b : _}
                -> {0 c : _}
                -> {0 e : _}
                -> (a -> b -> c)
                -> Either e a
                -> Either e b
                -> Either e c
```

考虑以下人为设计的示例：

```idris
foo : Integer -> String
foo n = show (the (Either String Integer) (Right n))
```

由于我们将 `Integer` 包装在 `Right` 中，很明显 `Either String Integer` 中的第二个参数是 `Integer`。 Idris 无法推断出的只有 `String` 参数。更妙的是，`Either` 本身就很明显了！让我们摆脱不必要的噪音：

```idris
foo' : Integer -> String
foo' n = show (the (_ String _) (Right n))
```

请注意，在 `foo'` 中使用下划线并不总是可取的，因为它会极大地混淆编写的代码。始终使用方便的语法来使代码更具可读性，而不是向人们展示你有多聪明。

## 孔编程

解决了到目前为止的所有练习？对类型检查器总是抱怨并且从来没有真正提供帮助而生气？是时候改变这一点了。 Idris 带有几个非常有用的交互式编辑功能。有时，编译器能够为我们实现完整的功能（如果类型足够具体）。即使这不可能，也有一个非常有用且重要的功能，当类型变得过于复杂时，它可以帮助我们：孔。孔是变量，其名称以问号为前缀。每当我们计划在以后实现某个功能时，我们都可以将它们用作占位符。此外，它们的类型以及范围内所有其他变量的类型和数量可以在 REPL（或在您的编辑器中，如果您设置了必要的插件）进行检查。让我们在实践中看看孔是什么样子。

还记得本节前面练习中的 `traverseList` 示例吗？如果这是您第一次遇到应用程序列表遍历，那么这可能是一项令人讨厌的工作。好吧，让我们让它变得更难一点。我们希望为返回 `Either e` 的函数实现相同的功能，其中 `e` 是具有 `Semigroup` 实现的类型，我们希望累积我们沿途遇到的所有 `Left` 中的值。

这是函数的类型：

```idris
traverseEither :  Semigroup e
               => (a -> Either e b)
               -> List a
               -> Either e (List b)
```

现在，为了继续进行，您可能想要启动自己的 Idris 源文件，将其加载到 REPL 会话中并按照此处所述调整代码。我们要做的第一件事是编写一个在右侧有一个孔的骨架实现：

```repl
traverseEither fun as = ?impl
```

当您现在转到 REPL 并使用命令 `:r` 重新加载文件时，您可以输入 `:m` 以列出所有 *元变量*：

```repl
Tutorial.Functions2> :m
1 hole:
  Tutorial.Functions2.impl : Either e (List b)
```

接下来，我们要显示孔的类型（包括周围上下文中的所有变量及其类型）：

```repl
Tutorial.Functions2> :t impl
 0 b : Type
 0 a : Type
 0 e : Type
   as : List a
   fun : a -> Either e b
------------------------------
impl : Either e (List b)
```

因此，我们有一些已擦除的类型参数（`a`、`b` 和 `e`），类型为 `List a` 的值称为 `as`，以及从 `a` 到 `Either a b` 的函数，称为 `fun`。我们的目标是提出一个类型为 `Either a (List b)` 的值。

我们 *可以* 只返回一个 `Right []`，但这只有在我们的输入列表确实是空列表时才有意义。因此，我们应该从列表中的模式匹配开始：

```repl
traverseEither fun []        = ?impl_0
traverseEither fun (x :: xs) = ?impl_1
```

结果是两个孔，它们必须被赋予不同的名称。在检查 `impl_0` 时，我们得到以下结果：

```repl
Tutorial.Functions2> :t impl_0
 0 b : Type
 0 a : Type
 0 e : Type
   fun : a -> Either e b
------------------------------
impl_0 : Either e (List b)
```

现在，这是一个有趣的情况。我们应该想出一个类型为 `Either e (List b)` 的值，而不使用任何东西。我们对 `a` 一无所知，因此我们无法提供调用 `fun` 的参数。同样，我们对 `e` 或 `b` 也一无所知，因此我们也无法生成这些值。我们拥有的 *唯一* 选项是将 `impl_0` 替换为包含在 `Right` 中的空列表：

```idris
traverseEither fun []        = Right []
```

非空的情况当然稍微多一些。这是 `?impl_1` 的上下文：

```repl
Tutorial.Functions2> :t impl_1
 0 b : Type
 0 a : Type
 0 e : Type
   x : a
   xs : List a
   fun : a -> Either e b
------------------------------
impl_1 : Either e (List b)
```

由于 `x` 是 `a` 类型，我们可以将其用作 `fun` 的参数，也可以放弃并忽略它。另一方面，`xs` 是 `List a` 类型列表的其余部分。我们可以通过递归调用 `traverseEither` 再次删除它或进一步处理它。由于目标是尝试转换 *所有* 值，我们都不应该放弃。因为在两个 `Left` 的情况下，我们应该累积值，我们最终还是需要运行这两个计算（调用 `fun`，并递归调用 `traverseEither`） .因此，我们可以同时进行这两项操作，并通过将两者包装在 `Pair` 中来分析单个模式匹配中的结果：

```repl
traverseEither fun (x :: xs) =
  case (fun x, traverseEither fun xs) of
   p => ?impl_2
```

我们再次检查上下文：

```repl
Tutorial.Functions2> :t impl_2
 0 b : Type
 0 a : Type
 0 e : Type
   xs : List a
   fun : a -> Either e b
   x : a
   p : (Either e b, Either e (List b))
------------------------------
impl_2 : Either e (List b)
```

我们肯定需要在对 `p` 进行模式匹配，以确定两个计算中的哪一个成功：

```repl
traverseEither fun (x :: xs) =
  case (fun x, traverseEither fun xs) of
    (Left y, Left z)   => ?impl_6
    (Left y, Right _)  => ?impl_7
    (Right _, Left z)  => ?impl_8
    (Right y, Right z) => ?impl_9
```

在这一点上，我们可能已经忘记了我们真正想要做什么（至少对我来说，这种情况经常发生），所以我们将快速检查我们的目标是什么：

```repl
Tutorial.Functions2> :t impl_6
 0 b : Type
 0 a : Type
 0 e : Type
   xs : List a
   fun : a -> Either e b
   x : a
   y : e
   z : e
------------------------------
impl_6 : Either e (List b)
```

因此，我们仍在寻找类型为 `Either e (List b)` 的值，并且我们在范围内有两个类型为 `e` 的值。根据规范，我们希望使用 `e` 的 `Semigroup` 实现来累积这些。我们可以以类似的方式处理其他情况，记住我们应该返回 `Right`，当且仅当所有转换都成功：

```idris
traverseEither fun (x :: xs) =
  case (fun x, traverseEither fun xs) of
    (Left y, Left z)   => Left (y <+> z)
    (Left y, Right _)  => Left y
    (Right _, Left z)  => Left z
    (Right y, Right z) => Right (y :: z)
```

为了收获我们的劳动成果，让我们用一个小例子来炫耀一下：

```idris
data Nucleobase = Adenine | Cytosine | Guanine | Thymine

readNucleobase : Char -> Either (List String) Nucleobase
readNucleobase 'A' = Right Adenine
readNucleobase 'C' = Right Cytosine
readNucleobase 'G' = Right Guanine
readNucleobase 'T' = Right Thymine
readNucleobase c   = Left ["Unknown nucleobase: " ++ show c]

DNA : Type
DNA = List Nucleobase

readDNA : String -> Either (List String) DNA
readDNA = traverseEither readNucleobase . unpack
```

让我们在 REPL 上试试这个：

```repl
Tutorial.Functions2> readDNA "CGTTA"
Right [Cytosine, Guanine, Thymine, Thymine, Adenine]
Tutorial.Functions2> readDNA "CGFTAQ"
Left ["Unknown nucleobase: 'F'", "Unknown nucleobase: 'Q'"]
```

### 交互式编辑

有一些可用于多个编辑器和编程环境的插件，它们有助于在实现您的功能时与 Idris 编译器进行交互。一位深受 Idris 社区支持的编辑器是 Neovim。由于我自己是 Neovim 用户，因此我在 [附录](../Appendices/Neovim.md) 中添加了一些可能的示例。现在是开始使用那里讨论的实用程序的好时机。

如果您使用不同的编辑器，可能对 Idris 编程语言的支持较少，您至少应该始终打开一个 REPL 会话，您当前正在处理的源文件被加载到该会话中。这允许您在开发代码时引入新的元变量并检查它们的类型和上下文。

## 结论

在本节中，我们再次涵盖了很多内容。我怎么强调都不过分，你应该让自己习惯于使用孔进行编程，并让类型检查器帮助你弄清楚下一步该做什么。

* 当需要局部使用函数时，考虑定义它们
作为 *where 块*中的局部定义。

* 使用 *let 表达式* 来定义和重用局部变量。


* 函数参数可以命名，可以作为文档，
可用于以任意顺序传递参数，并用于引用
它们在依赖类型中。

* 隐式参数用大括号括起来。编译器应该从上下文中推断出它们。如果这不可能，它们可以作为其他命名参数显式传递。

* 只要有可能，Idris 都会为所有参数自动添加隐式擦除参数。

* 定量允许我们跟踪函数参数的使用频率。定量 0 表示，参数在运行时被擦除。

* 使用 *孔* 作为您计划在稍后的时间填充代码片段的占位符。使用 REPL（或您的编辑器）检查孔的类型以及所有孔的名称、类型和在他们的上下文中的变量的定量。

### 下一步是什么

在 [下一章](Dependent.md) 中，我们将开始使用依赖类型来帮助我们编写可证明正确的代码。很好地理解如何阅读 Idris 的类型签名将是至关重要的。每当您感到迷茫时，添加一个或多个孔并检查其上下文以决定下一步该做什么。

<!-- vi: filetype=idris2
-->
