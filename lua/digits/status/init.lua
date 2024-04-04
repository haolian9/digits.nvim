local M = {}

local ex = require("infra.ex")
local rifts = require("infra.rifts")
local winsplit = require("infra.winsplit")

local create_git = require("digits.create_git")
local create_buf = require("digits.status.create_buf")

local api = vim.api

---@param git? digits.Git
function M.floatwin(git)
  git = git or create_git()

  local bufnr = create_buf(git)

  rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 })
end

---@param git? digits.Git
---@param side infra.winsplit.Side
function M.split(git, side)
  git = git or create_git()

  local bufnr = create_buf(git)

  winsplit(side, api.nvim_buf_get_name(bufnr))
  local winid = api.nvim_get_current_win()
  api.nvim_win_set_buf(winid, bufnr)
end

---@param git? digits.Git
function M.win1000(git)
  git = git or create_git()

  local bufnr = create_buf(git)

  local winid = api.nvim_get_current_win()
  api.nvim_win_set_buf(winid, bufnr)
end

---@param git? digits.Git
function M.tab(git)
  git = git or create_git()

  local bufnr = create_buf(git)

  ex("tabedit", string.format("sbuffer %d", bufnr))
end

return M
