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
            print(string.format("_get_remote:%s\n", vim.inspect(r)))
            assert_eq(type(r), "table")
        end)
    end)
    describe("[get_remote_url]", function()
        it("get remote url", function()
            local remote = git.get_branch_remote()
            print(string.format("get_branch_remote:%s\n", vim.inspect(remote)))
            if remote then
                assert_eq(type(remote), "string")
                assert_true(string.len(remote) > 0)
                local r = git.get_remote_url(remote)
                print(string.format("get_remote_url:%s\n", vim.inspect(r)))
                assert_eq(type(r), "string")
                assert_true(string.len(r) > 0)
            end
        end)
    end)
    describe("[_get_rev]", function()
        it("get rev @{u}", function()
            local rev = git._get_rev("@{u}")
            if rev then
                print(string.format("_get_rev:%s\n", vim.inspect(rev)))
                assert_eq(type(rev), "string")
                assert_true(string.len(rev) > 0)
            else
                assert_true(rev == nil)
            end
        end)
    end)
end)
