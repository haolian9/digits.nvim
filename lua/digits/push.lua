local jelly = require("infra.jellyfish")("digits.push", "info")
local strlib = require("infra.strlib")

local create_git = require("digits.create_git")

---@param git digits.Git
local function resolve_push_remote(git)
  local curbr = assert(git:run({ "branch", "--show-current" })())
  local output = git:run({ "config", "--get-regexp", string.format([[branch\.%s\.(remote|merge)]], curbr) })

  local remote
  do
    remote = output()
    if remote == nil then return jelly.warn("no upstream remote for local branch %s", curbr) end
    local prefix = string.format([[branch.%s.remote ]], curbr)
    assert(strlib.startswith(remote, prefix))
    remote = string.sub(remote, #prefix + 1)
  end

  local branch
  do
    branch = output()
    if branch == nil then return jelly.warn("no upstream branch for local branch %s", curbr) end
    local prefix = string.format([[branch.%s.merge refs/heads/]], curbr)
    assert(strlib.startswith(branch, prefix))
    branch = string.sub(branch, #prefix + 1)
  end

  return remote, branch
end

---@param git? digits.Git
return function(git)
  git = git or create_git()

  local remote, branch = resolve_push_remote(git)
  if not (remote and branch) then return end

  git:floatterm({ "push", remote, branch }, nil, { autoclose = false })
end
