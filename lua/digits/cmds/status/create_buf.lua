local ctx = require("infra.ctx")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fn = require("infra.fn")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("digits.cmds.status", "info")
local bufmap = require("infra.keymap.buffer")
local winsplit = require("infra.winsplit")

local commit = require("digits.cmds.commit")
local push = require("digits.cmds.push")
local contracts = require("digits.cmds.status.contracts")
local signals = require("digits.cmds.status.signals")
local puff = require("puff")

local api = vim.api

local RHS
do
  ---@private
  ---@param winid integer
  ---@return string?,string?,string?,string? @stage_status, unstage_status, path, renamed_path
  local function parse_current_entry(winid)
    local line
    do
      local lnum = assert(api.nvim_win_get_cursor(winid))[1] - 1
      local bufnr = api.nvim_win_get_buf(winid)
      local lines = api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)
      assert(#lines == 1)
      line = lines[1]
      if #line < 1 then return jelly.debug("blank line lnum#%d", lnum) end
      assert(#line >= 4)
    end

    return contracts.parse_status_line(line)
  end

  ---@class digits.status.RHS
  ---@field private git digits.Git
  ---@field private bufnr integer
  local Impl = {}

  Impl.__index = Impl

  function Impl:reload()
    local lines
    do
      local stdout = self.git:run({ "status", "--porcelain=v1", "--ignore-submodules=all" })
      --todo: sort entries based on ss and us for better
      lines = fn.tolist(stdout)
    end

    ctx.modifiable(self.bufnr, function() api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines) end)
  end

  function Impl:stage()
    local winid = api.nvim_get_current_win()
    local ss, us, path, renamed_path = parse_current_entry(winid)
    if not (ss and us) then return end
    if not contracts.is_stagable(ss, us) then return jelly.debug("not a stagable status; '%s%s'", ss, us) end

    local function stage()
      if ss ~= "R" then
        self.git:silent_run({ "add", path })
      else
        self.git:silent_run({ "add", assert(renamed_path) })
      end
      signals.reload()
    end

    if ss == "U" and us == "U" then
      puff.confirm({ prompt = "git.stage.UU", ents = { "处理过合并冲突了", "还没啊" } }, function(confirmed)
        if confirmed then stage() end
      end)
    else
      stage()
    end
  end

  do
    function Impl:unstage()
      local winid = api.nvim_get_current_win()
      local ss, us, path, renamed_path = parse_current_entry(winid)
      if not (ss and us) then return end
      if not contracts.is_unstagable(ss, us) then return jelly.debug("not an unstagable status; '%s%s'", ss, us) end
      if ss ~= "R" then
        self.git:silent_run({ "reset", "--", path })
      else
        self.git:silent_run({ "reset", "--", path, assert(renamed_path) })
      end
      signals.reload()
    end

    function Impl:interactive_unstage()
      local winid = api.nvim_get_current_win()
      local ss, us, path, renamed_path = parse_current_entry(winid)
      if not (ss and us) then return end
      if not contracts.is_unstagable(ss, us) then return jelly.debug("not an unstagable status; '%s%s'", ss, us) end
      if ss ~= "R" then
        self.git:floatterm({ "reset", "--patch", "--", path }, { on_exit = signals.reload }, { cbreak = true })
      else
        self.git:floatterm({ "reset", "--patch", "--", assert(renamed_path) }, { on_exit = signals.reload }, { cbreak = true })
      end
    end

    function Impl:interactive_unstage_all() self.git:floatterm({ "reset", "--patch" }, { on_exit = signals.reload }, { cbreak = true }) end
  end

  function Impl:interactive_stage()
    local winid = api.nvim_get_current_win()
    local ss, us, path, renamed_path = parse_current_entry(winid)
    if not contracts.is_interactive_stagable(ss, us) then return jelly.debug("not a interactive-stagable status; '%s%s'", ss, us) end
    if ss ~= "R" then
      self.git:floatterm({ "add", "--patch", path }, { on_exit = signals.reload }, { cbreak = true })
    else
      self.git:floatterm({ "add", "--patch", assert(renamed_path) }, { on_exit = signals.on_reload }, { cbreak = true })
    end
  end

  function Impl:interactive_stage_all() self.git:floatterm({ "add", "--patch", "." }, { on_exit = signals.reload }, { cbreak = true }) end

  function Impl:restore()
    local winid = api.nvim_get_current_win()
    local ss, us, path = parse_current_entry(winid)
    if ss == nil then return end
    if ss == "?" and us == "?" then return jelly.debug("not a tracked file") end
    if ss == "A" then return jelly.debug("not a tracked file") end
    if ss ~= " " then return jelly.info("unstage the file first") end

    puff.confirm({ prompt = "git.restore" }, function(confirmed)
      if not confirmed then return end
      self.git:silent_run({ "restore", "--source=HEAD", "--", path })
      signals.reload()
    end)
  end

  function Impl:clean()
    local winid = api.nvim_get_current_win()
    local ss, us, path = parse_current_entry(winid)
    if ss == nil then return end
    if not (ss == "?" and us == "?") then return jelly.debug("not a untracked file") end

    puff.confirm({ prompt = "git.clean" }, function(confirmed)
      if not confirmed then return end
      self.git:silent_run({ "clean", "--force", "--", path })
      signals.reload()
    end)
  end

  function Impl:interactive_clean_all() self.git:floatterm({ "clean", "--interactive", "-d" }, { on_exit = signals.reload }, { cbreak = true }) end

  do
    local function is_landed_win(winid) return api.nvim_win_get_config(winid).relative == "" end

    ---@param edit_cmd 'edit'|'tabedit'|infra.winsplit.Side
    function Impl:edit(edit_cmd)
      local winid = api.nvim_get_current_win()

      local target
      do
        local ss, us, path, renamed_path = parse_current_entry(winid)
        if ss == nil then return end
        if ss == "D" or us == "D" then return jelly.debug("file was deleted already") end
        target = ss == "R" and renamed_path or path
        assert(target)
      end

      --no closing landed window, eg. .win1000()
      if not is_landed_win(winid) then api.nvim_win_close(winid, false) end

      if edit_cmd == "edit" or edit_cmd == "tabedit" then
        ex(edit_cmd, target)
      else
        winsplit(edit_cmd, target)
      end
    end
  end

  function Impl:commit() commit.tab(self.git, signals.reload) end

  ---@param git digits.Git
  ---@param bufnr integer
  ---@return digits.status.RHS
  function RHS(git, bufnr) return setmetatable({ git = git, bufnr = bufnr }, Impl) end
end

---@param git digits.Git
return function(git)
  local bufnr
  do
    local function namefn(nr) return string.format("git://status/%s/%d", fs.basename(git.root), nr) end
    bufnr = Ephemeral({ namefn = namefn, handyclose = true })
  end

  local rhs = RHS(git, bufnr)
  do --setup keymaps to the buffer
    local bm = bufmap.wraps(bufnr)
    do
      bm.n("a", function() rhs:stage() end)
      bm.n("u", function() rhs:unstage() end)
      bm.n("r", function() rhs:reload() end)
      bm.n("p", function() rhs:interactive_stage() end)
      bm.n("P", function() rhs:interactive_stage_all() end)
      bm.n("w", function() rhs.commit(git) end)
      bm.n("c", function() rhs:restore() end)
      bm.n("d", function() rhs:interactive_unstage() end)
      bm.n("D", function() rhs:interactive_unstage_all() end)
      bm.n("x", function() rhs:clean() end)
      bm.n("X", function() rhs:interactive_clean_all() end)
      bm.n("Y", function() push(git) end)
    end
    do
      bm.n("i", function() rhs:edit("edit") end)
      bm.n("o", function() rhs:edit("below") end)
      bm.n("O", function() rhs:edit("above") end)
      bm.n("v", function() rhs:edit("right") end)
      bm.n("V", function() rhs:edit("left") end)
      bm.n("t", function() rhs:edit("tabedit") end)
    end
  end

  signals.on_reload(function()
    if not api.nvim_buf_is_valid(bufnr) then return true end
    rhs:reload()
  end)
  signals.reload()

  return bufnr
end
