--- @alias gitlinker.Action fun(url:string):any

local log = require("gitlinker.log")
local types = require("gitlinker.types")

local M = {}

-- copy url to clipboard
--- @param url string
local function clipboard(url)
  vim.fn.setreg("+", url)
end

--- Whether nvim is a Linux build running inside Windows WSL.
---
--- WSL has to be handled apart: `vim.ui.open()` picks its command by asking
--- `xdg-open` first on any Linux system, and the `xdg-open` inside WSL usually
--- cannot reach the browser that lives on the Windows host -- the link is
--- copied, the notification says nothing, and no window appears.
---
--- @package
--- @return boolean
M._is_wsl = function()
  if vim.fn.has("unix") ~= 1 then
    -- nvim itself runs on Windows, where its own opener already knows how to
    -- start a browser (`cmd.exe /c start`).
    return false
  end
  if vim.fn.has("wsl") == 1 then
    return true
  end
  -- The env var and the kernel string are the two facts `has('wsl')` is
  -- derived from; read them directly in case the flag is not compiled in.
  if not types.str_empty(vim.env.WSL_DISTRO_NAME) then
    return true
  end
  local uv = vim.uv or vim.loop
  local release = uv.os_uname().release or ""
  return string.lower(release):find("microsoft", 1, true) ~= nil
end

--- Quote `s` as a PowerShell string literal.
---
--- `powershell.exe -Command` takes one argument and parses it *as a script*, so
--- a url carrying `'` or `$` is source code, not data. Inside a single-quoted
--- literal PowerShell expands nothing, and doubling the quote is the only
--- escape that stays.
---
--- @param s string
--- @return string
local function powershell_literal(s)
  local escaped = string.gsub(s, "'", "''")
  return "'" .. escaped .. "'"
end

--- The commands to try, in order, to hand `url` to the Windows browser.
---
--- @package
--- @param url string
--- @return {name:string, cmd:string[]}[]
M._wsl_openers = function(url)
  local openers = {}
  if vim.fn.executable("wslview") == 1 then
    -- `wslview` (wslu) is the helper made for this: it crosses the interop
    -- boundary and opens the url in the Windows default browser.
    table.insert(openers, { name = "wslview", cmd = { "wslview", url } })
  end
  if vim.fn.executable("powershell.exe") == 1 then
    -- `Start-Process` is what a Windows shell does with a url, so it lands on
    -- the default browser without this plugin having to know its path.
    table.insert(openers, {
      name = "powershell.exe",
      cmd = {
        "powershell.exe",
        "-NoProfile",
        "-NonInteractive",
        "-Command",
        "Start-Process " .. powershell_literal(url),
      },
    })
  end
  return openers
end

--- Run `openers[index]`, moving to the next one when it fails to open `url`.
---
--- The chain is driven by failures rather than by a fixed sleep: the next
--- candidate starts inside the previous one's `on_exit`, so a command that
--- works costs nothing extra and one that does not is replaced as soon as the
--- host says so. `reasons` collects what each one reported, which is the only
--- thing left to say when the list runs out.
---
--- @param url string
--- @param openers {name:string, cmd:string[]}[]
--- @param index integer
--- @param reasons string[]
local function _wsl_open(url, openers, index, reasons)
  local opener = openers[index]
  if not opener then
    -- Deliberately no `vim.ui.open()` here: `xdg-open` is the command the whole
    -- WSL branch exists to step around, and reporting a dead end beats opening
    -- the link nowhere.
    local reason = #reasons > 0 and table.concat(reasons, "; ")
      or "wslview and powershell.exe are not installed"
    log.err(string.format("fatal: failed to open the url on WSL: %s", reason))
    return
  end

  --- @param why string
  local function on_fail(why)
    table.insert(reasons, string.format("%s %s", opener.name, why))
    _wsl_open(url, openers, index + 1, reasons)
  end

  --- @param completed vim.SystemCompleted
  local function on_exit(completed)
    if completed.code == 0 then
      return
    end
    local why
    if completed.code == nil then
      why = string.format("was killed by signal %s", tostring(completed.signal))
    else
      why = string.format("exited with code %d", completed.code)
      if not types.str_blank(completed.stderr) then
        why = string.format("%s: %s", why, vim.trim(completed.stderr))
      end
    end
    on_fail(why)
  end

  local ok, err = pcall(vim.system, opener.cmd, {
    -- The same options `vim.ui.open()` passes: the browser is handed off and
    -- nvim must not wait on it, nor die when it closes.
    text = true,
    detach = true,
  }, on_exit)
  if not ok then
    -- `vim.system` raises instead of invoking `on_exit` when the binary is
    -- missing, so surface this as a failure of this opener, too.
    local msg = tostring(err):gsub('^%[string ".*"%]:%d+: ', "")
    on_fail(string.format("could not be started: %s", msg))
  end
end

-- open url in browser
--
-- On Windows WSL the url is handed to the Windows browser through `wslview`,
-- falling back to `powershell.exe`; everywhere else `vim.ui.open()` is used.
--- @param url string
local function open(url)
  if not M._is_wsl() then
    local _, err = vim.ui.open(url)
    if err then
      -- `vim.ui.open` returns its failure instead of raising it, and the caller
      -- cannot see the return value from here: say so, rather than leaving the
      -- user with a link that silently never opened.
      log.err(string.format("fatal: failed to open the url: %s", err))
    end
    return
  end

  _wsl_open(url, M._wsl_openers(url), 1, {})
end

M.clipboard = clipboard
M.open = open

return M
