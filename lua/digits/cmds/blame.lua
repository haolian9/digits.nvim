local M = {}

local ropes = require("string.buffer")

local augroups = require("infra.augroups")
local bufpath = require("infra.bufpath")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("digits.cmds.blame", "info")
local bufmap = require("infra.keymap.buffer")
local mi = require("infra.mi")
local ni = require("infra.ni")
local rifts = require("infra.rifts")
local wincursor = require("infra.wincursor")

local create_git = require("digits.create_git")
local sting = require("sting")

local parse_blame
do
  local rope = ropes.new()

  ---@param line string
  ---@return string @obj
  ---@return string @author
  ---@return string @date 'yyyy-mm-dd'
  ---@return integer @row , 1-based
  function parse_blame(line)
    --samples:
    --* ^d545cdb (haoliang 2018-06-21 1)
    --* 7d03e957 (haoliang 2021-07-01 2) foo bar
    --* 0a39d4af (haoliang          2023-07-28 155)     foo bar
    --* 00000000 (Not Committed Yet 2023-08-15 149)       foo bar

    ---i personally prefer this verbose way over one single string.match(pattern)
    rope:set(line)
    local function pos_pre(substr) return assert(string.find(rope:tostring(), substr, 1, true)) - #substr end

    local obj = rope:get(pos_pre(" "))
    rope:skip(#" ")

    rope:skip(#"(")
    local in_brace = rope:get(pos_pre(")"))
    rope:skip(#")")

    local author, date, row = string.match(in_brace, "^(.+) +(%d%d%d%d%-%d%d%-%d%d) +(%d+)")

    rope:reset()

    if not (obj and author and date and row) then return jelly.fatal("ParseError", "unable to parse blame line: '%s'", line) end

    row = assert(tonumber(row))

    return obj, author, date, row
  end
end

---@param git digits.Git
---@param bufnr integer
---@return string?
local function resolve_path(git, bufnr)
  local abs = bufpath.file(bufnr)
  if abs == nil then return jelly.warn("no file associated to buf#%d", bufnr) end
  local path = fs.relative_path(git.root, abs)
  if path == nil then return jelly.warn("%s is outside of git repo", abs) end
  if not git:is_tracked(path) then return jelly.warn("untracked file cant be blamed on: %s", path) end
  return path
end

do
  local Blame
  do
    ---@class digits.Blame
    ---@field obj string @short hash
    ---@field author string
    ---@field date string @yyyy-mm-dd
    ---@field lnum integer @0-based
    ---@field path string

    ---@return digits.Blame
    function Blame(path, lnum, obj, author, date) return { path = path, lnum = lnum, obj = obj, author = author, date = date } end
  end

  ---@param git digits.Git
  ---@param bufnr integer
  ---@param lnum integer @0-based
  ---@return digits.Blame?
  local function seize_blame(git, bufnr, lnum)
    local path = resolve_path(git, bufnr)
    if path == nil then return end

    local line
    do
      local output = git:run({ "--no-pager", "blame", "--date=short", "--abbrev=8", "-L", string.format("%d,%d", lnum + 1, lnum + 1), "--", path })
      line = output()
      assert(line ~= nil and line ~= "")
    end

    local obj, author, date = parse_blame(line)
    return Blame(path, lnum, obj, author, date)
  end

  ---@param winid? integer
  ---@param git? digits.Git
  function M.line(winid, git)
    winid = mi.resolve_winid_param(winid)
    git = git or create_git()

    local bufnr = ni.win_get_buf(winid)

    local blame = seize_blame(git, bufnr, wincursor.lnum(winid))
    if blame == nil then return end

    local blame_bufnr, blame_len
    do
      local line = string.format("%s %s %s", blame.obj, blame.author, blame.date)
      blame_len = #line
      blame_bufnr = Ephemeral({ namepat = "git://blame/{bufnr}", handyclose = true }, { line })

      bufmap(blame_bufnr, "n", "gf", function() require("digits.cmds.show").open("float", string.format("%s:%s", blame.obj, blame.path), git) end)
    end

    local blame_winid
    do
      local winopts = { relative = "cursor", row = -1, col = 0, width = blame_len + 2, height = 1 }
      blame_winid = rifts.open.win(blame_bufnr, false, winopts)
    end

    local aug = augroups.BufAugroup(bufnr, "gitblame", true)
    aug:once("CursorMoved", {
      callback = function()
        if not ni.win_is_valid(blame_winid) then return end
        ni.win_close(blame_winid, false)
      end,
    })
  end
end

do
  ---@param bufnr integer
  ---@param line string
  ---@return sting.Pickle
  local function blame_to_pickle(bufnr, line)
    local blame = { parse_blame(line) }
    --NB: pickle.lnum is actually row
    return { bufnr = bufnr, lnum = blame[4], blame = blame }
  end

  local function pickle_flavor(pickle)
    local obj, author, date, lnum, line = unpack(pickle.blame)
    return string.format("%s %s %s|%d|%s", author, date, obj, lnum, line)
  end

  ---@param winid? integer
  ---@param git? digits.Git
  function M.file(winid, git)
    winid = mi.resolve_winid_param(winid)
    git = git or create_git()

    local bufnr = ni.win_get_buf(winid)

    local path = resolve_path(git, bufnr)
    if path == nil then return end

    do
      local loclist = sting.location.shelf(winid, string.format("git://blame#%s", path))
      ---@diagnostic disable-next-line: invisible
      loclist.flavor = pickle_flavor
      loclist:reset()
      local output = git:run({ "--no-pager", "blame", "--date=short", "--abbrev=8", "--", path })
      for line in output do
        loclist:append(blame_to_pickle(bufnr, line))
      end
      loclist:feed_vim(true, false)

      ex.eval("ll %d", wincursor.row(winid))
    end

    --it's really hard to maintain a usable side-by-side aligned via scrollbind'ed of locwin&blamed-buffer
  end
end

return M
