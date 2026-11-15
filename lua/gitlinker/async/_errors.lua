local M = {}

local nil_error = 'error(nil)'

--- Normalize a failed Lua operation for error slots where `nil` means success.
--- @param err any
--- @return any
function M.normalize(err)
  return err == nil and nil_error or err
end

--- Convert an error to a string without letting its metamethod interrupt cleanup.
--- @param err any
--- @return string
function M.stringify(err)
  local ok, message = pcall(tostring, err)
  return ok and message or '<unprintable error>'
end

return M
