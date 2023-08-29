local Augroup = require("infra.Augroup")
local bufrename = require("infra.bufrename")
local dictlib = require("infra.dictlib")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("digits.Git")
local rifts = require("infra.rifts")
local strlib = require("infra.strlib")
local subprocess = require("infra.subprocess")

local api = vim.api

---@class digits.Git
---@field root string
local Git = {}
do
  Git.__index = Git

  local mandatory_envs = {
    LC_ALL = "C", --avoid i18n
    LANG = "C", --avoid i18n
    GIT_CONFIG_PARAMETERS = "'color.ui=never'", --color=never
  }

  ---@param args string[]
  function Git:silent_run(args)
    local cp = subprocess.run("git", { args = args, cwd = self.root, env = mandatory_envs }, false)
    if cp.exit_code ~= 0 then
      jelly.err("cmd='%s'; exit code=%d", fn.join(args, " "), cp.exit_code)
      error("git cmd failed")
    end
  end

  ---@param args string[]
  ---@return fun(): string?
  function Git:run(args)
    local cp = subprocess.run("git", { args = args, cwd = self.root, env = mandatory_envs }, true)
    if cp.exit_code ~= 0 then
      jelly.err("cmd='%s'; exit code=%d", fn.join(args, " "), cp.exit_code)
      error("git cmd failed")
    end
    return cp.stdout
  end

  do
    ---for `git --no-pager status`, `git status`
    ---@param args string[]
    ---@return string?
    local function find_subcmd_in_args(args)
      for _, a in ipairs(args) do
        if not strlib.startswith(a, "-") then return a end
      end
      error("unreachable")
    end

    local function startinsert() ex("startinsert") end

    local function autoclose_on_success()
      if vim.v.event.status == 0 then api.nvim_win_close(0, false) end
    end

    ---@alias TermSpec {insert?: boolean, autoclose?: boolean}

    local resolve_termspec
    do
      local default = { insert = true, autoclose = true }
      ---@param user_specified? table
      ---@return TermSpec
      function resolve_termspec(user_specified)
        if user_specified == nil then return default end
        return dictlib.merged(user_specified, default)
      end
    end

    ---@param args string[]
    ---@param jobspec? {on_exit?: fun(job: integer, exit_code: integer, event: 'exit'), env?: {[string]: string}}
    ---@param termspec? TermSpec
    function Git:floatterm(args, jobspec, termspec)
      if jobspec == nil then jobspec = {} end
      termspec = resolve_termspec(termspec)

      local bufnr = Ephemeral()
      local aug = Augroup.buf(bufnr, true)

      if termspec.insert then
        aug:once("termopen", { callback = startinsert })
        --i dont know why, but termopen will not be always triggered
        aug:once("termclose", { callback = startinsert })
      end

      if termspec.autoclose then
        aug:once("termclose", {
          nested = true,
          callback = function()
            if vim.v.event.status ~= 0 then return end
            if termspec.insert then ex("stopinsert") end
            api.nvim_win_close(0, false)
          end,
        })
      end

      rifts.open.fullscreen(bufnr, true, { relative = "editor", border = "single" })

      do
        table.insert(args, 1, "git")
        if jobspec.env == nil then jobspec.env = {} end
        for k, v in pairs(mandatory_envs) do
          if jobspec.env[k] == nil then jobspec.env[k] = v end
        end
        vim.fn.termopen(args, { cwd = self.root, env = jobspec.env, on_exit = jobspec.on_exit })
      end

      bufrename(bufnr, string.format("git://%s/%d", find_subcmd_in_args(args), bufnr))
    end
  end

  ---@param path string
  ---@return boolean
  function Git:is_tracked(path)
    assert(path ~= nil and path ~= "")
    local cp = subprocess.run("git", { args = { "ls-files", "--error-unmatch", "--", path }, cwd = self.root, env = mandatory_envs }, false)
    return cp.exit_code == 0
  end
end

---@param root string
---@return digits.Git
return function(root) return setmetatable({ root = root }, Git) end
