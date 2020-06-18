# Vim Racer Plugin

This plugin allows vim to use [Racer](http://github.com/phildawes/racer) for Rust code completion and navigation.

## Installation

1. Build / Install [Racer](http://github.com/phildawes/racer)

2. Install using Pathogen, Vundle or NeoBundle. Or, copy `ftplugin/rust_racer.vim` into your `~/.vim/plugin` directory.

  Vundle users:
  ```
  Plugin 'racer-rust/vim-racer'
  ```

  NeoBundle users:
  ```
  NeoBundle 'racer-rust/vim-racer'
  ```

  vim-plug users:
  ```
  Plug 'racer-rust/vim-racer'
  ```

  Pathogen users:
  ```
  git clone --depth=1 https://github.com/racer-rust/vim-racer.git ~/.vim/bundle/vim-racer
  ```

3. Add `g:racer_cmd` to your `.vimrc`. It contains full path to `racer` executable file.
Variable `g:racer_cmd` is optional. You do not need to use this variable if the executable file is in a directory that is specified in `$PATH`, else you should specified full path to `racer` executable binary file in this `g:racer_cmd`. Also it's worth turning on 'hidden' mode for buffers otherwise you need to save the current buffer every time you do a goto-definition. E.g.:

  ```
  set hidden
  let g:racer_cmd = "/home/user/.cargo/bin/racer"
  ```

4. If you want completions to show the complete function definition (e.g. its arguments and return type), enable the experimental completer:

  ```
  let g:racer_experimental_completer = 1
  ```

5. If you want to insert the parenthesis in the completion:

  ```
  let g:racer_insert_paren = 1
  ```

## Example Mappings

vim-racer enables `C-x-C-o` to search for completions and provides several
`<Plug>` mappings for source code navigation. These mappings are not enabled by
default but you can easily use them by adding the following lines to your
`.vimrc` (Or `init.vim` in case of Neovim). 

For example, with the following mappings you can navigate to the identifier under
the cursor and open it on the current buffer, on an horizontal or vertical split, on a new tab,
or go straight to the documentation:

```
augroup Racer
    autocmd!
    autocmd FileType rust nmap <buffer> gd         <Plug>(rust-def)
    autocmd FileType rust nmap <buffer> gs         <Plug>(rust-def-split)
    autocmd FileType rust nmap <buffer> gx         <Plug>(rust-def-vertical)
    autocmd FileType rust nmap <buffer> gt         <Plug>(rust-def-tab)
    autocmd FileType rust nmap <buffer> <leader>gd <Plug>(rust-doc)
    autocmd FileType rust nmap <buffer> <leader>gD <Plug>(rust-doc-tab)
augroup END
```
