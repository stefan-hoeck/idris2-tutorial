# 函子和它的朋友们

编程，就像数学一样，是关于抽象的。我们尝试对现实世界的某些部分进行建模，通过对它们进行抽象来重用重复出现的模式。

在本章中，我们将学习几个相关的接口，它们都是关于抽象的，因此一开始可能很难理解。尤其是弄清楚 *为什么* 有用以及 *何时* 使用它们需要时间和经验。因此，本章包含大量练习，其中大部分练习只需几行代码即可解决。不要跳过它们。回到他们身边几次，直到这些事情开始对你来说很自然。然后你会意识到它们最初的复杂性已经消失了。

```idris
module Tutorial.Functor

import Data.List1
import Data.String
import Data.Vect

%default total
```

## 函子

`List`、`List1`、`Maybe` 或 `IO` 等类型构造函数有什么共同点？首先，它们都是类型 `Type -> Type`。其次，它们都将给定类型的值放在某个 *上下文* 中。对于 `List`，*上下文* 是 *不确定性*：我们知道有零个或多个值，但在开始之前我们不知道确切的数字通过对其进行模式匹配将列表分开。对于 `List1` 也是如此，尽管我们确定至少有一个值。对于 `Maybe`，我们仍然不确定有多少个值，但可能性要小得多：零或一。使用 `IO`，上下文是不同的：任意副作用。

尽管上面讨论的类型构造函数在它们的行为方式和何时有用方面有很大不同，但在使用它们时会不断出现某些操作。第一个这样的操作是 *在数据类型上映射一个纯函数，而不影响其底层结构*。

例如，给定一个数字列表，我们希望将每个数字乘以 2，而不更改它们的顺序或删除任何值：

```idris
multBy2List : Num a => List a -> List a
multBy2List []        = []
multBy2List (x :: xs) = 2 * x :: multBy2List xs
```

但是我们也可以将字符串列表中的每个字符串都转换为大写字符：

```idris
toUpperList : List String -> List String
toUpperList []        = []
toUpperList (x :: xs) = toUpper x :: toUpperList xs
```

有时，存储值的类型会发生变化。在下一个示例中，我们计算存储在列表中的字符串的长度：

```idris
toLengthList : List String -> List Nat
toLengthList []        = []
toLengthList (x :: xs) = length x :: toLengthList xs
```

我希望你能体会到，这些功能是多么无聊。它们几乎相同，唯一有趣的部分是我们应用于每个元素的函数。当然，必须有一个抽象的模式：

```idris
mapList : (a -> b) -> List a -> List b
mapList f []        = []
mapList f (x :: xs) = f x :: mapList f xs
```

这通常是函数式编程中抽象的第一步：编写一个（可能是通用的）高阶函数。我们现在可以根据 `mapList` 简洁地实现上面显示的所有示例：

```idris
multBy2List' : Num a => List a -> List a
multBy2List' = mapList (2 *)

toUpperList' : List String -> List String
toUpperList' = mapList toUpper

toLengthList' : List String -> List Nat
toLengthList' = mapList length
```

但我们肯定想对 `List1` 和 `Maybe` 做同样的事情！毕竟，它们只是像 `List` 这样的容器类型，唯一的区别是关于它们可以或不可以保存的值的数量的一些细节：

```idris
mapMaybe : (a -> b) -> Maybe a -> Maybe b
mapMaybe f Nothing  = Nothing
mapMaybe f (Just v) = Just (f v)
```

即使使用 `IO`，我们也希望能够将纯函数映射到副作用的计算上。由于数据构造函数的嵌套层，实现有点复杂，但如果有疑问，类型肯定会指导我们。但是请注意，`IO` 不是公开导出的，因此我们无法使用它的数据构造函数。我们可以使用函数 `toPrim` 和 `fromPrim`，但是，将 `IO` 与 `PrimIO` 相互转换，我们可以自由剖析：

```idris
mapIO : (a -> b) -> IO a -> IO b
mapIO f io = fromPrim $ mapPrimIO (toPrim io)
  where mapPrimIO : PrimIO a -> PrimIO b
        mapPrimIO prim w =
          let MkIORes va w2 = prim w
           in MkIORes (f va) w2
```

从 *将纯函数映射到上下文中的值的概念* 遵循一些派生函数，这些函数通常很有用。以下是 `IO` 中的一些：

```idris
mapConstIO : b -> IO a -> IO b
mapConstIO = mapIO . const

forgetIO : IO a -> IO ()
forgetIO = mapConstIO ()
```

当然，我们也想为 `List`、`List1` 和 `Maybe` 实现 `mapConst` 和 `forget` ]（以及其他几十个具有某种映射函数的类型构造函数），它们看起来都一样并且同样无聊。

当我们遇到具有几个有用的派生函数的重复函数类时，我们应该考虑定义一个接口。但是我们应该怎么做呢？当您查看 `mapList`、`mapMaybe` 和 `mapIO` 的类型时，您会发现它是 `List`、`我们需要去掉 List1` 和 `IO` 类型。这些不是 `Type` 类型，而是 `Type -> Type` 类型。幸运的是，除了 `Type` 之外，没有什么能阻止我们对接口进行参数化。

我们要找的接口叫做`Functor`。这是它的定义和一个示例实现（我在名称末尾附加了一个引号，以免它们与 *Prelude* 导出的接口和函数重叠）：

```idris
interface Functor' (0 f : Type -> Type) where
  map' : (a -> b) -> f a -> f b

implementation Functor' Maybe where
  map' _ Nothing  = Nothing
  map' f (Just v) = Just $ f v
```

请注意，我们必须明确给出参数 `f` 的类型，在这种情况下，如果您希望它在运行时被擦除（您几乎总是想要），则需要用定量零进行注释。

现在，读取仅包含类型参数（如 `map'` 中的某个）的类型签名可能需要一些时间来适应，尤其是当某些类型参数应用于其他参数时，例如 `f a` .检查这些签名以及 REPL 中的所有隐式参数会非常有帮助（我对输出进行了格式化以使其更具可读性）：

```repl
Tutorial.Functor> :ti map'
Tutorial.Functor.map' :  {0 b : Type}
                      -> {0 a : Type}
                      -> {0 f : Type -> Type}
                      -> Functor' f
                      => (a -> b)
                      -> f a
                      -> f b
```

将类型参数 `f` 替换为相同类型的具体值也很有帮助：

```repl
Tutorial.Functor> :t map' {f = Maybe}
map' : (?a -> ?b) -> Maybe ?a -> Maybe ?b
```

请记住，能够解释类型签名对于理解 Idris 声明中发生的事情至关重要。您 *必须* 练习这一点，并利用提供给您的工具和实用程序。

### 派生函数

有几个函数和运算符可以直接从接口 `Functor` 派生。最终，您应该知道并记住所有这些，因为它们非常有用。在这里，它们与它们的类型一起：

```repl
Tutorial.Functor> :t (<$>)
Prelude.<$> : Functor f => (a -> b) -> f a -> f b

Tutorial.Functor> :t (<&>)
Prelude.<&> : Functor f => f a -> (a -> b) -> f b

Tutorial.Functor> :t ($>)
Prelude.$> : Functor f => f a -> b -> f b

Tutorial.Functor> :t (<$)
Prelude.<$ : Functor f => b -> f a -> f b

Tutorial.Functor> :t ignore
Prelude.ignore : Functor f => f a -> f ()
```

`(<$>)` 是 `map` 的运算符别名，有时您可以去掉一些括号。例如：

```idris
tailShowReversNoOp : Show a => List1 a -> List String
tailShowReversNoOp xs = map (reverse . show) (tail xs)

tailShowReverse : Show a => List1 a -> List String
tailShowReverse xs = reverse . show <$> tail xs
```

`(<&>)` 是 `(<$>)` 参数被翻转后的别名，。其他三个（`ignore`、`($>)` 和 `(<$)`）都用于将上下文中的值替换为常量。当您不关心值本身但想要保留底层结构时，它们通常很有用。

### 具有多个类型参数的函子

到目前为止，我们看到的类型构造函数都是 `Type -> Type`。但是，我们也可以为其他类型的构造函数实现 `Functor`。唯一的先决条件是我们想用函数 `map` 更改的类型参数必须是参数列表中的最后一个。例如，这里是 `Either e` 的 `Functor` 实现（注意， `Either e` 当然有类型 `Type -> Type` 为必要条件）：

```idris
implementation Functor' (Either e) where
  map' _ (Left ve)  = Left ve
  map' f (Right va) = Right $ f va
```

这是另一个例子，这次是一个类型为 `Bool -> Type -> Type` 的类型构造函数（你可能还记得 [上一章](IO.md) 的练习中的这个）：

```idris
data List01 : (nonEmpty : Bool) -> Type -> Type where
  Nil  : List01 False a
  (::) : a -> List01 False a -> List01 ne a

implementation Functor (List01 ne) where
  map _ []        = []
  map f (x :: xs) = f x :: map f xs
```

### 函子组合

函子的好处是它们可以如何与其他函子配对和嵌套，结果又是函子：

```idris
record Product (f,g : Type -> Type) (a : Type) where
  constructor MkProduct
  fst : f a
  snd : g a

implementation Functor f => Functor g => Functor (Product f g) where
  map f (MkProduct l r) = MkProduct (map f l) (map f r)
```

以上允许我们方便地映射一对函子。但是请注意，Idris 需要一些帮助来推断所涉及的类型：

```idris
toPair : Product f g a -> (f a, g a)
toPair (MkProduct fst snd) = (fst, snd)

fromPair : (f a, g a) -> Product f g a
fromPair (x,y) = MkProduct x y

productExample :  Show a
               => (Either e a, List a)
               -> (Either e String, List String)
productExample = toPair . map show . fromPair {f = Either e, g = List}
```

更多时候，我们想一次映射多层嵌套函子。以下是如何通过示例执行此操作：

```idris
record Comp (f,g : Type -> Type) (a : Type) where
  constructor MkComp
  unComp  : f (g a)

implementation Functor f => Functor g => Functor (Comp f g) where
  map f (MkComp v) = MkComp $ map f <$> v

compExample :  Show a => List (Either e a) -> List (Either e String)
compExample = unComp . map show . MkComp {f = List, g = Either e}
```

#### 命名实现

有时，有更多方法可以为给定类型实现接口。例如，对于数字类型，我们可以有一个 `Monoid` 代表加法和一个代表乘法。同样，对于嵌套函子，`map` 可以解释为仅对第一层值的映射，或对若干层值的映射。

解决此问题的一种方法是定义单字段包装器，如上面的数据类型 `Comp` 所示。然而，Idris 也允许我们定义额外的接口实现，然后必须给它一个名字。例如：

```idris
[Compose'] Functor f => Functor g => Functor (f . g) where
  map f = (map . map) f
```

请注意，这定义了 `Functor` 的新实现，在隐式解析期间将 *不* 细化以避免歧义。但是，可以通过将其作为显式参数传递给 `map` 来显式选择使用此实现，并以 `@` 为前缀：

```idris
compExample2 :  Show a => List (Either e a) -> List (Either e String)
compExample2 = map @{Compose} show
```

在上面的示例中，我们使用 `Compose` 代替 `Compose'`，因为前者已经由 *Prelude* 导出。

### 函子定律

`Functor` 的实现应该遵守某些规律，就像 `Eq` 或 `Ord` 的实现一样。同样，这些法律并未得到 Idris 的验证，尽管这样做是可能的（而且通常很麻烦）。

1. `map id = id`：将恒等函数映射到函子上
    不得有任何可见的副作用，例如更改容器的
    结构或影响运行 `IO` 动作的副作用
    。

2. `map (f . g) = map f . map g`: 两个映射的顺序必须与使用两个函数组合后的单个映射相同。

这两条定律都要求 `map` 保留值的 *结构*。使用 `List`、`Maybe` 或 `Either e` 等容器类型更容易理解，其中 `map` 不允许添加或删除任何包装的值，也不 - 在 `List` 的情况下 - 更改它们的顺序。对于使用 `IO`，最好地描述为 `map` 没有执行额外的副作用。

### 练习第 1 部分

1. 为 `Maybe`、`List`、`List1`、`Vect n`、`Either e` 和 `Pair a` `编写自己的 `Functor'`
   实现。

2. 为 pairs 函数编写 `Functor` 的命名实现（类似于为 `Product` 实现的实现）。

3. 为数据类型 `Identity` 实现 `Functor`（可从 *base* 中的 `Control.Monad.Identity` 获得）：

   ```idris
   record Identity a where
     constructor Id
     value : a
   ```

4. 这是一个奇怪的问题：为 `Const e` 实现 `Functor`（也可以从 *base* 中的
   `Control.Applicative.Const`
   获得）。您可能会对第二个类型参数在运行时绝对没有相关性这一事实感到困惑，因为没有该类型的值。这种类型有时被称为
   *幻像类型*。它们对于使用附加类型信息标记值非常有用。

   不要让上述内容使您感到困惑：只有一种可能的实现。
   像往常一样，使用孔，如果你迷路了，让编译器指导你。

   ```idris
   record Const (e,a : Type) where
     constructor MkConst
     value : e
   ```

5. 这是用于描述数据存储中的 CRUD 操作（创建、读取、更新和删除）的求和类型：

   ```idris
   data Crud : (i : Type) -> (a : Type) -> Type where
     Create : (value : a) -> Crud i a
     Update : (id : i) -> (value : a) -> Crud i a
     Read   : (id : i) -> Crud i a
     Delete : (id : i) -> Crud i a
   ```

   为 `Crud i` 实现 `Functor`。

6. 以下是用于描述来自数据服务器的响应的和类型：

   ```idris
   data Response : (e, i, a : Type) -> Type where
     Created : (id : i) -> (value : a) -> Response e i a
     Updated : (id : i) -> (value : a) -> Response e i a
     Found   : (values : List a) -> Response e i a
     Deleted : (id : i) -> Response e i a
     Error   : (err : e) -> Response e i a
   ```

   为 `Repsonse e i` 实现 `Functor`。

7. 为 `Validated e` 实现 `Functor`：

   ```idris
   data Validated : (e,a : Type) -> Type where
     Invalid : (err : e) -> Validated e a
     Valid   : (val : a) -> Validated e a
   ```

## 应用子

虽然 `Functor` 允许我们将纯的一元函数映射到上下文中的值上，但它不允许我们在 n 元函数下组合 n 个这样的值。

例如，考虑以下函数：

```idris
liftMaybe2 : (a -> b -> c) -> Maybe a -> Maybe b -> Maybe c
liftMaybe2 f (Just va) (Just vb) = Just $ f va vb
liftMaybe2 _ _         _         = Nothing

liftVect2 : (a -> b -> c) -> Vect n a -> Vect n b -> Vect n c
liftVect2 _ []        []        = []
liftVect2 f (x :: xs) (y :: ys) = f x y :: liftVect2 f xs ys

liftIO2 : (a -> b -> c) -> IO a -> IO b -> IO c
liftIO2 f ioa iob = fromPrim $ go (toPrim ioa) (toPrim iob)
  where go : PrimIO a -> PrimIO b -> PrimIO c
        go pa pb w =
          let MkIORes va w2 = pa w
              MkIORes vb w3 = pb w2
           in MkIORes (f va vb) w3
```

`Functor` 没有涵盖这种行为，但这是很常见的事情。例如，我们可能想从标准输入中读取两个数字（这两个操作都可能失败），计算两者的乘积。这是代码：

```idris
multNumbers : Num a => Neg a => IO (Maybe a)
multNumbers = do
  s1 <- getLine
  s2 <- getLine
  pure $ liftMaybe2 (*) (parseInteger s1) (parseInteger s2)
```

它不会止步于此。对于三元函数，我们可能还希望有 `liftMaybe3` 和三个 `Maybe` 参数等等，对于任意数量的参数。

但还有更多：我们还想将纯的值提升到所讨论的上下文中。有了这个，我们可以做以下事情：

```idris
liftMaybe3 : (a -> b -> c -> d) -> Maybe a -> Maybe b -> Maybe c -> Maybe d
liftMaybe3 f (Just va) (Just vb) (Just vc) = Just $ f va vb vc
liftMaybe3 _ _         _         _         = Nothing

pureMaybe : a -> Maybe a
pureMaybe = Just

multAdd100 : Num a => Neg a => String -> String -> Maybe a
multAdd100 s t = liftMaybe3 calc (parseInteger s) (parseInteger t) (pure 100)
  where calc : a -> a -> a -> a
        calc x y z = x * y + z
```

正如您当然已经知道的那样，我现在将提供一个新接口来封装这种行为。它被称为 `Applicative`。这是它的定义和示例实现：

```idris
interface Functor' f => Applicative' f where
  app   : f (a -> b) -> f a -> f b
  pure' : a -> f a

implementation Applicative' Maybe where
  app (Just fun) (Just val) = Just $ fun val
  app _          _          = Nothing

  pure' = Just
```

接口 `Applicative` 当然已经由 *Prelude* 导出。在那里，函数 `app` 是一个有时称为 *app* 或 *apply* 的运算符：`(<*>)`。

您可能想知道，像 `liftMaybe2` 或 `liftIO3` 这样的函数如何与运算符 *apply* 相关联。让我演示一下：

```idris
liftA2 : Applicative f => (a -> b -> c) -> f a -> f b -> f c
liftA2 fun fa fb = pure fun <*> fa <*> fb

liftA3 : Applicative f => (a -> b -> c -> d) -> f a -> f b -> f c -> f d
liftA3 fun fa fb fc = pure fun <*> fa <*> fb <*> fc
```

了解这里发生的事情对您来说非常重要，所以让我们分解这些内容。如果我们将 `liftA2` 中的 `f` 用于 `Maybe`，则 `pure fun` 的类型为 `Maybe (a -> b -> c)`。同样，`pure fun <*> fa` 是 ` 类型为 `Maybe  (b -> c)`，因为 `(<*>)` 将应用存储在 `f a` 到存储在 `pure fun` 中的函数（柯里化！）。

你会经常看到 *apply* 这样的应用链，*applies* 的数量对应于我们提升的函数的数量。您有时还会看到以下内容，这使我们可以放弃对 `pure` 的初始调用，并改用 `map` 的运算符版本：

```idris
liftA2' : Applicative f => (a -> b -> c) -> f a -> f b -> f c
liftA2' fun fa fb = fun <$> fa <*> fb

liftA3' : Applicative f => (a -> b -> c -> d) -> f a -> f b -> f c -> f d
liftA3' fun fa fb fc = fun <$> fa <*> fb <*> fc
```

因此，接口 `Applicative` 允许我们将值（和函数！）提升到计算上下文中，并将它们应用于相同上下文中的值。在我们将看到一个扩展示例为什么这很有用之前，我将快速介绍一些用于使用应用函子的语法糖。

### 习语括号

用于实现 `liftA2'` 和 `liftA3'` 的编程风格也称为 *applicative 风格*，在 Haskell 中被大量用于将几个有效的计算与单一的纯函数。

在 Idris 中，有一个替代使用这种运算符应用程序链的方法：习语括号。这是 `liftA2` 和 `liftA3` 的另一个重新实现：

```idris
liftA2'' : Applicative f => (a -> b -> c) -> f a -> f b -> f c
liftA2'' fun fa fb = [| fun fa fb |]

liftA3'' : Applicative f => (a -> b -> c -> d) -> f a -> f b -> f c -> f d
liftA3'' fun fa fb fc = [| fun fa fb fc |]
```

在消除歧义、类型检查和填充隐式值 *之前*，上述实现将被简化为 `liftA2` 和 `liftA3` 给定的实现。与 *bind* 运算符一样，我们因此可以为 `pure` 和 `(<*>)` 编写自定义实现，如果 Idris 可以消除重载函数名称之间的歧义，它将使用这些名称。。

### 用例：CSV 阅读器

为了理解应用函子的强大功能和多功能性，我们将看一个稍微扩展的示例。我们将编写一些实用程序来解析和解码 CSV 文件中的内容。这些文件的每一行都包含一个由逗号（或其他分隔符）分隔的值列表。通常，它们用于存储表格数据，例如来自电子表格应用程序的数据。我们想要做的是转换 CSV 文件中的行并将结果存储在自定义记录中，其中每个记录字段对应于表中的一列。

例如，这是一个简单的示例文件，其中包含来自网络商店的表格用户信息：名字、姓氏、年龄（可选）、电子邮件地址、性别和密码。

```repl
Jon,Doe,42,jon@doe.ch,m,weijr332sdk
Jane,Doe,,jane@doe.ch,f,aa433sd112
Stefan,Hoeck,,nope@goaway.ch,m,password123
```

以下是在运行时保存此信息所必需的 Idris 数据类型。我们再次使用自定义字符串包装器来提高类型安全性，因为它允许我们为每种数据类型定义我们认为是有效输入的内容：

```idris
data Gender = Male | Female | Other

record Name where
  constructor MkName
  value : String

record Email where
  constructor MkEmail
  value : String

record Password where
  constructor MkPassword
  value : String

record User where
  constructor MkUser
  firstName : Name
  lastName  : Name
  age       : Maybe Nat
  email     : Email
  gender    : Gender
  password  : Password
```

我们首先定义一个用于读取 CSV 文件中的字段的接口，并为我们想要读取的数据类型编写实现：

```idris
interface CSVField a where
  read : String -> Maybe a
```

下面是 `Gender` 和 `Bool` 的实现。在这些情况下，我决定使用单个小写字符对每个值进行编码：

```idris
CSVField Gender where
  read "m" = Just Male
  read "f" = Just Female
  read "o" = Just Other
  read _   = Nothing

CSVField Bool where
  read "t" = Just True
  read "f" = Just False
  read _   = Nothing
```

对于数值类型，我们可以使用 `Data.String` 中的解析函数：

```idris
CSVField Nat where
  read = parsePositive

CSVField Integer where
  read = parseInteger

CSVField Double where
  read = parseDouble
```

对于可选值，存储的类型本身必须带有 `CSVField` 的实例。然后我们可以将空字符串 `""` 视为 `Nothing`，而将非空字符串传递给封装类型的字段读取器。 （记住 `(<$>)` 是 `map` 的别名。）

```idris
CSVField a => CSVField (Maybe a) where
  read "" = Just Nothing
  read s  = Just <$> read s
```

最后，对于我们的字符串包装器，我们需要决定我们认为什么是有效值。为简单起见，我决定限制允许的字符串长度和有效字符集。

```idris
readIf : (String -> Bool) -> (String -> a) -> String -> Maybe a
readIf p mk s = if p s then Just (mk s) else Nothing

isValidName : String -> Bool
isValidName s =
  let len = length s
   in 0 < len && len <= 100 && all isAlpha (unpack s)

CSVField Name where
  read = readIf isValidName MkName

isEmailChar : Char -> Bool
isEmailChar '.' = True
isEmailChar '@' = True
isEmailChar c   = isAlphaNum c

isValidEmail : String -> Bool
isValidEmail s =
  let len = length s
   in 0 < len && len <= 100 && all isEmailChar (unpack s)

CSVField Email where
  read = readIf isValidEmail MkEmail

isPasswordChar : Char -> Bool
isPasswordChar ' ' = True
isPasswordChar c   = not (isControl c) && not (isSpace c)

isValidPassword : String -> Bool
isValidPassword s =
  let len = length s
   in 8 < len && len <= 100 && all isPasswordChar (unpack s)

CSVField Password where
  read = readIf isValidPassword MkPassword
```

在后面的章节中，我们将学习细化类型以及如何将已擦除的有效性证明与验证值一起存储。

我们现在可以开始解码 CSV 文件中的整行。为了做到这一点，我们首先引入一个自定义错误类型来封装事情是如何出错的：

```idris
data CSVError : Type where
  FieldError           : (line, column : Nat) -> (str : String) -> CSVError
  UnexpectedEndOfInput : (line, column : Nat) -> CSVError
  ExpectedEndOfInput   : (line, column : Nat) -> CSVError
```

我们现在可以使用 `CSVField` 读取 CSV 文件中给定行和位置的单个字段，并在失败的情况下返回 `FieldError`。

```idris
readField : CSVField a => (line, column : Nat) -> String -> Either CSVError a
readField line col str =
  maybe (Left $ FieldError line col str) Right (read str)
```

如果我们事先知道需要读取的字段数量，我们可以尝试将字符串列表转换为给定长度的 `Vect`。这有助于读取已知数量字段的记录值，因为我们在向量上进行模式匹配时得到正确数量的字符串变量：

```idris
toVect : (n : Nat) -> (line, col : Nat) -> List a -> Either CSVError (Vect n a)
toVect 0     line _   []        = Right []
toVect 0     line col _         = Left (ExpectedEndOfInput line col)
toVect (S k) line col []        = Left (UnexpectedEndOfInput line col)
toVect (S k) line col (x :: xs) = (x ::) <$> toVect k line (S col) xs
```

最后，我们可以实现函数 `readUser` 来尝试将 CSV 文件中的一行转换为 `User` 类型的值：

```idris
readUser' : (line : Nat) -> List String -> Either CSVError User
readUser' line ss = do
  [fn,ln,a,em,g,pw] <- toVect 6 line 0 ss
  [| MkUser (readField line 1 fn)
            (readField line 2 ln)
            (readField line 3 a)
            (readField line 4 em)
            (readField line 5 g)
            (readField line 6 pw) |]

readUser : (line : Nat) -> String -> Either CSVError User
readUser line = readUser' line . forget . split (',' ==)
```

让我们在 REPL 上试一试：

```repl
Tutorial.Functor> readUser 1 "Joe,Foo,46,j@f.ch,m,pw1234567"
Right (MkUser (MkName "Joe") (MkName "Foo")
  (Just 46) (MkEmail "j@f.ch") Male (MkPassword "pw1234567"))
Tutorial.Functor> readUser 7 "Joe,Foo,46,j@f.ch,m,shortPW"
Left (FieldError 7 6 "shortPW")
```

请注意，在 `readUser'` 的实现中，我们如何使用习语括号将六个参数 (`MkUser`) 的函数映射到 `Either CSVError` 类型的六个值上。当且仅当所有解析都成功时，这将自动成功。众所周知，使用连续六个嵌套模式匹配来实现 `readUser'` 的代码的可读性会大大降低。

但是，上面的习语括号看起来仍然非常重复。当然，我们可以做得更好吗？

#### 异构列表的案例

是时候学习一组类型了，它们可以用作记录类型的通用表示，并且允许我们用最少的代码表示和读取异构表中的行：异构列表。

```idris
namespace HList
  public export
  data HList : (ts : List Type) -> Type where
    Nil  : HList Nil
    (::) : (v : t) -> (vs : HList ts) -> HList (t :: ts)
```

异构列表是在 *类型列表* 上索引的列表类型。这允许我们在每个位置将类型的值存储在列表索引中的相同位置。例如，这里有一个变体，它存储了 `Bool`、`Nat` 和 `Maybe String` 类型的三个值（按此顺序）：

```idris
hlist1 : HList [Bool, Nat, Maybe String]
hlist1 = [True, 12, Nothing]
```

您可能会争辩说，异构列表只是存储给定类型值的元组。没错，当然，但是，因为您将在练习中学习困难的方法，我们可以使用列表索引对 `HList` 执行编译时计算，例如连接两个这样的列表以保持同时跟踪结果中存储的类型。

但首先，我们将使用 `HList` 作为简洁解析 CSV 行的方法。为此，我们需要为对应于 CSV 文件中整行的类型引入一个新接口：

```idris
interface CSVLine a where
  decodeAt : (line, col : Nat) -> List String -> Either CSVError a
```

现在，我们将为 `HList` 编写 `CSVLine` 的两个实现：一个针对 `Nil` 的情况，当且仅当当前字符串列表为空时才会成功.另一个用于 *cons* 的情况，它将尝试从列表的头部读取单个字段，并从其尾部读取剩余部分。我们再次使用惯用括号来连接结果：

```idris
CSVLine (HList []) where
  decodeAt _ _ [] = Right Nil
  decodeAt l c _  = Left (ExpectedEndOfInput l c)

CSVField t => CSVLine (HList ts) => CSVLine (HList (t :: ts)) where
  decodeAt l c []        = Left (UnexpectedEndOfInput l c)
  decodeAt l c (s :: ss) = [| readField l c s :: decodeAt l (S c) ss |]
```

就是这样！我们需要添加的是两个实用函数，用于在将整行拆分为标记之前对其进行解码，其中一个专用于 `HList` 并将已擦除的类型列表作为参数，以使其更方便使用在 REPL：

```idris
decode : CSVLine a => (line : Nat) -> String -> Either CSVError a
decode line = decodeAt line 1 . forget . split (',' ==)

hdecode :  (0 ts : List Type)
        -> CSVLine (HList ts)
        => (line : Nat)
        -> String
        -> Either CSVError (HList ts)
hdecode _ = decode
```

是时候收获我们的劳动成果并在 REPL 上试一试了：

```repl
Tutorial.Functor> hdecode [Bool,Nat,Double] 1 "f,100,12.123"
Right [False, 100, 12.123]
Tutorial.Functor> hdecode [Name,Name,Gender] 3 "Idris,,f"
Left (FieldError 3 2 "")
```

### 应用函子法律

同样，`Applicative` 的实现必须遵循一定的规律。他们来了：

* `pure id <*> fa = fa`：提升和应用恒等函数没有可见作用。

* `[| F 。 g |] <*> v = f <*> (g <*> v)`：不管是先组合函数然后应用它们，还是先应用函数然后组合它们，结果应该相同。

  上面的可能很难理解，所以这里
  它们再次具有显式类型和实现：

  ```idris
  compL : Maybe (b -> c) -> Maybe (a -> b) -> Maybe a -> Maybe c
  compL f g v = [| f . g |] <*> v

  compR : Maybe (b -> c) -> Maybe (a -> b) -> Maybe a -> Maybe c
  compR f g v = f <*> (g <*> v)
  ```

  第二个应用函子法律规定，这两个实施
  `compL` 和 `compR` 的行为应该相同。

* `pure f <*> pure x = pure (f x)`。这也称为 *同态* 定律。这应该是不言自明的。

* `f <*> pure v = pure ($ v) <*> f`.。这称为*交换* 律。

  这应该再次用一个具体的例子来解释：

  ```idris
  interL : Maybe (a -> b) -> a -> Maybe b
  interL f v = f <*> pure v

  interR : Maybe (a -> b) -> a -> Maybe b
  interR f v = pure ($ v) <*> f
  ```

  注意，`($ v)` 的类型是 `(a -> b) -> b`，所以这个
  是应用于 `f` 的函数类型，它有一个
  `a -> b` 类型的函数，被包裹在 `Maybe` 上下文中。

  交换律指出， 我们是从左边应用一个纯值还是 *apply* 运算符的右侧。它必须无关紧要

### 练习第 2 部分

1. 为 `Either e` 和 `Identity` 实现 `Applicative'`。

2. 为 `Vect n` 实现 `Applicative'`。注意：为了实现
   `pure`，必须在运行时知道长度。这可以通过将其作为未擦除的隐式传递给接口实现来完成：

   ```idris
   implementation {n : _} -> Applicative' (Vect n) where
   ```

3. 为 `Pair e` 实现 `Applicative'`，其中 `e` 具有 `Monoid` 约束。

4. 为 `Const e` 实现 `Applicative`，其中 `e` 具有 `Monoid` 约束。

5. 为 `Validated e` 实现 `Applicative`，其中 `e` 具有 `Semigroup` 约束。这将允许我们在 *apply*
   的实现中使用 `(<+>)` 来累积两个 `Invalid` 值的错误。

6. 添加一个 `CSVError -> CSVError -> CSVError` 到 `CSVError` 类型的附加数据构造函数，并使用它为
   `CSVError` 实现 `Semigroup`。

7. 重构我们的 CSV 解析器和所有相关函数，使它们返回 `Validated` 而不是 `Either`。这只有在你解决了练习 6 的情况下才有效。

   需要注意的两件事：您将不得不调整很少的
   现有代码，因为我们仍然可以通过使用 `Validated`使用应用语法
   。此外，通过此更改，我们增强了 CSV 解析器
   具有累积误差的能力。这里有些来自 REPL 会话的例子：

   ```repl
   Solutions.Functor> hdecode [Bool,Nat,Gender] 1 "t,12,f"
   Valid [True, 12, Female]
   Solutions.Functor> hdecode [Bool,Nat,Gender] 1 "o,-12,f"
   Invalid (App (FieldError 1 1 "o") (FieldError 1 2 "-12"))
   Solutions.Functor> hdecode [Bool,Nat,Gender] 1 "o,-12,foo"
   Invalid (App (FieldError 1 1 "o")
     (App (FieldError 1 2 "-12") (FieldError 1 3 "foo")))
   ```

   看看应用函子和异构列表的力量：
   仅仅几行代码，我们就编写了一个纯粹的、类型安全的、完全的
   对 CSV 文件中的行进行错误累积的解析器，同时使用非常方便！

8. 由于我们在本章中介绍了异构列表，很遗憾没有对它们进行一些实验。

   这个练习旨在提高你的类型技巧的技能。
   因此，它带有很少的提示。您期望从给定函数中获得什么行为试着自己做决定
   ，这在类型中如何表达，以及之后如何实现它。
   如果您的类型足够正确和精确，那么实现
   几乎是轻而易举的。如果遇到困难，不要过早放弃。
   只有当你真的没有想法时，你才应该瞥一眼
   在解决方案上（然后，首先只在类型上！）

   1. 为 `HList` 实现 `head`。

   2. 为 `HList` 实现 `tail`。

   3. 为 `HList` 实现 `(++)`。

   4. 为 `HList` 实现 `index`。这可能比其他三个更难。回过头来看看我们如何在 [早期练习](Dependent.md) 中实现
      `indexList` 并从那里开始。

   5. 包 *contrib* 是 Idris 项目的一部分，它提供了 `Data.HVect.HVect`，一种异构向量的数据类型。与我们自己的
      `HList` 的唯一区别是，`HVect` 是通过类型向量而不是类型列表来索引的。这使得在类型级别表达某些操作变得更容易。

      编写您自己的 `HVect` 实现以及函数
      `head`、`tail`、`(++)` 和 `index`。

   6. 对于真正的挑战，尝试实现一个函数来转置 `Vect m (HVect ts)`。您首先必须对如何在类型中表达这一点有创意。

      注意：为了实现这一点，您需要在至少一个案例中的一个被抹去的参数上进行模式匹配，以帮助 Idris 进行类型推断。禁止对已擦除参数进行模式匹配
      （它们毕竟被删除了，所以我们不能在运行时检查它们），
      *除非* 可以通过另一个未被抹去的参数推导出被匹配的值的结构。

      另外，如果您卡在这个上，请不要担心。我花了好几次才试图把他弄清楚。但是我很享受这种体验，所以我 *必须* 把它包括在这里。 :-)

      但是请注意，当使用 CSV 文件时这样的函数会很有用，因为它允许我们将表示为行（元组向量）的表转换到表示为列（向量元组）的表。

9. 通过为 `Comp f g` 实现 `Applicative` 来证明两个应用函子的组合再次是一个应用函子。

10. 通过为 `Prod f g` 实现 `Applicative` 证明两个应用函子的乘积再次是一个应用函子。

## 单子

最后，`Monad`。关于这一点已经泼了很多墨水。然而，在我们已经在 [关于 `IO`](IO.md) 的章节中看到之后，这里就没有太多要讨论的内容了。`Monad` 扩展了 `Applicative` 并添加了两个新的相关函数：*bind* 运算符 (`(>>=)`) 和函数 `join `。这是它的定义：

```idris
interface Applicative' m => Monad' m where
  bind  : m a -> (a -> m b) -> m b
  join' : m (m a) -> m a
```

`Monad` 的实现者可以自由选择实现 `(>>=)` 或 `join` 或两者。您将在练习中展示如何根据 *bind* 来实现 `join`，反之亦然。

`Monad` 和 `Applicative` 之间的最大区别在于，前者允许计算依赖于早期计算的结果。例如，我们可以根据从标准输入中读取的字符串来决定是删除文件还是播放歌曲。第一个 `IO` 动作（读取一些用户输入）的结果将影响下一个要运行的 `IO` 动作。这对于 *apply* 运算符是不可能的：

```repl
```repl (<*>) : IO (a -> b) -> IO a -> IO b ```
```

两个 `IO` 动作在作为参数传递给 `(<*>)` 时已经确定。在一般情况下，第一个结果不能影响在第二个中运行哪个计算。 （实际上，使用 `IO` 理论上可以通过副作用实现：第一个操作可以将某些命令写入文件或覆盖某些可变状态，而第二个操作可以从该文件或状态读取，从而决定接下来要做的事情。但这是 `IO` 的特长，而不是一般的应用函子。如果有问题的函子是 `Maybe`，`List`，或 `Vector`，这是不可能的。）

让我们用一个例子来演示一下区别。假设我们想增强我们的 CSV 阅读器，使其能够将一行标记解码为和型。例如，我们想从 CSV 文件的行中解码 CRUD 请求：

```idris
data Crud : (i : Type) -> (a : Type) -> Type where
  Create : (value : a) -> Crud i a
  Update : (id : i) -> (value : a) -> Crud i a
  Read   : (id : i) -> Crud i a
  Delete : (id : i) -> Crud i a
```

我们需要一种方法来在每一行上决定为我们的解码选择哪个数据构造函数。一种方法是将数据构造函数的名称（或其他标识标签）放在 CSV 文件的第一列中：

```idris
hlift : (a -> b) -> HList [a] -> b
hlift f [x] = f x

hlift2 : (a -> b -> c) -> HList [a,b] -> c
hlift2 f [x,y] = f x y

decodeCRUD :  CSVField i
           => CSVField a
           => (line : Nat)
           -> (s    : String)
           -> Either CSVError (Crud i a)
decodeCRUD l s =
  let h ::: t = split (',' ==) s
   in do
     MkName n <- readField l 1 h
     case n of
       "Create" => hlift  Create  <$> decodeAt l 2 t
       "Update" => hlift2 Update  <$> decodeAt l 2 t
       "Read"   => hlift  Read    <$> decodeAt l 2 t
       "Delete" => hlift  Delete  <$> decodeAt l 2 t
       _        => Left (FieldError l 1 n)
```

我添加了两个实用函数来帮助进行类型推断并获得更好的语法。需要注意的重要一点是，我们如何对第一个解析函数的结果进行模式匹配，以决定数据构造函数，从而决定下一个要使用的解析函数。

在 REPL 中看一下工作原理：

```repl
Tutorial.Functor> decodeCRUD {i = Nat} {a = Email} 1 "Create,jon@doe.ch"
Right (Create (MkEmail "jon@doe.ch"))
Tutorial.Functor> decodeCRUD {i = Nat} {a = Email} 1 "Update,12,jane@doe.ch"
Right (Update 12 (MkEmail "jane@doe.ch"))
Tutorial.Functor> decodeCRUD {i = Nat} {a = Email} 1 "Delete,jon@doe.ch"
Left (FieldError 1 2 "jon@doe.ch")
```

总而言之，`Monad` 与 `Applicative` 不同，它允许我们按顺序链接计算，其中中间结果会影响后续计算的行为。因此，如果您有 n 个不相关的有效计算并希望将它们组合在一个纯 n 元函数下，`Applicative` 就足够了。但是，如果您想根据有效计算的结果来决定接下来要运行什么计算，则需要 `Monad`。

但是请注意，与 `Applicative` 相比，`Monad` 有一个重要的缺点：通常，monad 不能组合。例如， `Either e . IO` 没有 `Monad` 实例。稍后我们将了解可以与其他 monad 组合的 monad 转换器。

### 单子定律

事不宜迟，以下是 `Monad` 的定律：

* `ma >>= pure = ma` 和 `pure v >>= f = f v`。这些是 monad 的恒等律。下面是具体的例子：

  ```idris
  id1L : Maybe a -> Maybe a
  id1L ma = ma >>= pure

  id2L : a -> (a -> Maybe b) -> Maybe b
  id2L v f = pure v >>= f

  id2R : a -> (a -> Maybe b) -> Maybe b
  id2R v f = f v
  ```

  这两条定律规定 `pure` 在 *bind* 中应该表现为中立。

* (m >>= f) >>= g = m >>= (f >=> g) 这是 monad 的结合律。您可能没有见过第二个运算符
  `(>=>)`。它可用于对有效计算进行排序，并具有以下类型：

  ```repl
  Tutorial.Functor> :t (>=>)
  Prelude.>=> : Monad m => (a -> m b) -> (b -> m c) -> a -> m c
  ```

以上是 *官方的* monad 定律。但是，我们需要考虑第三个，因为在 Idris（和 Haskell）中，`Monad` 扩展自 `Applicative`: 由于 `(<*>)` 可以由 `(>>=)` 实现，`(<*>)` 的实际实现必须与 `(>>=)` 的实现表现相同：

* `mf <*> ma = mf >>= (\fun => map (fun $) ma)`.

### 练习第 3 部分

1. `Applicative` 扩展了 `Functor`，因为每个 `Applicative` 也是一个 `Functor`。通过根据 `pure`
   和 `(<*>)` 实现 `map` 来证明这一点。

2. `Monad` 扩展了 `Applicative`，因为每个 `Monad` 也是一个 `Applicative`。通过根据 `(>>=)` 和
   `pure` 实现 `(<*>)` 来证明这一点。

3. 根据 `join` 和 `Monad` 层次结构中的其他函数实现 `(>>=)`。

4. 根据 `(>>=)` 和 `Monad` 层次结构中的其他函数实现 `join`。

5. `Validated e` 没有合法的 `Monad` 实现。为什么？

6. 在这个稍微扩展的练习中，我们将在数据存储上模拟 CRUD 操作。我们将使用一个可变引用（从 *base* 库中的 `Data.IORef`
   导入），其中包含一个 `User` 列表和一个类型为 `Nat` 的唯一 ID 作为我们的用户数据库：

   ```idris
   DB : Type
   DB = IORef (List (Nat,User))
   ```

   数据库上的大多数操作都有失败的风险：
   当我们尝试更新或删除用户时，有问题的条目
   可能不再存在。当我们添加一个新用户时，一个用户
   与给定的电子邮件地址可能已经存在。这是
   处理此问题的自定义错误类型：

   ```idris
   data DBError : Type where
     UserExists        : Email -> Nat -> DBError
     UserNotFound      : Nat -> DBError
     SizeLimitExceeded : DBError
   ```

   一般来说，我们的函数因此会有一个
   类似于以下内容的类型：

   ```idris
   someDBProg : arg1 -> arg2 -> DB -> IO (Either DBError a)
   ```

   我们想通过引入一个新的包装器来抽象这个
   类型：

   ```idris
   record Prog a where
     constructor MkProg
     runProg : DB -> IO (Either DBError a)
   ```

   我们现在准备为我们编写一些实用函数。确保
   在实施时遵循以下业务规则
   以下功能：

   * 数据库中的电子邮件地址必须是唯一的。 （考虑实现 `Eq Email` 来验证这一点）。

   * 不得超过 1000 个条目的大小限制。

   * 如果在 DB 中找不到条目，则尝试通过 ID 查找用户的操作必须失败并显示 `UserNotFound`。

   工作时需要 `Data.IORef` 中的以下功能
   具有可变引用：`newIORef`、`readIORef` 和 `writeIORef`。
   此外，函数 `Data.List.lookup` 和 `Data.List.find` 可能
   对实现以下某些功能很有用。

   1. 为 `Prog` 实现接口 `Functor`、`Applicative` 和 `Monad`。

   2. 为 `Prog` 实现接口 `HasIO`。

   3. 实现以下实用功能：

      ```idris
      throw : DBError -> Prog a

      getUsers : Prog (List (Nat,User))

      -- check the size limit!
      putUsers : List (Nat,User) -> Prog ()

      -- implement this in terms of `getUsers` and `putUsers`
      modifyDB : (List (Nat,User) -> List (Nat,User)) -> Prog ()
      ```

   4. 实现函数`lookupUser`。如果找不到具有给定 ID 的用户，这应该会失败并出现适当的错误。

      ```idris
      lookupUser : (id : Nat) -> Prog User
      ```

   5. 实现函数 `deleteUser`。如果找不到具有给定 ID 的用户，这应该会失败并出现适当的错误。在您的实现中使用
      `lookupUser`。

      ```idris
      deleteUser : (id : Nat) -> Prog ()
      ```

   6. 实现函数 `addUser`。如果具有给定 `Email` 的用户已经存在，或者超过了 1000
      个条目的数据库大小限制，这应该会失败。此外，这应该为新用户条目创建并返回一个唯一 ID。

      ```idris
      addUser : (new : User) -> Prog Nat
      ```

   7. 实现函数`updateUser`。如果找不到相关用户或更新用户的 `Email` 的用户已经存在，这应该会失败。返回的值应该是更新的用户。

      ```idris
      updateUser : (id : Nat) -> (mod : User -> User) -> Prog User
      ```

   8. 数据类型 `Prog` 实际上太具体了。我们也可以抽象出错误类型和 `DB` 环境：

      ```idris
      record Prog' env err a where
        constructor MkProg
        runProg' : env -> IO (Either err a)
      ```

      验证您编写的所有接口实现
      对于 `Prog` 可以逐字使用来实现相同的
      `Prog' env err` 的接口。这同样适用于
      `throw` 只需稍微调整函数的
      类型。

## 背景和延伸阅读

*functor* 和 *monad* 等概念起源于数学分支 *范畴论*。这也是他们的定律的来源。范畴理论被发现在程序设计语言理论，特别是函数式程序设计中有应用。这是一个高度抽象的主题，但有一个非常容易理解的程序员介绍，由 [Bartosz Milewski](https://bartoszmilewski.com/2014/10/28/category-theory-for-programmers-the-preface/ ）。

应用函子作为函子和单子之间的中间地带的有用性是在单子已经在 Haskell 中使用几年之后才发现的。它们在文章 [*Applicative Programming with Effects*](https://www.staff.city.ac.uk/~ross/papers/Applicative.html) 中进行了介绍，该文章可在线免费获得，并且强烈推荐阅读。

## 结论

* 接口 `Functor`、`Applicative` 和 `Monad` 抽象了使用 `Type -> Type`
  类型的类型构造函数时出现的编程模式。此类数据类型也称为上下文中的 *值 *，或 * 有效计算 *。

* `Functor` 允许我们在上下文中的值上 *map* 而不影响上下文的底层结构。

* `Applicative` 允许我们将 n 元函数应用于 n 个有效计算，并将纯值提升到上下文中。

* `Monad` 允许我们链接有效的计算，其中中间结果可能会影响，哪些计算在链中运行得更远。

* 与 `Monad` 不同，`Functor` 和 `Applicative` 组合：两个函子或应用程序的乘积和组合再次分别是函子或应用程序。

* Idris 为使用此处介绍的一些接口提供了语法糖：`Applicative`、*do blocks* 的习语括号和 `Monad` 的感叹号运算符。

### 下一步是什么？

在[下一章](Folds.md) 中，我们将了解更多关于递归、完全性检查和折叠容器类型的接口：`Foldable`。

<!-- vi: filetype=idris2
-->
