local bufpath = require("infra.bufpath")
local ex = require("infra.ex")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("digits.diff", "debug")

---@param git digits.Git
---@param bufnr integer
---@param on_exit? fun()
return function(git, bufnr, on_exit)
  local path
  do
    local abs = bufpath.file(bufnr)
    if abs == nil then return jelly.debug("no file associated to buf=#d in git repo", bufnr) end
    path = fs.relative_path(git.root, abs)
    --no need to check if this path exists or not, as it can be deleted
  end

  git:floatterm_run({ "--no-pager", "diff", "HEAD", "--color=always", "--", path }, {
    on_exit = function()
      ex("stopinsert")
      if on_exit ~= nil then on_exit() end
    end,
  })
end
