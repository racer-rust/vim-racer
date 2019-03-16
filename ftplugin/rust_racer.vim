if !exists('g:racer_experimental_completer')
    let g:racer_experimental_completer = 0
endif

if !exists('g:racer_insert_paren')
    let g:racer_insert_paren = 0
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
