--stolen from fugitive
--
--      Object          Meaning ~
--* [+] @               The commit referenced by @ aka HEAD
--* [+] master          The commit referenced by master
--* [+] master^         The parent of the commit referenced by master
--* [+] master...other  The merge base of master and other
--* [-] master:         The tree referenced by master
--* [-] ./master        The file named master in the working directory
--* [-] :(top)master    The file named master in the work tree
--* [-] Makefile        The file named Makefile in the work tree
--* [+] @^:Makefile     The file named Makefile in the parent of HEAD
--* [+] :Makefile       The file named Makefile in the index (writable)
--* [+] @~2:%           The current file in the grandparent of HEAD
--* [+] :%              The current file in the index
--* [-] :1:%            The current file's common ancestor during a conflict
--* [-] :2:#            The alternate file in the target branch during a conflict
--* [-] :3:#5           The file from buffer #5 in the merged branch during a conflict
--* [-] !               The commit owning the current file
--* [-] !:Makefile      The file named Makefile in the commit owning the current file
--* [-] !3^2            The second parent of the commit owning buffer #3
--* [-] .git/config     The repo config file
--* [-] :               The |fugitive-summary| buffer
--* [-] -               A temp file containing the last |:Git| invocation's output
--* [-] <cfile>         The file or commit under the cursor

local strlib = require("infra.strlib")

---@param object string
---@return string,string? @obj, path
return function(object)
  if not strlib.contains(object, ":") then return object end
  local obj, path = string.match(object, "^(.*):(.+)$")
  if obj == "" then obj = "HEAD" end
  if path ~= nil then path = vim.fn.expand(path) end
  return obj, path
end
