provide some git workflows based on nvim

## design choices
* git cli is good
* focus on my personal git workflows
* utilize nvim's infrastructures for more convenient UX
    * tabpage/floatwin, terminal, syntax/{git,gitcommit}

## non-goals:
* a complete port of vim-fugitive
* a complete port of GV

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

## status
* just works
* feature-complete

## requirements
* linux
* git 2.*
* nvim 0.9.*
* haolian9/infra.nvim
* haolian9/puff.nvim

## usage
* `:lua require'digits.status'.floatwin()` # equals to fugitive `0Git`
* `:lua require'digits.commit'.tab()`
    * the COMMIT_EDITMSG is a buffer with ft=gitcommit

here is my personal config
```
do
  m.n("<leader>x", function() require("digits.status").floatwin() end)

  do --requires haolian9/cmds.nvim
    local handlers = {
      status = function() require("digits.status").floatwin() end,
      push = function() require("digits.push")() end,
      hunks = function() require("digits.diffhunks").setloclist() end,
      diff = function() require("digits.diff")() end,
      diff_file = function() require("digits.diff")(nil, api.nvim_get_current_buf()) end,
      diff_cached = function() require("digits.diff")(nil, nil, true) end,
      log = function() require("digits.log")(nil, 100) end,
      commit = function() require("digits.commit").tab() end,
    }
    local comp = cmds.ArgComp.constant(dictlib.keys(handlers))
    local spell = cmds.Spell("Git", function(args) assert(handlers[args.subcmd])() end)
    spell:add_arg("subcmd", "string", false, "status", comp)
    cmds.cast(spell)
  end
end
```
