" =============================================================================
" .vimrc - Vim configuration
" Managed by dotfiles repo
" =============================================================================

" Basic settings
set nocompatible
set encoding=utf-8
set fileencoding=utf-8
set number
set relativenumber
set cursorline
set showmatch
set hlsearch
set incsearch
set ignorecase
set smartcase
set autoindent
set smartindent
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4
set backspace=indent,eol,start
set ruler
set showcmd
set wildmenu
set laststatus=2
set scrolloff=5
set wrap
set linebreak

" Color scheme
syntax on
set background=dark
colorscheme desert

" Key mappings
let mapleader = ","
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>/ :nohlsearch<CR>
nnoremap <C-n> :NERDTreeToggle<CR>

" Split navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
