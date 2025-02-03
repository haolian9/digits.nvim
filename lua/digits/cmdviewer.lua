local M = {}

local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local itertools = require("infra.itertools")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")
local winsplit = require("infra.winsplit")

---NB: only the stdout is visible, but not stderr
---@param git digits.Git
---@param args string[]
---@return integer bufnr
function M.fullscreen_floatwin(git, args)
  local lines = itertools.tolist(git:run(args))

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
---@return integer bufnr
function M.tab(git, args)
  local lines = itertools.tolist(git:run(args))

  local bufnr
  do
    local function namefn(nr) return string.format("git://%s/%d", git:find_subcmd_in_args(args), nr) end
    bufnr = Ephemeral({ namefn = namefn, handyclose = true }, lines)
    prefer.bo(bufnr, "filetype", "git")
  end

  ex.eval("tab sb %d", bufnr)

  local winid = ni.get_current_win()
  prefer.wo(winid, "list", false)

  return bufnr
end

---NB: only the stdout is visible, but not stderr
---@param git digits.Git
---@param args string[]
---@param side infra.winsplit.Side
---@return integer bufnr
function M.split(git, args, side)
  local lines = itertools.tolist(git:run(args))

  local bufnr
  do
    local function namefn(nr) return string.format("git://%s/%d", git:find_subcmd_in_args(args), nr) end
    bufnr = Ephemeral({ namefn = namefn, handyclose = true }, lines)
    prefer.bo(bufnr, "filetype", "git")
  end

  winsplit(side, bufnr)
  local winid = ni.get_current_win()
  prefer.wo(winid, "list", false)

  return bufnr
end

return M
