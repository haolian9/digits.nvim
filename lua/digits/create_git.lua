local M = {}

local ni = require("infra.ni")
local project = require("infra.project")
local strlib = require("infra.strlib")

local Git = require("digits.Git")

local last_used_root

---@param bufnr integer
---@return string
function M.resolve_root(bufnr)
  local root = project.git_root(bufnr)

  if root == nil then
    local bufname = ni.buf_get_name(bufnr)
    if strlib.startswith(bufname, "git://") then root = last_used_root end
  end

  if root == nil then
    error("failed to resolve git root")
  else
    last_used_root = root
  end

  return root
end

---as default, it's based on the current buffer
---@param root? string
---@return digits.Git
function M.Git(root)
  root = root or M.resolve_root(ni.get_current_buf())

  return Git(root)
end

return setmetatable(M, {
  ---@param root? string
  ---@return digits.Git
  __call = function(_, root) return M.Git(root) end,
})
