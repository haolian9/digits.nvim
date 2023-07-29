local fn = require("infra.fn")
local handyclosekeys = require("infra.handyclosekeys")
local jelly = require("infra.jellyfish")("digits.log")
local bufmap = require("infra.keymap.buffer")
local listlib = require("infra.listlib")
local prefer = require("infra.prefer")

local api = vim.api

---@param git digits.Git
---@param n? integer
return function(git, n)
  local args = { "--no-pager", "log" }
  if n ~= nil then listlib.extend(args, { "-n", tostring(n) }) end

  local lines
  do
    ---@diagnostic disable-next-line: param-type-mismatch
    local output = git:run(args)
    lines = fn.tolist(output)
    assert(#lines > 0)
  end

  local bufnr
  do
    bufnr = api.nvim_create_buf(false, true)
    local bo = prefer.buf(bufnr)
    bo.bufhidden = "wipe"
    bo.filetype = "git"
    handyclosekeys(bufnr)

    local bm = bufmap.wraps(bufnr)
    bm.n("gf", function()
      local lnum = api.nvim_win_get_cursor(0)[1] - 1
      local line = api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1]
      local hash = string.match(line, "^commit (%x+)$")
      if hash == nil then return jelly.warn("no availabl object under cursor") end
      require("digits.show")(git, hash)
    end)
  end

  do
    api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    -- stylua: ignore
    api.nvim_open_win(bufnr, true, {
      relative = 'editor', style = 'minimal', border = 'single',
      width = vim.go.columns - 2, height = vim.go.lines - 3, col = 0, row = 0,
      title = table.concat(args, ' ')
    })
  end
end
