provide some git workflows based on nvim

## design choices
* git cli is good
* focus on my personal git workflows
* utilize nvim's infrastructures for more convenient UX
    * tabpage/floatwin, terminal, syntax/{git,gitcommit}

## status
* just works
* feature-complete

## requirements
* linux
* git 2.*
* nvim 0.9.*
* haolian9/infra.nvim
* haolian9/puff.nvim

## todo
* [x] fugitive `0Git` 
* [x] git commit -v
* [x] git diff HEAD -- file
* [x] git log
* [x] git blame {line}
* [x] git blame {file}
* [x] git diff {file}
* [x] git diff hunks -> loclist
* [x] git log {file}
* [x] git {cmd} ...
* [ ] fugitive `Gedit`
      * [x] git show {object}
* [x] ~~libgit2 instead of git bin~~ i quite satisfied with git bin
* [x] ~~git commit --fixup~~ just run it in a float term
* [x] git push when upstream is set for current branch

## non-goals:
* a complete port of vim-fugitive
* a complete port of GV

## usage
* `:lua require'digits'.status()` # equals to fugitive `0Git`
* `:lua require'digits'.commit()`
    * the COMMIT_EDITMSG is a buffer with ft=gitcommit

here is my personal config
```
do
  m.n("git status", "<leader>x", function() require("digits").status() end)

  usercmd("Status",    function() require("digits").status() end)
  usercmd("Commit",    function() require("digits").commit() end)
  usercmd("Diff",      function() require("digits").diff() end)
  usercmd("DiffFile",  function() require("digits").diff_file() end)
  usercmd("Hunks",     function() require("digits").hunks() end)
  usercmd("BlameLine", function() require("digits").blame_curline() end)
  usercmd("Blame",     function() require("digits").blame() end)
  usercmd("Log",       function() require("digits").log() end)

  do --:Git
    local comp = cmds.ArgComp.constant(function() return require("digits").comp.available_subcmds() end)
    local spell = cmds.Spell("Git", function(args) assert(require("digits")[args.subcmd])() end)
    spell:add_arg("subcmd", "string", false, "status", comp)
    cmds.cast(spell)
  end
end
```
