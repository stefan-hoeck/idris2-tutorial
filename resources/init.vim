" This is a small but complete init.vim file for getting
" started with programming Idris in Neovim.
"
" It comes with a few opinionated defaults plus the plugins
" necessary to interact with the idris2-lsp executable.
"
" Follow the tutorial at `src/Appendices/Neovim.md` for an
" introduction to interactive Idris editing in Neovim.

" The buffer local <localleader>
let maplocalleader = ','

autocmd ColorScheme * highlight Normal ctermfg=None ctermbg=None

" indent new line by the same amount as previous line
set autoindent
" display the actual vim mode
set showmode

" tabstop behavior
" don't wrap long lines
set nowrap
" expand tabstops with spaces (important for languages like Idris or Haskell)
set expandtab
" number of spaces for >> << and cindent
set shiftwidth=2
" <BS> deletes 2 characters and softtabs are inserted
set softtabstop=2

" line numbers
" show absolute line numer on actual line
set nu
" show relative line numbers
set rnu
" show file name and position of curser
set ruler

" Try to get terminal colors as close to GUI colors as possible
let g:rehash256 = 1

" Vimplug
call plug#begin('~/.local/share/nvim/plugged')
Plug 'vim-syntastic/syntastic'

" Color Schemes
Plug 'changyuheng/color-scheme-holokai-for-vim'

Plug 'neovim/nvim-lspconfig'
Plug 'ShinKage/idris2-nvim'
Plug 'MunifTanjim/nui.nvim'
call plug#end()

colorscheme holokai

" Idris LSP settings
"
" Press `gd` on a function, constructor, or operator to jump to its definition
" (for external modules, this works only if they were installed with
" idris2 --install-with-src)
"
" Press `K` on a function, constructor, or operator to print its type.
" Works especially well with holes.
"
" Press `<localleader>a` to add a new clause to a definition.
"
" Press `<localleader>c` to add a case split on a variable.
"
" Press `<localleader>o` to start an expression search.
lua << EOF

-- shortcut for displaying error messages in a popup.
vim.cmd [[nnoremap <LocalLeader><LocalLeader>e <Cmd>lua vim.diagnostic.open_float()<CR>]]
-- shortcut for displaying error messages in a separate window.
vim.cmd [[nnoremap <LocalLeader><LocalLeader>el <Cmd>lua vim.diagnostic.setloclist()<CR>]]

-- command to run after every code action.
local function save_hook(action)
  vim.cmd('silent write')
end

local opts = {
  client = {
    hover = {
      use_split = false, -- Persistent split instead of popups for hover
      split_size = '30%', -- Size of persistent split, if used
      auto_resize_split = false, -- Should resize split to use minimum space
      split_position = 'bottom', -- bottom, top, left or right
      with_history = false, -- Show history of hovers instead of only last
    },
  },
  server = {
    on_attach = function(...)
      vim.cmd [[nnoremap gd <Cmd>lua vim.lsp.buf.definition()<CR>]]
      vim.cmd [[nnoremap K <Cmd>lua vim.lsp.buf.hover()<CR>]]

      vim.cmd [[nnoremap <LocalLeader>c <Cmd>lua require('idris2.code_action').case_split()<CR>]]
      vim.cmd [[nnoremap <LocalLeader>mc <Cmd>lua require('idris2.code_action').make_case()<CR>]]
      vim.cmd [[nnoremap <LocalLeader>mw <Cmd>lua require('idris2.code_action').make_with()<CR>]]
      vim.cmd [[nnoremap <LocalLeader>ml <Cmd>lua require('idris2.code_action').make_lemma()<CR>]]
      vim.cmd [[nnoremap <LocalLeader>a <Cmd>lua require('idris2.code_action').add_clause()<CR>]]
      vim.cmd [[nnoremap <LocalLeader>o <Cmd>lua require('idris2.code_action').expr_search()<CR>]]
      vim.cmd [[nnoremap <LocalLeader>gd <Cmd>lua require('idris2.code_action').generate_def()<CR>]]
      vim.cmd [[nnoremap <LocalLeader>rh <Cmd>lua require('idris2.code_action').refine_hole()<CR>]]

      vim.cmd [[nnoremap <LocalLeader>so <Cmd>lua require('idris2.hover').open_split()<CR>]]
      vim.cmd [[nnoremap <LocalLeader>sc <Cmd>lua require('idris2.hover').close_split()<CR>]]

      vim.cmd [[nnoremap <LocalLeader>mm <Cmd>lua require('idris2.metavars').request_all()<CR>]]
      vim.cmd [[nnoremap <LocalLeader>mn <Cmd>lua require('idris2.metavars').goto_next()<CR>]]
      vim.cmd [[nnoremap <LocalLeader>mp <Cmd>lua require('idris2.metavars').goto_prev()<CR>]]

      vim.cmd [[nnoremap <LocalLeader>br <Cmd>lua require('idris2.browse').browse()<CR>]]

      vim.cmd [[nnoremap <LocalLeader>x <Cmd>lua require('idris2.repl').evaluate()<CR>]]
    end,
    init_options = {
      logFile = "~/.cache/idris2-lsp/server.log",
      longActionTimeout = 2000, -- 2 second
    },
  },
  autostart_semantic = true, -- Should start and refresh semantic highlight automatically
  code_action_post_hook = save_hook, -- Function to execute after a code action is performed:
  use_default_semantic_hl_groups = true, -- Set default highlight groups for semantic tokens
}
require('idris2').setup(opts)
EOF
