local M = {}

M.HAS_VIM_VERSION_EQ = type(vim.version) == "table" and vim.is_callable(vim.version.eq)
M.HAS_VIM_VERSION_GT = type(vim.version) == "table" and vim.is_callable(vim.version.gt)
M.HAS_VIM_VERSION_GE = type(vim.version) == "table" and vim.is_callable(vim.version.ge)
M.HAS_VIM_VERSION_LT = type(vim.version) == "table" and vim.is_callable(vim.version.lt)
M.HAS_VIM_VERSION_LE = type(vim.version) == "table" and vim.is_callable(vim.version.le)

--- @param l integer[]
--- @return string
M.to_string = function(l)
  assert(type(l) == "table")
  local builder = {}
  for _, v in ipairs(l) do
    table.insert(builder, tostring(v))
  end
  return table.concat(builder, ".")
end

--- @param s string
--- @return integer[]
M.to_list = function(s)
  assert(type(s) == "string")
  local splits = vim.split(s, ".", { plain = true })
  local result = {}
  for _, v in ipairs(splits) do
    table.insert(result, tonumber(v))
  end
  return result
end

--- @param ver string|integer[]
--- @return boolean
M.lt = function(ver)
  if type(ver) == "string" then
    ver = M.to_list(ver)
  end
  return vim.version.lt(vim.version(), ver)
end

--- @param ver string|integer[]
--- @return boolean
M.ge = function(ver)
  if type(ver) == "string" then
    ver = M.to_list(ver)
  end
  return vim.version.gt(vim.version(), ver) or vim.version.eq(vim.version(), ver)
end

return M
