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

if !exists('g:racer_cmd')
    let path = escape(expand('<sfile>:p:h'), '\') . '/../target/release/'
    if isdirectory(path)
        let s:pathsep = has("win32") ? ';' : ':'
        let $PATH .= s:pathsep . path
    endif
    let g:racer_cmd = 'racer'
endif

if !exists('$RUST_SRC_PATH')
    let s:rust_src_default = 1
    if isdirectory("/usr/local/src/rust/src")
        let $RUST_SRC_PATH="/usr/local/src/rust/src"
    endif
    if isdirectory("/usr/src/rust/src")
        let $RUST_SRC_PATH="/usr/src/rust/src"
    endif
    if isdirectory("C:\\rust\\src")
        let $RUST_SRC_PATH="C:\\rust\\src"
    endif
endif

if !exists('g:racer_experimental_completer')
    let g:racer_experimental_completer = 0
endif

if !exists('g:racer_insert_paren')
    let g:racer_insert_paren = 1
endif

function! s:RacerGetPrefixCol(base)
    let col = col(".")-1
    let b:racer_col = col
    let b:tmpfname = tempname()
    call writefile(s:RacerGetBufferContents(a:base), b:tmpfname)
    let cmd = g:racer_cmd." prefix ".line(".")." ".col." ".b:tmpfname
    let res = system(cmd)
    let prefixline = split(res, "\\n")[0]
    let startcol = split(prefixline[7:], ",")[0]
    return startcol
endfunction

function! s:RacerGetExpCompletions(base)
    let col = col(".")-1
    call writefile(s:RacerGetBufferContents(a:base), b:tmpfname)
    let fname = expand("%:p")
    let cmd = g:racer_cmd." complete ".line(".")." ".col." \"".fname."\" \"".b:tmpfname."\""
    let res = system(cmd)

    let typeMap = {
        \ 'Struct' : 's', 'Module' : 'M', 'Function' : 'f',
        \ 'Crate' : 'C', 'Let' : 'v', 'StructField' : 'm',
        \ 'Impl' : 'i', 'Enum' : 'e', 'EnumVariant' : 'E',
        \ 'Type' : 't', 'FnArg' : 'v', 'Trait' : 'T'
        \ }

    let lines = split(res, "\\n")
    let out = []

    for line in lines
        if line =~ "^MATCH"
            let completions = split(line[6:], ",")
            let kind = get(typeMap, completions[4])
            let completion = {'kind' : kind, 'word' : completions[0], 'dup':1 }

            if kind ==# 'f' " function
                let completion['menu'] = substitute(substitute(substitute(join(completions[5:], ','), '\(pub\|fn\) ',"","g"), '{*$', "", ""), ' where\s\?.*$', "", "")
                if g:racer_insert_paren == 1
                    let completion['abbr'] = completions[0]
                    let completion['word'] .= "("
                endif
                let completion['info'] = join(completions[5:], ',')
            elseif kind ==# 's' " struct
                let completion['menu'] = substitute(substitute(join(completions[5:], ','), '\(pub\|struct\) ',"","g"), '{*$', "", "")
            endif

            if stridx(tolower(completions[0]), tolower(a:base)) == 0
              let out = add(out, completion)
            endif
        endif
    endfor
    call delete(b:tmpfname)
    return out
endfunction

function! s:RacerSplitLine(line)
    let separator = ';'
    let placeholder = '{PLACEHOLDER}'
    let line = substitute(a:line, '\\;', placeholder, 'g')
    let b:parts = split(line, separator)
    let docs = substitute(substitute(substitute(substitute(get(b:parts, 7, ''), '^\"\(.*\)\"$', '\1', ''), '\\\"', '\"', 'g'), '\\''', '''', 'g'), '\\n', '\n', 'g')
    let b:parts = add(b:parts[:6], docs)
    let b:parts = map(copy(b:parts), 'substitute(v:val, ''{PLACEHOLDER}'', '';'', ''g'')')

    return b:parts
endfunction

function! s:RacerShowDocumentation()
    let l:winview = winsaveview()  " Save the current cursor position
    " Move to the end of the word for the entire token to search.
    " Move one char back to avoid moving to the end of the *next* word.
    execute "normal he"
    let col = col('.')
    let b:tmpfname = tempname()
    call writefile(getline(1, '$'), b:tmpfname)  " Create temporary file with the buffer's current state
    let fname = expand("%:p")
    let cmd = g:racer_cmd." complete-with-snippet ".line(".")." ".col." ".fname." ".b:tmpfname
    let res = system(cmd)
    call winrestview(l:winview)  " Restore de cursor position
    call delete(b:tmpfname)  " Delete the temporary file
    let lines = split(res, "\\n")
    for line in lines
       if line =~ "^MATCH"
           let docs = s:RacerSplitLine(line[6:])[7]
           if len(docs) > 0  " Only open doc buffer if there're docs to show
               let bn = bufnr("__doc__")
               if bn > 0
                   let wi=index(tabpagebuflist(tabpagenr()), bn)
                   if wi >= 0
                       " If the __doc__ buffer is open in the current tab, jump to it
                       silent execute (wi+1).'wincmd w'
                   else
                       silent execute "sbuffer ".bn
                   endif
               else
                   split '__doc__'
               endif

               setlocal modifiable
               setlocal noswapfile
               setlocal buftype=nofile
               silent normal! ggdG
               silent $put=docs
               silent normal! 1Gdd
               setlocal nomodifiable
               setlocal nomodified
               setlocal filetype=rustdoc
           endif
           break
       endif
    endfor
endfunction

function! s:RacerGetCompletions(base)
    let col = col(".") - 1
    let b:tmpfname = tempname()
    " HACK: Special case to offer autocompletion on a string literal
    if getline(".")[:col-1] =~# "\".*\"\.$"
        call writefile(["fn main() {", "    let x: &str = \"\";", "    x.", "}"], b:tmpfname)
        let fname = expand("%:p")
        let cmd = g:racer_cmd." complete 3 6 \"".fname."\" \"".b:tmpfname."\""
    else
        call writefile(s:RacerGetBufferContents(a:base), b:tmpfname)
        let fname = expand("%:p")
        let cmd = g:racer_cmd." complete ".line(".")." ".col." \"".fname."\" \"".b:tmpfname."\""
    endif
    let res = system(cmd)
    let lines = split(res, "\\n")
    let out = []
    for line in lines
       if line =~ "^MATCH"
           let completion = split(line[6:], ",")[0]
           if stridx(tolower(completion), tolower(a:base)) == 0
             let out = add(out, completion)
           endif
       endif
    endfor
    call delete(b:tmpfname)

    return out
endfunction

function! s:RacerGoToDefinition()
    if s:ErrorCheck()
        return
    endif

    let col = col(".")-1
    let b:racer_col = col
    let fname = expand("%:p")
    let tmpfname = tempname()
    call writefile(getline(1, '$'), tmpfname)
    let cmd = g:racer_cmd." find-definition ".line(".")." ".col." ".fname." ".tmpfname
    let res = system(cmd)
    let lines = split(res, "\\n")
    for line in lines
        if res =~# " error: " && line !=# "END"
            call s:Warn(line)
        elseif line =~ "^MATCH"
             let linenum = split(line[6:], ",")[1]
             let colnum = split(line[6:], ",")[2]
             let fname = split(line[6:], ",")[3]
             call s:RacerJumpToLocation(fname, linenum, colnum)
             break
        endif
    endfor
    call delete(tmpfname)
endfunction

function! s:RacerGetBufferContents(base)
    " Re-combine the completion base word from omnicomplete with the current
    " line contents. Since the base word gets remove from the buffer before
    " this function is invoked we have to put it back in to out tmpfile.
    let col = col(".") - 1
    let buf_lines = getline(1, '$')
    let line_contents = getline('.')
    let buf_lines[line('.') - 1] = strpart(line_contents, 0, col).a:base.strpart(line_contents, col, len(line_contents))
    return buf_lines
endfunction

function! s:RacerJumpToLocation(filename, linenum, colnum)
    if(a:filename != '')
        " Record jump mark
        normal! m`
        if a:filename != bufname('%')
            try
                exec 'keepjumps e ' . fnameescape(a:filename)
            catch /^Vim\%((\a\+)\)\=:E37/
                " When the buffer is not saved, E37 is thrown.  We can ignore it.
            endtry
        endif
        call cursor(a:linenum, a:colnum+1)
        " Center definition on screen
        normal! zz
    endif
endfunction

function! RacerComplete(findstart, base)
    if a:findstart
        if s:ErrorCheck()
            return -1
        endif

        return s:RacerGetPrefixCol(a:base)
    else
        if s:ErrorCheck()
            return []
        endif

        if g:racer_experimental_completer == 1
            return s:RacerGetExpCompletions(a:base)
        else
            return s:RacerGetCompletions(a:base)
        endif
    endif
endfunction

function! s:Warn(msg)
    echohl WarningMsg | echomsg a:msg | echohl NONE
endfunction

function! s:ErrorCheck()
    if !executable(g:racer_cmd)
        call s:Warn("No racer executable found in $PATH (" . $PATH . ")")
        return 1
    endif

    if !isdirectory($RUST_SRC_PATH)
        if exists('s:rust_src_default')
            call s:Warn("No RUST_SRC_PATH environment variable present, nor could default installation be found at: " . $RUST_SRC_PATH)
        else
            call s:Warn("No directory was found at provided RUST_SRC_PATH: " . $RUST_SRC_PATH)
        endif
        return 2
    endif
endfunction

function! s:Init()
    setlocal omnifunc=RacerComplete

    nnoremap <silent><buffer> <Plug>RacerGoToDefinitionDrect
          \ :call <SID>RacerGoToDefinition()<CR>
    nnoremap <silent><buffer> <Plug>RacerGoToDefinitionSplit
          \ :split<CR>:call <SID>RacerGoToDefinition()<CR>
    nnoremap <silent><buffer> <Plug>RacerGoToDefinitionVSplit
          \ :vsplit<CR>:call <SID>RacerGoToDefinition()<CR>
    nnoremap <silent><buffer> <Plug>RacerShowDocumentation
          \ :call <SID>RacerShowDocumentation()<CR>
    if !exists('g:racer_no_default_keymappings')
      nmap <buffer> gd <Plug>RacerGoToDefinitionDrect
      nmap <buffer> gs <Plug>RacerGoToDefinitionSplit
      nmap <buffer> gx <Plug>RacerGoToDefinitionVSplit
      nmap <buffer> K  <Plug>RacerShowDocumentation
    endif
endfunction

augroup vim-racer
  autocmd!
  autocmd FileType rust call s:Init()
augroup END

let &cpo = s:save_cpo
unlet s:save_cpo
