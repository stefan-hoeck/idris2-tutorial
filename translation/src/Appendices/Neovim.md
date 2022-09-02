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

* The following Neovim plugins:

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

Idris is also sometimes capable of coming up with complete function
implementations based on a function's type. For this to work well
in practice, the number of possible implementations satisfying
the type checker must be pretty small. As an example, here is
function `zipWith` for vectors. You might not have heard
about vectors yet: They will be introduced in the chapter about
[dependent types](../Tutorial/Dependent.md). You can still give
this a go to check out its effect. Just move the cursor on the
line declaring `zipWithV`, enter `<LocalLeader>gd` and select the first option.
This will automatically generate the whole function body including
case splits and implementations.

```idris
zipWithV : (a -> b -> c) -> Vect n a -> Vect n b -> Vect n c
```

Expression search only works well if the types are specific
enough. If you feel like that might be the case, go ahead
and give it a go, either by running `<LocalLeader>o` on
a metavariable, or by trying `<LocalLeader>gd` on a
function declaration.

## More Code Actions

There are other shortcuts available for generating part of your code,
two of which I'll explain here.

First, it is possible to add a new case block by entering
`<LocalLeader>mc` in normal mode when on a metavariable.
For instance, here is part of an implementation of `filterList`,
which appears in an exercise in the chapter about
algebraic data types. I arrived at this by letting Idris
generate a skeleton implementation followed by a case split
and an expression search on the first metavariable:

```idris
filterList : (a -> Bool) -> List a -> List a
filterList f [] = []
filterList f (x :: xs) = ?filterList_rhs_1
```

We will next have to pattern match on the result of applying
`x` to `f`. Idris can introduce a new case block for us,
if we move the cursor onto metavariable `?filterList_rhs_1`
and enter `<LocalLeader>mc` in normal mode. We can then
continue with our implementation by first giving the
expression to use in the case block (`f x`) followed by a
case split on the new variable in the case block.
This will lead us to an implementation similar to the following
(I had to fix the indentation, though):

```idris
filterList2 : (a -> Bool) -> List a -> List a
filterList2 f [] = []
filterList2 f (x :: xs) = case f x of
  False => ?filterList2_rhs_2
  True => ?filterList2_rhs_3
```

Sometimes, we want to extract a utility function from
an implementation we are working on. For instance, this is often
useful or even necessary when we write proofs about our code
(see chapters [Propositional Equality](../Tutorial/Eq.md)
and [Predicates](../Tutorial/Predicates.md), for instance).
In order to do so, we can move the cursor on a metavariable,
and enter `<LocalLeader>ml`. Give this a try with
`?whatNow` in the following example (this will work better
in a regular Idris source file instead of the literate
file I use for this tutorial):

```idris
traverseEither : (a -> Either e b) -> List a -> Either e (List b)
traverseEither f [] = Right []
traverseEither f (x :: xs) = ?whatNow x xs f (f x) (traverseEither f xs)
```

Idris will create a new function declaration with the
type and name of `?whatNow`, which takes as arguments
all variables currently in scope. It also replaces the hole in
`traverseEither` with a call to this new function. Typically,
you will have to manually remove unneeded arguments
afterwards. This led me to the following version:

```idris
whatNow2 : Either e b -> Either e (List b) -> Either e (List b)

traverseEither2 : (a -> Either e b) -> List a -> Either e (List b)
traverseEither2 f [] = Right []
traverseEither2 f (x :: xs) = whatNow2 (f x) (traverseEither f xs)
```

## Getting Information

The `idris2-lsp` executable and through it, the `idris2-nvim` plugin,
not only supports the code actions described above. Here is a
non-comprehensive list of other capabilities. I suggest you try
out each of them from within this source file.

* Typing `K` when on an identifier or operator in normal mode shows its type
  and namespace (if any). In case of a metavariable, variables
  in the current context are displayed as well together with their
  types and quantities (quantities will be explained in
  [Functions Part 2](../Tutorial/Functions2.md)).
  If you don't like popups, enter `<LocalLeader>so` to open a new window where
  this information is displayed and semantically highlighted instead.

* Typing `gd` on a function, operator, data constructor or type
  constructor in normal mode jumps to the item's definition.
  For external modules, this works only if the
  module in question has been installed together with its source code
  (by using the `idris2 --install-with-src` command).

* Typing `<LocalLeader>mm` opens a popup window listing all metavariables
  in the current module. You can place the cursor on an entry and
  jump to its location by pressing `<Enter>`.

* Typing `<LocalLeader>mn` (or `<LocalLeader>mp`) jumps to the next
  (or previous) metavariable in the current module.

* Typing `<LocalLeader>br` opens a popup where you can enter a
  namespace. Idris will then show all functions (plus their types)
  exported from that namespace in a popup window, and you can
  jump to a function's definition by pressing enter on one of the
  entries. Note: The module in question must be imported in the
  current source file.

* Typing `<LocalLeader>x` opens a popup where you can enter
  a REPL command or Idris expression, and the plugin will reply
  with a response from the REPL. Whenever REPL examples are shown
  in the main part of this guide, you can try them from within
  Neovim with this shortcut if you like.

* Typing `<LocalLeader><LocalLeader>e` will display the error message
  from the current line in a popup window. This can be highly useful,
  if error messages are too long to fit on a single line. Likewise,
  `<LocalLeader><LocalLeader>el` will list all error messages from the current
  buffer in a new window. You can then select an error message and
  jump to its origin by pressing `<Enter>`.


Other use cases and examples are described on the GitHub page
of the `idris2-nvim` plugin and can be included as described there.

## The `%name` Pragma

When you ask Idris for a skeleton implementation with `<LocalLeader>a`
or a case split with `<LocalLeader>c`,
it has to decide on what names to use for the new variables it introduces.
If these variables already have predefined names (from the function's
signature, record fields, or named data constructor arguments),
those names will be used, but
otherwise Idris will as a default use names `x`, `y`, and `z`, followed
by other letters. You can change this default behavior by
specifying a list of names to use for such occasions for any
data type.

For instance:

```idris
data Element = H | He | C | N | O | F | Ne

%name Element e,f
```

Idris will then use these names (followed by these names postfixed
with increasing integers), when it has to come up with variable names of this
type on its own. For instance, here is a test function and the
result of adding a skeleton definition to it:

```idris
test : Element -> Element -> Element -> Element -> Element -> Element
test e f e1 f1 e2 = ?test_rhs
```

## 结论

Neovim, together with the `idris2-lsp` executable and the
`idris2-nvim` editor plugin, provides extensive utilities for
interactive editing when programming in Idris. Similar functionality
is available for some other editors, so feel free to ask what's
available for your editor of choice, for instance on the
[Idris 2 Discord channel](https://discord.gg/UX68fDs2jc).

<!-- vi: filetype=idris2
-->
