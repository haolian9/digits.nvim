local M = {}

local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fn = require("infra.fn")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")

local api = vim.api

---NB: only the stdout is visible, but not stderr
---@param git digits.Git
---@param args string[]
---@return integer @bufnr
function M.fullscreen_floatwin(git, args)
  local lines = fn.tolist(git:run(args))

  local bufnr
  do
    local function namefn(nr) return string.format("git://%s/%d", git:find_subcmd_in_args(args), nr) end
    bufnr = Ephemeral({ namefn = namefn, handyclose = true }, lines)
    prefer.bo(bufnr, "filetype", "git")
  end

  local winid = rifts.open.fullscreen(bufnr, true, { relative = "editor" }, { laststatus3 = true })
  prefer.wo(winid, "list", false)

  return bufnr
end

---NB: only the stdout is visible, but not stderr
---@param git digits.Git
---@param args string[]
---@return integer @bufnr
function M.tab(git, args)
  local lines = fn.tolist(git:run(args))

  local bufnr
  do
    local function namefn(nr) return string.format("git://%s/%d", git:find_subcmd_in_args(args), nr) end
    bufnr = Ephemeral({ namefn = namefn, handyclose = true }, lines)
    prefer.bo(bufnr, "filetype", "git")
  end

  ex("tab sb " .. bufnr)

  local winid = api.nvim_get_current_win()
  prefer.wo(winid, "list", false)

  return bufnr
end

return M
