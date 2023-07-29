local M = {}

local bufpath = require("infra.bufpath")
local fn = require("infra.fn")
local fs = require("infra.fs")
local handyclosekeys = require("infra.handyclosekeys")
local jelly = require("infra.jellyfish")("digits.blame", "debug")
local bufmap = require("infra.keymap.buffer")
local prefer = require("infra.prefer")

local api = vim.api

local porcelain_parse
do
  local first10 = {
    --sample: 145b2df672c41669be78adc5ef6682bc8f91da5e 17 27 1
    function(line)
      local hash = string.match(line, "(%x+) (%d+) (%d+) (%d+)")
      return "hash", assert(hash, line)
    end,
    --sample: author haoliang
    function(line) return "author", assert(string.match(line, "author (.+)"), line) end,
    --sample: author-mail <haoliang0.1.2@gmail.com>
    function(line) return "author-mail", assert(string.match(line, "author%-mail <(.+)>"), line) end,
    --sample: author-time 1690265331
    function(line) return "author-time", assert(string.match(line, "author%-time (%d+)"), line) end,
    --sample: author-tz +0800
    function(line) return "author-tz", assert(string.match(line, "author%-tz (.+)"), line) end,
    --sample: committer haoliang
    function(line) return "committer", assert(string.match(line, "committer (.+)"), line) end,
    --sample: committer-mail <haoliang0.1.2@gmail.com>
    function(line) return "committer-mail", assert(string.match(line, "committer%-mail <(.+)>"), line) end,
    --sample: committer-time 1690265372
    function(line) return "committer-time", assert(string.match(line, "committer%-time (%d+)"), line) end,
    --sample: committer-tz +0800
    function(line) return "committer-tz", assert(string.match(line, "committer%-tz (.+)"), line) end,
    --sample: summary [nvim] split digits into several modules
    function(line) return "summary", assert(string.match(line, "summary (.+)"), line) end,
  }

  --CAUTION: this line can be missing
  --sample: previous b0bed28400fa3ecc7eb19b8968dbbb570e0e720e src/nvim/window.c
  local function possible11(line)
    local hash = string.match(line, "previous (%x+) (.+)")
    if hash == nil then return end
    return "previous", hash
  end

  local last2 = {
    --sample: filename nvim/.config/nvim/natives/lua/digits/commit.lua
    function(line) return "filename", assert(string.match(line, "filename (.+)"), line) end,
    function(line) return "line", line end,
  }

  local proj_all_fields = setmetatable({}, {
    __index = function() return true end,
  })

  ---@param lines fun(): string?
  ---@param projects? string[]
  function porcelain_parse(lines, projects)
    local iter = fn.iter(lines)
    local allows = projects and fn.toset(projects) or proj_all_fields
    local result = {}

    for zip in fn.zip(iter, first10) do
      local key, val = zip[2](zip[1])
      if allows[key] then result[key] = val end
    end

    do
      local possible_line = iter()
      local key, val = possible11(possible_line)
      if key ~= nil then
        result[key] = val
      else
        -- put it back to the iter
        iter = fn.chained({ possible_line }, iter)
      end
    end

    for zip in fn.zip(iter, last2) do
      local key, val = zip[2](zip[1])
      if allows[key] ~= nil then result[key] = val end
    end

    return result
  end
end

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
  local path
  do
    local abs = bufpath.file(bufnr)
    path = fs.relative_path(git.root, abs)
    if path == nil then return jelly.warn("%s is outside of git repo", abs) end
  end

  local line
  do
    --todo: deal with the file is not being tracked
    local output = git:run({ "--no-pager", "blame", "--date=short", "-L", string.format("%d,%d", lnum + 1, lnum + 1), "--", path })
    line = output()
    assert(line ~= nil and line ~= "")
  end

  --samples:
  --* ^d545cdb (haoliang 2018-06-21 1)
  --* 7d03e957 (haoliang 2021-07-01 2) setup checklist
  --* 0a39d4af (haoliang 2023-07-28 155)     blame_winid = api.nvim_open_win(blame_bufnr, false, { relative = "cursor", row = -1, col = 0, width = blame_len + 2, height = 1 })
  return Blame(path, lnum, string.match(line, "%^?(%x+) %(([^)]+) ([0-9-]+) .+%)"))
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
    blame_bufnr = api.nvim_create_buf(false, true)
    prefer.bo(blame_bufnr, "bufhidden", "wipe")
    handyclosekeys(blame_bufnr)
    local line = string.format("%s %s %s", blame.obj, blame.author, blame.date)
    blame_len = #line
    api.nvim_buf_set_lines(blame_bufnr, 0, -1, false, { line })
    bufmap(blame_bufnr, "n", "gf", function() require("digits.show")(git, blame.obj, blame.path) end)
  end

  local blame_winid
  do
    blame_winid = api.nvim_open_win(blame_bufnr, false, { relative = "cursor", row = -1, col = 0, width = blame_len + 2, height = 1 })
    api.nvim_create_autocmd("cursormoved", {
      buffer = bufnr,
      once = true,
      callback = function()
        if api.nvim_win_is_valid(blame_winid) then api.nvim_win_close(blame_winid, false) end
      end,
    })
  end
end

function M.file(git, winid)
  --design
  --* blame on each line of a file
  --* populate to loclist
  --* jump to the current line
end

return M
