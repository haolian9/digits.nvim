local facts = require("digits.facts")
local jelly = require("infra.jellyfish")("digits.commit", "debug")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local api = vim.api

---equals `git commit --verbose`
---@param git digits.Git
---@param on_exit? fun() @called when the commit command completed
return function(git, on_exit)
  local infos = {}
  do
    for line in git:run({ "status" }) do
      table.insert(infos, "# " .. line)
    end
    for line in git:run({ "--no-pager", "diff", "--cached" }) do
      table.insert(infos, line)
    end
  end

  local bufnr
  do
    bufnr = api.nvim_create_buf(false, true)
    prefer.bo(bufnr, "bufhidden", "wipe")
    api.nvim_buf_set_lines(bufnr, 0, 0, false, { "" })
    api.nvim_buf_set_lines(bufnr, 1, -1, false, infos)
    prefer.bo(bufnr, "filetype", "gitcommit")
  end

  local winid
  do
    local height = vim.go.lines - 3 -- top border + bottom border + cmdline
        -- stylua: ignore
        winid = api.nvim_open_win(bufnr, true, {
          relative = "editor", style = "minimal", border = "single",
          width = vim.go.columns, height = height, row = 0, col = 0,
          title = "gitcommit://"
        })
    api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)
  end

  --todo: maybe bufunload or bufwipeout for :split
  api.nvim_create_autocmd("winclosed", {
    buffer = bufnr,
    once = true,
    callback = function()
      local msgs = {}
      for i = 0, api.nvim_buf_line_count(bufnr) - 1 do
        local line = api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
        if strlib.startswith(line, "#") then break end
        table.insert(msgs, line)
      end
      if #msgs == 0 or msgs[1] == "" then return jelly.info("Aborting commit due to empty commit message.") end
      local msg = table.concat(msgs, "\n")
      git:floatterm_run({ "commit", "-m", msg }, { on_exit = on_exit })
    end,
  })
end
