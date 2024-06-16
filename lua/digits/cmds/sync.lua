local M = {}

local ex = require("infra.ex")
local ni = require("infra.ni")
local rifts = require("infra.rifts")

local create_git = require("digits.create_git")

---@param git? digits.Git
---@param open_win fun(bufnr: integer): integer @which returns the opened winid
---@param on_exit? fun()
local function main(git, open_win, on_exit)
  git = git or create_git()

  local remote, branch = git:resolve_upstream()
  if not (remote and branch) then return end

  git:execute({ "fetch", remote, branch })

  git:floatterm(
    --
    { "rebase", "--stat", "--autostash", string.format("%s/%s", remote, branch) },
    { on_exit = on_exit },
    { auto_close = false, open_win = open_win }
  )
end

---@param git? digits.Git
---@param on_exit fun()
function M.floatwin(git, on_exit)
  main(git, function(bufnr)
    --the same size of digits.status window
    return rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 })
  end, on_exit)
end

---@param git? digits.Git
---@param on_exit fun()
function M.tab(git, on_exit)
  return main(git, function(bufnr)
    ex.eval("tab sbuffer %d", bufnr)
    return ni.get_current_win()
  end, on_exit)
end

return M
