local M = {}

local bufopen = require("infra.bufopen")
local Ephemeral = require("infra.Ephemeral")
local itertools = require("infra.itertools")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")

local function prepare_buf(git, args)
  local lines = itertools.tolist(git:run(args))

  local function namefn(nr) return string.format("git://%s/%d", git:find_subcmd_in_args(args), nr) end
  local bufnr = Ephemeral({ namefn = namefn, handyclose = true }, lines)
  prefer.bo(bufnr, "filetype", "git")

  return bufnr
end

---NB: only the stdout is visible, but not stderr
---@param git digits.Git
---@param args string[]
---@return integer bufnr
function M.fullscreen_floatwin(git, args)
  local bufnr = prepare_buf(git, args)

  local winid = rifts.open.fullscreen(bufnr, true, { relative = "editor" }, { laststatus3 = true })
  prefer.wo(winid, "list", false)

  return bufnr
end

---@param mode infra.bufopen.Mode
---@param git digits.Git
---@param args string[]
---@return integer bufnr
function M.open(mode, git, args)
  local bufnr = prepare_buf(git, args)

  bufopen(mode, bufnr)
  local winid = ni.get_current_win()
  prefer.wo(winid, "list", false)

  return bufnr
end

return M
