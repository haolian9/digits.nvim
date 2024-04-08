local M = {}

local project = require("infra.project")
local strlib = require("infra.strlib")

local Git = require("digits.Git")

local api = vim.api

local last_used_root

---@param bufnr integer
---@return string
function M.resolve_root(bufnr)
  local root = project.git_root(bufnr)

  --todo: recognize the buffers created by digits itself
  if root == nil then
    local bufname = api.nvim_buf_get_name(bufnr)
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
  root = root or M.resolve_root(api.nvim_get_current_buf())

  return Git(root)
end

return setmetatable(M, {
  ---@param _ any
  ---@param root? string
  ---@return digits.Git
  __call = function(_, root) return M.Git(root) end,
})
