local cwd = vim.fn.getcwd()

describe("range", function()
    local assert_eq = assert.is_equal
    local assert_true = assert.is_true
    local assert_false = assert.is_false

    before_each(function()
        vim.api.nvim_command("cd " .. cwd)
        vim.opt.swapfile = false
        local logger = require("gitlinker.logger")
        logger.setup()
    end)

    local range = require("gitlinker.range")
    describe("[_is_visual_mode]", function()
        it("test", function()
            assert_true(range._is_visual_mode("V"))
            assert_true(range._is_visual_mode("v"))
            assert_true(range._is_visual_mode("ctrl-v"))
            assert_false(range._is_visual_mode("n"))
            assert_false(range._is_visual_mode("i"))
        end)
    end)
end)
