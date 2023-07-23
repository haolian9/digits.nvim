provide some git workflows based on nvim

## design choices
* git cli is good, prefer it ASAP
* focus on my personal workflow around git
* utilize nvim's infrastructures to provide more convenient UX
    * floatwin, terminal, luajit ffi

## status
* far from complete

## requirements
* linux
* git 2.41.0
* nvim 0.9.1
* ~~libgit2: 1.6.4~~
* ~~zig 0.10.1~~

## todo
* [x] fugitive `0Git` 
* [ ] GV
* [ ] git commit -v
* [ ] git blame file
* [ ] libgit2 instead of git bin

## non-goals:
* a complete port of vim-fugitive
* a complete port of GV

## usage
* `:lua require'digits'.status()` # equals fugitive's `0Git`
