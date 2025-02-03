local M = {}

local listlib = require("infra.listlib")

local cmdviewer = require("digits.cmdviewer")
local create_git = require("digits.create_git")
local parse_object = require("digits.parse_object")

---@param git? digits.Git
---@param object string @eg. HEAD
---@param viewer fun(git: digits.Git, args: string[])
local function main(git, object, viewer)
  git = git or create_git()

  local obj, path = parse_object(object)
  local args = { "--no-pager", "show", obj }
  if path ~= nil then listlib.extend(args, { "--", path }) end

  viewer(git, args)
end

---@param git? digits.Git
---@param object string @eg. HEAD
function M.floatwin(git, object) main(git, object, cmdviewer.fullscreen_floatwin) end

---@param git? digits.Git
---@param object string @eg. HEAD
function M.tab(git, object) main(git, object, cmdviewer.tab) end

return M
