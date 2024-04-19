local M = {}

local buflines = require("infra.buflines")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("digits.cmds.amend", "debug")
local listlib = require("infra.listlib")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local create_git = require("digits.create_git")

local api = vim.api

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
---@param on_exit? fun()
---@return integer
local function compose_buf(git, on_exit)
  local lines = {}
  do
    local msg = git:run({ "show", "--pretty=%B", "--no-patch", "HEAD" })
    listlib.extend(lines, msg)

    listlib.extend(lines, {
      "# Please enter the commit message for your changes. Lines starting",
      "# with '#' will be ignored, and an empty message aborts the commit.",
    })

    --todo: merge into `git status`
    listlib.extend(lines, { "#", "# Changes between HEAD~1..HEAD" })
    local diff = git:run({ "diff", "--name-status", "HEAD~1..HEAD" })
    listlib.extend(lines, fn.map(function(line) return "#   " .. line end, diff))

    table.insert(lines, "#")
    local status = git:run({ "status" }, { configs = { ["advice.statusHints"] = "false" } })
    listlib.extend(lines, fn.map(function(line) return "# " .. line end, status))
  end

  local bufnr = Ephemeral({ undolevels = 10, modifiable = true, namepat = "git://amend/{bufnr}" }, lines)

  api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    once = true,
    callback = function()
      local msg = collect_msg(bufnr)
      if msg == nil then return jelly.info("Aborting commit due to empty commit message.") end
      git:floatterm({ "commit", "--amend", "-m", msg }, { on_exit = on_exit }, { auto_close = false })
    end,
  })

  return bufnr
end

---@param git? digits.Git
---@param on_exit? fun() @called after commit did happen
function M.tab(git, on_exit)
  git = git or create_git()

  local bufnr = compose_buf(git, on_exit)

  ex.eval("tab sbuffer %d", bufnr)
  prefer.wo(api.nvim_get_current_win(), "list", false)
end

return M

