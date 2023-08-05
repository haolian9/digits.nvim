provide some git workflows based on nvim

## design choices
* git cli is good, prefer it ASAP
* focus on my personal workflows around git
* utilize nvim's infrastructures to provide more convenient UX
    * tabpage/floatwin, terminal, luajit ffi

## status
* it just works (tm)
* it covered almost all my workflows on git

## requirements
* linux
* git 2.41.0
* nvim 0.9.1
* ~~libgit2: 1.6.4~~
* ~~zig 0.10.1~~
* haolian9/infra.nvim

## todo
* [x] fugitive `0Git` 
* [x] git commit -v
* [x] git diff HEAD -- file
* [x] git log
* [x] git blame {line}
* [x] git blame {file}
* [x] git diff {file}
* [x] git log {file}
* [ ] fugitive `Gedit`
*     * [x] git show {object}
* [ ] libgit2 instead of git bin
* [x] ~~git commit --fixup~~ just run it in a float term

## non-goals:
* a complete port of vim-fugitive
* a complete port of GV

## usage
* `:lua require'digits'.status()` # equals to fugitive `0Git`
* `:lua require'digits'.commit()`
    * the COMMIT_EDITMSG is a buffer with ft=gitcommit
