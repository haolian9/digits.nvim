local M = {}

local project = require("infra.project")

local Git = require("digits.Git")

local api = vim.api

function M.status()
  local git = Git(assert(project.git_root()))
  require("digits.status")(git)
end

function M.commit()
  local git = Git(assert(project.git_root()))
  require("digits.commit")(git)
end

---@param bufnr? integer
function M.diff(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local git = Git(assert(project.git_root()))
  require("digits.diff")(git, bufnr)
end

return M
