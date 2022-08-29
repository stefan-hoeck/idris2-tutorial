# 谓词和证明搜索

在[上一章](Eq.md)中，我们了解了命题相等式，这使我们能够证明两个值相等。相等是值之间的关系，我们使用索引数据类型通过限制唯一数据构造函数中索引的自由度来编码这种关系。我们可以用这种方式编码其他关系和契约。这将允许我们限制我们接受作为函数参数的值或函数返回的值。

```idris
module Tutorial.Predicates

import Data.Either
import Data.List1
import Data.String
import Data.Vect
import Data.HList
import Decidable.Equality

import Text.CSV
import System.File

%default total
```

## 前置条件

通常，当我们实现对给定类型的值进行操作的函数时，并非所有值都被认为是所讨论函数的有效参数。例如，我们通常不允许除以零，因为在一般情况下结果是未定义的。这种将 *前置条件* 放在函数参数上的概念经常出现，并且有几种方法可以解决这个问题。

使用列表或其他容器类型时，一个非常常见的操作是提取序列中的第一个值。然而，这个函数不能在一般情况下工作，因为为了从列表中提取值，列表不能为空。这里有几种编码和实现它的方法，每种方法都有自己的优点和缺点：

* 将结果包装在故障类型中，例如 `Maybe` 或带有一些自定义错误类型 `e` 的 `Either
  e`。这立即清楚地表明该函数可能无法返回结果。这是处理来自未知来源的未经验证的输入的自然方式。这种方法的缺点是结果会带有 `Maybe`
  污点，即使在我们 *知道 *不可能为 *nil* 的情况下，例如因为我们知道list 参数在编译时的值，或者因为我们已经 *改进了*
  输入值，以确保它不为空（例如，由于较早的模式匹配）。

* 为非空列表定义一个新的数据类型并将其用作函数的参数。这是在模块 `Data.List1`
  中采用的方法。它允许我们返回一个纯值（这里的意思是“不包含在失败类型中”），因为函数不可能失败，但它带来了重新实现我们已经为 `List`
  实现的许多实用函数和接口的负担。对于非常常见的数据结构，这可能是一个有效的选项，但对于罕见的用例，它通常太麻烦了。

* 使用索引来跟踪我们感兴趣的属性。这是我们对类型族 `List01`
  采用的方法，到目前为止，我们在本指南的几个示例和练习中看到了这种方法。这也是向量采用的方法，我们使用精确的长度作为索引，这样更有表现力。虽然这允许我们在类型级别以更高的精度实现许多函数，但它也带来了跟踪类型变化的负担，产生更复杂的函数类型并迫使我们有时返回存在量化的包装器（例如，依赖对），因为直到运行时才知道计算的结果。

* 失败并出现运行时异常。这是许多编程语言（甚至是 Haskell）中流行的解决方案，但在 Idris
  中我们尽量避免这种情况，因为它在某种程度上破坏了完全性，这也会影响客户端代码。幸运的是，我们可以利用我们强大的类型系统来避免这种情况。

* 取一个类型的附加（可能已删除）参数，我们可以将其用作输入值的类型或形状正确的见证。这是我们将在本章中详细讨论的解决方案。这是一种非常强大的方式来讨论对值的限制，而无需复制许多已经存在的功能。

Idris 中列出的大多数（如果不是全部）解决方案都有时间和地点，但我们经常会转向最后一个并使用谓词（所谓的 *前置条件*）优化函数参数，因为它使我们的函数在运行时 *和* 编译时更好用。

### 示例：非空列表

记住我们是如何实现命题相等的索引数据类型的：我们限制了构造函数中索引的有效值。我们可以对非空列表的谓词做同样的事情：

```idris
data NotNil : (as : List a) -> Type where
  IsNotNil : NotNil (h :: t)
```

这是一种单值数据类型，因此我们始终可以将其用作已擦除的函数参数并仍然对其进行模式匹配。我们现在可以使用它来实现一个安全且纯粹的 `head` 函数：

```idris
head1 : (as : List a) -> (0 _ : NotNil as) -> a
head1 (h :: _) _ = h
head1 [] IsNotNil impossible
```

请注意，值 `IsNotNil` 是 *witness* 的值，它对应于我们的列表参数，它的索引确实是非空的，因为这是我们在它的类型中指定的。 `head1` 实现中的不可能的情况在这里不是绝对必要的。上面给出的遵循完全性。

我们将 `NotNil` 称为列表上的 *谓词*，因为它限制了索引中允许的值。我们可以通过在函数的参数列表中添加额外的（可能被删除的）谓词来表达函数的前置条件。

第一个非常酷的事情是我们如何安全地使用 `head1`，如果我们可以在编译时显示我们的列表参数确实是非空的：

```idris
headEx1 : Nat
headEx1 = head1 [1,2,3] IsNotNil
```

我们必须手动通过 `IsNotNil` 证明有点麻烦。在我们解决这个问题之前，我们将首先讨论如何处理列表，其值直到运行时才知道。对于这些情况，我们必须通过检查运行时列表值来尝试以编程方式生成谓词的值。在最简单的情况下，我们可以将证明包装在 `Maybe` 中，但是如果我们可以证明我们的谓词是 *可判定的*，我们可以通过返回 `Dec` 来获得更强的保证：

```idris
Uninhabited (NotNil []) where
  uninhabited IsNotNil impossible

nonEmpty : (as : List a) -> Dec (NotNil as)
nonEmpty (x :: xs) = Yes IsNotNil
nonEmpty []        = No uninhabited
```

有了这个，我们可以实现函数 `headMaybe`，它可以用于未知来源的列表：

```idris
headMaybe1 : List a -> Maybe a
headMaybe1 as = case nonEmpty as of
  Yes prf => Just $ head1 as prf
  No  _   => Nothing
```

当然，对于像 `headMaybe` 这样的小函数，直接通过 list 参数上的模式匹配来实现它们更有意义，但是我们很快就会看到谓词的示例，其值创建起来更麻烦。

### 自动隐式

必须手动将非空证明传递给 `head1` 使得这个函数在编译时使用起来不必要地冗长。 Idris 允许我们定义隐式函数参数，它试图通过一种称为 *证明搜索* 的技术自行组装其值。这不要与类型推断混淆，类型推断意味着从周围的上下文推断值或类型。最好看一些例子来解释差异。

让我们首先看一下向量的 `replicate` 的以下实现：

```idris
replicate' : {n : _} -> a -> Vect n a
replicate' {n = 0}   _ = []
replicate' {n = S _} v = v :: replicate' v
```

函数 `replicate'` 采用未擦除的隐式参数。此参数的 *值* 必须可从周围的上下文中派生。例如，在下面的示例中，很明显 `n` 等于 3，因为这是我们想要的向量的长度：

```idris
replicateEx1 : Vect 3 Nat
replicateEx1 = replicate' 12
```

在下一个示例中，`n` 的值在编译时是未知的，但它可以作为未擦除的隐式使用，因此可以再次将其按原样传递给 `replicate'`：

```idris
replicateEx2 : {n : _} -> Vect n Nat
replicateEx2 = replicate' 12
```

但是，在以下示例中，无法推断 `n` 的值，因为中间向量会立即转换为未知长度的列表。尽管 Idris 可以尝试在这里为 `n` 插入任何值，但它不会这样做，因为它不能确定这是我们想要的长度。因此，我们必须明确地传递长度：

```idris
replicateEx3 : List Nat
replicateEx3 = toList $ replicate' {n = 17} 12
```

请注意，在这些示例中，`n` 的 *值* 必须是可推断的，这意味着它必须出现在周围的上下文中。使用自动隐式参数，这会有所不同。这是 `head` 示例，这次使用自动隐式：

```idris
head : (as : List a) -> {auto 0 prf : NotNil as} -> a
head (x :: _) = x
head [] impossible
```

注意隐式参数 `prf` 的数量之前的 `auto` 关键字。这意味着，我们希望 Idris 自己构造这个值，而不是在周围的上下文中可见。为此，Idris 必须在编译时知道列表参数 `as` 的结构。然后它将尝试从数据类型的构造函数中构建这样的值。如果成功，该值将自动填充为所需的参数，否则，Idris 将失败并出现类型错误。

让我们看看它的实际效果：

```idris
headEx3 : Nat
headEx3 = Predicates.head [1,2,3]
```

以下示例因错误而失败：

```idris
failing "Can't find an implementation\nfor NotNil []."
  errHead : Nat
  errHead = Predicates.head []
```

等待！ “找不到...的实现”？这不是我们因缺少接口实现而得到的错误消息吗？没错，我将在本章末尾向您展示接口解析只是证明搜索。我已经可以向您展示的是，一直编写冗长的 `{auto prf : t} ->` 可能很麻烦。因此，Idris 允许我们使用与约束函数相同的语法：`(prf : t) =>`，或者如果我们不需要命名约束甚至可以写成 `t =>`。像往常一样，我们可以通过名称（如果有的话）访问函数体中的约束。这是 `head` 的另一个实现：

```idris
head' : (as : List a) -> (0 _ : NotNil as) => a
head' (x :: _) = x
head' [] impossible
```

在证明搜索期间，Idris 还将在当前函数上下文中查找所需类型的值。这允许我们实现 `headMaybe` 而无需手动传递 `NotNil` 证明：

```idris
headMaybe : List a -> Maybe a
headMaybe as = case nonEmpty as of
  -- `prf` is available during proof seach
  Yes prf => Just $ Predicates.head as
  No  _   => Nothing
```

总结：谓词允许我们限制函数接受作为参数的值。在运行时，我们需要通过函数参数的模式匹配来构建这样的 *witnesses*。这些操作通常会失败。在编译时，我们可以让 Idris 尝试使用称为 *证明搜索* 的技术为我们构建这些值。这使我们能够同时使函数安全和方便地使用。

### 练习第 1 部分

在这些练习中，您必须使用自动隐式实现几个函数，以约束作为函数参数接受的值。结果应该是 *纯的*，也就是说，没有包裹在像 `Maybe` 这样的失败类型中。

1. 为列表实现 `tail`。

2. 为列表实现 `concat1` 和 `foldMap1`。这些应该像 `concat` 和 `foldMap` 一样工作，但对元素类型仅采用
   `Semigroup` 约束。

3. 实现用于返回列表中最大和最小元素的函数。

4. 为严格的正自然数定义一个谓词，并用它来实现一个安全且可证明的自然数全除函数。

5. 为非空 `Maybe` 定义一个谓词，并使用它安全地提取存储在 `Just` 中的值。通过实现相应的转换函数来证明这个谓词是可判定的。

6. 使用合适的谓词定义和实现从 `Left` 和 `Right` 安全地提取值的函数。再次证明这些谓词是可判定的。

您在这些练习中实现的谓词已经在 *base* 库中可用：`Data.List.NonEmpty`、`Data.Maybe.IsJust`、`Data。 Either.IsLeft`、`Data.Either.IsRight` 和 `Data.Nat.IsSucc`。

## 值之间的契约

到目前为止，我们看到的谓词限制了单一类型的值，但也可以定义谓词来描述可能不同类型的多个值之间的契约。

### `Elem` 谓词

假设我们想从异构列表中提取给定类型的值：

```idris
get' : (0 t : Type) -> HList ts -> t
```

这在一般情况下是行不通的：如果我们可以实现这一点，我们将立即获得无效证明：

```idris
voidAgain : Void
voidAgain = get' Void []
```

问题很明显：我们要提取值的类型必须是异构列表索引的元素。这是一个谓词，我们可以用它来表达：

```idris
data Elem : (elem : a) -> (as : List a) -> Type where
  Here  : Elem x (x :: xs)
  There : Elem x xs -> Elem x (y :: xs)
```

这是一个描述两个值之间的契约的谓词：一个 `a` 类型的值和一个 `a` 的列表。该谓词的值是该值是列表元素的见证。请注意，这是如何递归定义的：我们查找的值位于列表头部的情况由 `Here` 构造函数处理，其中相同的变量 (`x`) 是用于元素和列表的头部。值在列表中更深的情况由 `There` 构造函数处理。可以这样理解：如果 `x` 是 `xs` 的元素，那么 `x` 也是 `y :: xs` 的元素对于任何值 `y`。让我们写一些例子来感受一下：

```idris
MyList : List Nat
MyList = [1,3,7,8,4,12]

oneElemMyList : Elem 1 MyList
oneElemMyList = Here

sevenElemMyList : Elem 7 MyList
sevenElemMyList = There $ There Here
```

现在，`Elem` 只是索引到值列表的另一种方式。我们不使用受列表长度限制的 `Fin` 索引，而是使用可以在特定位置找到值的证明。

我们可以使用 `Elem` 谓词从所需类型的异构列表中提取值：

```idris
get : (0 t : Type) -> HList ts -> (prf : Elem t ts) => t
```

重要的是要注意在这种情况下不能删除自动隐式。这不再是单值数据类型，我们必须能够对这个值进行模式匹配，以便弄清楚我们的值在异构列表中存储多远：

```idris
get t (v :: vs) {prf = Here}    = v
get t (v :: vs) {prf = There p} = get t vs
get _ [] impossible
```

自己实现 `get` 可能很有启发性，使用右侧的孔查看 Idris 根据 `Elem` 谓词的值推断的值的上下文和类型。

让我们在 REPL 上试一试：

```repl
Tutorial.Predicates> get Nat ["foo", Just "bar", S Z]
1
Tutorial.Predicates> get Nat ["foo", Just "bar"]
Error: Can't find an implementation for Elem Nat [String, Maybe String].

(Interactive):1:1--1:28
 1 | get Nat ["foo", Just "bar"]
     ^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

通过这个例子，我们开始理解 *证明搜索* 的实际含义：给定一个值 `v` 和一个值列表 `vs`，Idris 试图找到一个 `v` 是 `vs` 中的元素的证明。现在，在我们继续之前，请注意证明搜索不是灵丹妙药。搜索算法具有合理限制的 *搜索深度*，如果超过此限制，搜索将失败。例如：

```idris
Tps : List Type
Tps = List.replicate 50 Nat ++ [Maybe String]

hlist : HList Tps
hlist = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        , Nothing ]
```

在 REPL 试一下：

```repl
Tutorial.Predicates> get (Maybe String) hlist
Error: Can't find an implementation for Elem (Maybe String) [Nat,...
```

如您所见，Idris 未能找到 `Maybe String` 是 `Tps` 的一个元素的证明。可以使用 `%auto_implicit_depth` 指令增加搜索深度，该指令将保留源文件的其余部分或直到设置为不同的值。默认值设置为 25。通常，不建议将其设置为太大的值，因为这会大大增加编译时间。

```idris
%auto_implicit_depth 100
aMaybe : Maybe String
aMaybe = get _ hlist

%auto_implicit_depth 25
```

### 用例：更好的模式

在关于 [sigma 类型](DPair.md) 的章节中，我们介绍了 CSV 文件的模式。这不是很好用，因为我们必须使用自然数来访问某个列。更糟糕的是，我们小型图书馆的用户也必须这样做。无法为每个列定义名称并按名称访问列。我们将改变这一点。这是此用例的编码：

```idris
data ColType = I64 | Str | Boolean | Float

IdrisType : ColType -> Type
IdrisType I64     = Int64
IdrisType Str     = String
IdrisType Boolean = Bool
IdrisType Float   = Double

record Column where
  constructor MkColumn
  name : String
  type : ColType

infixr 8 :>

(:>) : String -> ColType -> Column
(:>) = MkColumn

Schema : Type
Schema = List Column

Show ColType where
  show I64     = "I64"
  show Str     = "Str"
  show Boolean = "Boolean"
  show Float   = "Float"

Show Column where
  show (MkColumn n ct) = "\{n}:\{show ct}"

showSchema : Schema -> String
showSchema = concat . intersperse "," . map show
```

如您所见，在模式中，我们现在将列的类型与其名称配对。以下是保存公司员工信息的 CSV 文件的示例架构：

```idris
EmployeeSchema : Schema
EmployeeSchema = [ "firstName"  :> Str
                 , "lastName"   :> Str
                 , "email"      :> Str
                 , "age"        :> I64
                 , "salary"     :> Float
                 , "management" :> Boolean
                 ]
```

这样的模式当然可以再次从用户输入中读取，但我们将等到本章稍后再实现解析器。将这个新模式与 `HList` 一起使用会直接导致类型推断问题，因此我很快编写了一个自定义行类型：基于模式索引的异构列表。

```idris
data Row : Schema -> Type where
  Nil  : Row []

  (::) :  {0 name : String}
       -> {0 type : ColType}
       -> (v : IdrisType type)
       -> Row ss
       -> Row (name :> type :: ss)
```

在 *cons* 的签名中，我明确列出了已删除的隐式参数。这是一种很好的做法，否则 Idris 在客户端代码中使用此类数据构造函数时会经常发出阴影警告。

我们现在可以为代表员工的 CSV 行定义一个类型别名：

```idris
0 Employee : Type
Employee = Row EmployeeSchema

hock : Employee
hock = [ "Stefan", "HÃ¶ck", "hock@foo.com", 46, 5443.2, False ]
```

请注意，我如何给 `Employee` 一个定量 0。这意味着，我们只被允许在编译时使用这个函数，但绝不允许在运行时使用。这是一种确保我们的类型级函数和别名在构建应用程序时不会泄漏到可执行文件中的安全方法。我们可以在类型签名和计算其他擦除值时使用零数量的函数和值，但不能用于与运行时相关的计算。

我们现在想根据给定的名称访问一行中的值。为此，我们编写了一个自定义谓词，它可以证明具有给定名称的列是模式的一部分。现在，有一件重要的事情需要注意：在这个谓词中，我们包含一个索引，用于给定名称的列的 *类型*。我们需要这个，因为当我们按名称访问列时，我们需要一种方法来确定返回类型。但是在证明搜索期间，Idris 必须根据所讨论的列名和模式派生这种类型（否则，除非事先知道返回类型，否则证明搜索将失败）。因此，我们 *必须* 告诉 Idris，它不能将此类型包含在搜索条件列表中，否则它会在运行证明搜索之前尝试从上下文中推断列类型（使用类型推断）。这可以通过列出要在搜索中使用的索引来完成，如下所示：`[search name schema]`。

```idris
data InSchema :  (name    : String)
              -> (schema  : Schema)
              -> (colType : ColType)
              -> Type where
  [search name schema]
  IsHere  : InSchema n (n :> t :: ss) t
  IsThere : InSchema n ss t -> InSchema n (fld :: ss) t

Uninhabited (InSchema n [] c) where
  uninhabited IsHere impossible
  uninhabited (IsThere _) impossible
```

有了这个，我们现在可以根据列的名称访问给定列的值：

```idris
getAt :  {0 ss : Schema}
      -> (name : String)
      -> (row  : Row ss)
      -> (prf  : InSchema name ss c)
      => IdrisType c
getAt name (v :: vs) {prf = IsHere}    = v
getAt name (_ :: vs) {prf = IsThere p} = getAt name vs
```

下面是一个如何在编译时使用它的示例。请注意 Idris 为我们执行的工作量：首先证明 `firstName`、`lastName` 和 `age` 确实是 `Employee` 模式中的有效名称。从这些证明中，它会自动计算出对 `getAt` 的调用的返回类型，并从行中提取相应的值。所有这些都以可证明的完全性和类型安全的方式发生。

```idris
shoeck : String
shoeck =  getAt "firstName" hock
       ++ " "
       ++ getAt "lastName" hock
       ++ ": "
       ++ show (getAt "age" hock)
       ++ " years old."
```

为了在运行时指定列名，我们需要一种通过将列名与相关架构进行比较来计算 `InSchema` 类型值的方法。因为我们必须比较两个字符串值是否在命题上相等，所以我们在这里为 `String` 使用 `DecEq` 实现（Idris 为所有原语提供 `DecEq` 实现）。我们同时提取列类型并将其（作为依赖对）与 `InSchema` 证明配对：

```idris
inSchema : (ss : Schema) -> (n : String) -> Maybe (c ** InSchema n ss c)
inSchema []                    _ = Nothing
inSchema (MkColumn cn t :: xs) n = case decEq cn n of
  Yes Refl   => Just (t ** IsHere)
  No  contra => case inSchema xs n of
    Just (t ** prf) => Just $ (t ** IsThere prf)
    Nothing         => Nothing
```

在本章的最后，我们将在 CSV 命令行应用程序中使用 `InSchema` 来列出列中的所有值。

### 练习第 2 部分

1. 通过将 `inSchema` 的输出类型更改为 `Dec (c ** InSchema n ss c)` 来证明 `InSchema`
   是可判定的。

2. 声明并实现一个函数，用于根据给定的列名修改行中的字段。

3. 定义一个谓词用作见证一个列表仅包含第二个列表中相同顺序的元素，并使用此谓词一次从一行中提取几列。

   例如，`[1,2,3,4,5,6]` 包含的 `[2,4,5]` 顺序是正确的，但是 `[4,2,5]` 不是。

4. 通过定义一个新的谓词来改进练习 3 的功能，见证列表中的所有字符串都对应于模式中的列名（以任意顺序）。使用它可以以任意顺序一次从一行中提取几列。

   提示：确保包含生成的模式作为索引，
   仅根据名称列表和输入模式进行搜索。

## 用例：灵活的错误处理

编写大型应用程序时反复出现的模式是在更大的有效计算中组合程序的不同部分，每个部分都有自己的故障类型。例如，我们在实现用于处理 CSV 文件的命令行工具时就看到了这一点。在那里，我们从文件读取和写入数据，我们解析列类型和模式，我们解析行和列索引以及命令行命令。所有这些操作都有失败的可能性，并且可能在我们应用程序的不同部分中实现。为了统一这些不同的失败类型，我们编写了一个自定义的和类型来封装它们中的每一个，并为这个和类型编写了一个单独的处理程序。这种方法当时还可以，但它不能很好地扩展，并且缺乏灵活性。因此，我们在这里尝试不同的方法。在继续之前，我们快速实现了几个可能失败的函数以及一些自定义错误类型：

```idris
record NoNat where
  constructor MkNoNat
  str : String

readNat' : String -> Either NoNat Nat
readNat' s = maybeToEither (MkNoNat s) $ parsePositive s

record NoColType where
  constructor MkNoColType
  str : String

readColType' : String -> Either NoColType ColType
readColType' "I64"     = Right I64
readColType' "Str"     = Right Str
readColType' "Boolean" = Right Boolean
readColType' "Float"   = Right Float
readColType' s         = Left $ MkNoColType s
```

但是，如果我们想解析 `Fin n`，已经有两种方法会导致失败：有问题的字符串不能表示自然数（导致 `NoNat`错误），或者它可能超出范围（导致 `OutOfBounds` 错误）。我们必须以某种方式在返回类型中编码这两种可能性，例如，通过使用 `Either` 作为错误类型：

```idris
record OutOfBounds where
  constructor MkOutOfBounds
  size  : Nat
  index : Nat

readFin' : {n : _} -> String -> Either (Either NoNat OutOfBounds) (Fin n)
readFin' s = do
  ix <- mapFst Left (readNat' s)
  maybeToEither (Right $ MkOutOfBounds n ix) $ natToFin ix n
```

这是难以置信的丑陋。自定义和类型可能会稍微好一些，但是在调用 `readNat'` 时我们仍然必须使用 `mapFst`，并且为每个可能的错误组合编写自定义和类型也会很快变得非常麻烦。我们正在寻找的是一种广义的和类型：一种由类型列表（可能的选择）索引的类型，其中包含所讨论类型之一的单个值。这是第一次天真的尝试：

```idris
data Sum : List Type -> Type where
  MkSum : (val : t) -> Sum ts
```

但是，缺少一条关键信息：我们尚未验证 `t` 是 `ts` 的元素，也没有验证它实际上是 *哪个* 类型。事实上，这是另一种被抹去的存在，我们将无法在运行时了解 `t`。我们需要做的是将值与证明配对，证明其类型 `t` 是 `ts` 的元素。为此，我们可以再次使用 `Elem`，但对于某些用例，我们将需要访问列表中的类型数量。因此，我们将使用向量而不是列表作为索引。这是一个类似于 `Elem` 的谓词，但用于向量：

```idris
data Has :  (v : a) -> (vs  : Vect n a) -> Type where
  Z : Has v (v :: vs)
  S : Has v vs -> Has v (w :: vs)

Uninhabited (Has v []) where
  uninhabited Z impossible
  uninhabited (S _) impossible
```

`Has v vs` 类型的值证明 `v` 是 `vs` 的一个元素。有了这个，我们现在可以实现一个索引和类型（也称为 *开放联合*）：

```idris
data Union : Vect n Type -> Type where
  U : (ix : Has t ts) -> (val : t) -> Union ts

Uninhabited (Union []) where
  uninhabited (U ix _) = absurd ix
```

注意 `HList` 和 `Union` 之间的区别。 `HList` 是 * 广义积类型*：它在其索引中为每个类型保存一个值。 `Union` 是 * 广义和类型*：它只保存一个值，该值必须是索引中列出的类型。有了这个，我们现在可以定义一个更灵活的错误类型：

```idris
0 Err : Vect n Type -> Type -> Type
Err ts t = Either (Union ts) t
```

返回 `Err ts a` 的函数描述了一个计算，该计算可能会因 `ts` 中列出的错误之一而失败。我们首先需要一些实用函数。

```idris
inject : (prf : Has t ts) => (v : t) -> Union ts
inject v = U prf v

fail : Has t ts => (err : t) -> Err ts a
fail err = Left $ inject err

failMaybe : Has t ts => (err : Lazy t) -> Maybe a -> Err ts a
failMaybe err = maybeToEither (inject err)
```

接下来，我们可以为上面编写的解析器编写更灵活的版本：

```idris
readNat : Has NoNat ts => String -> Err ts Nat
readNat s = failMaybe (MkNoNat s) $ parsePositive s

readColType : Has NoColType ts => String -> Err ts ColType
readColType "I64"     = Right I64
readColType "Str"     = Right Str
readColType "Boolean" = Right Boolean
readColType "Float"   = Right Float
readColType s         = fail $ MkNoColType s
```

在我们实现 `readFin` 之前，我们引入一个快捷方式来指定必须存在几种错误类型：

```idris
0 Errs : List Type -> Vect n Type -> Type
Errs []        _  = ()
Errs (x :: xs) ts = (Has x ts, Errs xs ts)
```

函数 `Errs` 返回一个约束元组。这可以用作所有列出的类型都存在于类型向量中的见证：Idris 将根据需要自动从元组中提取证明。


```idris
readFin : {n : _} -> Errs [NoNat, OutOfBounds] ts => String -> Err ts (Fin n)
readFin s = do
  S ix <- readNat s | Z => fail (MkOutOfBounds n Z)
  failMaybe (MkOutOfBounds n (S ix)) $ natToFin ix n
```

作为最后一个示例，这里是模式和 CSV 行的解析器：

```idris
fromCSV : String -> List String
fromCSV = forget . split (',' ==)

record InvalidColumn where
  constructor MkInvalidColumn
  str : String

readColumn : Errs [InvalidColumn, NoColType] ts => String -> Err ts Column
readColumn s = case forget $ split (':' ==) s of
  [n,ct] => MkColumn n <$> readColType ct
  _      => fail $ MkInvalidColumn s

readSchema : Errs [InvalidColumn, NoColType] ts => String -> Err ts Schema
readSchema = traverse readColumn . fromCSV

data RowError : Type where
  InvalidField  : (row, col : Nat) -> (ct : ColType) -> String -> RowError
  UnexpectedEOI : (row, col : Nat) -> RowError
  ExpectedEOI   : (row, col : Nat) -> RowError

decodeField :  Has RowError ts
            => (row,col : Nat)
            -> (c : ColType)
            -> String
            -> Err ts (IdrisType c)
decodeField row col c s =
  let err = InvalidField row col c s
   in case c of
        I64     => failMaybe err $ read s
        Str     => failMaybe err $ read s
        Boolean => failMaybe err $ read s
        Float   => failMaybe err $ read s

decodeRow :  Has RowError ts
          => {s : _}
          -> (row : Nat)
          -> (str : String)
          -> Err ts (Row s)
decodeRow row = go 1 s . fromCSV
  where go : Nat -> (cs : Schema) -> List String -> Err ts (Row cs)
        go k []       []                    = Right []
        go k []       (_ :: _)              = fail $ ExpectedEOI row k
        go k (_ :: _) []                    = fail $ UnexpectedEOI row k
        go k (MkColumn n c :: cs) (s :: ss) =
          [| decodeField row k c s :: go (S k) cs ss |]
```

这是一个示例 REPL 会话，我在其中测试 `readSchema`。我使用 `:let` 命令定义了变量 `ts` 以使其更方便。请注意，错误类型的顺序并不重要，只要错误列表中存在 `InvalidColumn` 和 `NoColType` 类型：

```repl
Tutorial.Predicates> :let ts = the (Vect 3 _) [NoColType,NoNat,InvalidColumn]
Tutorial.Predicates> readSchema {ts} "foo:bar"
Left (U Z (MkNoColType "bar"))
Tutorial.Predicates> readSchema {ts} "foo:Float"
Right [MkColumn "foo" Float]
Tutorial.Predicates> readSchema {ts} "foo Float"
Left (U (S (S Z)) (MkInvalidColumn "foo Float"))
```

### 错误处理

有几种处理错误的技术，所有这些技术有时都很有用。例如，我们可能希望在早期单独处理一些错误，而在我们的应用程序中处理其他错误。或者我们可能想一举解决所有问题。我们在这里看看这两种方法。

首先，为了单独处理单个错误，我们需要将联合 *拆分* 为以下两种可能性之一：所讨论的错误类型的值或新联合，包含其他错误类型之一。为此我们需要一个新的谓词，它不仅编码向量中值的存在，还编码删除该值的结果：

```idris
data Rem : (v : a) -> (vs : Vect (S n) a) -> (rem : Vect n a) -> Type where
  [search v vs]
  RZ : Rem v (v :: rem) rem
  RS : Rem v vs rem -> Rem v (w :: vs) (w :: rem)
```

再一次，我们希望在函数的返回类型中使用其中一个索引 (`rem`)，因此我们只在证明搜索期间使用其他索引。这是一个从开放联合中分离值的函数：

```idris
split : (prf : Rem t ts rem) => Union ts -> Either t (Union rem)
split {prf = RZ}   (U Z     val) = Left val
split {prf = RZ}   (U (S x) val) = Right (U x val)
split {prf = RS p} (U Z     val) = Right (U Z val)
split {prf = RS p} (U (S x) val) = case split {prf = p} (U x val) of
  Left vt        => Left vt
  Right (U ix y) => Right $ U (S ix) y
```

这试图从联合中提取 `t` 类型的值。如果有效，则将结果包装在 `Left` 中，否则将在 `Right` 中返回一个新联合，但此联合已从其列表中删除了 `t`可能的类型。

有了这个，我们可以实现单个错误的处理程序。错误处理通常发生在有效的上下文中（我们可能希望将消息打印到控制台或将错误写入日志文件），因此我们使用应用效果类型来处理错误。

```idris
handle :  Applicative f
       => Rem t ts rem
       => (h : t -> f a)
       -> Err ts a
       -> f (Err rem a)
handle h (Left x)  = case split x of
  Left v    => Right <$> h v
  Right err => pure $ Left err
handle _ (Right x) = pure $ Right x
```

为了一次处理所有错误，我们可以使用由错误向量索引并由输出类型参数化的处理程序类型：

```idris
namespace Handler
  public export
  data Handler : (ts : Vect n Type) -> (a : Type) -> Type where
    Nil  : Handler [] a
    (::) : (t -> a) -> Handler ts a -> Handler (t :: ts) a

extract : Handler ts a -> Has t ts -> t -> a
extract (f :: _)  Z     val = f val
extract (_ :: fs) (S y) val = extract fs y val
extract []        ix    _   = absurd ix

handleAll : Applicative f => Handler ts (f a) -> Err ts a -> f a
handleAll _ (Right v)       = pure v
handleAll h (Left $ U ix v) = extract h ix v
```

下面，我们将看到另一种通过定义用于错误处理的自定义接口来一次处理所有错误的方法。

### 练习第 3 部分

1. 为 `Union` 实现以下实用函数：

   ```idris
   project : (0 t : Type) -> (prf : Has t ts) => Union ts -> Maybe t

   project1 : Union [t] -> t

   safe : Err [] a -> a
   ```
2. 实现以下两个函数，以便在更大的可能性集合中嵌入开放联合。请注意 `extend` 中的未擦除隐式！

   ```idris
   weaken : Union ts -> Union (ts ++ ss)

   extend : {m : _} -> {0 pre : Vect m _} -> Union ts -> Union (pre ++ ts)
   ```

3. 找到一种将 `Union ts` 嵌入到 `Union ss` 中的通用方法，以便可以进行以下操作：

   ```idris
   embedTest :  Err [NoNat,NoColType] a
             -> Err [FileError, NoColType, OutOfBounds, NoNat] a
   embedTest = mapFst embed
   ```

4. 通过让处理程序将有问题的错误转换为 `f (Err rem a)`，使 `handle` 更强大。

## 关于接口的真相

好吧，终于到了：关于接口的真相。在内部，接口只是一种记录数据类型，其字段对应于接口的成员。接口实现是此类记录的 *值*，使用 `%hint` pragma 注解（见下文）以使值在证明搜索期间可用。最后，受约束的函数只是具有一个或多个自动隐式参数的函数。例如，这里是在列表中查找元素的相同函数，一次使用已知语法的约束函数，一次使用自动隐式参数。 Idris 生成的代码在两种情况下都是相同的：

```idris
isElem1 : Eq a => a -> List a -> Bool
isElem1 v []        = False
isElem1 v (x :: xs) = x == v || isElem1 v xs

isElem2 : {auto _ : Eq a} -> a -> List a -> Bool
isElem2 v []        = False
isElem2 v (x :: xs) = x == v || isElem2 v xs
```

作为单纯的记录，我们还可以将接口作为常规函数参数，并使用模式匹配对其进行剖析：

```idris
eq : Eq a -> a -> a -> Bool
eq (MkEq feq fneq) = feq
```

### 手动接口定义

我现在将演示我们如何使用证明搜索实现与使用常规接口定义和实现相同的行为。由于我想用我们的新错误处理工具完成 CSV 示例，我们将实现一些错误处理程序。首先，一个接口只是一个记录：

```idris
record Print a where
  constructor MkPrint
  print' : a -> String
```

为了在受约束的函数中访问记录，我们使用 `%search` 关键字，它将尝试通过以下方式变出所需类型的值（在这种情况下为 `Print a`）证明搜索：

```idris
print : Print a => a -> String
print = print' %search
```

作为替代方案，我们可以使用命名约束，并通过其名称直接访问它：

```idris
print2 : (impl : Print a) => a -> String
print2 = print' impl
```

作为另一种选择，我们可以使用自动隐式参数的语法：

```idris
print3 : {auto impl : Print a} -> a -> String
print3 = print' impl
```

`print` 的所有三个版本在运行时的行为完全相同。所以，每当我们写 `{auto x : Foo} ->` 时，我们也可以写成 `(x : Foo) =>` ，反之亦然。

接口实现只是给定记录类型的值，但为了在证明搜索期间可用，这些需要用 `%hint` pragma 注解：

```idris
%hint
noNatPrint : Print NoNat
noNatPrint = MkPrint $ \e => "Not a natural number: \{e.str}"

%hint
noColTypePrint : Print NoColType
noColTypePrint = MkPrint $ \e => "Not a column type: \{e.str}"

%hint
outOfBoundsPrint : Print OutOfBounds
outOfBoundsPrint = MkPrint $ \e => "Index is out of bounds: \{show e.index}"

%hint
rowErrorPrint : Print RowError
rowErrorPrint = MkPrint $
  \case InvalidField r c ct s =>
          "Not a \{show ct} in row \{show r}, column \{show c}. \{s}"
        UnexpectedEOI r c =>
          "Unexpected end of input in row \{show r}, column \{show c}."
        ExpectedEOI r c =>
          "Expected end of input in row \{show r}, column \{show c}."
```

我们还可以为联合或错误编写 `Print` 的实现。为此，我们首先要证明联合索引中的所有类型都带有 `Print` 的实现：

```idris
0 All : (f : a -> Type) -> Vect n a -> Type
All f []        = ()
All f (x :: xs) = (f x, All f xs)

unionPrintImpl : All Print ts => Union ts -> String
unionPrintImpl (U Z val)     = print val
unionPrintImpl (U (S x) val) = unionPrintImpl $ U x val

%hint
unionPrint : All Print ts => Print (Union ts)
unionPrint = MkPrint unionPrintImpl
```

以这种方式定义接口可能是一个优势，因为发生的魔法要少得多，而且我们对字段的类型和值有更细粒度的控制。还要注意，所有的魔法都来自搜索提示，我们的“接口实现” 带有注解。这会使相应的值和功能在证明搜索期间可用。

#### 解析 CSV 命令

为了结束本章，我们使用上一节中灵活的错误处理方法重新实现了 CSV 命令解析器。虽然不一定比原始解析器更冗长，但这种方法将错误处理和错误消息打印与应用程序的其余部分分离：可能失败的函数可以在不同的上下文中重用，就像我们使用的美观打印器一样错误信息。

首先，我们重复前面章节中的一些内容。我偷偷输入了一个新命令来打印列中的所有值：

```idris
record Table where
  constructor MkTable
  schema : Schema
  size   : Nat
  rows   : Vect size (Row schema)

data Command : (t : Table) -> Type where
  PrintSchema :  Command t
  PrintSize   :  Command t
  New         :  (newSchema : Schema) -> Command t
  Prepend     :  Row (schema t) -> Command t
  Get         :  Fin (size t) -> Command t
  Delete      :  Fin (size t) -> Command t
  Col         :  (name : String)
              -> (tpe  : ColType)
              -> (prf  : InSchema name t.schema tpe)
              -> Command t
  Quit        : Command t

applyCommand : (t : Table) -> Command t -> Table
applyCommand t                 PrintSchema = t
applyCommand t                 PrintSize   = t
applyCommand _                 (New ts)    = MkTable ts _ []
applyCommand (MkTable ts n rs) (Prepend r) = MkTable ts _ $ r :: rs
applyCommand t                 (Get x)     = t
applyCommand t                 Quit        = t
applyCommand t                 (Col _ _ _) = t
applyCommand (MkTable ts n rs) (Delete x)  = case n of
  S k => MkTable ts k (deleteAt x rs)
  Z   => absurd x
```

接下来，下面是重新实现的命令解析器。总的来说，它可能在七种不同的情况下失败，至少其中一些可能在更大应用程序的其他部分中也可能出现。

```idris
record UnknownCommand where
  constructor MkUnknownCommand
  str : String

%hint
unknownCommandPrint : Print UnknownCommand
unknownCommandPrint = MkPrint $ \v => "Unknown command: \{v.str}"

record NoColName where
  constructor MkNoColName
  str : String

%hint
noColNamePrint : Print NoColName
noColNamePrint = MkPrint $ \v => "Unknown column: \{v.str}"

0 CmdErrs : Vect 7 Type
CmdErrs = [ InvalidColumn
          , NoColName
          , NoColType
          , NoNat
          , OutOfBounds
          , RowError
          , UnknownCommand ]

readCommand : (t : Table) -> String -> Err CmdErrs (Command t)
readCommand _                "schema"  = Right PrintSchema
readCommand _                "size"    = Right PrintSize
readCommand _                "quit"    = Right Quit
readCommand (MkTable ts n _) s         = case words s of
  ["new",    str] => New     <$> readSchema str
  "add" ::   ss   => Prepend <$> decodeRow 1 (unwords ss)
  ["get",    str] => Get     <$> readFin str
  ["delete", str] => Delete  <$> readFin str
  ["column", str] => case inSchema ts str of
    Just (ct ** prf) => Right $ Col str ct prf
    Nothing          => fail $ MkNoColName str
  _               => fail $ MkUnknownCommand s
```

请注意，我们如何直接调用像 `readFin` 或 `readSchema` 这样的函数，因为必要的错误类型是我们可能的错误列表的一部分。

总结本节，这里是打印命令结果和应用程序主循环的函数。其中大部分内容从前面的章节中重复，但请注意我们如何通过一次调用 `print` 来一次处理所有错误：

```idris
encodeField : (t : ColType) -> IdrisType t -> String
encodeField I64     x     = show x
encodeField Str     x     = show x
encodeField Boolean True  = "t"
encodeField Boolean False = "f"
encodeField Float   x     = show x

encodeRow : (s : Schema) -> Row s -> String
encodeRow s = concat . intersperse "," . go s
  where go : (s' : Schema) -> Row s' -> Vect (length s') String
        go []        []        = []
        go (MkColumn _ c :: cs) (v :: vs) = encodeField c v :: go cs vs

encodeCol :  (name : String)
          -> (c    : ColType)
          -> InSchema name s c
          => Vect n (Row s)
          -> String
encodeCol name c = unlines . toList . map (\r => encodeField c $ getAt name r)

result :  (t : Table) -> Command t -> String
result t PrintSchema   = "Current schema: \{showSchema t.schema}"
result t PrintSize     = "Current size: \{show t.size}"
result _ (New ts)      = "Created table. Schema: \{showSchema ts}"
result t (Prepend r)   = "Row prepended: \{encodeRow t.schema r}"
result _ (Delete x)    = "Deleted row: \{show $ FS x}."
result _ Quit          = "Goodbye."
result t (Col n c prf) = "Column \{n}:\n\{encodeCol n c t.rows}"
result t (Get x)       =
  "Row \{show $ FS x}: \{encodeRow t.schema (index x t.rows)}"

covering
runProg : Table -> IO ()
runProg t = do
  putStr "Enter a command: "
  str <- getLine
  case readCommand t str of
    Left err   => putStrLn (print err) >> runProg t
    Right Quit => putStrLn (result t Quit)
    Right cmd  => putStrLn (result t cmd) >>
                  runProg (applyCommand t cmd)

covering
main : IO ()
main = runProg $ MkTable [] _ []
```

这是一个示例 REPL 会话：

```repl
Tutorial.Predicates> :exec main
Enter a command: new name:Str,age:Int64,salary:Float
Not a column type: Int64
Enter a command: new name:Str,age:I64,salary:Float
Created table. Schema: name:Str,age:I64,salary:Float
Enter a command: add John Doe,44,3500
Row prepended: "John Doe",44,3500.0
Enter a command: add Jane Doe,50,4000
Row prepended: "Jane Doe",50,4000.0
Enter a command: get 1
Row 1: "Jane Doe",50,4000.0
Enter a command: column salary
Column salary:
4000.0
3500.0

Enter a command: quit
Goodbye.
```

## 结论

谓词允许我们描述类型之间的契约并细化我们接受为有效函数参数的值。它们允许我们通过将它们用作自动隐式参数来使函数在运行时 *和* 编译时安全且方便地使用 ，如果Idris有足够的关于函数参数结构的信息，Idris 应该尝试自己构造它。

<!-- vi: filetype=idris2
-->
