local jelly = require("infra.jellyfish")("digits.log")
local bufmap = require("infra.keymap.buffer")
local listlib = require("infra.listlib")

local cmdviewer = require("digits.cmdviewer")

local api = vim.api

---@param git digits.Git
---@param n? integer
return function(git, n)
  local args = { "--no-pager", "log" }
  if n ~= nil then listlib.extend(args, { "-n", tostring(n) }) end

  local bufnr = cmdviewer.fullscreen_floatwin(git, args)

  bufmap(bufnr, "n", "gf", function()
    local lnum = api.nvim_win_get_cursor(0)[1] - 1
    local line = api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1]
    local hash = string.match(line, "^commit (%x+)$")
    if hash == nil then return jelly.warn("no availabl object under cursor") end
    require("digits.show")(git, hash)
  end)
end
