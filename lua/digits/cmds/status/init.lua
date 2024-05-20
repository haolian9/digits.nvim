local M = {}

local ex = require("infra.ex")
local rifts = require("infra.rifts")
local winsplit = require("infra.winsplit")

local create_buf = require("digits.cmds.status.create_buf")
local create_git = require("digits.create_git")

local api = vim.api

---@param git? digits.Git
function M.floatwin(git)
  git = git or create_git()

  rifts.open.fragment(create_buf(git), true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 })
end

---@param git? digits.Git
---@param side infra.winsplit.Side
function M.split(git, side)
  git = git or create_git()

  winsplit(side, create_buf(git))
end

---@param git? digits.Git
function M.win1000(git)
  git = git or create_git()

  api.nvim_win_set_buf(0, create_buf(git))
end

---@param git? digits.Git
function M.tab(git)
  git = git or create_git()

  ex.eval("tab sbuffer %d", create_buf(git))
end

return M
