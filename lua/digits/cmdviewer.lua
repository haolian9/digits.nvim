local M = {}

local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fn = require("infra.fn")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")
local strlib = require("infra.strlib")

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
  local lines = fn.tolist(git:run(args))

  local bufnr
  do
    local function namefn(nr) return string.format("git://%s/%d", find_subcmd_in_args(args), nr) end
    bufnr = Ephemeral({ namefn = namefn, handyclose = true }, lines)
    prefer.bo(bufnr, "filetype", "git")
  end

  local winid = rifts.open.fullscreen(bufnr, true, { relative = "editor", border = "single" })
  prefer.wo(winid, "list", false)

  return bufnr
end

---@param git digits.Git
---@param args string[]
---@return integer @bufnr
function M.tab(git, args)
  local lines = fn.tolist(git:run(args))

  local bufnr
  do
    local function namefn(nr) return string.format("git://%s/%d", find_subcmd_in_args(args), nr) end
    bufnr = Ephemeral({ namefn = namefn, handyclose = true }, lines)
    prefer.bo(bufnr, "filetype", "git")
  end

  ex("tab sb " .. bufnr)

  local winid = api.nvim_get_current_win()
  prefer.wo(winid, "list", false)

  return bufnr
end

return M
