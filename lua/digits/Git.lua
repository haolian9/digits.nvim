local ex = require("infra.ex")
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("digits.Git")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")
local subprocess = require("infra.subprocess")

local facts = require("digits.facts")

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
    --jelly.debug("cmd='git %s' cwd=%s env='%s'", table.concat(args, " "), self.root, vim.inspect(mandatory_envs))
    local cp = subprocess.run("git", { args = args, cwd = self.root, env = mandatory_envs }, false)
    if cp.exit_code ~= 0 then
      jelly.err("cmd='%s'; exit code=%d", fn.join(args, " "), cp.exit_code)
      error("git cmd failed")
    end
  end

  ---@param args string[]
  ---@return fun(): string?
  function Git:run(args)
    --jelly.debug("cmd='git %s' cwd=%s env='%s'", table.concat(args, " "), self.root, vim.inspect(mandatory_envs))
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
    local function find_cmd_in_args(args)
      for _, a in ipairs(args) do
        if not strlib.startswith(a, "-") then return a end
      end
    end

    local function startinsert() ex("startinsert") end

    ---@param args string[]
    ---@param jobspec {on_exit?: fun(job: integer, exit_code: integer, event: 'exit'), env?: {[string]: string}}
    ---@param enter_insertmode? boolean @nil=true
    function Git:floatterm_run(args, jobspec, enter_insertmode)
      if enter_insertmode == nil then enter_insertmode = true end

      local bufnr
      do
        bufnr = api.nvim_create_buf(false, true)
        prefer.bo(bufnr, "bufhidden", "wipe")
      end

      if enter_insertmode then
        api.nvim_create_autocmd("termopen", { buffer = bufnr, once = true, callback = startinsert })
        --i dont know why, but termopen will not be always triggered
        api.nvim_create_autocmd("termclose", { buffer = bufnr, once = true, callback = startinsert })
      end

      local winid
      do
        local height = vim.go.lines - 3 -- top border + bottom border + cmdline
        -- stylua: ignore
        winid = api.nvim_open_win(bufnr, true, {
          relative = "editor", style = "minimal", border = "single",
          width = vim.go.columns, height = height, row = 0, col = 0,
          title = string.format("git://%s", find_cmd_in_args(args) or "")
        })
        api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)
      end

      do
        table.insert(args, 1, "git")
        if jobspec.env == nil then jobspec.env = {} end
        for k, v in pairs(mandatory_envs) do
          if jobspec.env[k] == nil then jobspec.env[k] = v end
        end
        --jelly.debug("cmd='git %s' cwd=%s env='%s'", table.concat(args, " "), self.root, vim.inspect(jobspec.env))
        vim.fn.termopen(args, { cwd = self.root, env = jobspec.env, on_exit = jobspec.on_exit })
      end
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
