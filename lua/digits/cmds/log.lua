local jelly = require("infra.jellyfish")("digits.cmds.log")
local bufmap = require("infra.keymap.buffer")
local buflines = require"infra.buflines"
local listlib = require("infra.listlib")

local cmdviewer = require("digits.cmdviewer")
local create_git = require("digits.create_git")

local api = vim.api

---@param git? digits.Git
---@param n? integer @nil means show whole log
return function(git, n)
  git = git or create_git()

  local args = { "--no-pager", "log" }
  if n ~= nil then listlib.extend(args, { "-n", tostring(n) }) end

  local bufnr = cmdviewer.fullscreen_floatwin(git, args)

  bufmap(bufnr, "n", "gf", function()
    local lnum = api.nvim_win_get_cursor(0)[1] - 1
    local line = assert(buflines.line(bufnr, lnum))
    local hash = string.match(line, "^commit (%x+)$")
    if hash == nil then return jelly.warn("no availabl object under cursor") end
    require("digits.cmds.show")(git, hash)
  end)
end
