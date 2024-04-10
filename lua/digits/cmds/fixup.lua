local augroups = require("infra.augroups")
local buflines = require("infra.buflines")
local Ephemeral = require("infra.Ephemeral")
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("digits.cmds.fixup", "debug")
local rifts = require("infra.rifts")
local strlib = require("infra.strlib")

local create_git = require("digits.create_git")

---@param git? digits.Git
---@param on_exit fun() @called after commit does happened
return function(git, on_exit)
  git = git or create_git()

  local bufnr
  do
    local stdout = git:run({ "log", "--oneline", "-n", "20" })
    local lines = fn.tolist(fn.map(function(line) return "# " .. line end, stdout))
    bufnr = Ephemeral({ modifiable = true }, lines)
  end

  local aug = augroups.BufAugroup(bufnr, false)
  aug:once("BufWipeout", {
    callback = function()
      aug:unlink()

      local hash
      do
        local iter = buflines.unmatched(bufnr, "^#")
        local line = iter()
        if line == nil then return jelly.info("no hash is chosen") end
        line = strlib.lstrip(line)
        hash = string.sub(line, 1, 8)
        jelly.debug("hash=%s", hash)
      end

      git:floatterm(
        --
        { "commit", "--fixup", hash },
        { on_exit = on_exit },
        { insert = true, auto_close = false, open_win = function(nr) return rifts.open.fullscreen(nr, true, { relative = "editor" }) end }
      )
    end,
  })

  rifts.open.fragment(bufnr, true, { relative = "editor" }, { width = 0.6, height = 0.8 })
end
