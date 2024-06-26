local bufpath = require("infra.bufpath")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("digits.cmds.diff", "info")

local cmdviewer = require("digits.cmdviewer")
local create_git = require("digits.create_git")

---@param git? digits.Git
---@param bufnr? integer @nil means diff of whole repo
---@param cached? boolean @nil=false
return function(git, bufnr, cached)
  git = git or create_git()

  local args = { "--no-pager", "diff", "HEAD" }

  if cached then table.insert(args, "--cached") end

  if bufnr ~= nil then
    local abs = bufpath.file(bufnr)
    if abs == nil then return jelly.debug("no file associated to buf=#d in git repo", bufnr) end
    local path = fs.relative_path(git.root, abs)
    --no need to check if this path exists or not, as it can be deleted
    --`git diff --porcelain=v1 -- {file}`
    table.insert(args, "--")
    table.insert(args, path)
  end

  cmdviewer.split(git, args, "right")
end
