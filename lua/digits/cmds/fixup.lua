local M = {}

local buflines = require("infra.buflines")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("digits.cmds.fixup", "debug")
local rifts = require("infra.rifts")
local strlib = require("infra.strlib")

local create_git = require("digits.create_git")

local api = vim.api

---@param git digits.Git
---@return integer
local function compose_buf(git)
  local stdout = git:run({ "log", "--oneline", "-n", "20" })
  local lines = fn.tolist(fn.map(function(line) return "# " .. line end, stdout))
  return Ephemeral({ undolevels = 10, modifiable = true, namepat = "git://fixup/{bufnr}" }, lines)
end

local function find_chosen_hash(bufnr)
  local iter = buflines.iter_unmatched(bufnr, "^#")
  local line = iter()
  if line == nil then return end
  line = strlib.lstrip(line)
  return string.sub(line, 1, 8)
end

do
  ---@param git? digits.Git
  ---@param on_exit? fun() @called after commit did happen
  ---@param open_hashes_win fun(bufnr: integer): integer @which returns the opened winid
  local function main(git, on_exit, open_hashes_win)
    git = git or create_git()

    local bufnr = compose_buf(git)

    api.nvim_create_autocmd("BufWipeout", {
      buffer = bufnr,
      once = true,
      callback = function()
        local hash = find_chosen_hash(bufnr)
        if hash == nil then return jelly.info("no hash is chosen") end

        git:floatterm({ "commit", "--fixup", hash }, { on_exit = on_exit }, { auto_close = false })
      end,
    })

    open_hashes_win(bufnr)
  end

  ---@param git? digits.Git
  ---@param on_exit? fun() @called after commit did happen
  function M.floatwin(git, on_exit)
    main(git, on_exit, function(bufnr) return rifts.open.fragment(bufnr, true, { relative = "editor" }, { width = 0.6, height = 0.8 }) end)
  end

  ---@param git? digits.Git
  ---@param on_exit? fun() @called after commit did happen
  function M.tab(git, on_exit)
    main(git, on_exit, function(bufnr)
      ex.eval("tab sbuffer %d", bufnr)
      return api.nvim_get_current_win()
    end)
  end
end
return M
