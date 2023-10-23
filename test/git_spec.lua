local cwd = vim.fn.getcwd()

describe("git", function()
    local assert_eq = assert.is_equal
    local assert_true = assert.is_true
    local assert_false = assert.is_false

    before_each(function()
        vim.api.nvim_command("cd " .. cwd)
    end)

    local logger = require("gitlinker.logger")
    logger.setup({
        level = "DEBUG",
        console_log = true,
        file_log = true,
    })
    local git = require("gitlinker.git")
    describe("[_get_remote]", function()
        it("get remote", function()
            local r = git._get_remote()
            assert_eq(type(r), "table")
        end)
    end)
end)
