# IO：有副作用的编程

到目前为止，我们所有的例子和练习都是关于纯函数的。我们没有从文件读取或写入内容，也没有将任何消息写入标准输出。是时候改变这一点并学习如何在 Idris 中编写有效的程序了。

```idris
module Tutorial.IO

import Data.List1
import Data.String
import Data.Vect

import System.File

%default total
```

## 纯副作用？

如果我们再次查看 [介绍](Intro.md) 中的 *hello world* 示例，它具有以下类型和实现：

```idris
hello : IO ()
hello = putStrLn "Hello World!"
```

如果您在 REPL 会话中加载此模块并求值 `hello`，您将获得以下信息：

```repl
Tutorial.IO> hello
MkIO (prim__putStr "Hello World!")
```

这可能不是您所期望的，因为我们实际上希望程序只打印“Hello World！”。为了解释这里发生了什么，我们需要快速了解 REPL 的求值是如何工作的。

当我们在 REPL 中求值某个表达式时，Idris 会尝试将其减少为一个值，直到它卡在某个地方。在上述情况下，Idris 卡在函数 `prim__putStr` 上。这是在 *Prelude* 中定义的 *外部函数*，必须由每个后端实现才能在那里可用。在编译时（以及在 REPL 中），Idris 对外部函数的实现一无所知，因此无法减少外部函数调用，除非它们内置于编译器本身中。但即便如此，`IO a` 类型的值（`a` 是一个类型参数）通常不会减少。

重要的是要理解 `IO a` 类型的值 *描述* 一个程序，当 *执行* 时，在一路执行任意副作用之后，将返回 `a` 类型的值。例如，`putStrLn` 的类型为 `String -> IO ()`。将其读作：“`putStrLn` 是一个函数，当给定一个 `String` 参数时，它将返回一个输出类型为 `()` 的有效程序的描述”。 (`()` 是 `Unit` 类型的语法糖，在 *Prelude* 中定义的空元组，它只有一个值称为 `MkUnit`，我们也可以在我们的代码中使用 `()`。）

由于 `IO a` 类型的值仅仅是对有效计算的描述，因此返回此类值或将此类值作为参数的函数仍然是 *纯 * 并且因此是引用透明的。但是，不可能从 `IO a` 类型的值中提取 `a` 类型的值，也就是说，没有通用函数 `IO a -> a `，因为这样的函数在从其参数中提取结果时会无意中执行副作用，从而破坏引用透明度。 （实际上，确实 *有* 这样一个名为 `unsafePerformIO` 的函数。除非您知道自己在做什么，否则不要在代码中使用它。）

### Do 代码块

如果您是纯函数式编程的新手，那么您现在可能会——理所当然地——咕哝一些关于如果无法运行有效程序的描述是多么无用的话。所以，请听我说完。虽然我们在编写程序时无法运行 `IO a` 类型的值，也就是说，没有 `IO a -> a` 类型的函数，但我们能够链接这样的计算并描述更复杂的程序。 Idris 为此提供了特殊语法：*Do 代码块*。这是一个例子：

```idris
readHello : IO ()
readHello = do
  name <- getLine
  putStrLn $ "Hello " ++ name ++ "!"
```

在我们谈论这里发生的事情之前，让我们在 REPL 上试一试：

```repl
Tutorial.IO> :exec readHello
Stefan
Hello Stefan!
```

这是一个交互式程序，它将从标准输入 (`getLine`) 中读取一行，将结果赋值给变量 `name`，然后使用 `name` 创建一个友好的问候并将其写入标准输出。

注意 `readHello` 实现开始时的 `do` 关键字：它启动了一个 *do 代码块*，我们可以在其中链接 `IO` 计算和使用指向左侧的箭头 (`<-`) 将中间结果绑定到变量，然后可以在以后的 `IO` 操作中使用。这个概念足够强大，可以让我们将具有副作用的任意程序封装在 `IO` 类型的单个值中。然后可以通过函数 `main` 返回这样的描述，这是 Idris 程序的主入口点，当我们运行已编译的 Idris 二进制文件时，该程序正在执行。

### 程序描述和执行的区别

为了更好地理解 *描述* 有效计算和 *执行* 或 *运行* 之间的区别，这里有一个小程序：

```idris
launchMissiles : IO ()
launchMissiles = putStrLn "Boom! You're dead."

friendlyReadHello : IO ()
friendlyReadHello = do
  _ <- putStrLn "Please enter your name."
  readHello

actions : Vect 3 (IO ())
actions = [launchMissiles, friendlyReadHello, friendlyReadHello]

runActions : Vect (S n) (IO ()) -> IO ()
runActions (_ :: xs) = go xs
  where go : Vect k (IO ()) -> IO ()
        go []        = pure ()
        go (y :: ys) = do
          _ <- y
          go ys

readHellos : IO ()
readHellos = runActions actions
```

在我解释上面代码的作用之前，请注意 `runActions` 的实现中使用的函数 `pure`。它是一个受约束的函数，我们将在下一章中学习。专门用于 `IO`，它具有通用类型 `a -> IO a`：它允许我们将值包装在 `IO` 动作中。生成的 `IO` 程序将只返回包装后的值，而不会执行任何副作用。我们现在可以看一下 `readHellos` 中发生的事情的总体情况。

首先，我们定义了一个更友好的 `readHello` 版本：当执行时，它会明确询问我们的名字。由于我们将不再使用 `putStrLn` 的结果，因此我们可以在这里使用下划线作为包罗万象的模式。之后，调用 `readHello`。我们还定义了`launchMissiles`，执行时会导致地球毁灭。

现在，`runActions` 是我们用来证明 *描述* `IO` 动作与 *运行* 动作是不同的函数。它将从作为参数的非空向量中删除第一个动作，并返回一个新的 `IO` 动作，它描述了按顺序执行剩余的 `IO` 动作。如果这符合预期，则传递给 `runActions` 的第一个 `IO` 操作应连同其所有潜在副作用一起被静默删除。

当我们在 REPL 中执行 `readHellos` 时，我们会被要求输入我们的名字两次，尽管 `actions` 开头也包含 `launchMissiles`。幸运的是，虽然我们描述了如何摧毁地球，但行动并未执行，我们（可能）还在这里。

从这个例子中，我们学到了几件事：

* Values of type `IO a` are *pure descriptions* of programs, which,
  when being *executed*, perform arbitrary side effects before
  returning a value of type `a`.


* Values of type `IO a` can be safely returned from functions and
  passed around as arguments or in data structures, without
  the risk of them being executed.


* Values of type `IO a` can be safely combined in *do blocks* to
  *describe* new `IO` actions.


* An `IO` action will only ever get executed when it's passed to
  `:exec` at the REPL, or when it is the `main` function of
  a compiled Idris program that is being executed.


* It is not possible to ever break out of the `IO` context: There
  is no function of type `IO a -> a`, as such a function would
  need to execute its argument in order to extract the final
  result, and this would break referential transparency.


### 组合纯代码和 `IO` 动作

本小节的标题有些误导。 `IO` 动作 *是* 纯值，但这里通常的意思是我们将非 `IO` 函数与有效计算相结合。

作为演示，在本节中，我们将编写一个用于计算算术表达式的小程序。我们将保持简单，只允许具有单个运算符和两个参数的表达式，这两个参数都必须是整数，例如 `12 + 13`。

我们将使用 *base* 中 `Data.String` 中的函数 `split` 来标记算术表达式。然后我们尝试解析两个整数值和运算符。这些操作可能会失败，因为用户输入可能无效，所以我们还需要一个错误类型。我们实际上可以只使用 `String`，但我认为对错误条件使用自定义求和类型是一种好习惯。

```idris
data Error : Type where
  NotAnInteger    : (value : String) -> Error
  UnknownOperator : (value : String) -> Error
  ParseError      : (input : String) -> Error

dispError : Error -> String
dispError (NotAnInteger v)    = "Not an integer: " ++ v ++ "."
dispError (UnknownOperator v) = "Unknown operator: " ++ v ++ "."
dispError (ParseError v)      = "Invalid expression: " ++ v ++ "."
```

为了解析整数字面量，我们使用来自 `Data.String` 的函数 `parseInteger`：

```idris
readInteger : String -> Either Error Integer
readInteger s = maybe (Left $ NotAnInteger s) Right $ parseInteger s
```

同样，我们声明并实现了一个解析算术运算符的函数：

```idris
readOperator : String -> Either Error (Integer -> Integer -> Integer)
readOperator "+" = Right (+)
readOperator "*" = Right (*)
readOperator s   = Left (UnknownOperator s)
```

我们现在准备解析和求值简单的算术表达式。这包括几个步骤（拆分输入字符串，解析每个字面量），每个步骤都可能失败。稍后，当我们了解 monad 时，我们会看到 do 块也可以在这种情况下使用。但是，在这种情况下，我们可以使用另一种语法便利：let 绑定中的模式匹配。这是代码：

```idris
eval : String -> Either Error Integer
eval s =
  let [x,y,z]  := forget $ split isSpace s | _ => Left (ParseError s)
      Right v1 := readInteger x  | Left e => Left e
      Right op := readOperator y | Left e => Left e
      Right v2 := readInteger z  | Left e => Left e
   in Right $ op v1 v2
```

让我们分解一下。在第一行，我们在所有出现的空格处拆分输入字符串。由于 `split` 返回 `List1` （从 *base* 中的 `Data.List1` 导出的非空列表的类型），但用 `List`更方便，我们使用`Data.List1.forget` 转换结果。请注意，我们如何在赋值运算符 `:=` 的左侧使用模式匹配。这是一个部分模式匹配（*部分* 的意思，它没有涵盖所有可能的情况），因此我们还必须处理其他可能性，这是在垂直线之后完成的。可以这样理解：“如果左侧的模式匹配成功，并且我们得到一个正好包含三个标记的列表，则继续使用 `let` 表达式，否则立即返回 在 `Left` 中的 `ParseError` "。

其他三行的行为完全相同：每一行在左侧都有一个部分模式匹配，指示在竖线后输入无效时返回的内容。我们稍后会看到，这种语法也可以在 *do blocks* 中使用。

请注意，到目前为止实现的所有功能都是 *纯的*，也就是说，它没有描述具有副作用的计算。 （有人可能会争辩说，失败的可能性已经是可观察到的 *副作用*，但即便如此，上面的代码仍然是引用透明的，可以在 REPL 轻松测试，并在编译时求值，这是这里很重要。）

最后，我们可以将此功能包装在 `IO` 操作中，该操作从标准输入读取字符串并尝试计算算术表达式：

```idris
exprProg : IO ()
exprProg = do
  s <- getLine
  case eval s of
    Left err  => do
      putStrLn "An error occured:"
      putStrLn (dispError err)
    Right res => putStrLn (s ++ " = " ++ show res)
```

请注意，在 `exprProg` 中，我们如何被迫处理失败的可能性并以不同方式处理 `Either` 的两个构造函数以打印结果。还要注意，*do blocks* 是普通表达式，例如，我们可以在 case 表达式的右侧开始一个新的 *do block*。

### 练习第 1 部分

在这些练习中，您将实现一些小型命令行应用程序。其中一些可能会永远运行，因为它们只会在用户输入退出应用程序的关键字时停止。这样的程序不再是可证明的全部。如果您在源文件的顶部添加了 `%default total` 杂注，则需要使用 `covering` 注释这些函数，这意味着您涵盖了所有模式匹配中的所有情况，但由于不受限制的递归，您的程序可能仍会循环。

1. Implement function `rep`, which will read a line
   of input from the terminal, evaluate it using the
   given function, and print the result to standard output:


   ```idris
   rep : (String -> String) -> IO ()
   ```

2. Implement function `repl`, which behaves just like `rep`
   but will repeat itself forever (or until being forcefully
   terminated):


   ```idris
   covering
   repl : (String -> String) -> IO ()
   ```

3. Implement function `replTill`, which behaves just like `repl`
   but will only continue looping if the given function returns
   a `Right`. If it returns a `Left`, `replTill` should print
   the final message wrapped in the `Left` and then stop.


   ```idris
   covering
   replTill : (String -> Either String String) -> IO ()
   ```

4. Write a program, which reads arithmetic
   expressions from standard input, evaluates them
   using `eval`, and prints the result to standard
   output. The program should loop until
   users stops it by entering "done", in which case
   the program should terminate with a friendly greeting.
   Use `replTill` in your implementation.


5. Implement function `replWith`, which behaves just like `repl`
   but uses some internal state to accumulate values.
   At each iteration (including the very first one!),
   the current state should be printed
   to standard output using function `dispState`, and
   the next state should be computed using function `next`.
   The loop should terminate in case of a `Left` and
   print a final message using `dispResult`:


   ```idris
   covering
   replWith :  (state      : s)
            -> (next       : s -> String -> Either res s)
            -> (dispState  : s -> String)
            -> (dispResult : res -> s -> String)
            -> IO ()
   ```

6. Use `replWith` from Exercise 5 to write a program
   for reading natural numbers from standard input and
   printing the accumulated sum of these numbers.
   The program should terminate in case of invalid input
   and if a user enters "done".


## Do 语法块，脱糖

这里有一条重要信息：*do blocks* 没有什么特别之处。它们只是语法糖，被转换为一系列运算符应用程序。使用 [语法糖](https://en.wikipedia.org/wiki/Syntactic_sugar)，我们指的是一种编程语言中的语法，它可以更容易地用该语言表达某些事物，而不会使语言本身更强大或更具表现力。在这里，这意味着您可以编写所有 `IO` 程序而不使用 `do` 符号，但是您编写的代码有时会更难阅读，因此 *do blocks* 为这些场合提供更好的语法。

考虑以下示例程序：

```idris
sugared1 : IO ()
sugared1 = do
  str1 <- getLine
  str2 <- getLine
  str3 <- getLine
  putStrLn (str1 ++ str2 ++ str3)
```

*在消除函数名称歧义和类型检查之前*，编译器会将其转换为以下程序：

```idris
desugared1 : IO ()
desugared1 =
  getLine >>= (\str1 =>
    getLine >>= (\str2 =>
      getLine >>= (\str3 =>
        putStrLn (str1 ++ str2 ++ str3)
      )
    )
  )
```

在 `desugared1` 的实现中有一个称为 *bind* 的新运算符 (`(>>=)`)。如果您在 REPL 中查看它的类型，您将看到以下内容：

```repl
Main> :t (>>=)
Prelude.>>= : Monad m => m a -> (a -> m b) -> m b
```

这是一个受约束的函数，需要一个名为 `Monad` 的接口。我们将在下一章讨论 `Monad` 和它的一些朋友。专门针对`IO`，*bind*有以下类型：

```repl
Main> :t (>>=) {m = IO}
>>= : IO a -> (a -> IO b) -> IO b
```

这描述了 `IO` 动作的顺序。执行时，第一个 `IO` 动作正在运行，其结果作为参数传递给生成第二个 `IO` 动作的函数，然后也将执行该动作。

您可能还记得，您已经在之前的练习中实现了类似的东西：在 [代数数据类型](DataTypes.md) 中，您为 `Maybe` 和 `Either e` 实现了 *bind* 。我们将在下一章中了解到，`Maybe` 和 `Either e` 也都带有 `Monad` 的实现。现在，可以说 `Monad` 允许我们通过将第一次计算的 返回 *结果* 传递给第二次计算的函数来按顺序运行具有某种副作用的计算。在 `desugared1` 中，您可以看到，我们如何首先执行 `IO` 动作并使用其结果来计算下一个 `IO` 动作等等。代码有点难以阅读，因为我们使用了多层嵌套匿名函数，这就是为什么在这种情况下，*do 块* 是表达相同功能的不错选择。

由于 *do 块* 总是与应用的 *bind* 运算符序列脱糖，因此我们可以使用它们链接任何一元计算。例如，我们可以使用 *do 块 * 重写函数 `eval`，如下所示：

```idris
evalDo : String -> Either Error Integer
evalDo s = case forget $ split isSpace s of
  [x,y,z] => do
    v1 <- readInteger x
    op <- readOperator y
    v2 <- readInteger z
    Right $ op v1 v2
  _       => Left (ParseError s)
```

别担心，如果这还没有太大意义。我们将看到更多示例，您很快就会掌握其中的窍门。要记住的重要一点是 *do 块* 总是转换为 *bind* 运算符的序列，如 `desugared1` 所示。

### Unit 绑定

还记得我们对 `friendlyReadHello` 的实现吗？这里又是：

```idris
friendlyReadHello' : IO ()
friendlyReadHello' = do
  _ <- putStrLn "Please enter your name."
  readHello
```

那里的下划线有点丑陋和不必要。事实上，一个常见的用例是将有效计算与结果类型 `Unit` (`()`) 链接起来，只是为了它们执行的副作用。例如，我们可以重复 `friendlyReadHello` 三次，如下所示：

```idris
friendly3 : IO ()
friendly3 = do
  _ <- friendlyReadHello
  _ <- friendlyReadHello
  friendlyReadHello
```

这是很常见的事情，Idris 允许我们完全放弃绑定的下划线：

```idris
friendly4 : IO ()
friendly4 = do
  friendlyReadHello
  friendlyReadHello
  friendlyReadHello
  friendlyReadHello
```

但是请注意，上述内容的脱糖略有不同：

```idris
friendly4Desugared : IO ()
friendly4Desugared =
  friendlyReadHello >>
  friendlyReadHello >>
  friendlyReadHello >>
  friendlyReadHello
```

运算符 `(>>)` 具有以下类型：

```repl
Main> :t (>>)
Prelude.>> : Monad m => m () -> Lazy (m b) -> m b
```

注意类型签名中的 `Lazy` 关键字。这意味着，包装的参数将被 *延迟求值*。这在很多场合都是有道理的。例如，如果所讨论的 `Monad` 是 `Maybe` 如果第一个参数是 `Nothing`，那么结果将是 `Nothing`，在这种情况下甚至不需要求值第二个参数。

### Do和重载

因为 Idris 支持函数和运算符重载，我们可以编写自定义的 *bind* 运算符，这允许我们对没有实现 `Monad` 的类型使用 *do notation*。例如，这是 `(>>=)` 的自定义实现，用于对返回向量的计算进行排序。第一个向量（长度为 `m`）中的每个值都将转换为长度为 `n` 的向量，结果将被连接到长度为 `m * n ` 的向量：

```idris
flatten : Vect m (Vect n a) -> Vect (m * n) a
flatten []        = []
flatten (x :: xs) = x ++ flatten xs

(>>=) : Vect m a -> (a -> Vect n b) -> Vect (m * n) b
as >>= f = flatten (map f as)
```

无法编写封装此行为的 `Monad` 的实现，因为类型不匹配：专用于 `Vect` 的 Monadic *bind* 具有类型 `Vect k a -> (a -> Vect k b) -> Vect k b`。如您所见，所有三个 `Vect` 的大小必须相同，这不是我们在自定义版本的 *bind* 中表达的。下面是一个例子，可以看到这一点：

```idris
modString : String -> Vect 4 String
modString s = [s, reverse s, toUpper s, toLower s]

testDo : Vect 24 String
testDo = IO.do
  s1 <- ["Hello", "World"]
  s2 <- [1, 2, 3]
  modString (s1 ++ show s2)
```

尝试通过手动对 `testDo` 进行脱糖，然后将其结果与您在 REPL 中的预期结果进行比较来弄清楚 `testDo` 是如何工作的。请注意，我们如何帮助 Idris 消除歧义，通过在 `do` 关键字前加上运算符名称空间的一部分来使用哪个版本的 *bind* 运算符。在这种情况下，这不是绝对必要的，虽然 `Vect k` 确实有 `Monad` 的实现，但知道它可以帮助编译器消除歧义对 do 语法块来说仍然是件好事。

当然，如果我们想重载 *do 语法块* 的行为，我们可以（并且应该！）重载 `(>>)` 和 `(>>=)`。

#### 模块和命名空间

每个数据类型、函数或运算符都可以通过为其 *命名空间* 加上前缀来明确标识。函数的命名空间通常与定义它的模块相同。例如，函数 `eval` 的完全限定名称将是 `Tutorial.IO.eval`。函数和运算符名称在其命名空间中必须是唯一的。

正如我们已经了解到的那样，Idris 通常可以消除具有相同名称但根据所涉及的类型在不同命名空间中定义的函数之间的歧义。如果这还是不行的话，我们可以通过 *前缀* 使用完整命名空间的 *后缀* 的函数或运算符名称来帮助编译器。让我们在 REPL 上演示一下：

```repl
Tutorial.IO> :t (>>=)
Prelude.>>= : Monad m => m a -> (a -> m b) -> m b
Tutorial.IO.>>= : Vect m a -> (a -> Vect n b) -> Vect (m * n) b
```

如您所见，如果我们在 REPL 会话中加载此模块并检查 `(>>=)` 的类型，我们会得到两个结果，因为具有此名称的两个运算符都在范围内。如果我们只希望 REPL 打印我们自定义的 *bind* 运算符的类型，那么在它前面加上 `IO` 就足够了，尽管我们也可以在它前面加上完整的命名空间：

```repl
Tutorial.IO> :t IO.(>>=)
Tutorial.IO.>>= : Vect m a -> (a -> Vect n b) -> Vect (m * n) b
Tutorial.IO> :t Tutorial.IO.(>>=)
Tutorial.IO.>>= : Vect m a -> (a -> Vect n b) -> Vect (m * n) b
```

由于函数名称在它们的命名空间中必须是唯一的，而且我们仍然可能希望在 Idris 模块中定义函数的两个重载版本，因此 Idris 可以为模块添加额外的命名空间。例如，为了定义另一个名为 `eval` 的函数，我们需要将它添加到它自己的命名空间中（注意，命名空间中的所有定义必须缩进相同数量的空格）：

```idris
namespace Foo
  export
  eval : Nat -> Nat -> Nat
  eval = (*)

-- prefixing `eval` with its namespace is not strictly necessary here
testFooEval : Nat
testFooEval = Foo.eval 12 100
```

现在，这里有一件重要的事情：对于要从其命名空间或模块外部访问的函数和数据类型，需要通过使用 `export` 或 `public export` 关键字注释它们来 *导出*。

`export` 和 `public export` 的区别如下：用 `export` 注解的函数导出其类型，可以从其他命名空间调用。使用 `export` 注释的数据类型导出其类型构造函数，但不导出其数据构造函数。使用 `public export` 注释的函数也会导出其实现。这是在编译时计算中使用该函数所必需的。使用 `public export` 注释的数据类型也会导出其数据构造函数。

通常，请考虑使用 `public export` 注释数据类型，否则您将无法创建这些类型的值或在模式匹配中解构它们。同样，除非您打算在编译时计算中使用您的函数，否则请使用 `export` 注释它们。

### 绑定，砰的一声

有时，即使是 *do 块* 也过于嘈杂，无法表达有效计算的组合。在这种情况下，我们可以在副作用部分前面加上一个感叹号（如果它们包含额外的空格，则将它们括在括号中），同时保持纯表达式不变：

```idris
getHello : IO ()
getHello = putStrLn $ "Hello " ++ !getLine ++ "!"
```

上面的内容被分解为以下 *do 块*：

```idris
getHello' : IO ()
getHello' = do
  s <- getLine
  putStrLn $ "Hello " ++ s ++ "!"
```

这是另一个例子：

```idris
bangExpr : String -> String -> String -> Maybe Integer
bangExpr s1 s2 s3 =
  Just $ !(parseInteger s1) + !(parseInteger s2) * !(parseInteger s3)
```

这是脱糖的 *do 块*：

```idris
bangExpr' : String -> String -> String -> Maybe Integer
bangExpr' s1 s2 s3 = do
  x1 <- parseInteger s1
  x2 <- parseInteger s2
  x3 <- parseInteger s3
  Just $ x1 + x2 * x3
```

请记住以下几点： 已引入语法糖以使代码更具可读性或更方便编写。如果它被滥用只是为了展示你有多聪明，你会让其他人（包括你未来的自己！）阅读和试图理解你的代码变得更加困难。

### 练习第 2 部分

1. Reimplement the following *do blocks*, once by using
   *bang notation*, and once by writing them in their
   desugared form with nested *bind*s:


   ```idris
   ex1a : IO String
   ex1a = do
     s1 <- getLine
     s2 <- getLine
     s3 <- getLine
     pure $ s1 ++ reverse s2 ++ s3

   ex1b : Maybe Integer
   ex1b = do
     n1 <- parseInteger "12"
     n2 <- parseInteger "300"
     Just $ n1 + n2 * 100
   ```

2. Below is the definition of an indexed family of types,
   the index of which keeps track of whether the value in
   question is possibly empty or provably non-empty:


   ```idris
   data List01 : (nonEmpty : Bool) -> Type -> Type where
     Nil  : List01 False a
     (::) : a -> List01 False a -> List01 ne a
   ```

   请注意，`Nil` 分支 *必须* 有一个值为 `False` 的 `nonEmpty` 标签，而在 *cons* 的情况下，这是可选的。因此，`List01 False a` 可以为空或非空，
   我们只会通过模式找出匹配它的情况。 另一方面， `List01 True a` *必须* 是 *cons*，对于 `Nil` 的情况， `nonEmpty` 标签应始终设置为 `False`。

   1. Declare and implement function `head` for non-empty lists:


      ```idris
      head : List01 True a -> a
      ```

   2. Declare and implement function `weaken` for converting any `List01 ne a`
      to a `List01 False a` of the same length and order
      of values.


   3. Declare and implement function `tail` for extracting the possibly
      empty tail from a non-empty list.


   4. Implement function `(++)` for concatenating two
      values of type `List01`. Note, how we use a type-level computation
      to make sure the result is non-empty if and only if
      at least one of the two arguments is non-empty:


      ```idris
      (++) : List01 b1 a -> List01 b2 a -> List01 (b1 || b2) a
      ```

   5. Implement utility function `concat'` and use it in
      the implementation of `concat`. Note, that in `concat` the
      two boolean tags are passed as unrestricted implicits,
      since you will need to pattern match on these to determine
      whether the result is provably non-empty or not:


      ```idris
      concat' : List01 ne1 (List01 ne2 a) -> List01 False a

      concat :  {ne1, ne2 : _}
             -> List01 ne1 (List01 ne2 a)
             -> List01 (ne1 && ne2) a
      ```

   6. Implement `map01`:


      ```idris
      map01 : (a -> b) -> List01 ne a -> List01 ne b
      ```

   7. Implement a custom *bind* operator in namespace `List01`
      for sequencing computations returning `List01`s.


      提示：在你的实现中使用 `map01` 和 `concat`
      确保在必要时使用不受限制的隐式。

      您可以使用以下示例来测试您的
      自定义 *bind* 运算符：

      ```idris
      -- this and lf are necessary to make sure, which tag to use
      -- when using list literals
      lt : List01 True a -> List01 True a
      lt = id

      lf : List01 False a -> List01 False a
      lf = id

      test : List01 True Integer
      test = List01.do
        x  <- lt [1,2,3]
        y  <- lt [4,5,6,7]
        op <- lt [(*), (+), (-)]
        [op x y]

      test2 : List01 False Integer
      test2 = List01.do
        x  <- lt [1,2,3]
        y  <- Nil {a = Integer}
        op <- lt [(*), (+), (-)]
        lt [op x y]
      ```

练习 2 的一些注意事项：在这里，我们将 `List` 和 `Data.List1` 的函数组合在一个索引类型族中。这使我们能够正确处理列表连接：如果至少有一个参数可证明是非空的，则结果也是非空的。为了用 `List` 和 `List1` 正确解决这个问题，总共需要编写四个连接函数。因此，虽然通常可以定义不同的数据类型而不是索引族，但后者允许我们执行类型级计算，以更精确地了解我们编写的函数的前置条件和后置条件，但代价是更复杂类型签名。此外，有时不可能仅从数据值的模式匹配中导出索引的值，因此必须将它们作为未擦除（可能是隐式）参数传递。

请记住，首先对 *do 块* 进行脱糖，然后再进行类型检查、消除使用哪个 *bind* 运算符的歧义以及填充隐式参数。因此，使用任意约束或隐式参数定义 *bind* 运算符是非常好的，如上所示。 Idris 将脱糖 *do 块* *之后*处理所有细节。

## 使用文件

*base* 库中的模块 `System.File` 导出处理文件句柄和读取和写入文件所需的实用程序。当您有一个文件路径（例如“/home/hock/idris/tutorial/tutorial.ipkg”）时，我们通常会做的第一件事是尝试创建一个文件句柄（类型为 `System.File. File` 通过调用 `fileOpen`）。

这是一个计算 Unix/Linux 文件中所有空行的程序：

```idris
covering
countEmpty : (path : String) -> IO (Either FileError Nat)
countEmpty path = openFile path Read >>= either (pure . Left) (go 0)
  where covering go : Nat -> File -> IO (Either FileError Nat)
        go k file = do
          False <- fEOF file | True => closeFile file $> Right k
          Right "\n" <- fGetLine file
            | Right _  => go k file
            | Left err => closeFile file $> Left err
          go (k + 1) file
```

在上面的示例中，我调用了 `(>>=)` 而不启动 *do 块*。确保你了解这里发生了什么。阅读简洁的函数代码对于理解其他人的代码很重要。查看 REPL 中的函数 `either`，尝试弄清楚 `(pure . Left)` 做了什么，并注意我们如何使用 `go` 的柯里化版本`either` 的第二个参数。

函数 `go` 需要一些额外的解释。首先，请注意我们如何使用与 `let` 绑定相同的语法来进行模式匹配中间结果。如您所见，我们可以使用多个垂直条来处理多个附加模式。为了从文件中读取单行，我们使用函数 `fGetLine`。与使用文件系统的大多数操作一样，此函数可能会因 `FileError` 而失败，我们必须正确处理。另请注意，`fGetLine` 将返回包含其尾随换行符 `'\n'` 的行，因此为了检查空行，我们必须匹配 `"\ n"` 而不是空字符串 `""`。

最后，`go` 不能被证明是完全的并且是正确的。像 `/dev/urandom` 或 `/dev/zero` 这样的文件提供了无限的数据流，所以当使用这样的文件路径调用时，`countEmpty` 永远不会终止。

### 安全资源处理

注意，我们必须手动打开和关闭 `countEmpty` 中的文件句柄。这是容易出错且乏味的。资源处理是一个很大的话题，这里肯定不赘述，但是从`System.File`导出一个方便的函数：`withFile`，处理打开，为我们关闭和处理文件错误。

```idris
covering
countEmpty' : (path : String) -> IO (Either FileError Nat)
countEmpty' path = withFile path Read pure (go 0)
  where covering go : Nat -> File -> IO (Either FileError Nat)
        go k file = do
          False <- fEOF file | True => pure (Right k)
          Right "\n" <- fGetLine file
            | Right _  => go k file
            | Left err => pure (Left err)
          go (k + 1) file
```

来吧，看看 `withFile` 的类型，然后看看我们如何使用它来简化 `countEmpty'` 的实现。在学习 Idris 编程时，阅读和理解稍微复杂的函数类型很重要。

#### `HasIO` 接口

当您查看我们目前使用的 `IO` 函数时，您会注意到大多数（如果不是全部）实际上不适用于 `IO` 本身，而是使用类型参数 `io`，约束为 `HasIO`。该接口允许我们将 *提升* 类型为 `IO a` 的值放入另一个上下文中。我们将在后面的章节中看到这方面的用例，尤其是当我们谈论 monad 转换器时。现在，您可以将这些 `io` 参数视为专用于 `IO`。

### 练习第 3 部分

1. As we have seen in the examples above, `IO` actions
   working with file handles often come with the risk
   of failure. We can therefore simplify things by
   writing some utility functions and a custom *bind*
   operator to work with these nested effects. In
   a new namespace `IOErr`, implement the following
   utility functions and use these to further cleanup
   the implementation of `countEmpty'`:


   ```idris
   pure : a -> IO (Either e a)

   fail : e -> IO (Either e a)

   lift : IO a -> IO (Either e a)

   catch : IO (Either e1 a) -> (e1 -> IO (Either e2 a)) -> IO (Either e2 a)

   (>>=) : IO (Either e a) -> (a -> IO (Either e b)) -> IO (Either e b)

   (>>) : IO (Either e ()) -> Lazy (IO (Either e a)) -> IO (Either e a)
   ```

2. Write a function `countWords` for counting the words in a file.
   Consider using `Data.String.words` and the utilities from
   exercise 1 in your implementation.


3. We can generalize the functionality used in `countEmpty`
   and `countWords`, by implementing a helper function for
   iterating over the lines in a file and accumulating some
   state along the way. Implement `withLines` and use it to
   reimplement `countEmpty` and `countWords`:


   ```idris
   covering
   withLines :  (path : String)
             -> (accum : s -> String -> s)
             -> (initialState : s)
             -> IO (Either FileError s)
   ```

4. We often use a `Monoid` for accumulating values.
   It is therefore convenient to specialize `withLines`
   for this case. Use `withLines` to implement
   `foldLines` according to the type given below:


   ```idris
   covering
   foldLines :  Monoid s
             => (path : String)
             -> (f    : String -> s)
             -> IO (Either FileError s)
   ```

5. Implement function `wordCount` for counting
   the number of lines, words, and characters in
   a text document. Define a custom record type
   together with an implementation of `Monoid`
   for storing and accumulating these values
   and use `foldLines` in your implementation of
   `wordCount`.


## `IO` 是如何实现的

在已经很长的一章的最后一节中，我们将冒险看一眼 `IO` 在 Idris 中是如何实现的。有趣的是，`IO` 不是内置类型，而是只有一个小特性的常规数据类型。让我们在 REPL 中了解它：

```repl
Tutorial.IO> :doc IO
data PrimIO.IO : Type -> Type
  Totality: total
  Constructor: MkIO : (1 _ : PrimIO a) -> IO a
  Hints:
    Applicative IO
    Functor IO
    HasLinearIO IO
    Monad IO
```

在这里，我们了解到 `IO` 有一个名为 `MkIO` 的单个数据构造函数，它采用类型为 `PrimIO a` 的单个参数，定量为 *1* .我们不打算在这里讨论定量，因为事实上它们对于理解 `IO` 的工作原理并不重要。

现在，`PrimIO a` 是以下函数的类型别名：

```repl
Tutorial.IO> :printdef PrimIO
PrimIO.PrimIO : Type -> Type
PrimIO a = (1 _ : %World) -> IORes a
```

同样，不要介意定量。只缺少一块拼图：`IORes a`，这是一种公开导出的记录类型：

```repl
Solutions.IO> :doc IORes
data PrimIO.IORes : Type -> Type
  Totality: total
  Constructor: MkIORes : a -> (1 _ : %World) -> IORes a
```

所以，总而言之，`IO` 是一个类似于以下函数类型的包装器：

```repl
%World -> (a, %World)
```

您可以将类型 `%World` 视为程序外部世界状态（文件系统、内存、网络连接等）的占位符。从概念上讲，要执行 `IO a` 动作，我们将世界的当前状态传递给它，并作为回报获得更新的世界状态加上 `a` 类型的结果。正在更新的世界状态代表了计算机程序中可描述的所有副作用。

现在，重要的是要了解世界上没有 *状态* 这样的东西。 `%World` 类型只是一个占位符，它被转换为某种常量，在运行时不会被检查。因此，如果我们有一个 `%World` 类型的值，我们可以将它传递给 `IO a` 动作并执行它，这正是运行时发生的情况：类型 `%World`（一个无趣的占位符，如 `null`、`0`，或者 - 如果是 JavaScript 后端 - `undefined`）被传递给`main` 函数，从而使整个程序运行起来。但是，不可能以编程方式创建 `%World` 类型的值（它是一种抽象的原始类型），因此我们永远无法从 `IO a` 动作中提取 `a`（模 `unsafePerformIO`）。

一旦我们将讨论 monad 转换器和状态 monad，你会发现 `IO` 只不过是一个伪装的状态 monad，但具有抽象的状态类型，这使得我们无法运行有状态计算.

## 结论

* Values of type `IO a` describe programs with side effects,
  which will eventually result in a value of type `a`.


* While we cannot safely extract a value of type `a`
  from an `IO a`, we can use several combinators and
  syntactic constructs to combine `IO` actions and
  build more-complex programs.


* *Do blocks* offer a convenient way to run and combine
  `IO` actions sequentially.


* *Do blocks* are desugared to nested applications of
  *bind* operators (`(>>=)`).


* *Bind* operators, and thus *do blocks*, can be overloaded
  to achieve custom behavior instead of the default
  (monadic) *bind*.


* Under the hood, `IO` actions are stateful computations
  operating on a symbolic `%World` state.


### 下一步是什么

现在，我们已经了解了 *monads* 和 *bind* 运算符，是时候在 [下一章](Functor.md) 中介绍 `Monad` 和一些和现实世界相关的接口。

<!-- vi: filetype=idris2
-->
