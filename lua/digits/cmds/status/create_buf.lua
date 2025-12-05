local buflines = require("infra.buflines")
local bufopen = require("infra.bufopen")
local ctx = require("infra.ctx")
local Ephemeral = require("infra.Ephemeral")
local fs = require("infra.fs")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("digits.cmds.status", "info")
local bufmap = require("infra.keymap.buffer")
local ni = require("infra.ni")
local wincursor = require("infra.wincursor")

local amend = require("digits.cmds.amend")
local commit = require("digits.cmds.commit")
local fixup = require("digits.cmds.fixup")
local push = require("digits.cmds.push")
local contracts = require("digits.cmds.status.contracts")
local signals = require("digits.cmds.status.signals")
local sync = require("digits.cmds.sync")
local puff = require("puff")

local RHS
do
  ---@private
  ---@param winid integer
  ---@return string?,string?,string?,string? @stage_status, unstage_status, path, renamed_path
  local function parse_current_entry(winid)
    local line
    do
      local lnum = wincursor.lnum(winid)
      local bufnr = ni.win_get_buf(winid)
      line = assert(buflines.line(bufnr, lnum))
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
      lines = itertools.tolist(stdout)
    end

    ctx.modifiable(self.bufnr, function() buflines.replaces_all(self.bufnr, lines) end)
  end

  function Impl:stage()
    local winid = ni.get_current_win()
    local ss, us, path, renamed_path = parse_current_entry(winid)
    if not (ss and us) then return end
    if not contracts.is_stagable(ss, us) then return jelly.debug("not a stagable status; '%s%s'", ss, us) end

    local function stage()
      if ss ~= "R" then
        self.git:execute({ "add", path })
      else
        self.git:execute({ "add", assert(renamed_path) })
      end
      signals.reload()
    end

    if ss == "U" and us == "U" then
      puff.confirm({ subject = "git.stage.UU", desc = { "Unstaged Unmerged" }, entries = { "处理过合并冲突了", "还没啊" } }, function(confirmed)
        if confirmed then stage() end
      end)
    else
      stage()
    end
  end

  do
    function Impl:unstage()
      local winid = ni.get_current_win()
      local ss, us, path, renamed_path = parse_current_entry(winid)
      if not (ss and us) then return end
      if not contracts.is_unstagable(ss, us) then return jelly.debug("not an unstagable status; '%s%s'", ss, us) end
      if ss ~= "R" then
        self.git:execute({ "reset", "--", path })
      else
        self.git:execute({ "reset", "--", path, assert(renamed_path) })
      end
      signals.reload()
    end

    function Impl:interactive_unstage()
      local winid = ni.get_current_win()
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
    local winid = ni.get_current_win()
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
    local winid = ni.get_current_win()
    local ss, us, path = parse_current_entry(winid)
    if ss == nil then return end
    if ss == "?" and us == "?" then return jelly.debug("not a tracked file") end
    if ss == "A" then return jelly.debug("not a tracked file") end
    if ss ~= " " then return jelly.info("unstage the file first") end

    puff.confirm({ subject = "git.restore", desc = { "any local changes will be discarded" } }, function(confirmed)
      if not confirmed then return end
      self.git:execute({ "restore", "--source=HEAD", "--", path })
      signals.reload()
    end)
  end

  function Impl:clean()
    local winid = ni.get_current_win()
    local ss, us, path = parse_current_entry(winid)
    if ss == nil then return end
    if not (ss == "?" and us == "?") then return jelly.info("not a untracked file") end

    puff.confirm({ subject = "git.clean" }, function(confirmed)
      if not confirmed then return end
      self.git:execute({ "clean", "--force", "--", path })
      signals.reload()
    end)
  end

  function Impl:interactive_clean_all() self.git:floatterm({ "clean", "--interactive", "-d" }, { on_exit = signals.reload }, { cbreak = true }) end

  do
    local function is_landed_win(winid) return ni.win_get_config(winid).relative == "" end

    ---@param open_mode infra.bufopen.Mode
    function Impl:edit(open_mode)
      local winid = ni.get_current_win()

      local target
      do
        local ss, us, path, renamed_path = parse_current_entry(winid)
        if ss == nil then return end
        if ss == "D" or us == "D" then return jelly.debug("file was deleted already") end
        target = ss == "R" and renamed_path or path
        assert(target)
      end

      --no closing landed window, eg. .win1000()
      if not is_landed_win(winid) then ni.win_close(winid, false) end

      bufopen(open_mode, target)
    end
  end

  function Impl:commit() commit.open("tab", signals.reload, self.git) end
  function Impl:fixup() fixup.open("tab", signals.reload, self.git) end
  function Impl:amend() amend.open("tab", signals.reload, self.git) end
  function Impl:push() push.open("tab", self.git) end
  function Impl:sync() sync.open("tab", signals.reload, self.git) end

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
    bufnr = Ephemeral({ namefn = namefn, handyclose = true, modifiable = false })
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
      bm.n("w", function() rhs:commit() end)
      bm.n("W", function() rhs:amend() end)
      bm.n("F", function() rhs:fixup() end)
      bm.n("c", function() rhs:restore() end)
      bm.n("d", function() rhs:interactive_unstage() end)
      bm.n("D", function() rhs:interactive_unstage_all() end)
      bm.n("x", function() rhs:clean() end)
      bm.n("X", function() rhs:interactive_clean_all() end)
      bm.n("Y", function() rhs:push() end)
      bm.n("S", function() rhs:sync() end)
    end
    do
      bm.n("i", function() rhs:edit("inplace") end)
      bm.n("o", function() rhs:edit("below") end)
      bm.n("v", function() rhs:edit("right") end)
      bm.n("t", function() rhs:edit("tab") end)
    end
  end

  signals.on_reload(function()
    if not ni.buf_is_valid(bufnr) then return true end
    rhs:reload()
  end)
  signals.reload()

  return bufnr
end
