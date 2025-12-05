local M = {}

local buflines = require("infra.buflines")
local bufopen = require("infra.bufopen")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local its = require("infra.its")
local jelly = require("infra.jellyfish")("digits.cmds.fixup", "debug")
local ni = require("infra.ni")
local rifts = require("infra.rifts")
local strlib = require("infra.strlib")

local create_git = require("digits.create_git")

---@param git digits.Git
---@return integer
local function compose_buf(git)
  local stdout = git:run({ "log", "--oneline", "--abbrev=8", "-n", "20" })
  local lines = its(stdout):map(function(line) return "# " .. line end):tolist()
  return Ephemeral({ undolevels = 10, modifiable = true, namepat = "git://fixup/{bufnr}" }, lines)
end

local function find_chosen_hash(bufnr)
  local iter = buflines.iter_unmatched(bufnr, vim.regex("^#"))
  local line = iter()
  if line == nil then return end
  line = strlib.lstrip(line)
  return string.sub(line, 1, 8)
end

---@param mode? infra.bufopen.Mode|'tab'
---@param on_exit? fun() @called after commit did happen
---@param git? digits.Git
function M.open(mode, on_exit, git)
  mode = mode or "tab"
  git = git or create_git()

  local bufnr = compose_buf(git)

  ni.create_autocmd("BufWipeout", {
    buffer = bufnr,
    once = true,
    callback = function()
      local hash = find_chosen_hash(bufnr)
      if hash == nil then return jelly.info("no hash is chosen") end

      git:floatterm({ "commit", "--fixup", hash }, { on_exit = on_exit }, { auto_close = false })
    end,
  })

  if mode == "float" then
    rifts.open.fragment(bufnr, true, { relative = "editor" }, { width = 0.6, height = 0.8 })
  else
    bufopen(mode, bufnr)
  end
end

return M
