local create_git = require("digits.create_git")

---@param ... (string|integer)[]
return function(...)
  local args = { ... }
  assert(#args > 0)

  local git = create_git()
  git:floatterm(args, {}, { insert = false, auto_close = false })
end
