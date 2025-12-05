local M = {}

local bufopen = require("infra.bufopen")
local ni = require("infra.ni")
local rifts = require("infra.rifts")

local create_git = require("digits.create_git")

local function open_float(bufnr)
  --the same size of digits.status window
  return rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 })
end

---@param mode? infra.bufopen.Mode|'float'
---@param git? digits.Git
function M.open(mode, git)
  mode = mode or "tab"
  git = git or create_git()

  local remote, branch = git:resolve_upstream()
  if not (remote and branch) then return end

  local open_win
  if open_win == "float" then
    open_win = open_float
  else
    open_win = function(bufnr)
      bufopen(mode, bufnr)
      return ni.get_current_win()
    end
  end

  git:floatterm({ "push", remote, branch }, nil, { auto_close = false, open_win = open_win })
end

return M
