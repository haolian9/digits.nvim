local M = {}

local ex = require("infra.ex")
local jelly = require("infra.jellyfish")("digits.cmds.push", "info")
local rifts = require("infra.rifts")
local strlib = require("infra.strlib")

local create_git = require("digits.create_git")

local api = vim.api

---@param git digits.Git
local function resolve_push_remote(git)
  local curbr = assert(git:run({ "branch", "--show-current" })())
  local output = git:run({ "config", "--get-regexp", string.format([[branch\.%s\.(remote|merge)]], curbr) })

  local remote
  do
    remote = output()
    if remote == nil then return jelly.warn("no upstream remote for local branch %s", curbr) end
    local prefix = string.format([[branch.%s.remote ]], curbr)
    assert(strlib.startswith(remote, prefix))
    remote = string.sub(remote, #prefix + 1)
  end

  local branch
  do
    branch = output()
    if branch == nil then return jelly.warn("no upstream branch for local branch %s", curbr) end
    local prefix = string.format([[branch.%s.merge refs/heads/]], curbr)
    assert(strlib.startswith(branch, prefix))
    branch = string.sub(branch, #prefix + 1)
  end

  return remote, branch
end

do
  ---@param git? digits.Git
  ---@param open_win fun(bufnr: integer): integer @which returns the opened winid
  local function main(git, open_win)
    git = git or create_git()

    local remote, branch = resolve_push_remote(git)
    if not (remote and branch) then return end

    git:floatterm({ "push", remote, branch }, nil, { auto_close = false, open_win = open_win })
  end

  ---@param git? digits.Git
  function M.floatwin(git)
    main(git, function(bufnr)
      --the same size of digits.status window
      return rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 })
    end)
  end

  ---@param git? digits.Git
  function M.tab(git)
    return main(git, function(bufnr)
      ex.eval("tab sbuffer %d", bufnr)
      return api.nvim_get_current_win()
    end)
  end
end

return M
