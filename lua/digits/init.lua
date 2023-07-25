local Git = require("digits.Git")
local project = require("infra.project")

return {
  status = function()
    local git = Git(assert(project.git_root()))
    require("digits.status")(git)
  end,
  commit = function()
    local git = Git(assert(project.git_root()))
    require("digits.commit")(git)
  end,
}
