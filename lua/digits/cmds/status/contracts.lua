--terms
--* status 3-length '{ss}{us} '
--  * ss: staged status
--  * us: unstaged status
--  * enum: '?AMDRU '
--    * UU: unstaged && unmerged, when rebase

local M = {}

local strlib = require("infra.strlib")

do
  local truth = {
    ["??"] = true,
    ["A "] = false,
    ["AM"] = true,
    ["AD"] = true,
    ["D "] = false,
    ["R "] = false,
    ["RM"] = true,
    ["RD"] = true,
    ["M "] = false,
    ["MM"] = true,
    ["MD"] = true,
    [" M"] = true,
    [" D"] = true,
    ["UU"] = true,
  }
  ---@param ss string @stage status
  ---@param us string @unstage status
  function M.is_stagable(ss, us)
    local bool = truth[ss .. us]
    if bool ~= nil then return bool end
    error(string.format("unexpected status; ss='%s', us='%s'", ss, us))
  end
end

do
  local truth = {
    ["??"] = false,
    ["A "] = false,
    ["AM"] = true,
    ["D "] = false,
    ["R "] = false,
    ["RM"] = true,
    ["RD"] = false,
    ["M "] = false,
    ["MM"] = true,
    ["MD"] = false,
    [" M"] = true,
    [" D"] = false,
    ["UU"] = false, --error: needs merge
  }

  function M.is_interactive_stagable(ss, us)
    local bool = truth[ss .. us]
    if bool ~= nil then return bool end
    error(string.format("unexpected status; ss='%s', us='%s'", ss, us))
  end
end

do
  local truth = {
    ["??"] = false,
    ["A "] = true,
    ["AM"] = true,
    ["AD"] = true,
    ["D "] = true,
    ["M "] = true,
    ["MM"] = true,
    ["MD"] = true,
    ["R "] = true,
    ["RM"] = true,
    ["RD"] = true,
    [" M"] = false,
    [" D"] = false,
    ["UU"] = false,
  }
  ---@param ss string @stage status
  ---@param us string @unstage status
  function M.is_unstagable(ss, us)
    local bool = truth[ss .. us]
    if bool ~= nil then return bool end
    error(string.format("unexpected status; ss='%s', us='%s'", ss, us))
  end
end

---@param line string
---@return string,string,string,(string?) @stage_status, unstage_status, path, renamed_path
function M.parse_status_line(line)
  local stage_status = string.sub(line, 1, 1)
  local unstage_status = string.sub(line, 2, 2)

  local path, renamed_path
  do
    if stage_status ~= "R" then
      path = string.sub(line, 4)
    else
      local splits = strlib.iter_splits(string.sub(line, 4), " -> ")
      path, renamed_path = splits(), splits()
      assert(path, path)
      assert(renamed_path, renamed_path)
    end
  end

  return stage_status, unstage_status, path, renamed_path
end

return M
