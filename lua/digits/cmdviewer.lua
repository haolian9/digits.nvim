local M = {}

local dictlib = require("infra.dictlib")
local Ephemeral = require("infra.Ephemeral")
local fn = require("infra.fn")
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

do
  ---@param git digits.Git
  ---@param args string[]
  ---@return integer @bufnr
  function M.fullscreen_floatwin(git, args)
    local lines
    do
      local output = git:run(args)
      lines = fn.tolist(output)
      assert(#lines > 0)
    end

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
end

function M.split(git, args, split_cmd) error("not implemented") end

return M
