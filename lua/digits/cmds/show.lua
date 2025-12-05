local M = {}

local listlib = require("infra.listlib")

local cmdviewer = require("digits.cmdviewer")
local create_git = require("digits.create_git")
local parse_object = require("digits.parse_object")

---@param mode? infra.bufopen.Mode|'float'
---@param object string @eg. HEAD
---@param git? digits.Git
function M.open(mode, object, git)
  mode = mode or "tab"
  git = git or create_git()

  local obj, path = parse_object(object)
  local args = { "--no-pager", "show", obj }
  if path ~= nil then listlib.extend(args, { "--", path }) end

  if mode == "float" then
    cmdviewer.fullscreen_floatwin(git, args)
  else
    cmdviewer.open(mode, git, args)
  end
end

return M
