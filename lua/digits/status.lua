--terms
--* status 3-length '{ss}{us} '
--  * ss: staged status
--  * us: unstaged status
--  * enum: '?AMDR '

local dictlib = require("infra.dictlib")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fn = require("infra.fn")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("digits.status", "debug")
local bufmap = require("infra.keymap.buffer")
local popupgeo = require("infra.popupgeo")
local prefer = require("infra.prefer")

local commit = require("digits.commit")
local facts = require("digits.facts")
local tui = require("tui")

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
  ---@class digits.status.RHS
  ---@field private git digits.Git
  ---@field private bufnr integer
  local Prototype = {}

  Prototype.__index = Prototype

  function Prototype:reload()
    local lines
    do
      local stdout = self.git:run({ "status", "--porcelain=v1", "--ignore-submodules=all" })
      --todo: sort entries based on ss and us for better
      lines = fn.tolist(stdout)
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
  ---@return string?,string?,string?,string? @stage_status, unstage_status, path, renamed_path
  function Prototype:parse_current_entry(winid)
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

  function Prototype:stage()
    local winid = api.nvim_get_current_win()
    local ss, us, path, renamed_path = self:parse_current_entry(winid)
    if not (ss and us) then return end
    if not contracts.is_stagable(ss, us) then return jelly.debug("not a stagable status; '%s%s'", ss, us) end
    if ss ~= "R" then
      self.git:silent_run({ "add", path })
    else
      self.git:silent_run({ "add", assert(renamed_path) })
    end
    self:reload()
  end

  do
    function Prototype:unstage()
      local winid = api.nvim_get_current_win()
      local ss, us, path, renamed_path = self:parse_current_entry(winid)
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
      local ss, us, path, renamed_path = self:parse_current_entry(winid)
      if not (ss and us) then return end
      if not contracts.is_unstagable(ss, us) then return jelly.debug("not an unstagable status; '%s%s'", ss, us) end
      if ss ~= "R" then
        self.git:floatterm({ "reset", "--patch", "--", path }, nil, true)
      else
        self.git:floatterm({ "reset", "--patch", "--", assert(renamed_path) }, nil, true)
      end
    end

    function Prototype:interactive_unstage_all() self.git:floatterm({ "reset", "--patch" }, {}, true) end
  end

  function Prototype:interactive_stage()
    local winid = api.nvim_get_current_win()
    local ss, us, path, renamed_path = self:parse_current_entry(winid)
    if not contracts.is_interactive_stagable(ss, us) then return jelly.debug("not a interactive-stagable status; '%s%s'", ss, us) end
    if ss ~= "R" then
      self.git:floatterm({ "add", "--patch", path })
    else
      self.git:floatterm({ "add", "--patch", assert(renamed_path) })
    end
  end

  function Prototype:interactive_stage_all() self.git:floatterm({ "add", "--patch", "." }) end

  function Prototype:restore()
    local winid = api.nvim_get_current_win()
    local ss, us, path = self:parse_current_entry(winid)
    if ss == nil then return end
    if ss == "?" and us == "?" then return jelly.debug("not a tracked file") end
    if ss == "A" then return jelly.debug("not a tracked file") end
    if ss ~= " " then return jelly.info("unstage the file first") end

    tui.confirm({ prompt = "gitrest://confirm" }, function(confirmed)
      if not confirmed then return end
      self.git:silent_run({ "restore", "--source=HEAD", "--", path })
    end)
  end

  ---@param edit_cmd string @modifiers are not supported, eg. `leftabove split`
  function Prototype:edit(edit_cmd)
    local winid = api.nvim_get_current_win()

    local target
    do
      local ss, us, path, renamed_path = self:parse_current_entry(winid)
      if ss == nil then return end
      if ss == "D" or us == "D" then return jelly.debug("file was deleted already") end
      target = ss == "R" and renamed_path or path
    end

    api.nvim_win_close(winid, false)
    ex(edit_cmd, target)
  end

  ---@param git digits.Git
  ---@param bufnr integer
  ---@return digits.status.RHS
  function RHS(git, bufnr) return setmetatable({ git = git, bufnr = bufnr }, Prototype) end
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
      -- stylua: ignore
      bm.n("w", function() commit.tab(git) end)
      bm.n("x", function() rhs:restore() end)
      bm.n("d", function() rhs:interactive_unstage() end)
      bm.n("D", function() rhs:interactive_unstage_all() end)
    end
    do
      bm.n("i", function() rhs:edit("edit") end)
      bm.n("o", function() rhs:edit("split") end)
      bm.n("v", function() rhs:edit("split") end)
      bm.n("t", function() rhs:edit("tabedit") end)
    end
    --intended to have no auto-close on winleave
    --intended to have no reloading on winenter
  end

  local winid
  do
    local winopts = dictlib.merged({ relative = "editor", border = "single" }, popupgeo.editor(0.6, 0.8, "mid", "mid", 1))
    winid = api.nvim_open_win(bufnr, true, winopts)
    api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)
  end

  --reload
  api.nvim_create_autocmd("winenter", {
    callback = function()
      if not api.nvim_win_is_valid(winid) then return true end -- unregister this autocmd
      do -- necessary checks for https://github.com/neovim/neovim/issues/24843
        if api.nvim_get_current_win() ~= winid then return end
        if api.nvim_win_get_buf(winid) ~= bufnr then return end
      end
      rhs:reload()
    end,
  })

  rhs:reload()
end
