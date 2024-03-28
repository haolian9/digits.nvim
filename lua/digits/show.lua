local listlib = require("infra.listlib")

local cmdviewer = require("digits.cmdviewer")
local create_git = require("digits.create_git")
local parse_object = require("digits.parse_object")

---@param git? digits.Git
---@param object string @eg. HEAD
return function(git, object)
  git = git or create_git()

  local obj, path = parse_object(object)
  local args = { "--no-pager", "show", obj }
  if path ~= nil then listlib.extend(args, { "--", path }) end

  cmdviewer.fullscreen_floatwin(git, args)
end
