local M = {}

-- RFC 2396: https://www.ietf.org/rfc/rfc2396.txt
--
--- @param value string?
--- @return string?
M.encode = function(value)
  if type(value) ~= "string" then
    return nil
  end
  value = string.gsub(
    value,
    "([^0-9a-zA-Z !'()*._~-])", -- locale independent
    function(c)
      return string.format("%%%02X", string.byte(c))
    end
  )
  value = string.gsub(value, " ", "+")
  return value
end

--- @param value string?
--- @return string?
M.decode = function(value)
  if type(value) ~= "string" then
    return nil
  end
  value = string.gsub(value, "+", " ")
  value = string.gsub(value, "%%(%x%x)", function(h)
    return string.char(tonumber(h, 16))
  end)
  return value
end

return M
