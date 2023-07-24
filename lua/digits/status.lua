--{staged,unstaged} statuses: 3-length
--* ? '? {path}'
--* A 'A {path}'
--* M 'M {path}'
--* D 'D {path}'
--* R 'R {path} -> {path}'
--
--operations on each entry
--* add -p {path}
--* reset -- {path}
--* restore from HEAD
--
--fluent ux
--* prefer floatwin over tab/window
--  * proper position: editor or cursor or window
--  * size: decided by content
--* interactive terminal
--* lock shadowed window

local ex = require("infra.ex")
local fn = require("infra.fn")
local highlighter = require("infra.highlighter")
local jelly = require("infra.jellyfish")("digits.status", "debug")
local bufmap = require("infra.keymap.buffer")
local popupgeo = require("infra.popupgeo")
local prefer = require("infra.prefer")
local project = require("infra.project")
local strlib = require("infra.strlib")
local subprocess = require("infra.subprocess")

local api = vim.api

local facts = {}
do
  do
    local hl_ns = api.nvim_create_namespace("digits.status")
    local hi = highlighter(hl_ns)
    if vim.go.background == "light" then
      hi("NormalFloat", { fg = 8 })
      hi("WinSeparator", { fg = 243 })
      hi("FloatTitle", { fg = 8 })
    else
      hi("NormalFloat", { fg = 7 })
      hi("FloatTitle", { fg = 7 })
      hi("WinSeparator", { fg = 243 })
    end
    facts.hl_ns = hl_ns
  end
end

local contracts = {}
do
  --todo: could be a truth table

  ---@param ss string @stage status
  ---@param us string @unstage status
  function contracts.is_stagable(ss, us)
    if ss == "?" then
      assert(us == "?", us)
      return true
    end
    if ss == "A" then
      if us == " " then return false end
      assert(us == "M" or us == "D", us)
      return true
    end
    if ss == "D" then
      assert(us == " ", us)
      return false
    end
    if ss == "R" then
      if us == " " then return false end
      assert(us == "D" or us == "M")
      return true
    end
    if ss == "M" then
      if us == " " then return false end
      assert(us == "M" or us == "D")
      return true
    end
    if ss == " " then
      assert(us == "M" or us == "D", us)
      return true
    end
    error(string.format("unexpected status; ss=%s, us=%s", ss, us))
  end

  function contracts.is_interactive_stagable(ss, us)
    if ss == "?" then
      assert(us == "?", us)
      return false
    end
    if ss == "A" then
      if us == " " then return false end
      assert(us == "M", us)
      return true
    end
    if ss == "D" then
      assert(us == " ", us)
      return false
    end
    if ss == "R" then
      if us == " " then return false end
      if us == "M" then return true end
      if us == "D" then return false end
    end
    if ss == "M" then
      if us == " " then return false end
      if us == "M" then return true end
      if us == "D" then return false end
    end
    if ss == " " then
      assert(us == "M" or us == "D", us)
      return true
    end
    error(string.format("unexpected status; ss=%s, us=%s", ss, us))
  end

  ---@param ss string @stage status
  ---@param us string @unstage status
  function contracts.is_unstagable(ss, us)
    if ss == "?" then
      assert(us == "?", us)
      return false
    end
    if ss == "A" then
      assert(us == " " or us == "M" or us == "D", us)
      return true
    end
    if ss == "D" then
      assert(us == " ", us)
      return true
    end
    if ss == "M" then
      assert(us == " " or us == "M" or us == "D", us)
      return true
    end
    if ss == "R" then
      assert(us == " " or us == "M" or us == "D")
      return true
    end

    if ss == " " then
      assert(us == "M" or us == "D", us)
      return false
    end
    error(string.format("unexpected status; ss=%s, us=%s", ss, us))
  end

  ---@param line string
  ---@return string,string,string,(string?) @stage_status, unstage_status, path, renamed_path
  function contracts.parse_status_line(line)
    local stage_status = string.sub(line, 1, 1)
    local unstage_status = string.sub(line, 2, 2)
    local path, renamed_path
    do
      if stage_status ~= "R" then
        path = string.sub(line, 4)
      else
        local splits = fn.split_iter(string.sub(line, 4), " -> ")
        path, renamed_path = splits(), splits()
        assert(path, path)
        assert(renamed_path, renamed_path)
      end
    end

    return stage_status, unstage_status, path, renamed_path
  end
end

local Git
do
  ---@class digits.status.Git
  ---@field private root string
  local Prototype = {}

  Prototype.__index = Prototype

  local mandatory_envs = {
    LC_ALL = "C", --avoid i18n
    GIT_CONFIG_PARAMETERS = "'color.ui=never'", --color=never
  }

  ---@param args string[]
  function Prototype:silent_run(args)
    local cp = subprocess.run("git", { args = args, cwd = self.root, env = mandatory_envs }, false)
    if cp.exit_code ~= 0 then
      jelly.err("cmd='%s'; exit code=%d", fn.join(args, " "), cp.exit_code)
      error("git cmd failed")
    end
  end

  ---@param args string[]
  ---@return fun(): string?
  function Prototype:run(args)
    local cp = subprocess.run("git", { args = args, cwd = self.root, env = mandatory_envs }, true)
    if cp.exit_code ~= 0 then
      jelly.err("cmd='%s'; exit code=%d", fn.join(args, " "), cp.exit_code)
      error("git cmd failed")
    end
    return cp.stdout
  end

  do
    ---@param args string[]
    ---@param jobspec {on_exit: fun(job: integer, exit_code: integer, event: 'exit'), env?: {[string]: string}}
    function Prototype:floatterm_run(args, jobspec)
      local bufnr
      do
        bufnr = api.nvim_create_buf(false, true)
        prefer.bo(bufnr, "bufhidden", "wipe")
        local function startinsert() ex("startinsert") end
        api.nvim_create_autocmd("termopen", { buffer = bufnr, once = true, callback = startinsert })
        --todo: i dont know why, but termopen will not be always triggered
        api.nvim_create_autocmd("termclose", { buffer = bufnr, once = true, callback = startinsert })
      end

      local winid
      do
        local height = vim.go.lines - 3 -- top border + bottom border + cmdline
        -- stylua: ignore
        winid = api.nvim_open_win(bufnr, true, {
          relative = "editor", style = "minimal", border = "single",
          width = vim.go.columns, height = height, row = 0, col = 0,
          title = string.format("gitterm://")
        })
        api.nvim_win_set_hl_ns(winid, facts.hl_ns)
      end

      do
        table.insert(args, 1, "git")
        if jobspec.env == nil then jobspec.env = {} end
        for k, v in pairs(mandatory_envs) do
          jobspec.env[k] = v
        end
        vim.fn.termopen(args, { cwd = self.root, env = jobspec.env, on_exit = jobspec.on_exit })
      end
    end
  end

  ---@param root string
  ---@return digits.status.Git
  function Git(root) return setmetatable({ root = root }, Prototype) end
end

local RHS
do
  ---@class digits.status.RHS
  ---@field private git digits.status.Git
  ---@field private bufnr integer
  local Prototype = {}

  Prototype.__index = Prototype

  ---@private
  function Prototype:reload_status_to_buf()
    local lines
    do
      local stdout = self.git:run({ "status", "--porcelain=v1", "--ignore-submodules=all" })
      lines = fn.concrete(stdout)
    end

    do --reload
      local bo = prefer.buf(self.bufnr)
      bo.modifiable = true
      api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
      bo.modifiable = false
    end
  end

  ---@private
  ---@param winid integer
  ---@return string,string,string,(string?) @stage_status, unstage_status, path, renamed_path
  function Prototype:parse_current_entry(winid)
    local line
    do
      local lnum = assert(api.nvim_win_get_cursor(winid))[1] - 1
      local bufnr = api.nvim_win_get_buf(winid)
      local lines = api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)
      assert(#lines == 1)
      line = lines[1]
      assert(#line >= 4)
    end

    return contracts.parse_status_line(line)
  end

  ---@param winid integer
  function Prototype:stage(winid)
    local ss, us, path, renamed_path = self:parse_current_entry(winid)
    if not contracts.is_stagable(ss, us) then return jelly.debug("not a stagable status; '%s%s'", ss, us) end
    if ss ~= "R" then
      self.git:silent_run({ "add", path })
    else
      self.git:silent_run({ "add", assert(renamed_path) })
    end
    self:reload_status_to_buf()
  end

  function Prototype:unstage(winid)
    local ss, us, path, renamed_path = self:parse_current_entry(winid)
    if not contracts.is_unstagable(ss, us) then return jelly.debug("not an unstagable status; '%s%s'", ss, us) end
    if ss ~= "R" then
      self.git:silent_run({ "reset", "--", path })
    else
      self.git:silent_run({ "reset", "--", path, assert(renamed_path) })
    end
    self:reload_status_to_buf()
  end

  Prototype.reload = Prototype.reload_status_to_buf

  ---@param winid integer
  function Prototype:interactive_stage(winid)
    local ss, us, path, renamed_path = self:parse_current_entry(winid)
    if not contracts.is_interactive_stagable(ss, us) then return jelly.debug("not a interactive-stagable status; '%s%s'", ss, us) end
    local function on_exit() self:reload_status_to_buf() end
    if ss ~= "R" then
      self.git:floatterm_run({ "add", "--patch", path }, { on_exit = on_exit })
    else
      self.git:floatterm_run({ "add", "--patch", assert(renamed_path) }, { on_exit = on_exit })
    end
  end

  do
    function Prototype:verbose_commit()
      local infos = {}
      do
        for line in self.git:run({ "status" }) do
          table.insert(infos, "# " .. line)
        end
        for line in self.git:run({ "--no-pager", "diff", "--cached" }) do
          table.insert(infos, line)
        end
      end

      local bufnr
      do
        bufnr = api.nvim_create_buf(false, true)
        prefer.bo(bufnr, "bufhidden", "wipe")
        api.nvim_buf_set_lines(bufnr, 0, 0, false, { "" })
        api.nvim_buf_set_lines(bufnr, 1, -1, false, infos)
      end

      local winid
      do
        local height = vim.go.lines - 3 -- top border + bottom border + cmdline
        -- stylua: ignore
        winid = api.nvim_open_win(bufnr, true, {
          relative = "editor", style = "minimal", border = "single",
          width = vim.go.columns, height = height, row = 0, col = 0,
          title = "gitcommit://"
        })
        api.nvim_win_set_hl_ns(winid, facts.hl_ns)
      end

      api.nvim_create_autocmd("winclosed", {
        buffer = bufnr,
        once = true,
        callback = function()
          local msgs = {}
          for i = 0, api.nvim_buf_line_count(bufnr) - 1 do
            local line = api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
            if strlib.startswith(line, "#") then break end
            table.insert(msgs, line)
          end
          if #msgs == 0 or msgs[1] == "" then return jelly.info("Aborting commit due to empty commit message.") end
          local msg = table.concat(msgs, "\n")
          self.git:floatterm_run({ "commit", "-m", msg }, { on_exit = function() self:reload_status_to_buf() end })
        end,
      })
    end
  end

  ---@param git digits.status.Git
  ---@param bufnr integer
  ---@return digits.status.RHS
  function RHS(git, bufnr) return setmetatable({ git = git, bufnr = bufnr }, Prototype) end
end

return function()
  local root = assert(project.git_root())
  local git = Git(root)

  local bufnr = api.nvim_create_buf(false, true)
  prefer.bo(bufnr, "bufhidden", "wipe")

  do --setup keymaps to the buffer
    local rhs = RHS(git, bufnr)
    rhs:reload()
    local bm = bufmap.wraps(bufnr)
    bm.n("a", function() rhs:stage(api.nvim_get_current_win()) end)
    bm.n("u", function() rhs:unstage(api.nvim_get_current_win()) end)
    bm.n("r", function() rhs:reload() end)
    bm.n("p", function() rhs:interactive_stage(api.nvim_get_current_win()) end)
    bm.n("w", function() rhs:verbose_commit() end)
  end

  local winid
  do
    local width, height, row, col = popupgeo.editor_central(0.6, 0.8)
    -- stylua: ignore
    winid = api.nvim_open_win(bufnr, true, {
      relative = "editor", style = "minimal", border = "single",
      width = width, height = height, row = row, col = col,
      title = string.format("gitstatus://%s", vim.fs.basename(root)),
    })
    api.nvim_win_set_hl_ns(winid, facts.hl_ns)

    local function close_win() api.nvim_win_close(winid, false) end
    --no auto-close on winleave
    bufmap(bufnr, "n", "q", close_win)
    bufmap(bufnr, "n", "<c-[>", close_win)
  end
end
