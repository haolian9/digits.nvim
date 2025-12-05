local jelly = require("infra.jellyfish")("digits.cmds.log")
local bufmap = require("infra.keymap.buffer")
local listlib = require("infra.listlib")
local ni = require("infra.ni")
local strlib = require("infra.strlib")

local cmdviewer = require("digits.cmdviewer")
local create_git = require("digits.create_git")

---@param raw? string
---@return string?
local function resolve_path(raw)
  if raw == nil then return end

  --for '%', '#'
  local result = vim.fn.expand(raw)
  assert(result ~= "", "not a valid path")

  --for paths relative to fn.getcwd()
  if strlib.startswith(result, "/") then return result end

  return result
end

---@param n? integer @nil means show whole log
---@param path? '%'|'#'|string @special case: %, #. see also digits.parse_object
---@param git? digits.Git
return function(n, path, git)
  path = resolve_path(path)
  git = git or create_git()

  local args = { "--no-pager", "log", "--no-merges", "--oneline" }
  if n ~= nil then listlib.extend(args, { "-n", tostring(n) }) end
  if path ~= nil then listlib.extend(args, { "--", path }) end

  --depends on above git args
  local hash_pattern = "^(%x+)"

  local bufnr = cmdviewer.open("tab", git, args)

  local function rhs_detail()
    local obj
    do
      local line = ni.get_current_line()
      local hash = string.match(line, hash_pattern)
      if hash == nil then return jelly.warn("no availabl object under cursor") end
      obj = hash
      if path ~= nil then obj = string.format("%s:%s", hash, path) end
    end
    require("digits.cmds.show").open("tab", obj, git)
  end

  bufmap(bufnr, "n", "gf", rhs_detail)
  bufmap(bufnr, "n", "K", rhs_detail)
end
