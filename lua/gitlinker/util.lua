local logger = require("gitlinker.logger")

-- normalize path slash from '\\' to '/'
--- @param p string
--- @return string
local function path_normalize(p)
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
    cwd = path_normalize(cwd)

    local bufpath = vim.api.nvim_buf_get_name(0)
    bufpath = vim.fn.resolve(bufpath)
    bufpath = path_normalize(bufpath)

    logger.debug(
        "|util.path_relative| enter, cwd:%s, bufpath:%s",
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
    logger.debug("|util.path_relative| result:%s", vim.inspect(result))
    return result
end

local M = {
    path_normalize = path_normalize,
    path_relative_bufpath = path_relative_bufpath,
}

return M
