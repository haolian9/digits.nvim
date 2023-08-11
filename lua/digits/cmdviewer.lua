local M = {}

local bufrename = require("infra.bufrename")
local bufrename = require("infra.bufrename")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fn = require("infra.fn")
local handyclosekeys = require("infra.handyclosekeys")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local facts = require("digits.facts")

local api = vim.api

---for `git --no-pager status`, `git status`
---@param args string[]
---@return string
local function find_subcmd_in_args(args)
  for _, a in ipairs(args) do
    if not strlib.startswith(a, "-") then return a end
  end
  error("unreachable")
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
    bufrename(bufnr, string.format("git://%s/%d", find_subcmd_in_args(args), bufnr))
  end

  do
    local height = vim.go.lines - 2 - vim.go.cmdheight
    local width = vim.go.columns - 2
    -- stylua: ignore
    local winid = api.nvim_open_win(bufnr, true, {
      relative = "editor", style = "minimal", border = "single",
      width = width, height = height, col = 0, row = 0,
    })
    api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)
  end

  return bufnr
end

function M.split(git, args, split_cmd)
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
    bufrename(bufnr, string.format("git://%s/%d", find_subcmd_in_args(args), bufnr))
  end

  do
    ex(split_cmd)
    local height = vim.go.lines - 2 - vim.go.cmdheight
    local width = vim.go.columns - 2
    -- stylua: ignore
    local winid = api.nvim_open_win(bufnr, true, {
      relative = "editor", style = "minimal", border = "single",
      width = width, height = height, col = 0, row = 0,
    })
    api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)
  end

  return bufnr
end

return M
