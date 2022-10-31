# Getting Started with pack and Idris2

Here I describe what I find to be the most convenient way to get
up and running with Idris2. We are going to install the
[pack](https://github.com/stefan-hoeck/idris2-pack) package manager, which
will install a recent version of the Idris compiler along the way.
However, this means that you need access to a Unix-like operating system
such as Linux or macOS. Windows users can make use of
[WSL](https://learn.microsoft.com/en-us/windows/wsl/about) to get access to
a Linux environment on their system. As a prerequisite, it is assumed that
readers know how to start a terminal session on their system, and how
to run commands from the terminal's command-line. In addition, readers
need to know how to add directories to the
[`$PATH` variable](https://en.wikipedia.org/wiki/PATH_(variable))
on their system.

## Installing pack

In order to install the *pack* package manager together with a recent version
of the Idris2 compiler, follow the instructions on
[pack's GitHub page](https://github.com/stefan-hoeck/idris2-pack/blob/main/INSTALL.md).

If all goes well, I suggest you take a moment to inspect the default settings
available in your global `pack.toml` file, which can be found at `$HOME/.pack/user/pack.toml`
(unless you explicitly set the `$PACK_DIR` environment variable to a different
directory). If possible, I suggest you install the *rlwrap* tool and change the
following setting in your global `pack.toml` file to `true`:

```toml
repl.rlwrap = true
```

This will lead to a nicer experience when running REPL sessions.
You might also want to set up your editor to make use of the interactive
editing features provided by Idris. Instruction to do this for Neovim
can be found [here](Neovim.md).

### Updating pack and Idris

Both projects, pack and the Idris compiler, are still being actively developed.
It is therefore a good idea to update them at regular occasions. To update
pack itself, just run the following command:

```sh
pack update
```

To build and install the latest commit of the Idris compiler and use the
latest package collection, run

```sh
pack switch latest
```

## Setting up your Playground

If you are going to solve the exercises in this tutorial (you should!), you'll have
to write a lot of code. It is best to setup a small playground project for
tinkering with Idris. In a directory of your choice, run the following command:

```sh
pack new lib tut
```

This will setup a minimal Idris package in directory `tut` together with an
`.ipkg` file called `tut.ipkg`, a directory to put your Idris sources called
`src`, and a minimal Idris module at `src/Playground.idr`.

In addition, it sets up a minimal test suite in directory `test`. All of this is
put together and made accessible to pack in a `pack.toml` file in the project's
root directory. Take your time and quickly inspect the content of every file
created by pack: The `.idr` files contain Idris source code. The `.ipkg` files
contain detailed descriptions of packages for the Idris compiler
including where the sources are located,
the modules a package makes available to other projects, and a list of packages
the project itself depends on. Finally, the `pack.toml` file informs pack about
the local packages in the current project.

With this, here is a bunch of things you can do (make sure you are in the
project's root directory (called `tut` if you followed my suggestion)
or one of its child folders when running these commands.

To typecheck the library sources, run

```sh
pack typecheck tut
```

To build and execute the test suite, run

```sh
pack test tut
```

To start a REPL session with `src/Playground.idr` loaded, run

```sh
pack repl src/Playground.idr
```

## Conclusion

In this very short tutorial you set up an environment to work on
Idris projects and follow along with this tutorial. You are now ready
to start with the [first chapter](../Tutorial/Intro.md), or - if you
already wrote some Idris code - to learn about the details of the
[Idris module system](Modules.md).

Please note that this tutorial itself is setup as a pack project:
It contains a `pack.toml` and `tutorial.ipkg` file in its root
directory (have a look at them to get a feel for how such projects are
setup) and a lot of Idris sources in the subfolders of directory `src`.
