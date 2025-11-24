local ropes = require("string.buffer")

local augroups = require("infra.augroups")
local bufrename = require("infra.bufrename")
local ctx = require("infra.ctx")
local dictlib = require("infra.dictlib")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local feedkeys = require("infra.feedkeys")
local jelly = require("infra.jellyfish")("digits.Git")
local mi = require("infra.mi")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")
local strlib = require("infra.strlib")
local subprocess = require("infra.subprocess")

---@class digits.Git
---@field root string
local Git = {}
Git.__index = Git

---@class digits.GitTermSpec
---@field insert?     boolean @nil=true, enter the insert/terminal mode
---@field auto_close? boolean @nil=true, only when exit code is 0
---@field cbreak?     boolean @nil=false, the cbreak mode
---@field open_win?   fun(bufnr: integer): integer  @which returns the opened winid

---@class digits.GitJobSpec
---@field on_exit? fun(job: integer, exit_code: integer, event: 'exit')
---@field env? {[string]: string}
---@field configs? {[string]: string} @eg. {['color.ui'] = 'never'}

---@class digits.GitJobSpecResolved
---@field on_exit? fun(job: integer, exit_code: integer, event: 'exit')
---@field env {[string]: string}

---used for uv.spawn who expects env be string[]
---@class digits.GitSpawnSpec
---@field on_exit? fun(job: integer, exit_code: integer, event: 'exit')
---@field env string[]

local resolve_jobspec
do
  local mandatory_envs = {
    --avoid localization
    LC_ALL = "C",
    LANG = "C",
  }

  local rope = ropes.new()

  ---@param jobspec? digits.GitJobSpec
  ---@param default_gitcfg? {[string]: string}
  ---@return digits.GitJobSpecResolved
  function resolve_jobspec(jobspec, default_gitcfg)
    if jobspec == nil then jobspec = {} end

    local gitcfg
    do
      local kv = {}
      if default_gitcfg then dictlib.merge(kv, default_gitcfg) end
      if jobspec.configs then dictlib.merge(kv, jobspec.configs) end

      for k, v in pairs(kv) do
        assert(not strlib.contains(k, "'") and not strlib.contains(v, "'"))
        rope:putf(" '%s=%s'", k, v)
      end

      gitcfg = rope:skip(#" "):get()
    end

    local env
    do
      local kv = {}
      if jobspec.env ~= nil then dictlib.merge(kv, jobspec.env) end
      dictlib.merge(kv, mandatory_envs)

      assert(kv.GIT_CONFIG_PARAMETERS == nil, "GIT_CONFIG_PARAMETER env conficts with jobspec.configs")
      kv.GIT_CONFIG_PARAMETERS = gitcfg

      env = kv
    end

    return { env = env, on_exit = jobspec.on_exit }
  end
end

do
  ---@param jobspec? digits.GitJobSpec
  ---@param default_gitcfg? {[string]: string}
  ---@return digits.GitSpawnSpec
  local function resolve_spawnspec(jobspec, default_gitcfg)
    local resolved = resolve_jobspec(jobspec, default_gitcfg)

    local env = {}
    for k, v in pairs(resolved.env) do
      table.insert(env, string.format("%s=%s", k, v))
    end

    return { env = env, on_exit = resolved.on_exit }
  end

  ---@param capture_stdout false|'raw'|'lines'
  ---@param root string
  ---@param args string[]
  ---@param spawnspec digits.GitSpawnSpec
  ---@return infra.subprocess.CompletedProc
  local function main(capture_stdout, root, args, spawnspec)
    local cp = subprocess.run("git", { args = args, cwd = root, env = spawnspec.env, on_exit = spawnspec.on_exit }, capture_stdout)
    if cp.exit_code ~= 0 then return jelly.fatal("ProcRunError", "cmd='%s'; exit_code=%d", args, cp.exit_code) end
    return cp
  end

  ---@param args string[]
  ---@param jobspec? digits.GitJobSpec
  function Git:execute(args, jobspec) main(false, self.root, args, resolve_spawnspec(jobspec)) end

  ---@param args string[]
  ---@param jobspec? digits.GitJobSpec
  ---@return fun(): string?
  function Git:run(args, jobspec)
    local cp = main("lines", self.root, args, resolve_spawnspec(jobspec, { ["color.ui"] = "never" }))

    return cp.stdout
  end
end

do
  local function startinsert() ex("startinsert") end

  local resolve_termspec
  do
    local default = { insert = true, auto_close = true }
    ---@param user_specified? table
    ---@return digits.GitTermSpec
    function resolve_termspec(user_specified)
      if user_specified == nil then return default end
      return dictlib.merged(default, user_specified)
    end
  end

  ---as default it shows output of the given cmd in a fullscreen window
  ---@param args string[]
  ---@param jobspec? digits.GitJobSpec
  ---@param termspec? digits.GitTermSpec
  function Git:floatterm(args, jobspec, termspec)
    ---@diagnostic disable-next-line: cast-local-type
    jobspec = resolve_jobspec(jobspec, { ["color.ui"] = "always" })
    termspec = resolve_termspec(termspec)

    local bufnr = Ephemeral()
    local bufname = string.format("git://%s/%d", self:find_subcmd_in_args(args), bufnr)

    local aug = augroups.BufAugroup(bufnr, "gitcmd", true)

    if termspec.insert then
      aug:once("TermOpen", { callback = startinsert })
      --i dont know why, but termopen will not be always triggered
      aug:once("TermClose", { callback = startinsert })
    end

    if termspec.auto_close then
      aug:once("TermClose", {
        nested = true,
        callback = function()
          if vim.v.event.status ~= 0 then return end
          if termspec.insert then mi.stopinsert() end
          ni.win_close(0, false)
        end,
      })
    end

    local winid
    if termspec.open_win then
      winid = termspec.open_win(bufnr)
    else
      winid = rifts.open.fullscreen(bufnr, true, { relative = "editor" }, { laststatus3 = true })
    end
    prefer.wo(winid, "list", false)

    do
      table.insert(args, 1, "git")
      ctx.win(winid, function() --ensure doing to the right window
        mi.become_term(args, { cwd = self.root, env = jobspec.env, on_exit = jobspec.on_exit })
      end)
    end

    --since termopen will change the buffer name
    bufrename(bufnr, bufname)

    if termspec.cbreak then
      aug:repeats("InsertCharPre", {
        callback = function()
          local char = vim.v.char
          --dont repeat this callback itself
          if char == "\r" then return end
          vim.v.char = char .. "\r"
        end,
      })
    end
  end
end

---@param path string
---@return boolean
function Git:is_tracked(path)
  assert(path ~= nil and path ~= "")
  local cp = subprocess.run("git", { args = { "ls-files", "--error-unmatch", "--", path }, cwd = self.root })
  return cp.exit_code == 0
end

---for `--no-pager status`, `status`
---@param args string[]
---@return string
function Git:find_subcmd_in_args(args)
  assert(args[1] ~= "git")
  for _, a in ipairs(args) do
    if not strlib.startswith(a, "-") then return a end
  end
  error("unreachable")
end

---@return string? remote
---@return string? branch
function Git:resolve_upstream()
  local curbr = assert(self:run({ "branch", "--show-current" })())
  local output = self:run({ "config", "--get-regexp", string.format([[branch\.%s\.(remote|merge)]], curbr) })

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

---@param root string
---@return digits.Git
return function(root) return setmetatable({ root = root }, Git) end
