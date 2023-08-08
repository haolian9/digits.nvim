local M = {}

local bufpath = require("infra.bufpath")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fs = require("infra.fs")
local handyclosekeys = require("infra.handyclosekeys")
local jelly = require("infra.jellyfish")("digits.blame", "debug")
local bufmap = require("infra.keymap.buffer")
local prefer = require("infra.prefer")

local qltoggle = require("qltoggle")
local sting = require("sting")

local api = vim.api

---@param line string
---@return string,string,string,integer
local function parse_blame(line)
  --samples:
  --* ^d545cdb (haoliang 2018-06-21 1)
  --* 7d03e957 (haoliang 2021-07-01 2) setup checklist
  --* 0a39d4af (haoliang 2023-07-28 155)     blame_winid = api.nvim_open_win(blame_bufnr, false, { relative = "cursor", row = -1, col = 0, width = blame_len + 2, height = 1 })
  local obj, author, date, lnum
  if string.sub(line, 10, 10) == "(" then
    obj, author, date, lnum = string.match(line, "%^?(%x+) %((.+) +(%d%d%d%d%-%d%d%-%d%d) +(%d+)%)")
  else
    obj, author, date, lnum = string.match(line, "%^?(%x+) .+ %((.+) +(%d%d%d%d%-%d%d%-%d%d) +(%d+)%)")
  end
  if not (obj and author and date and lnum) then
    jelly.err('unable to parse blame line: "%s"', line)
    error("unreachable")
  end
  lnum = assert(tonumber(lnum))
  return obj, author, date, lnum
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
      local output = git:run({ "--no-pager", "blame", "--date=short", "--abbrev=7", "-L", string.format("%d,%d", lnum + 1, lnum + 1), "--", path })
      line = output()
      assert(line ~= nil and line ~= "")
    end

    local obj, author, date = parse_blame(line)
    return Blame(path, lnum, obj, author, date)
  end

  ---@param git digits.Git
  function M.line(git, winid)
    local bufnr = api.nvim_win_get_buf(winid)

    local blame
    do
      local lnum = api.nvim_win_get_cursor(winid)[1] - 1
      blame = seize_blame(git, bufnr, lnum)
      if blame == nil then return end
    end

    local blame_bufnr, blame_len
    do
      local line = string.format("%s %s %s", blame.obj, blame.author, blame.date)
      blame_len = #line
      blame_bufnr = Ephemeral(nil, { line })

      handyclosekeys(blame_bufnr)
      bufmap(blame_bufnr, "n", "gf", function() require("digits.show")(git, blame.obj, blame.path) end)
    end

    do
      local blame_winid = api.nvim_open_win(blame_bufnr, false, { relative = "cursor", row = -1, col = 0, width = blame_len + 2, height = 1 })
      api.nvim_create_autocmd("cursormoved", {
        buffer = bufnr,
        once = true,
        callback = function()
          if api.nvim_win_is_valid(blame_winid) then api.nvim_win_close(blame_winid, false) end
        end,
      })
    end
  end
end

do
  ---@param bufnr integer
  ---@param line string
  ---@return sting.Pickle
  local function blame_to_pickle(bufnr, line)
    local obj, author, date, lnum = parse_blame(line)
    return { bufnr = bufnr, lnum = lnum, text = string.format("%s %s %s", obj, date, author) }
  end
  function M.file(git, winid)
    local bufnr = api.nvim_win_get_buf(winid)

    local path = resolve_path(git, bufnr)
    if path == nil then return end

    do
      local loclist = sting.location.shelf(winid, string.format("git://blame#%s", path))
      loclist:reset()
      local output = git:run({ "--no-pager", "blame", "--date=short", "--abbrev=7", "--", path })
      for line in output do
        loclist:append(blame_to_pickle(bufnr, line))
      end
      loclist:feed_vim()
    end

    do
      qltoggle.open_loclist()
      local loc_winid = api.nvim_get_current_win()
      assert(loc_winid ~= winid)
      local lnum = api.nvim_win_get_cursor(winid)[1] - 1
      vim.fn.setloclist(winid, {}, "a", { idx = lnum })
      ex("wincmd", "H")
      api.nvim_win_set_width(loc_winid, 50)
      prefer.wo(loc_winid, "scrollbind", true)
      --todo: unset when?
      prefer.wo(winid, "scrollbind", true)
      --todo: close the loclist on bufwinleave
    end
  end
end

return M
