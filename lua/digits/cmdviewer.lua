local M = {}

local Ephemeral = require("infra.Ephemeral")
local fn = require("infra.fn")
local handyclosekeys = require("infra.handyclosekeys")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local facts = require("digits.facts")

local api = vim.api

---for `git --no-pager status`, `git status`
---@param args string[]
---@return string?
local function find_subcmd_in_args(args)
  for _, a in ipairs(args) do
    if not strlib.startswith(a, "-") then return a end
  end
end

---@param git digits.Git
---@param args string[]
---@return integer @bufnr
function M.fullscreen_floatwin(git, args)
  local lines
  do
    local output = git:run(args)
    lines = fn.tolist(output)
    assert(#lines > 0)
  end

  local bufnr
  do
    bufnr = Ephemeral(nil, lines)
    prefer.bo(bufnr, "filetype", "git")
    handyclosekeys(bufnr)
  end

  do
    local height = vim.go.lines - 2 - vim.go.cmdheight
    local width = vim.go.columns - 2
    -- stylua: ignore
    local winid = api.nvim_open_win(bufnr, true, {
      relative = "editor", style = "minimal", border = "single",
      width = width, height = height, col = 0, row = 0,
      title = string.format("git://%s", find_subcmd_in_args(args) or ""),
    })
    api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)
  end

  return bufnr
end

return M
