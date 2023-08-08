local listlib = require("infra.listlib")

local cmdviewer = require("digits.cmdviewer")
local parse_object = require("digits.parse_object")

---@param git digits.Git
---@param object string
return function(git, object)
  local obj, path = parse_object(object)
  local args = { "--no-pager", "show", obj }
  if path ~= nil then listlib.extend(args, { "--", path }) end

  cmdviewer.fullscreen_floatwin(git, args)
end
