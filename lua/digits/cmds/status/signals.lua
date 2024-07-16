local M = {}

local augroups = require("infra.augroups")

local aug = augroups.Augroup("digits://cmds.status")

function M.reload() aug:emit("user", { pattern = "digits:cmds:status:reload" }) end

function M.on_reload(callback) aug:repeats("User", { pattern = "digits:cmds:status:reload", callback = callback }) end

return M

