" Vim plugin for Racer
" (by Phil Dawes)
"
" 1. Edit the variables below (or override in .vimrc)
" 2. copy this file into .vim/plugin/
" 3. - now in insert mode do 'C-x C-o' to autocomplete the thing at the cursor
"    - in normal mode do 'gd' to go to definition
"    - 'gD' goes to the definition in a new vertical split
"
" (This plugin is best used with the 'hidden' option enabled so that switching buffers doesn't force you to save)

if exists('g:loaded_racer')
    finish
endif

let g:loaded_racer = 1

let s:save_cpo = &cpo
set cpo&vim

let s:is_win = has('win32') || has('win64')

if !exists('g:racer_cmd')
    let s:sep = s:is_win ? '\' : '/'
    let s:path = join([
            \ escape(expand('<sfile>:p:h'), '\'),
            \ '..',
            \ 'target',
            \ 'release',
            \ ], s:sep)
    if isdirectory(s:path)
        let s:pathsep = s:is_win ? ';' : ':'
        let $PATH .= s:pathsep . s:path
    endif
    let g:racer_cmd = 'racer'
endif

" Expand '~' and environment variables
let g:racer_cmd = expand(g:racer_cmd)

if !exists('g:racer_experimental_completer')
    let g:racer_experimental_completer = 0
endif

if !exists('g:racer_insert_paren')
    let g:racer_insert_paren = 1
endif

nnoremap <silent><buffer> <Plug>(rust-def)
        \ :call racer#GoToDefinition()<CR>
nnoremap <silent><buffer> <Plug>(rust-def-split)
        \ :split<CR>:call racer#GoToDefinition()<CR>
nnoremap <silent><buffer> <Plug>(rust-def-vertical)
        \ :vsplit<CR>:call racer#GoToDefinition()<CR>
nnoremap <silent><buffer> <Plug>(rust-doc)
        \ :call racer#ShowDocumentation()<CR>

augroup vim-racer
    autocmd!
    autocmd FileType rust setlocal omnifunc=racer#RacerComplete
augroup END

let &cpo = s:save_cpo
unlet s:save_cpo
