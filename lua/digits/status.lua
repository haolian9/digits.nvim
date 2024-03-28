--terms
--* status 3-length '{ss}{us} '
--  * ss: staged status
--  * us: unstaged status
--  * enum: '?AMDRU '
--    * UU: unstaged && unmerged, when rebase

local M = {}

local Augroup = require("infra.Augroup")
local ctx = require("infra.ctx")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fn = require("infra.fn")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("digits.status", "info")
local bufmap = require("infra.keymap.buffer")
local rifts = require("infra.rifts")
local winsplit = require("infra.winsplit")

local commit = require("digits.commit")
local create_git = require("digits.create_git")
local push = require("digits.push")
local puff = require("puff")

local api = vim.api

local contracts = {}
do
  do
    local truth = {
      ["??"] = true,
      ["A "] = false,
      ["AM"] = true,
      ["AD"] = true,
      ["D "] = false,
      ["R "] = false,
      ["RM"] = true,
      ["RD"] = true,
      ["M "] = false,
      ["MM"] = true,
      ["MD"] = true,
      [" M"] = true,
      [" D"] = true,
      ["UU"] = true,
    }
    ---@param ss string @stage status
    ---@param us string @unstage status
    function contracts.is_stagable(ss, us)
      local bool = truth[ss .. us]
      if bool ~= nil then return bool end
      error(string.format("unexpected status; ss='%s', us='%s'", ss, us))
    end
  end

  do
    local truth = {
      ["??"] = false,
      ["A "] = false,
      ["AM"] = true,
      ["D "] = false,
      ["R "] = false,
      ["RM"] = true,
      ["RD"] = false,
      ["M "] = false,
      ["MM"] = true,
      ["MD"] = false,
      [" M"] = true,
      [" D"] = false,
      ["UU"] = false, --error: needs merge
    }

    function contracts.is_interactive_stagable(ss, us)
      local bool = truth[ss .. us]
      if bool ~= nil then return bool end
      error(string.format("unexpected status; ss='%s', us='%s'", ss, us))
    end
  end

  do
    local truth = {
      ["??"] = false,
      ["A "] = true,
      ["AM"] = true,
      ["AD"] = true,
      ["D "] = true,
      ["M "] = true,
      ["MM"] = true,
      ["MD"] = true,
      ["R "] = true,
      ["RM"] = true,
      ["RD"] = true,
      [" M"] = false,
      [" D"] = false,
      ["UU"] = false,
    }
    ---@param ss string @stage status
    ---@param us string @unstage status
    function contracts.is_unstagable(ss, us)
      local bool = truth[ss .. us]
      if bool ~= nil then return bool end
      error(string.format("unexpected status; ss='%s', us='%s'", ss, us))
    end
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
  ---@field private no_reload boolean @some operations may take time, which will not be ready on winenter
  local Prototype = {}

  Prototype.__index = Prototype

  ---@private
  function Prototype:_reload()
    local lines
    do
      local stdout = self.git:run({ "status", "--porcelain=v1", "--ignore-submodules=all" })
      --todo: sort entries based on ss and us for better
      lines = fn.tolist(stdout)
    end

    ctx.modifiable(self.bufnr, function() api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines) end)
  end

  function Prototype:reload()
    if self.no_reload then return end
    self:_reload()
  end

  function Prototype:stage()
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
      self:reload()
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
    function Prototype:unstage()
      local winid = api.nvim_get_current_win()
      local ss, us, path, renamed_path = parse_current_entry(winid)
      if not (ss and us) then return end
      if not contracts.is_unstagable(ss, us) then return jelly.debug("not an unstagable status; '%s%s'", ss, us) end
      if ss ~= "R" then
        self.git:silent_run({ "reset", "--", path })
      else
        self.git:silent_run({ "reset", "--", path, assert(renamed_path) })
      end
      self:reload()
    end

    function Prototype:interactive_unstage()
      local winid = api.nvim_get_current_win()
      local ss, us, path, renamed_path = parse_current_entry(winid)
      if not (ss and us) then return end
      if not contracts.is_unstagable(ss, us) then return jelly.debug("not an unstagable status; '%s%s'", ss, us) end
      if ss ~= "R" then
        self.git:floatterm({ "reset", "--patch", "--", path }, nil, { cbreak = true })
      else
        self.git:floatterm({ "reset", "--patch", "--", assert(renamed_path) }, nil, { cbreak = true })
      end
    end

    function Prototype:interactive_unstage_all() self.git:floatterm({ "reset", "--patch" }, nil, { cbreak = true }) end
  end

  function Prototype:interactive_stage()
    local winid = api.nvim_get_current_win()
    local ss, us, path, renamed_path = parse_current_entry(winid)
    if not contracts.is_interactive_stagable(ss, us) then return jelly.debug("not a interactive-stagable status; '%s%s'", ss, us) end
    if ss ~= "R" then
      self.git:floatterm({ "add", "--patch", path }, nil, { cbreak = true })
    else
      self.git:floatterm({ "add", "--patch", assert(renamed_path) }, nil, { cbreak = true })
    end
  end

  function Prototype:interactive_stage_all() self.git:floatterm({ "add", "--patch", "." }, nil, { cbreak = true }) end

  function Prototype:restore()
    local winid = api.nvim_get_current_win()
    local ss, us, path = parse_current_entry(winid)
    if ss == nil then return end
    if ss == "?" and us == "?" then return jelly.debug("not a tracked file") end
    if ss == "A" then return jelly.debug("not a tracked file") end
    if ss ~= " " then return jelly.info("unstage the file first") end

    self.no_reload = true
    puff.confirm({ prompt = "git.restore" }, function(confirmed)
      if confirmed then
        self.git:silent_run({ "restore", "--source=HEAD", "--", path })
        self:_reload()
      end
      self.no_reload = false
    end)
  end

  function Prototype:clean()
    local winid = api.nvim_get_current_win()
    local ss, us, path = parse_current_entry(winid)
    if ss == nil then return end
    if not (ss == "?" and us == "?") then return jelly.debug("not a untracked file") end

    self.no_reload = true
    puff.confirm({ prompt = "git.clean" }, function(confirmed)
      if confirmed then
        self.git:silent_run({ "clean", "--force", "--", path })
        self:_reload()
      end
      self.no_reload = false
    end)
  end

  function Prototype:interactive_clean_all() self.git:floatterm({ "clean", "--interactive", "-d" }, nil, { cbreak = true }) end

  do
    local function is_landed_win(winid) return api.nvim_win_get_config(winid).relative == "" end

    ---@param edit_cmd string @'left'|'right'|'above'|'below'|'edit'|'tabedit'
    function Prototype:edit(edit_cmd)
      local winid = api.nvim_get_current_win()

      local target
      do
        local ss, us, path, renamed_path = parse_current_entry(winid)
        if ss == nil then return end
        if ss == "D" or us == "D" then return jelly.debug("file was deleted already") end
        target = ss == "R" and renamed_path or path
        assert(target)
      end

      --no closing landed window, eg. M.win1000
      if not is_landed_win(winid) then api.nvim_win_close(winid, false) end

      if edit_cmd == "edit" or edit_cmd == "tabedit" then
        ex(edit_cmd, target)
      else
        winsplit(edit_cmd, target)
      end
    end
  end

  ---@param git digits.Git
  ---@param bufnr integer
  ---@return digits.status.RHS
  function RHS(git, bufnr) return setmetatable({ git = git, bufnr = bufnr }, Prototype) end
end

---@param git digits.Git
---@param create_win fun(bufnr: integer): integer
local function main(git, create_win)
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
      bm.n("w", function() commit.tab(git) end)
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

  local winid = create_win(bufnr)

  --reload
  local aug = Augroup.win(winid, true)
  aug:repeats("WinEnter", {
    callback = function()
      do -- necessary checks for https://github.com/neovim/neovim/issues/24843
        if api.nvim_get_current_win() ~= winid then return end
        if api.nvim_win_get_buf(winid) ~= bufnr then return end
      end
      rhs:reload()
    end,
  })

  rhs:reload()
end

---@param git? digits.Git
function M.floatwin(git)
  git = git or create_git()

  main(git, function(bufnr) return rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 }) end)
end

---@param git? digits.Git
---@param side infra.winsplit.Side
function M.split(git, side)
  git = git or create_git()

  main(git, function(bufnr)
    winsplit(side, api.nvim_buf_get_name(bufnr))
    local winid = api.nvim_get_current_win()
    api.nvim_win_set_buf(winid, bufnr)
    return winid
  end)
end

---@param git? digits.Git
function M.win1000(git)
  git = git or create_git()

  main(git, function(bufnr)
    local winid = api.nvim_get_current_win()
    api.nvim_win_set_buf(winid, bufnr)
    return winid
  end)
end

---@param git? digits.Git
function M.tab(git)
  git = git or create_git()

  main(git, function(bufnr)
    ex("tabedit", string.format("sbuffer %d", bufnr))
    return api.nvim_get_current_win()
  end)
end

return M
