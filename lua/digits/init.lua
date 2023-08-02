--fluent ux
--* prefer floatwin over tab/window
--  * proper position: editor or cursor or window
--  * size: decided by content
--* interactive terminal

local M = {}

local project = require("infra.project")
local strlib = require("infra.strlib")

local Git = require("digits.Git")

local api = vim.api

local function create_git()
  local root = project.git_root()
  if root == nil then error("unable to solve the git root") end
  return Git(root)
end

function M.status() require("digits.status")(create_git()) end

function M.commit() require("digits.commit").verbose(create_git()) end

---@param bufnr? integer
function M.diff(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  require("digits.diff").file(create_git(), bufnr)
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
  git:floatterm_run(args, {}, false)
end

function M.hunk()
  --todo: goto prev/next hunk of the current file
end

do
  ---@param str string
  ---@return string,string? @obj, path
  local function parse_obj(str)
    if not strlib.find(str, ":") then return str end
    local obj, path = string.match(str, "^(.*):(.+)$")
    if obj == "" then obj = "HEAD" end
    if path ~= nil then path = vim.fn.expand(path) end
    return obj, path
  end

  --stolen from fugitive
  --
  --      Object          Meaning ~
  --* [+] @               The commit referenced by @ aka HEAD
  --* [+] master          The commit referenced by master
  --* [+] master^         The parent of the commit referenced by master
  --* [+] master...other  The merge base of master and other
  --* [-] master:         The tree referenced by master
  --* [-] ./master        The file named master in the working directory
  --* [-] :(top)master    The file named master in the work tree
  --* [-] Makefile        The file named Makefile in the work tree
  --* [+] @^:Makefile     The file named Makefile in the parent of HEAD
  --* [+] :Makefile       The file named Makefile in the index (writable)
  --* [+] @~2:%           The current file in the grandparent of HEAD
  --* [+] :%              The current file in the index
  --* [-] :1:%            The current file's common ancestor during a conflict
  --* [-] :2:#            The alternate file in the target branch during a conflict
  --* [-] :3:#5           The file from buffer #5 in the merged branch during a conflict
  --* [-] !               The commit owning the current file
  --* [-] !:Makefile      The file named Makefile in the commit owning the current file
  --* [-] !3^2            The second parent of the commit owning buffer #3
  --* [-] .git/config     The repo config file
  --* [-] :               The |fugitive-summary| buffer
  --* [-] -               A temp file containing the last |:Git| invocation's output
  --* [-] <cfile>         The file or commit under the cursor
  ---@param obj string
  function M.show(obj)
    if obj == nil then obj = "HEAD" end
    local git = create_git()
    require("digits.show")(git, parse_obj(obj))
  end
end

return M
