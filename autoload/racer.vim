let s:is_win = has('win32')

function! racer#GetRacerCmd() abort
    if !exists('g:racer_cmd')
        let sep = s:is_win ? '\' : '/'
        let path = join([
              \ escape(expand('<sfile>:p:h'), '\'),
              \ '..',
              \ 'target',
              \ 'release',
              \ ], sep)
        if isdirectory(path)
            let pathsep = s:is_win ? ';' : ':'
            let $PATH .= pathsep . path
        endif
        let g:racer_cmd = 'racer'
    endif

    return expand(g:racer_cmd)
endfunction

function! s:RacerGetPrefixCol(base)
    let col = col('.') - 1
    let b:racer_col = col
    let b:tmpfname = tempname()
    call writefile(s:RacerGetBufferContents(a:base), b:tmpfname)
    let cmd = racer#GetRacerCmd() . ' prefix ' .
        \ line('.') . ' ' . col . ' ' . b:tmpfname
    let res = system(cmd)
    let prefixline = split(res, '\n')[0]
    let startbyte = split(prefixline[7:], ',')[0]
    call delete(b:tmpfname)
    return startbyte - line2byte(byte2line(startbyte)) + (col == 1 ? 0 : 1)
endfunction

function! s:RacerGetExpCompletions(base)
    let col = col('.')-1
    let b:tmpfname = tempname()
    call writefile(s:RacerGetBufferContents(a:base), b:tmpfname)
    let fname = expand('%:p')
    let cmd = racer#GetRacerCmd() . ' complete ' .
        \ line('.') . ' ' . col . ' "' . fname . '" "' . b:tmpfname . '"'
    let res = system(cmd)

    let typeMap = {
        \ 'Struct' : 's', 'Module' : 'M', 'Function' : 'f',
        \ 'Crate' : 'C', 'Let' : 'v', 'StructField' : 'm',
        \ 'Impl' : 'i', 'Enum' : 'e', 'EnumVariant' : 'E',
        \ 'Type' : 't', 'FnArg' : 'v', 'Trait' : 'T'
        \ }

    let lines = split(res, '\n')
    let out = []

    for line in lines
        if line !~# '^MATCH'
            continue
        endif

        let completions = split(line[6:], ',')
        let kind = get(typeMap, completions[4])
        let completion = { 'kind' : kind, 'word' : completions[0], 'dup' : 1 }
        let info = join(completions[5:], ',')

        if kind ==# 'f'
            " function
            let menu = substitute(info, '\(pub\|fn\) ', '', 'g')
            let menu = substitute(menu, '{*$', '', '')
            let menu = substitute(menu, ' where\s\?.*$', '', '')
            let completion['menu'] = menu
            if g:racer_insert_paren == 1
                let completion['abbr'] = completions[0]
                let completion['word'] .= '('
            endif
            let completion['info'] = info
        elseif kind ==# 's' " struct
            let menu = substitute(info, '\(pub\|struct\) ', '', 'g')
            let menu = substitute(menu, '{*$', '', '')
            let completion['menu'] = menu
        endif

        if stridx(tolower(completions[0]), tolower(a:base)) == 0
            let out = add(out, completion)
        endif
    endfor
    call delete(b:tmpfname)
    return out
endfunction

function! s:RacerSplitLine(line)
    let separator = ';'
    let placeholder = '{PLACEHOLDER}'
    let line = substitute(a:line, '\\;', placeholder, 'g')
    let parts = split(line, separator)

    let docs = substitute(get(parts, 7, ''), '^\"\(.*\)\"$', '\1', '')
    let docs = substitute(docs, '\\\"', '\"', 'g')
    let docs = substitute(docs, '\\''', '''', 'g')
    let docs = substitute(docs, '\\n', '\n', 'g')

    " Add empty lines to before/after code snippets and before section titles
    let docs =  substitute(docs, '\n```\zs\n', '\n\n', 'g')
    let docs =  substitute(docs, '\n\ze\%(```rust\|#\+ .\+\)\n', '\n\n', 'g')

    let parts = add(parts[:6], docs)
    let parts = map(copy(parts), 'substitute(v:val, ''{PLACEHOLDER}'', '';'', ''g'')')

    return parts
endfunction

function! racer#ShowDocumentation(tab)
    let winview = winsaveview()  " Save the current cursor position
    " Move to the end of the word for the entire token to search.
    " Move one char back to avoid moving to the end of the *next* word.
    execute 'normal! he'
    let col = col('.')
    let b:tmpfname = tempname()
    " Create temporary file with the buffer's current state
    call writefile(getline(1, '$'), b:tmpfname)
    let fname = expand('%:p')
    let cmd = racer#GetRacerCmd() . ' complete-with-snippet ' .
        \ line('.') . ' ' . col . ' ' . fname . ' ' . b:tmpfname
    let res = system(cmd)
    " Restore de cursor position
    call winrestview(winview)
    " Delete the temporary file
    call delete(b:tmpfname)
    let lines = split(res, '\n')
    for line in lines
        if line !~# '^MATCH'
            continue
        endif

        let docs = s:RacerSplitLine(line[6:])[7]
        if len(docs) == 0
            break
        endif

        " Only open doc buffer if there're docs to show
        let bn = bufnr('__doc__')
        let wi = index(tabpagebuflist(tabpagenr()), bn)
        if wi > 0
            " If the __doc__ buffer is open in the current tab, jump to it
            silent execute (wi+1) . 'wincmd w'
        else
            if a:tab
                tab pedit __doc__
            else
                pedit __doc__
            endif
            wincmd P
        endif

        setlocal nobuflisted
        setlocal modifiable
        setlocal noswapfile
        setlocal buftype=nofile
        silent normal! ggdG
        silent $put=docs
        silent normal! 1Gdd
        setlocal nomodifiable
        setlocal nomodified
        setlocal filetype=rustdoc
        break
    endfor
endfunction

function! s:RacerGetCompletions(base)
    let col = col('.') - 1
    let b:tmpfname = tempname()
    " HACK: Special case to offer autocompletion on a string literal
    if getline('.')[:col-1] =~# '".*"\.$'
        call writefile(['fn main() {', '    let x: &str = "";', '    x.', '}'], b:tmpfname)
        let fname = expand('%:p')
        let cmd = racer#GetRacerCmd() . ' complete 3 6 "' .
            \ fname . '" "' . b:tmpfname . '"'
    else
        call writefile(s:RacerGetBufferContents(a:base), b:tmpfname)
        let fname = expand('%:p')
        let cmd = racer#GetRacerCmd() . ' complete ' .
            \ line('.') . ' ' . col . ' "' . fname . '" "' . b:tmpfname . '"'
    endif
    let res = system(cmd)
    let lines = split(res, '\n')
    let out = []
    for line in lines
        if line !~# '^MATCH'
            continue
        endif
        let completion = split(line[6:], ',')[0]
        if stridx(tolower(completion), tolower(a:base)) == 0
            let out = add(out, completion)
        endif
    endfor
    call delete(b:tmpfname)

    return out
endfunction

function! racer#GoToDefinition()
    if s:ErrorCheck()
        return
    endif

    let col = col('.') - 1
    let b:racer_col = col
    let fname = expand('%:p')
    let tmpfname = tempname()
    call writefile(getline(1, '$'), tmpfname)
    let cmd = racer#GetRacerCmd() . ' find-definition ' .
        \ line('.') . ' ' . col . ' ' . fname . ' ' . tmpfname
    let res = system(cmd)
    let lines = split(res, '\n')
    for line in lines
        if res =~# ' error: ' && line !=# 'END'
            call s:Warn(line)
        elseif line =~# '^MATCH'
            let linenum = split(line[6:], ',')[1]
            let colnum = split(line[6:], ',')[2]
            let fname = split(line[6:], ',')[3]
            let dotag = &tagstack && exists('*gettagstack') && exists('*settagstack')
            if dotag
                let from = [bufnr('%'), line('.'), col('.'), 0]
                let tagname = expand('<cword>')
                let stack = gettagstack()
                if stack.curidx > 1
                    let stack.items = stack.items[0:stack.curidx-2]
                else
                    let stack.items = []
                endif
                let stack.items += [{'from': from, 'tagname': tagname}]
                let stack.curidx = len(stack.items)
                call settagstack(win_getid(), stack)
            endif
            call s:RacerJumpToLocation(fname, linenum, colnum)
            if dotag
                let curidx = gettagstack().curidx + 1
                call settagstack(win_getid(), {'curidx': curidx})
            endif
            break
        endif
    endfor
    call delete(tmpfname)
endfunction

function! s:RacerGetBufferContents(base)
    " Re-combine the completion base word from omnicomplete with the current
    " line contents. Since the base word gets remove from the buffer before
    " this function is invoked we have to put it back in to out tmpfile.
    let col = col('.') - 1
    let buf_lines = getline(1, '$')
    let line_contents = getline('.')
    let buf_lines[line('.') - 1] =
        \ strpart(line_contents, 0, col) .
        \ a:base .
        \ strpart(line_contents, col, len(line_contents))
    return buf_lines
endfunction

function! s:RacerJumpToLocation(filename, linenum, colnum)
    if a:filename == ''
        return
    endif

    " Record jump mark
    normal! m`
    if a:filename != expand('%:p')
        try
            exec 'keepjumps e ' . fnameescape(a:filename)
        catch /^Vim\%((\a\+)\)\=:E37/
            " When the buffer is not saved, E37 is thrown.  We can ignore it.
        endtry
    endif
    call cursor(a:linenum, a:colnum + 1)
    " Center definition on screen
    normal! zz
endfunction

function! racer#RacerComplete(findstart, base)
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
    if !executable(racer#GetRacerCmd())
        call s:Warn('No racer executable found in $PATH (' . $PATH . ')')
        return 1
    endif
    if !exists('$RUST_SRC_PATH')
        if executable('rustc')
            let sep = s:is_win ? '\' : '/'
            let path = join([
                \ substitute(system('rustc --print sysroot'), '\n$', '', ''),
                \ 'lib',
                \ 'rustlib',
                \ 'src',
                \ 'rust',
                \ 'library',
                \ ], sep)
            if isdirectory(path)
                return 0
            endif
        endif
        call s:Warn('Could not locate Rust source. Try setting $RUST_SRC_PATH.')
        return 1
    endif
endfunction
