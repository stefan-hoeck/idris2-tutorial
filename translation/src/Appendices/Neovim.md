# Neovim 中的交互式编辑

Idris 提供了广泛的交互功能
来分析我们程序中的值和表达式的类型
并填写骨架实现，有时甚至根据提供的类型为我们提供完整的的程序。这些交互
编辑功能可通过不同编辑器中的插件获得。
由于我是 Neovim 用户，我会详细解释一下我自己的设置中 Idris 的相关部分。

Neovim 中运行所有这些功能所需的主要组件是由 [idris2-lsp](https://github.com/idris-community/idris2-lsp) 项目提供的可执行文件。
此可执行文件内部使用 Idris 编译器 API（应用程序编程接口），可以检查语法和
我们正在处理的源代码的类型。它与
Neovim 通过语言服务器协议 (LSP)。这种沟通由 [idris2-nvim](https://github.com/ShinKage/idris2-nvim) 
插件来完成 。

正如我们将在本教程中看到的，`idris2-lsp` 可执行文件不仅
支持语法和类型检查，但还附带额外的
交互式编辑功能。最后，Idris 编译器 API 支持
Idris 源代码的语义高亮：标识符和关键字
突出显示不仅基于语言的语法（这将
成为 *语法高亮*，所有现代编程环境和编辑器都预期会有的功能），也基于它们的
*语义*。例如，函数实现中的局部变量
以不同于顶级函数名称的方式突出显示，
尽管从语法上讲，它们都只是标识符。

```idris
module Appendices.Neovim

import Data.Vect

%default total
```

## 设置

为了充分利用交互式 Idris 编辑
Neovim，至少需要安装以下工具：

* A recent version of Neovim (version 0.5 or later).
* A recent version of the Idris compiler (at least version 0.5.1).
* The Idris compiler API.
* The [idris2-lsp](https://github.com/idris-community/idris2-lsp) package.
* 以下 Neovim 插件：
  * [idris2-nvim](https://github.com/ShinKage/idris2-nvim)
  * [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)

`idris2-lsp` 项目提供了有关如何使用的详细说明
安装 Idris 2 及其标准库和编译器
API。确保遵循这些说明，以便您的编译器和 `idris2-lsp` 可执行文件是同步的。

如果你是 Neovim 的新手，你可能想要使用 `resource` 文件夹中提供的 `init.vim` 文件。在这种情况下，
已经包含了必要的 Neovim 插件，但您需要安装
[vim-plug](https://github.com/junegunn/vim-plug)，一个插件管理器。
之后，将 `resources/init.vim` 的全部或部分复制到你自己的 `init.vim`
文件。 （在 Neovim 中使用 `:help init.vim` 来查找
在哪里可以找到这个文件。）。设置好 `init.vim` 文件后，重启 Neovim 并运行 `:PlugUpdate` 安装
必要的插件。

## 常见的工作流程

为了检查可供我们使用的交互式编辑功能
，我们将重新实现一些来自 *Prelude* 的小型实用程序。跟随我到这一步，你应该已经完成了[介绍](../Tutorial/Intro.md)，
[函数第 1 部分](../Tutorial/Functions1.md)，并且至少
[代数数据类型](../Tutorial/DataTypes.md) 的一部分，否则很难理解这里发生了什么。

在开始之前，请注意这里显示的命令和操作在编辑源文件后教程可能无法正常工作
引用没有将您的更改写入磁盘。因此，第一件事是
如果这里描述的东西不起作用，你应该尝试，快速保存当前文件（`:w`）。

让我们从布尔值的否定开始：

```idris
negate1 : Bool -> Bool
```

通常，在编写 Idris 代码时，我们遵循“类型优先”准则。虽然您可能已经知道如何实现某一功能，但在开始编写实现之前，仍然需要提供准确的类型。这意味着，在 Idris 中编程时，我们需要在脑海中跟踪算法的实现以及同时涉及的类型，两者都有可能会变得异常复杂。我们还可以吗？请记住，请记住，Idris 至少和我们一样了解当前函数实现上下文中可用的变量及其类型，因此我们可能应该向Idris寻求指导，而不是尝试自己做所有事情。

所以，为了继续，我们向 Idris 请求一个骨架函数体：在普通编辑器模式下，将光标移动到 `negate1` 声明并快速输入 `<LocalLeader>a`。 `<LocalLeader>` 是可以在 `init.vim` 文件中指定的特殊键。如果你使用 `resources` 文件夹中的 `init.vim`，它被设置为
逗号字符 (`,`)，在这种情况下，上面的命令由一个逗号后跟小写字母“a”组成。
另见 Neovim 中的 `:help leader` 和 `:help localleader`

Idris 将生成一个类似于下面的代码：

```idris
negate2 : Bool -> Bool
negate2 x = ?negate2_rhs
```

请注意，在左边有一个名称为 `x` 的新变量被引入，而在右边 Idris 添加了一个*元变量*（也称为*孔*）。这是个
以问号为前缀的标识符。它向 Idris 发出信号，
我们将在稍后实现函数的这一部分。
孔的好处在于，我们可以*悬停*来检查它们的类型和上下文中所有值的类型。在正常模式下，您可以通过放置光标在孔的标识符上然后输入 `K`（大写字母）来做到。这将打开一个弹窗，显示光标下的变量类型和上下文中变量的类型和定量。你也可以让这些信息在单独的窗口中显示：输入 `<LocalLeader>so` 以打开此窗口并重复悬停。该信息将
出现在新窗口中，作为额外的好处，它将在语义上突出显示。输入`<LocalLeader>sc`关闭这个窗口。继续检查`?negate2_rhs` 的类型和上下文。

Idris 中的大部分函数都是通过模式匹配一个或多个参数实现的。
Idris 了解所有非原语数据类型的数据构造函数，
可以为我们编写这样的模式匹配（这个过程也称为*案例拆分*）。要尝试一下，请将光标移动到在`negate2`的骨架实现中的 `x` 上，在常规模式下输入 `<LocalLeader>c` 。结果将如下所示
如下：

```idris
negate3 : Bool -> Bool
negate3 False = ?negate3_rhs_0
negate3 True = ?negate3_rhs_1
```

如您所见，Idris 为每个情况的右侧插入了一个孔。我们可以再次检查它们的类型或直接用适当的实现替换它们。

（在我看来）对于交互式编辑的核心特点的介绍到此结束：悬停在元变量上，
添加骨架函数实现和案例拆分
（这也适用于案例块和嵌套模式匹配）。你应该开始使用这些 *now*！

## 表达式搜索

有时，Idris 对所涉及的类型有足够的了解但能自己想出一个函数的实现。例如，让我们实现 *Prelude* 中 `either` 函数。
在给出它的类型之后，创建一个骨架实现，
然后 `Either` 的参数上进行案例分割，我们得出类似于以下内容：

```idris
either2 : (a -> c) -> (b -> c) -> Either a b -> c
either2 f g (Left x) = ?either2_rhs_0
either2 f g (Right x) = ?either2_rhs_1
```

Idris 可以仅凭自己就可以提取出两个元变量的表达式，因为类型足够具体。
将光标移到其中一个元变量上并在常规模式下输入 `<LocalLeader>o`。你会得到一组可能的表达式（在这种情况下只有一个），
您可以从中选择一个合适的（或使用 `q` 中止）。

这是另一个例子：函数 `maybe` 的重新实现。
如果您在 `?maybe2_rhs1` 上运行表达式搜索，您将
获得更大的选择列表。

```idris
maybe2 : b -> (a -> b) -> Maybe a -> b
maybe2 x f Nothing = x
maybe2 x f (Just y) = ?maybe2_rhs_1
```

Idris 有时也能够基于函数类型提出完整的函数实现。为了让它在实践中运作良好，
满足类型检查器的可能实现的数量必须非常小。
例如，这里是用于向量的函数 `zipWith`。你可能没听说过向量：它们将在[依赖类型](../Tutorial/Dependent.md)的章节中介绍。
你仍然可以去检查一下它的效果。只需将光标移到声明 `zipWithV` 的行，输入 `<LocalLeader>gd` 并选择第一个选项。
这将自动生成整个函数体，包括案例拆分和实现。

```idris
zipWithV : (a -> b -> c) -> Vect n a -> Vect n b -> Vect n c
```

表达式搜索仅在类型足够特定时才有效。如果您觉得可能是这种情况，请继续
试一试，方法是在元变量上运行 `<LocalLeader>o`，或在函数声明处尝试 `<LocalLeader>gd`。

## 更多代码操作

还有其他快捷方式可用于生成部分代码，
其中两个我将在这里解释。

首先，处于正常模式是可以通过在元变量上按下 `<LocalLeader>mc` 添加一个新的案例块。
例如，这里是 `filterList` 实现的一部分，
它出现在代数数据类型一章中。让 Idris 先生成骨架实现，然后是进行一次案例拆分
以及对第一个元变量的表达式搜索：

```idris
filterList : (a -> Bool) -> List a -> List a
filterList f [] = []
filterList f (x :: xs) = ?filterList_rhs_1
```

接下来我们必须对应用 `x` 到 `f` 的结果进行模式匹配。
Idris 可以为我们介绍一个新的案例块，
如果我们将光标移动到元变量 `?filterList_rhs_1`
并在正常模式下输入 `<LocalLeader>mc`。那么我们可以
继续我们的实现，首先给出
在 case 块中使用的表达式 (`f x`) 后跟一个
对 case 块中的新变量进行 case 拆分。
这将导致我们实现类似于以下的实现
（不过，我必须修复缩进）：

```idris
filterList2 : (a -> Bool) -> List a -> List a
filterList2 f [] = []
filterList2 f (x :: xs) = case f x of
  False => ?filterList2_rhs_2
  True => ?filterList2_rhs_3
```

有时，我们想从正在工作的实现中提取一个工具函数。例如，
当我们编写代码证明时通常是有用甚至是必要的
（参见章节 [命题等式](../Tutorial/Eq.md)
和 [谓词](../Tutorial/Predicates.md)）。
为此，我们可以将光标移动到元变量上，
并输入 `<LocalLeader>ml`。试试这个
`?whatNow` 在下面的例子中（这在常规的 Idris 源文件中会更好，
而不是我用于本教程的文学编程文件）：

```idris
traverseEither : (a -> Either e b) -> List a -> Either e (List b)
traverseEither f [] = Right []
traverseEither f (x :: xs) = ?whatNow x xs f (f x) (traverseEither f xs)
```

Idris 将创建一个新的带有类型的函数声明，其名称为 `?whatNow`，
可以把当前作用域内的所有变量作为参数。它也取代了 `traverseEither` 中的孔来调用这个新函数。通常，
您将不得不手动删除不需要的参数。这导致我得到以下版本：

```idris
whatNow2 : Either e b -> Either e (List b) -> Either e (List b)

traverseEither2 : (a -> Either e b) -> List a -> Either e (List b)
traverseEither2 f [] = Right []
traverseEither2 f (x :: xs) = whatNow2 (f x) (traverseEither f xs)
```

## 获取资讯

`idris2-nvim` 通过`idris2-lsp` 可执行文件并通过它不仅支持上述代码操作。
这里有一个其他功能的非全面列表。
我建议你从这个源文件中取出它们中的每一个去试试。

* Typing `K` when on an identifier or operator in normal mode shows its type
  and namespace (if any). In case of a metavariable, variables in the
  current context are displayed as well together with their types and
  quantities (quantities will be explained in [Functions Part
  2](../Tutorial/Functions2.md)).  If you don't like popups, enter
  `<LocalLeader>so` to open a new window where this information is displayed
  and semantically highlighted instead.
* Typing `gd` on a function, operator, data constructor or type constructor
  in normal mode jumps to the item's definition.  For external modules, this
  works only if the module in question has been installed together with its
  source code (by using the `idris2 --install-with-src` command).
* Typing `<LocalLeader>mm` opens a popup window listing all metavariables in
  the current module. You can place the cursor on an entry and jump to its
  location by pressing `<Enter>`.
* Typing `<LocalLeader>mn` (or `<LocalLeader>mp`) jumps to the next (or
  previous) metavariable in the current module.
* Typing `<LocalLeader>br` opens a popup where you can enter a
  namespace. Idris will then show all functions (plus their types)  exported
  from that namespace in a popup window, and you can jump to a function's
  definition by pressing enter on one of the entries. Note: The module in
  question must be imported in the current source file.
* Typing `<LocalLeader>x` opens a popup where you can enter a REPL command
  or Idris expression, and the plugin will reply with a response from the
  REPL. Whenever REPL examples are shown in the main part of this guide, you
  can try them from within Neovim with this shortcut if you like.
* Typing `<LocalLeader><LocalLeader>e` will display the error message from
  the current line in a popup window. This can be highly useful, if error
  messages are too long to fit on a single line. Likewise,
  `<LocalLeader><LocalLeader>el` will list all error messages from the
  current buffer in a new window. You can then select an error message and
  jump to its origin by pressing `<Enter>`.

`idris2-nvim` 插件其他用例和示例在 GitHub 页面上进行了描述，这些描述也包含在内。

## `%name` 编译指示

当您向 Idris 询问使用 `<LocalLeader>a` 的框架实现
或用 `<LocalLeader>c` 案例拆分时，
它必须决定为它引入的新变量使用什么名称。
如果这些变量已经有预定义的名称（来自函数的
签名、记录字段或命名数据构造函数参数），
这些名称将被使用，否则 Idris 将默认使用名称 `x`、`y` 和 `z`，然后
或其他字母。您可以更改此默认行为，
只要指定用于此类数据类型场合的名称列表。

例如：

```idris
data Element = H | He | C | N | O | F | Ne

%name Element e,f
```

然后 Idris 将使用这些名称（这些名称后跟自增数字的后缀），
当它必须想出这个类型的自己变量名时。
例如，这是一个测试函数和向其添加骨架定义的结果：

```idris
test : Element -> Element -> Element -> Element -> Element -> Element
test e f e1 f1 e2 = ?test_rhs
```

## 结论

Neovim，连同 `idris2-lsp` 可执行文件和 `idris2-nvim` 编辑器插件，
为在 Idris 中编程时的交互式编辑。
其他一些编辑也可以使用类似的功能，
所以请随时询问可供您选择使用的编辑器有什么，
例如在 [Idris 2 Discord 频道](https://discord.gg/UX68fDs2jc) 上。

<!-- vi: filetype=idris2
-->
