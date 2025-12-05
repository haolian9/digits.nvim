local M = {}

local bufopen = require("infra.bufopen")
local rifts = require("infra.rifts")

local create_buf = require("digits.cmds.status.create_buf")
local create_git = require("digits.create_git")

---@param mode? infra.bufopen.Mode|'float'
---@param git? digits.Git
function M.open(mode, git)
  mode = mode or "tab"
  git = git or create_git()

  if mode == "float" then
    rifts.open.fragment(create_buf(git), true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 })
  else
    bufopen(mode, create_buf(git))
  end
end

return M
