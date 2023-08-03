local fn = require("infra.fn")
local handyclosekeys = require("infra.handyclosekeys")
local jelly = require("infra.jellyfish")("digits.show")
local listlib = require("infra.listlib")
local prefer = require("infra.prefer")

local facts = require("digits.facts")

local api = vim.api

--todo: consider showing it in a tab
--todo: goto prev/next sibling

---@param git digits.Git
---@param obj string
---@param path? string
return function(git, obj, path)
  local args = { "--no-pager", "show", obj }
  if path ~= nil then listlib.extend(args, { "--", path }) end

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
    api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    bo.modifiable = false
  end

  -- stylua: ignore
  local winid = api.nvim_open_win(bufnr, true, {
    relative = 'editor', style = 'minimal', border = 'single',
    width = vim.go.columns - 2, height = vim.go.lines - 3, col = 0, row = 0,
    title = table.concat(args, ' ')
  })
  api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)
end
