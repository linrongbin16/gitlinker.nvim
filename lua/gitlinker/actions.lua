local spawn = require("gitlinker.commons.spawn")
local str = require("gitlinker.commons.str")
local tbl = require("gitlinker.commons.tbl")
local logging = require("gitlinker.commons.logging")

--- @alias gitlinker.Action fun(url:string):any

-- copy url to clipboard
--- @param url string
local function clipboard(url)
  vim.api.nvim_command("let @+ = '" .. url .. "'")
end

-- open url in browser
-- see: https://github.com/axieax/urlview.nvim/blob/b183133fd25caa6dd98b415e0f62e51e061cd522/lua/urlview/actions.lua#L38
--- @param url string
local function system(url)
  local errors = {}
  local logger = logging.get("gitlinker")

  local function _dummy() end
  local function _error(line)
    if str.not_empty(line) then
      table.insert(errors, line)
    end
  end
  local function _has_exitcode(result)
    return type(result) == "table" and type(result.exitcode) == "number" and result.exitcode ~= 0
  end
  local function _exit(result)
    if tbl.list_not_empty(errors) then
      if _has_exitcode(result) then
        logger:err(
          string.format(
            "failed to open url, error:%s, exitcode:%s",
            vim.inspect(table.concat(errors, " ")),
            vim.inspect(result.exitcode)
          )
        )
      else
        logger:err(
          string.format("failed to open url, error:%s", vim.inspect(table.concat(errors, " ")))
        )
      end
    elseif _has_exitcode(result) then
      logger:err(string.format("failed to open url, exitcode:%s", vim.inspect(result.exitcode)))
    end
  end

  if vim.fn.has("mac") > 0 then
    spawn.detached({ "open", url }, {
      on_stdout = _dummy,
      on_stderr = _error,
    }, _exit)
    -- vim.fn.jobstart({ "open", url }, { on_stderr = function() end })
  elseif vim.fn.has("win32") > 0 or vim.fn.has("win64") > 0 then
    spawn.detached({ "cmd", "/C", "start", url }, {
      on_stdout = _dummy,
      on_stderr = _error,
    }, _exit)
    -- vim.fn.jobstart({ "cmd", "/C", "start", url })
  elseif vim.fn.executable("wslview") > 0 then
    spawn.detached({ "wslview", url }, {
      on_stdout = _dummy,
      on_stderr = _error,
    }, _exit)
    -- vim.fn.jobstart({ "wslview", url })
  else
    spawn.detached({ "xdg-open", url }, {
      on_stdout = _dummy,
      on_stderr = _error,
    }, _exit)
    -- vim.fn.jobstart({ "xdg-open", url })
  end
end

local M = {
  clipboard = clipboard,
  system = system,
}

return M
