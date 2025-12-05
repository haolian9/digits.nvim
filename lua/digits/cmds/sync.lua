local M = {}

local bufopen = require("infra.bufopen")
local ni = require("infra.ni")
local rifts = require("infra.rifts")

local create_git = require("digits.create_git")

local function open_float(bufnr)
  --the same size of digits.status window
  return rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 })
end

---@param mode? infra.bufopen.Mode|'tab'
---@param on_exit? fun()
---@param git? digits.Git
function M.open(mode, on_exit, git)
  mode = mode or "tab"
  git = git or create_git()

  local remote, branch = git:resolve_upstream()
  if not (remote and branch) then return end

  git:execute({ "fetch", remote, branch })

  local open_win
  if mode == "float" then
    open_win = open_float
  else
    open_win = function(bufnr)
      bufopen(mode, bufnr)
      return ni.get_current_win()
    end
  end

  git:floatterm( --
    { "rebase", "--stat", "--autostash", string.format("%s/%s", remote, branch) },
    { on_exit = on_exit },
    { auto_close = false, open_win = open_win }
  )
end

return M
