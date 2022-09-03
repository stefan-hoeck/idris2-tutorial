# Sigma 类型

到目前为止，在我们的依赖类型编程示例中，类型索引（例如向量的长度）在编译时是已知的，或者可以从编译时已知的值中计算出来。然而，在实际应用中，此类信息通常在运行时才可用，其中值取决于用户做出的决定或周围世界的状态。例如，如果我们将文件的内容存储为文本行向量，则该向量的长度通常在文件加载到内存之前是未知的。因此，我们使用的值的类型依赖于仅在运行时才知道的其他值，并且我们通常只能通过对它们所依赖的值进行模式匹配来找出这些类型。为了表达这些依赖关系，我们需要所谓的 [*sigma types*](https://en.wikipedia.org/wiki/Dependent_type#%CE%A3_type)：依赖对及其泛化，依赖记录。

```idris
module Tutorial.DPair

import Control.Monad.State

import Data.DPair
import Data.Either
import Data.HList
import Data.List
import Data.List1
import Data.Singleton
import Data.String
import Data.Vect

import Text.CSV

%default total
```

## 依赖对

我们已经看到了几个例子，说明向量的长度索引在更精确地描述函数可以做什么和不能做什么的类型中是多么有用。例如，对向量进行操作的 `map` 或 `traverse` 将返回长度完全相同的向量。这些类型保证这是真的，因此以下函数是完全安全的并且可以证明是完全的：

```idris
parseAndDrop : Vect (3 + n) String -> Maybe (Vect n Nat)
parseAndDrop = map (drop 3) . traverse parsePositive
```

由于 `traverse parsePositive` 的参数是 `Vect (3 + n) String` 类型，其结果将是 `Maybe (Vect (3 + n) Nat)` 类型]。因此在调用 `drop 3` 时使用它是安全的。请注意，所有这些在编译时是如何知道的：我们编码的先决条件是第一个参数是长度索引中至少三个元素的向量，并且可以从中得出结果的长度。

### 未知长度的向量

然而，这并不总是可能的。考虑以下函数，在 `List` 上定义并由 `Data.List` 导出：

```repl
Tutorial.Relations> :t takeWhile
Data.List.takeWhile : (a -> Bool) -> List a -> List a
```

这将采用列表参数的最长前缀，给定谓词为此返回 `True`。在这种情况下，它取决于列表元素和谓词，这个前缀有多长。我们可以为向量编写这样的函数吗？试一试吧：

```idris
takeWhile' : (a -> Bool) -> Vect n a -> Vect m a
```

继续，并尝试实现这一点。不要尝试太久，因为您将无法以可证明的整体方式这样做。问题是：这里有什么问题？为了理解这一点，我们必须了解 `takeWhile'` 的类型所承诺的内容：“对于所有对 `a` 类型的值进行操作的谓词，以及所有包含此类型值的向量，对于所有长度 `m`，我给你一个长度为 `m` 的向量，其中包含 `a`" 类型的值。所有三个参数都被称为 [*universally quantified*](https://en.wikipedia.org/wiki/Universal_quantification)：我们函数的调用者可以自由选择谓词、输入向量、向量持有的值的类型，以及 *输出向量的长度*。不相信我？看这里：

```idris
-- This looks like trouble: We got a non-empty vector of `Void`...
voids : Vect 7 Void
voids = takeWhile' (const True) []

-- ...from which immediately follows a proof of `Void`
proofOfVoid : Void
proofOfVoid = head voids
```

看看我在调用 `takeWhile'` 时如何自由决定 `m` 的值？尽管我将 `takeWhile'` 传递给了一个空向量（唯一的现有向量包含 `Void` 类型的值），但该函数的类型保证我返回一个可能非空的向量，该向量包含相同类型的值，我从中自由地提取了第一个。

幸运的是，Idris 不允许这样做：我们将无法在不作弊的情况下实现 `takeWhile'`（例如，通过关闭完全性检查并永远循环）。所以，问题仍然存在，如何在一个类型中表达 `takeWhile'` 的结果。对此的答案是：“使用 *依赖对*”，一个向量与与其长度对应的值配对。

```idris
record AnyVect a where
  constructor MkAnyVect
  length : Nat
  vect   : Vect length a
```

这对应于谓词逻辑中的[*存在量化*](https://en.wikipedia.org/wiki/Existential_quantification)：有一个自然数，对应于我这里的向量的长度。请注意，从 `AnyVect a` 的外部，包装矢量的长度在类型级别不再可见，但我们仍然可以检查它并在运行时了解它，因为它被包装在一起与实际向量。我们可以实现 `takeWhile`，使其返回 `AnyVect a` 类型的值：

```idris
takeWhile : (a -> Bool) -> Vect n a -> AnyVect a
takeWhile f []        = MkAnyVect 0 []
takeWhile f (x :: xs) = case f x of
  False => MkAnyVect 0 []
  True  => let MkAnyVect n ys = takeWhile f xs in MkAnyVect (S n) (x :: ys)
```

这可以证明是完全可行的，因为这个函数的调用者不能再自己选择结果向量的长度。我们的函数 `takeWhile` 决定这个长度并将它与向量一起返回，类型检查器验证我们在配对两个值时没有错误。事实上，长度可以由 Idris 自动推断，所以如果我们愿意，我们可以用下划线替换它：

```idris
takeWhile2 : (a -> Bool) -> Vect n a -> AnyVect a
takeWhile2 f []        = MkAnyVect _ []
takeWhile2 f (x :: xs) = case f x of
  False => MkAnyVect 0 []
  True  => let MkAnyVect _ ys = takeWhile2 f xs in MkAnyVect _ (x :: ys)
```

总结：泛型函数类型中的参数是通用量化的，它们的值可以在此类函数的调用处确定。依赖记录类型允许我们描述存在量化的值。调用者不能自由选择这些值：它们作为函数结果的一部分返回。

请注意，Idris 允许我们明确地进行全称量化。 `takeWhile'` 的类型也可以这样写：

```idris
takeWhile'' : forall a, n, m . (a -> Bool) -> Vect n a -> Vect m a
```

普遍量化的参数被 Idris 脱糖为隐式的已擦除参数。上面是以下函数类型的一个不那么冗长的版本，我们之前已经看到过类似的函数类型：

```idris
takeWhile''' :  {0 a : _}
             -> {0 n : _}
             -> {0 m : _}
             -> (a -> Bool)
             -> Vect n a
             -> Vect m a
```

在 Idris 中，我们可以自由选择是否要明确全称量化。有时它可以帮助理解在类型级别上发生了什么。其他语言 - 例如 [PureScript](https://www.purescript.org/) - 对此更为严格：在那里，对普遍量化参数的显式注释是 [强制性](https://github.com/purescript/documentation/blob/master/language/Differences-from-Haskell.md#explicit-forall)的。

### 依赖对的本质

了解这里发生的事情可能需要一些时间和经验。至少在我的情况下，在 Idris 中进行了许多会话编程，然后我才弄清楚依赖对的含义：它们将某种类型的 *value* 与从第一个值计算的类型的第二个值配对。例如，自然数 `n`（值）与长度为 `n` 的向量对（第二个值，其类型 *取决于* 第一个值）。这是使用依赖类型进行编程的基本概念，*Prelude* 提供了一个通用的依赖对类型。这是它的实现（准备消除歧义）：

```idris
record DPair' (a : Type) (p : a -> Type) where
  constructor MkDPair'
  fst : a
  snd : p fst
```

必须了解这里发生了什么。有两个参数：类型 `a` 和函数 `p`，从类型 `a` 的 *值* 计算出一个 *类型* 。这个值 (`fst`) 被用来计算第二个值 (`snd`) 的 *类型*。例如，这里是 `AnyVect a` 使用 `DPair` 的表示：

```idris
AnyVect' : (a : Type) -> Type
AnyVect' a = DPair Nat (\n => Vect n a)
```

请注意，`\n => Vect n a` 如何是从 `Nat` 到 `Type` 的函数。 Idris 提供了用于描述依赖对的特殊语法，因为它们是使用一流类型的语言进行编程的重要构建块：

```idris
AnyVect'' : (a : Type) -> Type
AnyVect'' a = (n : Nat ** Vect n a)
```

我们可以在 REPL 中检查，`AnyVect''` 的右侧被脱糖到 `AnyVect'` 的右侧：

```repl
Tutorial.Relations> (n : Nat ** Vect n Int)
DPair Nat (\n => Vect n Int)
```

Idris 可以推断，`n` 必须是 `Nat` 类型，因此我们可以删除此信息。 （我们仍然需要将整个表达式放在括号中。）

```idris
AnyVect3 : (a : Type) -> Type
AnyVect3 a = (n ** Vect n a)
```

这允许我们将自然数 `n` 与长度为 `n` 的向量配对，这正是我们对 `AnyVect` 所做的。因此，我们可以重写 `takeWhile` 以返回 `DPair` 而不是我们的自定义类型 `AnyVect`。请注意，与常规对一样，我们可以使用相同的语法 `(x ** y)` 在依赖对上创建和模式匹配：

```idris
takeWhile3 : (a -> Bool) -> Vect m a -> (n ** Vect n a)
takeWhile3 f []        = (_ ** [])
takeWhile3 f (x :: xs) = case f x of
  False => (_ ** [])
  True  => let (_  ** ys) = takeWhile3 f xs in (_ ** x :: ys)
```

就像常规对一样，我们可以使用依赖对语法来定义依赖三元组和更大的元组：

```idris
AnyMatrix : (a : Type) -> Type
AnyMatrix a = (m ** n ** Vect m (Vect n a))
```

### 已删除的存在

有时，可以通过对索引类型的值进行模式匹配来确定索引的值。例如，通过对向量进行模式匹配，我们可以了解它的长度索引。在这些情况下，不一定要在运行时携带索引，我们可以编写一个特殊版本的依赖对，其中第一个参数的数量为零。 *base* 中的模块 `Data.DPair` 为此用例导出数据类型 `Exists`。

例如，下面是 `takeWhile` 的一个版本，返回一个 `Exists` 类型的值：

```idris
takeWhileExists : (a -> Bool) -> Vect m a -> Exists (\n => Vect n a)
takeWhileExists f []        = Evidence _ []
takeWhileExists f (x :: xs) = case f x of
  True  => let Evidence _ ys = takeWhileExists f xs
            in Evidence _ (x :: ys)
  False => takeWhileExists f xs
```

为了恢复已擦除的值，来自 *base* 模块 `Data.Singleton` 的数据类型 `Singleton` 可能很有用：它由参数化 *值* 来存储：

```idris
true : Singleton True
true = Val True
```

这称为 *singleton* 类型：与一个值对应的类型。返回常量 `true` 的任何其他值都是类型错误，Idris 知道这一点：

```idris
true' : Singleton True
true' = Val _
```

我们可以使用它凭空变出一个向量的（擦除的！）长度：

```idris
vectLength : Vect n a -> Singleton n
vectLength []        = Val 0
vectLength (x :: xs) = let Val k = vectLength xs in Val (S k)
```

此函数提供比 `Data.Vect.length` 更强的保证：后者声称只返回 *任意* 自然数，而 `vectLength` *必须*准确返回 `n` 以便进行类型检查。作为演示，这里是 `length` 的良类型的虚假实现：

```idris
bogusLength : Vect n a -> Nat
bogusLength = const 0
```

这不会被接受为 `vectLength` 的有效实现，因为您可以快速验证自己。

在 `vectLength` 的帮助下（但不是 `Data.Vect.length`），我们可以将已擦除的存在转换为正确的依赖对：

```idris
toDPair : Exists (\n => Vect n a) -> (m ** Vect m a)
toDPair (Evidence _ as) = let Val m = vectLength as in (m ** as)
```

同样，作为一个快速练习，尝试根据 `length` 实现 `toDPair`，并注意 Idris 无法将 `length` 的结果与实际长度向量统一。

### 练习第 1 部分

1. 声明并实现一个过滤向量的函数，类似于 `Data.List.filter`。


2. 声明并实现一个函数，用于将偏函数映射到类似于 `Data.List.mapMaybe` 的向量的值上。


3. 为向量声明并实现类似于 `Data.List.dropWhile` 的函数。使用 `Data.DPair.Exists` 作为您的返回类型。


4. 重复练习 3，但返回正确的依赖对。在您的实现中使用练习 3 中的函数。


## 用例：核酸

我们想提出一个小型、简化的库，用于运行核酸计算：RNA 和 DNA。它们由五种类型的核碱基构成，其中三种用于两种类型的核酸中，两种碱基对每种类型的酸具有特异性。我们想确保只有有效的碱基存在于核酸链中。这是一种可能的编码：

```idris
data BaseType = DNABase | RNABase

data Nucleobase : BaseType -> Type where
  Adenine  : Nucleobase b
  Cytosine : Nucleobase b
  Guanine  : Nucleobase b
  Thymine  : Nucleobase DNABase
  Uracile  : Nucleobase RNABase

NucleicAcid : BaseType -> Type
NucleicAcid = List . Nucleobase

RNA : Type
RNA = NucleicAcid RNABase

DNA : Type
DNA = NucleicAcid DNABase

encodeBase : Nucleobase b -> Char
encodeBase Adenine  = 'A'
encodeBase Cytosine = 'C'
encodeBase Guanine  = 'G'
encodeBase Thymine  = 'T'
encodeBase Uracile  = 'U'

encode : NucleicAcid b -> String
encode = pack . map encodeBase
```

在 DNA 链中使用 `Uracile` 是一个类型错误：

```idris
failing "Mismatch between: RNABase and DNABase."
  errDNA : DNA
  errDNA = [Uracile, Adenine]
```

请注意，我们如何为核碱基 `Adenine`、`Cytosine` 和 `Guanine` 使用变量：这些又是普遍量化的，客户代码可以在这里自由选择一个值.这使我们能够在 DNA *和* RNA 链中使用这些碱基：

```idris
dna1 : DNA
dna1 = [Adenine, Cytosine, Guanine]

rna1 : RNA
rna1 = [Adenine, Cytosine, Guanine]
```

对于 `Thymine` 和 `Uracile`，我们的限制性更强：`Thymine` 仅允许用于 DNA，而 `Uracile` 仅限用于 RNA。让我们为 DNA 和 RNA 链编写解析器：

```idris
readAnyBase : Char -> Maybe (Nucleobase b)
readAnyBase 'A' = Just Adenine
readAnyBase 'C' = Just Cytosine
readAnyBase 'G' = Just Guanine
readAnyBase _   = Nothing

readRNABase : Char -> Maybe (Nucleobase RNABase)
readRNABase 'U' = Just Uracile
readRNABase c   = readAnyBase c

readDNABase : Char -> Maybe (Nucleobase DNABase)
readDNABase 'T' = Just Thymine
readDNABase c   = readAnyBase c

readRNA : String -> Maybe RNA
readRNA = traverse readRNABase . unpack

readDNA : String -> Maybe DNA
readDNA = traverse readDNABase . unpack
```

同样，如果碱基出现在两种链中，通用量化的 `readAnyBase` 的用户可以自由选择他们想要的碱基类型，但他们永远不会得到 `Thymine` 或`Uracile`值。

我们现在可以对核碱基序列进行一些简单的计算。例如，我们可以提出互补链：

```idris
complementRNA' : RNA -> RNA
complementRNA' = map calc
  where calc : Nucleobase RNABase -> Nucleobase RNABase
        calc Guanine  = Cytosine
        calc Cytosine = Guanine
        calc Adenine  = Uracile
        calc Uracile  = Adenine

complementDNA' : DNA -> DNA
complementDNA' = map calc
  where calc : Nucleobase DNABase -> Nucleobase DNABase
        calc Guanine  = Cytosine
        calc Cytosine = Guanine
        calc Adenine  = Thymine
        calc Thymine  = Adenine
```

呃，代码重复！这里还不错，但想象一下有几十个基础的，只有几个特殊的。那么，我们可以做得更好吗？不幸的是，以下方法不起作用：

```idris
complementBase' : Nucleobase b -> Nucleobase b
complementBase' Adenine  = ?what_now
complementBase' Cytosine = Guanine
complementBase' Guanine  = Cytosine
complementBase' Thymine  = Adenine
complementBase' Uracile  = Adenine
```

除了 `Adenine` 情况外，一切都很顺利。请记住：参数 `b` 是通用量化的，我们函数的 *callers* 可以决定 `b` 应该是什么。因此，我们不能只返回 `Thymine`：Idris 将响应类型错误，因为调用者可能需要 `Nucleobase RNABase` 代替。解决此问题的一种方法是采用表示基本类型的附加未擦除参数（显式或隐式）：

```idris
complementBase : (b : BaseType) -> Nucleobase b -> Nucleobase b
complementBase DNABase Adenine  = Thymine
complementBase RNABase Adenine  = Uracile
complementBase _       Cytosine = Guanine
complementBase _       Guanine  = Cytosine
complementBase _       Thymine  = Adenine
complementBase _       Uracile  = Adenine
```

这又是一个依赖 *函数* 类型（也称为 [*pi 类型*](https://en.wikipedia.org/wiki/Dependent_type#%CE%A0_type)）的示例 : 输入和输出类型都 *取决于* 第一个参数的 *值*。我们现在可以使用它来计算任何核酸的互补链：

```idris
complement : (b : BaseType) -> NucleicAcid b -> NucleicAcid b
complement b = map (complementBase b)
```

现在，这是一个有趣的用例：我们想从用户输入中读取一个核碱基序列，接受两个字符串：第一个告诉我们，用户打算输入 DNA 还是 RNA 序列，第二个是序列本身.这种函数的类型应该是什么？好吧，我们正在描述具有副作用的计算，因此涉及 `IO` 的东西似乎是正确的。用户输入几乎总是需要验证或翻译，因此可能会出现问题，我们需要针对这种情况的错误类型。最后，我们的用户可以决定是否要输入一条 RNA 或 DNA，因此也应该对这种区别进行编码。

当然，总是可以为这样的用例编写自定义和类型：

```idris
data Result : Type where
  UnknownBaseType : String -> Result
  InvalidSequence : String -> Result
  GotDNA          : DNA -> Result
  GotRNA          : RNA -> Result
```

这具有以单一数据类型编码的所有可能结果。但是，它缺乏灵活性。如果我们想及早处理错误并只提取一条 RNA 或 DNA，我们需要另一种数据类型：

```idris
data RNAOrDNA = ItsRNA RNA | ItsDNA DNA
```

这可能是要走的路，但对于有很多选项的结果，这很快就会变得很麻烦。另外：当我们已经拥有处理这个问题的工具时，为什么还要提出自定义数据类型？

以下是我们如何使用依赖对对其进行编码：

```idris
namespace InputError
  public export
  data InputError : Type where
    UnknownBaseType : String -> InputError
    InvalidSequence : String -> InputError

readAcid : (b : BaseType) -> String -> Either InputError (NucleicAcid b)
readAcid b str =
  let err = InvalidSequence str
   in case b of
        DNABase => maybeToEither err $ readDNA str
        RNABase => maybeToEither err $ readRNA str

getNucleicAcid : IO (Either InputError (b ** NucleicAcid b))
getNucleicAcid = do
  baseString <- getLine
  case baseString of
    "DNA" => map (MkDPair _) . readAcid DNABase <$> getLine
    "RNA" => map (MkDPair _) . readAcid RNABase <$> getLine
    _     => pure $ Left (UnknownBaseType baseString)
```

请注意，我们如何将核碱基类型与核酸序列配对。假设现在我们实现了一个将 DNA 链转录为 RNA 的函数，并且我们希望将用户输入的核碱基序列转换为相应的 RNA 序列。以下是如何执行此操作：

```idris
transcribeBase : Nucleobase DNABase -> Nucleobase RNABase
transcribeBase Adenine  = Uracile
transcribeBase Cytosine = Guanine
transcribeBase Guanine  = Cytosine
transcribeBase Thymine  = Adenine

transcribe : DNA -> RNA
transcribe = map transcribeBase

printRNA : RNA -> IO ()
printRNA = putStrLn . encode

transcribeProg : IO ()
transcribeProg = do
  Right (b ** seq) <- getNucleicAcid
    | Left (InvalidSequence str) => putStrLn $ "Invalid sequence: " ++ str
    | Left (UnknownBaseType str) => putStrLn $ "Unknown base type: " ++ str
  case b of
    DNABase => printRNA $ transcribe seq
    RNABase => printRNA seq
```

通过对依赖对的第一个值的模式匹配，我们可以确定第二个值是 RNA 还是 DNA 序列。在第一种情况下，我们必须先转录序列，在第二种情况下，我们可以直接调用 `printRNA`。

在一个更有趣的场景中，我们将 RNA 序列 *翻译* 成相应的蛋白质序列。尽管如此，这个例子展示了如何处理一个简化的现实世界场景：数据可能以不同的方式编码并且来自不同的来源。通过使用精确类型，我们被迫首先将值转换为正确的格式。不这样做会导致编译时异常，而不是运行时错误，或者 - 更糟糕的是 - 程序静默运行虚假计算。

### 依赖记录与和类型

`AnyVect a` 所示的依赖记录是依赖对的概括：我们可以有任意数量的字段并使用其中存储的值来计算其他值的类型。对于非常简单的情况，例如带有核碱基的示例，无论我们使用 `DPair`、自定义相关记录还是和类型都没有太大关系。事实上，这三种编码同样具有表现力：

```idris
Acid1 : Type
Acid1 = (b ** NucleicAcid b)

record Acid2 where
  constructor MkAcid2
  baseType : BaseType
  sequence : NucleicAcid baseType

data Acid3 : Type where
  SomeRNA : RNA -> Acid3
  SomeDNA : DNA -> Acid3
```

在这些编码之间编写无损转换是微不足道的，并且对于每种编码，我们可以通过简单的模式匹配来决定我们当前是否具有 RNA 或 DNA 序列。然而，依赖类型可以依赖多个值，正如我们将在练习中看到的那样。在这种情况下，和类型和依赖对很快就会变得笨拙，您应该将编码作为依赖记录。

### 练习第 2 部分

提高您使用依赖对和依赖记录的技能！在练习 2 到 7 中，你必须自己决定什么时候函数应该返回一个依赖对或记录，什么时候函数需要额外的参数，你可以在这些参数上进行模式匹配，以及可能需要哪些其他实用函数。

1. 通过编写从 `Acid1` 到 `Acid2` 并返回的无损转换函数，证明核碱基的三种编码是*同构的*（意思是：结构相同）。同样适用于 `Acid1` 和 `Acid3`。


2. 核碱基序列可以在以下两个方向之一编码：[*Sense* 和 *antisense*](https://en.wikipedia.org/wiki/Sense_(molecular_biology))。声明一个新的数据类型来描述核碱基序列的意义，并将其作为附加参数添加到类型 `Nucleobase` 、`DNA` 和 `RNA`。


3. 细化 `complement` 和 `transcribe` 的类型，使其反映 *sense* 的变化。在 `transcribe` 的情况下，反义 DNA 链被转化为 sense RNA 链。


4. 定义一个依赖记录，将碱基类型和 sense 与一系列核碱基一起存储。


5. 调整 `readRNA` 和 `readDNA` 使得从输入字符串中读取 *sense* 的序列。 Sense 链编码如下："3´-CGGTAG-5´"。反义链编码如下："3´-CGGTAG-5´"。


6. 调整 `encode` 使其在输出中包含 sense。


7. 增强 `getNucleicAcid` 和 `transcribeProg` 以使 sense 和碱基类型与序列一起存储，并且 `transcribeProg` 始终打印 *sense* RNA 链（转录后，如有必要）。


8. 享受您的劳动成果并在 REPL 测试您的程序。


注意：我们可以再次使用四个构造函数的和类型来编码不同类型的序列，而不是使用依赖记录。但是，所需的构造函数数量对应于每个类型级别索引的值数量的 *积*。因此，这个数字会快速增长，并且在这些情况下，和类型编码会导致模式匹配的块很长。

## 用例：带有模式的 CSV 文件

在本节中，我们将看一个基于我们之前在 CSV 解析器上的工作的扩展示例。我们想编写一个小型命令行程序，用户可以在其中为他们想要解析并加载到内存中的 CSV 表指定模式。在我们开始之前，这是一个运行最终程序的 REPL 会话，您将在练习中完成它：

```repl
Solutions.DPair> :exec main
Enter a command: load resources/example
Table loaded. Schema: str,str,fin2023,str?,boolean?
Enter a command: get 3
Row 3:

str   | str    | fin2023 | str? | boolean?
------------------------------------------
Floor | Jansen | 1981    |      | t

Enter a command: add Mikael,Stanne,1974,,
Row prepended:

str    | str    | fin2023 | str? | boolean?
-------------------------------------------
Mikael | Stanne | 1974    |      |

Enter a command: get 1
Row 1:

str    | str    | fin2023 | str? | boolean?
-------------------------------------------
Mikael | Stanne | 1974    |      |

Enter a command: delete 1
Deleted row: 1.
Enter a command: get 1
Row 1:

str | str     | fin2023 | str? | boolean?
-----------------------------------------
Rob | Halford | 1951    |      |

Enter a command: quit
Goodbye.
```

这个例子的灵感来自于 [Type-Driven Development with Idris](https://www.manning.com/books/type-driven-development-with-idris) 一书中用作示例的类似程序。

我们想在这里重点关注几件事：

* 纯度：除了主程序循环之外，实现中使用的所有函数都应该是纯函数，在这种情况下，这意味着“不在任何具有副作用的 monad 中运行，例如 `IO`”。

* 尽早失败：除了命令解析器之外，所有更新表和处理查询的函数都应该以不会失败的方式输入和实现。


我们经常被建议遵守这两个准则，因为它们可以使我们的大多数函数更容易实现和测试。

由于我们允许我们库的用户为他们使用的表指定模式（列的顺序和类型），因此直到运行时才知道此信息。表的当前大小也是如此。因此，我们会将这两个值作为字段存储在依赖记录中。

### 为模式编码

我们需要在运行时检查表模式。尽管理论上可行，但不建议在此处直接对 Idris 类型进行操作。我们宁愿使用封闭的自定义数据类型来描述我们理解的列类型。在第一次尝试中，我们只支持一些 Idris 原语：

```idris
data ColType = I64 | Str | Boolean | Float

Schema : Type
Schema = List ColType
```

接下来，我们需要一种将 `Schema` 转换为 Idris 类型列表的方法，然后将其用作表示表中行的异构列表的索引：

```idris
IdrisType : ColType -> Type
IdrisType I64     = Int64
IdrisType Str     = String
IdrisType Boolean = Bool
IdrisType Float   = Double

Row : Schema -> Type
Row = HList . map IdrisType
```

我们现在可以将表描述为将表内容存储为行向量的依赖记录。为了安全地索引表的行并解析要添加的新行，必须在运行时知道表的当前模式和大小：

```idris
record Table where
  constructor MkTable
  schema : Schema
  size   : Nat
  rows   : Vect size (Row schema)
```

最后，我们定义了一个索引数据类型来描述对当前表进行操作的命令。使用当前表作为命令的索引允许我们确保访问和删除行的索引在界限内，并且新行与当前模式一致。这对于维护我们的第二个设计原则是必要的：所有在表上操作的函数都必须这样做，并且没有失败的可能性。

```idris
data Command : (t : Table) -> Type where
  PrintSchema : Command t
  PrintSize   : Command t
  New         : (newSchema : Schema) -> Command t
  Prepend     : Row (schema t) -> Command t
  Get         : Fin (size t) -> Command t
  Delete      : Fin (size t) -> Command t
  Quit        : Command t
```

我们现在可以实现主要的应用程序逻辑：用户输入的命令如何影响应用程序的当前状态。正如所承诺的那样，这没有失败的风险，因此我们不必将返回类型包装在 `Either` 中：

```idris
applyCommand : (t : Table) -> Command t -> Table
applyCommand t                 PrintSchema = t
applyCommand t                 PrintSize   = t
applyCommand _                 (New ts)    = MkTable ts _ []
applyCommand (MkTable ts n rs) (Prepend r) = MkTable ts _ $ r :: rs
applyCommand t                 (Get x)     = t
applyCommand t                 Quit        = t
applyCommand (MkTable ts n rs) (Delete x)  = case n of
  S k => MkTable ts k (deleteAt x rs)
  Z   => absurd x
```

请理解，`Command t` 的构造函数的类型使得索引始终在范围内（构造函数 `Get` 和 `Delete`），并且新行遵循到表的当前模式（构造函数 `Prepend`）。`

到目前为止你可能没有看到的一件事是最后一行对 `absurd` 的调用。这是 `Uninhabited` 接口的派生函数，用于描述诸如 `Void` 或 - 在上述情况下 - `Fin 0` 等类型，其中有可以没有价值。函数`absurd` 则只是爆炸原理的另一种表现。如果这还没有太大意义，请不要担心。我们将在下一章中介绍 `Void` 及其用法。

### 解析命令

用户输入验证是编写应用程序时的一个重要主题。如果它发生得早，您可以保持应用程序的大部分纯净（在这种情况下，这意味着：“没有失败的可能性”）并且可以证明是完全的。如果操作正确，此步骤将编码和处理程序中可能出现问题的大部分（可能不是全部）方式，从而使您能够提出明确的错误消息，告诉用户究竟是什么导致了问题。正如您自己所经历的那样，没有什么比一个有意义的计算机程序以无用的“发生错误”消息终止更令人沮丧的了。

因此，为了以应有的尊重对待这个重要的话题，我们首先要实现一个自定义错误类型。这对于小程序来说 *严格* 不是所必需的，但是一旦您的软件变得更加复杂，它对于跟踪可能出错的地方非常有帮助。为了找出可能出错的地方，我们首先需要决定如何输入命令。在这里，我们为每个命令使用一个关键字，以及由单个空格字符与关键字分隔的可选数量的参数。例如：`"new i64,boolean,str,str"`，用于使用新模式初始化空表。解决了这个问题，这里列出了可能出错的地方，以及我们想要打印的消息：

* 输入了虚假命令。我们使用我们不知道命令的消息以及我们知道的命令列表重复输入。

* 输入了无效的模式。在这种情况下，我们列出了第一个未知类型的位置、我们在那里找到的字符串以及我们知道的类型列表。

* 输入的行的 CSV 编码无效。我们列出了错误的位置、在那里遇到的字符串以及预期的类型。如果字段数量过少或过多，我们也会打印相应的错误消息。

* 索引超出范围。当用户尝试访问或删除特定行时，可能会发生这种情况。我们打印当前行数加上输入的值。

* 输入了不代表自然数的值作为索引。我们打印相应的错误消息。


有很多东西需要跟踪，所以让我们将其编码为和类型：

```idris
data Error : Type where
  UnknownCommand : String -> Error
  UnknownType    : (pos : Nat) -> String -> Error
  InvalidField   : (pos : Nat) -> ColType -> String -> Error
  ExpectedEOI    : (pos : Nat) -> String -> Error
  UnexpectedEOI  : (pos : Nat) -> String -> Error
  OutOfBounds    : (size : Nat) -> (index : Nat) -> Error
  NoNat          : String -> Error
```

为了方便地构造我们的错误消息，最好使用 Idris 的字符串插值工具：我们可以通过将任意字符串表达式括在花括号中，将它们括在字符串文字中，第一个必须用反斜杠转义。像这样：`"foo \{myExpr a b c}"`。我们可以将它与多行字符串文字配对以获得格式良好的错误消息。

```idris
showColType : ColType -> String
showColType I64      = "i64"
showColType Str      = "str"
showColType Boolean  = "boolean"
showColType Float    = "float"

showSchema : Schema -> String
showSchema = concat . intersperse "," . map showColType

allTypes : String
allTypes = concat
         . List.intersperse ", "
         . map showColType
         $ [I64,Str,Boolean,Float]

showError : Error -> String
showError (UnknownCommand x) = """
  Unknown command: \{x}.
  Known commands are: clear, schema, size, new, add, get, delete, quit.
  """

showError (UnknownType pos x) = """
  Unknown type at position \{show pos}: \{x}.
  Known types are: \{allTypes}.
  """

showError (InvalidField pos tpe x) = """
  Invalid value at position \{show pos}.
  Expected type: \{showColType tpe}.
  Value found: \{x}.
  """

showError (ExpectedEOI k x) = """
  Expected end of input.
  Position: \{show k}
  Input: \{x}
  """

showError (UnexpectedEOI k x) = """
  Unxpected end of input.
  Position: \{show k}
  Input: \{x}
  """

showError (OutOfBounds size index) = """
  Index out of bounds.
  Size of table: \{show size}
  Index: \{show index}
  Note: Indices start at 1.
  """

showError (NoNat x) = "Not a natural number: \{x}"
```

我们现在可以为不同的命令编写解析器。我们需要工具来解析向量索引、模式和 CSV 行。由于我们使用 CSV 格式对行进行编码和解码，因此也可以将模式编码为逗号分隔的值列表：

```idris
zipWithIndex : Traversable t => t a -> t (Nat, a)
zipWithIndex = evalState 1 . traverse pairWithIndex
  where pairWithIndex : a -> State Nat (Nat,a)
        pairWithIndex v = (,v) <$> get <* modify S

fromCSV : String -> List String
fromCSV = forget . split (',' ==)

readColType : Nat -> String -> Either Error ColType
readColType _ "i64"      = Right I64
readColType _ "str"      = Right Str
readColType _ "boolean"  = Right Boolean
readColType _ "float"    = Right Float
readColType n s          = Left $ UnknownType n s

readSchema : String -> Either Error Schema
readSchema = traverse (uncurry readColType) . zipWithIndex . fromCSV
```

我们还需要根据当前模式解码 CSV 内容。请注意，我们如何通过模式上的模式匹配以类型安全的方式做到这一点，直到运行时才知道。不幸的是，我们需要重新实现 CSV 解析，因为我们想将预期的类型添加到错误消息中（使用接口 `CSVLine` 和错误类型 `CSVError`）。

```idris
decodeField : Nat -> (c : ColType) -> String -> Either Error (IdrisType c)
decodeField k c s =
  let err = InvalidField k c s
   in case c of
        I64     => maybeToEither err $ read s
        Str     => maybeToEither err $ read s
        Boolean => maybeToEither err $ read s
        Float   => maybeToEither err $ read s

decodeRow : {ts : _} -> String -> Either Error (Row ts)
decodeRow s = go 1 ts $ fromCSV s
  where go : Nat -> (cs : Schema) -> List String -> Either Error (Row cs)
        go k []       []         = Right []
        go k []       (_ :: _)   = Left $ ExpectedEOI k s
        go k (_ :: _) []         = Left $ UnexpectedEOI k s
        go k (c :: cs) (s :: ss) = [| decodeField k c s :: go (S k) cs ss |]
```

关于是否将索引作为隐式参数传递没有硬性规定。一些考虑：

* 显式参数的模式匹配具有较少的语法开销。

* 如果大多数时候可以从上下文中推断出参数，请考虑将其作为隐式传递，以使您的函数更好地在客户端代码中使用。

* 对于大多数时候 Idris 无法推断的值，请使用显式（可能已删除）参数。


现在缺少的只是一种解析索引以访问当前表行的方法。我们使用索引的转换从 1 而不是 0 开始，这对于大多数非程序员来说感觉更自然。

```idris
readFin : {n : _} -> String -> Either Error (Fin n)
readFin s = do
  S k <- maybeToEither (NoNat s) $ parsePositive {a = Nat} s
    | Z => Left $ OutOfBounds n Z
  maybeToEither (OutOfBounds n $ S k) $ natToFin k n
```

我们终于能够为用户命令实现解析器。函数 `Data.String.words` 用于在空格字符处分割字符串。在大多数情况下，我们期望命令的名称加上一个没有额外空格的参数。但是，CSV 行可以有额外的空格字符，因此我们在拆分字符串上使用 `Data.String.unwords`。

```idris
readCommand :  (t : Table) -> String -> Either Error (Command t)
readCommand _                "schema"  = Right PrintSchema
readCommand _                "size"    = Right PrintSize
readCommand _                "quit"    = Right Quit
readCommand (MkTable ts n _) s         = case words s of
  ["new",    str] => New     <$> readSchema str
  "add" ::   ss   => Prepend <$> decodeRow (unwords ss)
  ["get",    str] => Get     <$> readFin str
  ["delete", str] => Delete  <$> readFin str
  _               => Left $ UnknownCommand s
```

### 运行应用程序

剩下要做的就是编写用于向用户打印命令结果的函数并循环运行应用程序，直到输入命令 `"quit"`。

```idris
encodeField : (t : ColType) -> IdrisType t -> String
encodeField I64     x     = show x
encodeField Str     x     = show x
encodeField Boolean True  = "t"
encodeField Boolean False = "f"
encodeField Float   x     = show x

encodeRow : (ts : List ColType) -> Row ts -> String
encodeRow ts = concat . intersperse "," . go ts
  where go : (cs : List ColType) -> Row cs -> Vect (length cs) String
        go []        []        = []
        go (c :: cs) (v :: vs) = encodeField c v :: go cs vs

result :  (t : Table) -> Command t -> String
result t PrintSchema = "Current schema: \{showSchema t.schema}"
result t PrintSize   = "Current size: \{show t.size}"
result _ (New ts)    = "Created table. Schema: \{showSchema ts}"
result t (Prepend r) = "Row prepended: \{encodeRow t.schema r}"
result _ (Delete x)  = "Deleted row: \{show $ FS x}."
result _ Quit        = "Goodbye."
result t (Get x)     =
  "Row \{show $ FS x}: \{encodeRow t.schema (index x t.rows)}"

covering
runProg : Table -> IO ()
runProg t = do
  putStr "Enter a command: "
  str <- getLine
  case readCommand t str of
    Left err   => putStrLn (showError err) >> runProg t
    Right Quit => putStrLn (result t Quit)
    Right cmd  => putStrLn (result t cmd) >>
                  runProg (applyCommand t cmd)

covering
main : IO ()
main = runProg $ MkTable [] _ []
```

### 练习第 3 部分

这里提出的挑战都涉及以几种有趣的方式增强我们的表格编辑器。其中一些更多的是风格问题，而不是学习编写依赖类型程序的问题，所以请随意解决这些问题。练习 1 到 3 应该被认为是强制性的。

1. 添加对在 CSV 列中存储 Idris 类型 `Integer` 和 `Nat` 的支持


2. 添加对 `Fin n` 到 CSV 列的支持。注意：我们需要运行时访问 `n` 才能使其工作。


3. 向 CSV 列添加对可选类型的支持。由于缺失值应该由空字符串编码，因此允许嵌套可选类型没有意义，这意味着应该允许 `Maybe Nat` 等类型，而 `Maybe (Maybe Nat)` 不被允许.


   提示：有几种编码方式，一种是
   为 `ColType` 添加一个布尔索引。

4. 添加用于打印整个表格的命令。如果所有列都正确对齐，则加分。


5. 添加对简单查询的支持：给定列号和值，列出条目与给定值匹配的所有行。


   这可能是一个挑战，因为类型变得非常有趣。

6. 添加对从磁盘加载和保存表的支持。表应存储在两个文件中：一个用于模式，一个用于 CSV 内容。


   注意：以可证明的全部方式读取文件可能很困难，这将成为另一天的话题。目前，
   只需使用从 `System.File` 导出的函数 `readFile`
   用于读取整个文件。
   这是一个偏函数，因为
   与无限输入一起使用时不会终止
   流，例如 `/dev/urandom` 或 `/dev/zero`。
   重要的是 *不能* 在此处使用 `assert_total`。
   使用像 `readFile` 这样的部分函数可能会强加
   现实世界应用程序中的安全风险，所以最终，
   我们必须处理这个问题并允许某种方式
   限制接受输入的大小。因此最好
   使这种偏见可见并注释所有下游
   相应地函数。

您可以在解决方案中找到这些添加的实现。可以在文件夹 `resources` 中找到一个小示例表。

注意：当然还有大量的项目要从这里开始，例如编写适当的查询语言、从现有行计算新行、在列中累积值、连接和压缩表等等。我们现在将停止，可能会在后面的示例中回到这一点。

## 结论

依赖对和记录对于在运行时检查定义我们使用的类型的值是必要的。通过对这些值进行模式匹配，我们可以了解其他值的类型和可能的形状，从而减少程序中潜在错误的数量。

在[下一章](Eq.md)中，我们开始学习如何编写数据类型，我们将其用作值之间某些契约成立的证据。这些最终将允许我们为函数参数和输出类型定义前置和后置条件。

<!-- vi: filetype=idris2
-->
