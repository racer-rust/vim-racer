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

setlocal omnifunc=racer#RacerComplete

let &cpo = s:save_cpo
unlet s:save_cpo
