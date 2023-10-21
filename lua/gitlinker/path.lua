local logger = require("gitlinker.logger")

-- normalize path slash from '\\' to '/'
--- @param p string
--- @return string
local function normalize(p)
    local result = vim.fn.expand(p)
    if string.match(result, [[\\]]) then
        result = string.gsub(result, [[\\]], [[/]])
    end
    if string.match(result, [[\]]) then
        result = string.gsub(result, [[\]], [[/]])
    end
    return vim.trim(result)
end

--- @param cwd string?
--- @return string?
local function path_relative_bufpath(cwd)
    cwd = cwd or vim.fn.getcwd()
    cwd = vim.fn.resolve(cwd)
    cwd = normalize(cwd)

    local bufpath = vim.api.nvim_buf_get_name(0)
    bufpath = vim.fn.resolve(bufpath)
    bufpath = normalize(bufpath)

    logger.debug(
        "|path.relative_bufpath| enter, cwd:%s, bufpath:%s",
        vim.inspect(cwd),
        vim.inspect(bufpath)
    )

    local result = nil
    if
        string.len(bufpath) >= string.len(cwd)
        and bufpath:sub(1, #cwd) == cwd
    then
        result = bufpath:sub(#cwd + 1)
        if result:sub(1, 1) == "/" or result:sub(1, 1) == "\\" then
            result = result:sub(2)
        end
    end
    logger.debug("|path.relative_bufpath| result:%s", vim.inspect(result))
    return result
end

local M = {
    path_normalize = normalize,
    path_relative_bufpath = path_relative_bufpath,
}

return M
