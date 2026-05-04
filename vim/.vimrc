" Install vim-plug if not found
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
endif

call plug#begin()
Plug 'vim-airline/vim-airline'                " Status/tabline customization
Plug 'vim-airline/vim-airline-themes'         " Airline themes
Plug 'lervag/vimtex'				" LaTeX editing
Plug 'SirVer/ultisnips'				" Snippets
Plug 'tpope/vim-dispatch'			
Plug 'jiangmiao/auto-pairs'                   " Auto-pairs for (), [], {}
Plug 'ycm-core/YouCompleteMe'                 " Autocompletion and docs
Plug 'kkoomen/vim-doge'                       " (Do)cumentation (Ge)nerator
Plug 'tmhedberg/SimpylFold'                   " No BS Python code folding
Plug 'dense-analysis/ale'                     " Async linting (Python + LaTeX)
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'                       " Fuzzy file/buffer/grep finder
Plug 'tpope/vim-surround'                     " Surround text with cs/ds/ys
Plug 'tpope/vim-commentary'                   " gc to toggle comments
Plug 'preservim/nerdtree'                     " File tree explorer
call plug#end()

" Run PlugInstall if there are missing plugins
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif

set nu
set expandtab                   " Expand tabs to spaces
set softtabstop=4               " Set the number of spaces a <Tab> character counts for
set shiftwidth=4                " Width used for >> and << commands

set wrap          " enable wrapping
set linebreak     " break lines at word boundaries
set showbreak=↳\  " (optional) show an arrow when lines wrap
nnoremap j gj
nnoremap k gk

" UltiSnips shortcuts:
"let g:UltiSnipsExpandTrigger       = '<Tab>'    " use Tab to expand snippets
"let g:UltiSnipsJumpForwardTrigger  = '<Tab>'    " use Tab to move forward through tabstops
"let g:UltiSnipsJumpBackwardTrigger = '<S-Tab>'  " use Shift-Tab to move backward through tabstops
let g:UltiSnipsExpandTrigger = '<C-j>'
let g:UltiSnipsJumpForwardTrigger = '<C-j>'
let g:UltiSnipsJumpBackwardTrigger = '<C-k>'
let g:UltiSnipsSnippetDirectories=[$HOME.'/.vim/UltiSnips']          " default snippet directory

" --- YouCompleteMe ---
" Use <C-Space> to trigger completion manually
inoremap <silent><expr> <C-Space> ycm#TriggerCompletion()

inoremap <expr> <CR> pumvisible() ? "\<C-y>" : "\<CR>"

" K: show docs for symbol under cursor (hover-like); gd: go to definition
nnoremap <silent> K :YcmCompleter GetDoc<CR>
nnoremap <silent> gd :YcmCompleter GoTo<CR>

" --- Intuitive keybindings ---
nnoremap <C-s> :w<CR>
inoremap <C-s> <Esc>:w<CR>a
nnoremap <leader>q :q<CR>
nnoremap <leader>w :w<CR>
nnoremap <leader>n :NERDTreeToggle<CR>
nnoremap <C-p> :Files<CR>
nnoremap <leader>/ :Rg<CR>
nnoremap <leader>b :Buffers<CR>

" Code Formating and Documenting
" *********************
" Map <leader>af to auto-format the current file
nnoremap <leader>F :call AutoFormat()<CR>
" (Do)cumentation (Ge)nerator settings
let g:doge_doc_standard_python = 'numpy'
let g:doge_mapping = '<leader>D'
let g:doge_python_settings = {'single_quotes': 0,'omit_redundant_param_types': 0}


" COLOR-THEME
" *********************
let g:airline_powerline_fonts = 1               " Enable Powerline-style fonts for the vim-airline status bar
let g:airline_theme = 'badwolf'                 " Set the theme of vim-airline to 'badwolf'
colorscheme molokai                             " Set the overall Vim colorscheme to 'molokai'
hi Normal guibg=NONE ctermbg=NONE|              " Make the background of the Normal text group transparent
highlight LineNr ctermfg=grey ctermbg=NONE|     " Set line numbers to grey text with transparent background


" --- VimTeX configuration ---
filetype plugin indent on
syntax enable

" Use latexmk for automatic compilation
let g:vimtex_compiler_method = 'latexmk'
let g:vimtex_compiler_latexmk = {
    \ 'build_dir' : 'build',
    \ 'continuous' : 1,
    \ 'callback' : 1,
    \ 'options' : [
    \   '-pdf',
    \   '-interaction=nonstopmode',
    \   '-synctex=1',
    \ ],
    \}

" Choose your PDF viewer
" Options: 'zathura', 'okular', 'skim', 'sumatrapdf', 'mupdf', etc.
let g:vimtex_view_method = 'zathura'

" Optional: Start continuous compilation automatically when opening a tex file
autocmd FileType tex VimtexCompile

" Optional: Use folds for sections, not macros
let g:vimtex_fold_enabled = 1
let g:vimtex_fold_types = {
    \ 'sections' : {'parse_levels': 1},
    \ 'envs' : {'parse': 0},
    \ 'preamble' : {'parse': 0},
    \ }

" Quick mappings reminder:
" \ll = compile (continuous)
" \lv = view PDF
" \lk = stop compilation
" \lo = show log

" --- ALE (async linting) ---
let g:ale_linters = {
    \ 'python': ['flake8', 'pylint'],
    \ 'tex': ['chktex'],
    \ }
let g:ale_fixers = {
    \ 'python': ['black', 'isort'],
    \ }
let g:ale_python_flake8_options = '--max-line-length=88'
let g:ale_sign_error = 'x'
let g:ale_sign_warning = '!'
let g:ale_echo_msg_format = '[%linter%] %s'
nnoremap <leader>af :ALEFix<CR>
nnoremap ]e :ALENextWrap<CR>
nnoremap [e :ALEPreviousWrap<CR>

" --- NERDTree ---
let g:NERDTreeShowHidden = 1
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
