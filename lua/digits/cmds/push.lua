local M = {}

local ex = require("infra.ex")
local jelly = require("infra.jellyfish")("digits.cmds.push", "info")
local rifts = require("infra.rifts")
local strlib = require("infra.strlib")

local create_git = require("digits.create_git")

local api = vim.api

---@param git? digits.Git
---@param open_win fun(bufnr: integer): integer @which returns the opened winid
local function main(git, open_win)
  git = git or create_git()

  local remote, branch = git:resolve_upstream()
  if not (remote and branch) then return end

  git:floatterm({ "push", remote, branch }, nil, { auto_close = false, open_win = open_win })
end

---@param git? digits.Git
function M.floatwin(git)
  main(git, function(bufnr)
    --the same size of digits.status window
    return rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 })
  end)
end

---@param git? digits.Git
function M.tab(git)
  return main(git, function(bufnr)
    ex.eval("tab sbuffer %d", bufnr)
    return api.nvim_get_current_win()
  end)
end

return M