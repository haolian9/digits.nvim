local M = {}

local buflines = require("infra.buflines")
local bufopen = require("infra.bufopen")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local jelly = require("infra.jellyfish")("digits.cmds.commit", "info")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")
local strlib = require("infra.strlib")

local create_git = require("digits.create_git")

---collect from the first line, until a #-prefixed line
---@param bufnr integer
---@return nil|string
local function collect_msg(bufnr)
  local lines = {}
  for line in buflines.iter(bufnr) do
    if strlib.startswith(line, "#") then break end
    table.insert(lines, line)
  end

  if #lines == 0 or lines[1] == "" then return end

  return table.concat(lines, "\n")
end

---@param git digits.Git
---@param on_exit? fun() @called when the commit command completed
local function compose_buf(git, on_exit)
  local infos = {}
  do
    local status = git:run({ "status" }, { configs = { ["advice.statusHints"] = "false" } })
    for line in status do
      table.insert(infos, "# " .. line)
    end

    local diff = git:run({ "--no-pager", "diff", "--cached" })
    for line in diff do
      table.insert(infos, line)
    end
  end

  local bufnr
  do
    bufnr = Ephemeral({ undolevels = 10, modifiable = true, namepat = "git://commit/{bufnr}" }, { "", infos })
    prefer.bo(bufnr, "filetype", "gitcommit")
  end

  --NB: as one buffer can be attached to many windows, worsely :sp and :vs are inevitable
  --    hence avoid winclosed
  ni.create_autocmd("bufwipeout", {
    buffer = bufnr,
    once = true,
    callback = function()
      local msg = collect_msg(bufnr)
      if msg == nil then return jelly.info("Aborting commit due to empty commit message.") end
      git:floatterm({ "commit", "-m", msg }, { on_exit = on_exit }, { auto_close = false })
    end,
  })

  return bufnr
end

---equal to `git commit --verbose`
---@param mode? infra.bufopen.Mode
---@param on_exit? fun() @called when the commit command completed
---@param git? digits.Git
function M.open(mode, on_exit, git)
  mode = mode or "tab"
  git = git or create_git()
  local bufnr = compose_buf(git, on_exit)

  if mode == "float" then
    rifts.open.fullscreen(bufnr, true, { relative = "editor" }, { laststatus3 = true })
  else
    bufopen(mode, bufnr)
  end
end

return M
