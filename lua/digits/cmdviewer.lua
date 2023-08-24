local M = {}

local bufrename = require("infra.bufrename")
local dictlib = require("infra.dictlib")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fn = require("infra.fn")
local handyclosekeys = require("infra.handyclosekeys")
local popupgeo = require("infra.popupgeo")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local facts = require("digits.facts")

local api = vim.api

---for `git --no-pager status`, `git status`
---@param args string[]
---@return string
local function find_subcmd_in_args(args)
  for _, a in ipairs(args) do
    if not strlib.startswith(a, "-") then return a end
  end
  error("unreachable")
end

---@param git digits.Git
---@param args string[]
---@return integer @bufnr
function M.fullscreen_floatwin(git, args)
  local lines = fn.tolist(git:run(args))

  local bufnr
  do
    local function namefn(nr) return string.format("git://%s/%d", find_subcmd_in_args(args), nr) end
    bufnr = Ephemeral({ namefn = namefn, handyclose = true }, lines)
    prefer.bo(bufnr, "filetype", "git")
  end

  do
    local win_opts = dictlib.merged({ relative = "editor", border = "single" }, popupgeo.fullscreen(1))
    local winid = api.nvim_open_win(bufnr, true, win_opts)
    api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)
  end

  return bufnr
end

---@param git digits.Git
---@param args string[]
---@return integer @bufnr
function M.tab(git, args)
  local lines = fn.tolist(git:run(args))

  ex("tabnew")

  local bufnr = api.nvim_get_current_buf()
  do --the same as ephemeral
    local bo = prefer.buf(bufnr)
    bufrename(bufnr, string.format("git://%s/%d", find_subcmd_in_args(args), bufnr))
    bo.buftype = "nofile"
    bo.bufhidden = "wipe"
    bo.buflisted = false
    bo.filetype = "git"
    bo.undolevels = -1
    api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    bo.modifiable = false
    handyclosekeys(bufnr)
  end

  return bufnr
end

return M
