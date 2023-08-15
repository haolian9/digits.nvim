local M = {}

local bufrename = require("infra.bufrename")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("digits.commit", "debug")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local facts = require("digits.facts")

local api = vim.api

---@param bufnr integer
---@return fun(): string?
local function buflines(bufnr)
  return fn.map(function(lnum) return api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] end, fn.range(api.nvim_buf_line_count(bufnr)))
end

local next_id
do
  local count = 0
  function next_id()
    count = count + 1
    return count
  end
end

---@param git digits.Git
---@param on_exit? fun() @called when the commit command completed
local function compose_the_buffer(git, on_exit)
  local infos = {}
  do
    for line in git:run({ "status" }) do
      table.insert(infos, "# " .. line)
    end
    for line in git:run({ "--no-pager", "diff", "--cached" }) do
      table.insert(infos, line)
    end
  end

  local bufnr, bufname
  do
    bufnr = Ephemeral({ undolevels = 10 }, { "", infos })
    prefer.bo(bufnr, "filetype", "gitcommit")
    bufname = string.format("git://commit/%d", next_id())
    bufrename(bufnr, bufname)
  end

  --NB: as one buffer can be attached to many windows, worsely :sp and :vs are inevitable
  --    hence avoid winclosed
  api.nvim_create_autocmd("bufwipeout", {
    buffer = bufnr,
    once = true,
    callback = function()
      local msgs = {}
      for line in buflines(bufnr) do
        if strlib.startswith(line, "#") then break end
        table.insert(msgs, line)
      end
      if #msgs == 0 or msgs[1] == "" then return jelly.info("Aborting commit due to empty commit message.") end
      git:floatterm({ "commit", "-m", table.concat(msgs, "\n") }, { on_exit = on_exit })
    end,
  })

  return bufnr, bufname
end

---equals `git commit --verbose`
---@param git digits.Git
---@param on_exit? fun() @called when the commit command completed
function M.floatwin(git, on_exit)
  local bufnr = compose_the_buffer(git, on_exit)

  do
    local height = vim.go.lines - 3 -- top border + bottom border + cmdline
    local winid = api.nvim_open_win(bufnr, true, { relative = "editor", style = "minimal", border = "single", width = vim.go.columns, height = height, row = 0, col = 0 })
    api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)
    prefer.wo(winid, "list", false)
  end
end

---equals `git commit --verbose`
---@param git digits.Git
---@param on_exit? fun() @called when the commit command completed
function M.tab(git, on_exit)
  local _, bufname = compose_the_buffer(git, on_exit)
  ex("tabedit", bufname)
  prefer.wo(api.nvim_get_current_win(), "list", false)
end

return M
