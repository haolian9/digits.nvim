--fluent ux
--* prefer floatwin over tab/window
--  * proper position: editor or cursor or window
--  * size: decided by content
--* interactive terminal

local M = {}

local dictlib = require("infra.dictlib")
local fn = require("infra.fn")
local project = require("infra.project")

local Git = require("digits.Git")

local api = vim.api

local function create_git()
  local bufnr = api.nvim_get_current_buf()
  local root = project.git_root(bufnr)
  --todo: recognize the buffers created by digits itself
  if root == nil then error("unable to solve the git root") end
  return Git(root)
end

function M.status() require("digits.status")(create_git()) end

function M.commit() require("digits.commit").tab(create_git()) end

function M.diff() require("digits.diff")(create_git()) end

---@param bufnr? integer
function M.diff_file(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  require("digits.diff")(create_git(), bufnr)
end

function M.blame_curline()
  local winid = api.nvim_get_current_win()
  require("digits.blame").line(create_git(), winid)
end

function M.blame()
  local winid = api.nvim_get_current_win()
  require("digits.blame").file(create_git(), winid)
end

function M.log() require("digits.log")(create_git(), 100) end

---@param ... (string|integer)[]
function M.cmd(...)
  local args = { ... }
  assert(#args > 0)

  local git = create_git()
  git:floatterm(args, {}, { insert = false, autoclose = false })
end

---@param winid? integer
function M.hunks(winid)
  winid = winid or api.nvim_get_current_win()

  local git = create_git()
  require("digits.diffhunks").setloclist(git, winid)
end

---@param object string @supported forms are defined by .parse_object()
function M.show(object)
  if object == nil then object = "HEAD" end

  local git = create_git()
  require("digits.show")(git, object)
end

function M.push()
  local git = create_git()
  require("digits.push")(git)
end

M.comp = {
  available_subcmds = function()
    return fn.tolist(fn.filter(function(e) return e ~= "comp" and e ~= "cmd" end, dictlib.keys(M)))
  end,
}

return M
