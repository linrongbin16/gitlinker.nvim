local actions = require("gitlinker.actions")

describe("gitlinker.actions", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false
  local assert_same = assert.same

  -- The WSL branch reads the platform through `vim.fn.has`, the environment,
  -- `vim.fn.executable` and `vim.uv.os_uname`, and hands the url out through
  -- `vim.system` / `vim.ui.open`. None of that can be trusted from the machine
  -- running the suite (GitHub CI is a plain Linux runner, a developer may be
  -- on WSL), so every case patches these doors and restores them afterwards.
  --- @type table<string, any>
  local saved = {}

  --- @type {msg:string, level:integer?}[]
  local notices

  before_each(function()
    saved.is_wsl = actions._is_wsl
    saved.wsl_openers = actions._wsl_openers
    saved.has = vim.fn.has
    saved.executable = vim.fn.executable
    saved.system = vim.system
    saved.os_uname = vim.uv.os_uname
    saved.notify = vim.notify
    saved.ui_open = vim.ui.open
    saved.wsl_distro = vim.env.WSL_DISTRO_NAME
    notices = {}
    -- The console sink of `gitlinker.log`: capture what the user would see.
    vim.notify = function(msg, level)
      table.insert(notices, { msg = tostring(msg), level = level })
    end
  end)

  after_each(function()
    actions._is_wsl = saved.is_wsl
    actions._wsl_openers = saved.wsl_openers
    vim.fn.has = saved.has
    vim.fn.executable = saved.executable
    vim.system = saved.system
    vim.uv.os_uname = saved.os_uname
    vim.notify = saved.notify
    vim.ui.open = saved.ui_open
    vim.env.WSL_DISTRO_NAME = saved.wsl_distro
  end)

  --- Answer `vim.fn.has` from `answers`, 0 for anything unstated.
  --- @param answers table<string, integer>
  local function stub_has(answers)
    vim.fn.has = function(name)
      return answers[name] or 0
    end
  end

  --- Answer `vim.fn.executable` with 1 exactly for the names in `present`.
  --- @param present string[]
  local function stub_executable(present)
    local lookup = {}
    for _, name in ipairs(present) do
      lookup[name] = 1
    end
    vim.fn.executable = function(name)
      return lookup[name] or 0
    end
  end

  --- Pretend the kernel release is `release`.
  --- @param release string
  local function stub_release(release)
    vim.uv.os_uname = function()
      return { sysname = "Linux", release = release, version = "", machine = "x86_64" }
    end
  end

  --- Record every `vim.system` spawn and feed each one the `on_exit` result
  --- (or raise, for a `raise` entry) matching its order. The stub calls
  --- `on_exit` synchronously, so the whole fallback chain finishes before
  --- `open` returns.
  --- @param results {code:integer?, stderr:string?, raise:boolean?}[]
  --- @return {cmd:string[], opts:vim.SystemOpts?}[]
  local function stub_system(results)
    local spawned = {}
    vim.system = function(cmd, opts, on_exit)
      table.insert(spawned, { cmd = cmd, opts = opts })
      local result = results[#spawned]
      assert_true(result ~= nil, string.format("unexpected spawn: %s", table.concat(cmd, " ")))
      if result.raise then
        error(string.format("ENOENT: no such file or directory (cmd): '%s'", cmd[1]), 0)
      end
      on_exit({ code = result.code, signal = 0, stdout = "", stderr = result.stderr or "" })
      return {}
    end
    return spawned
  end

  --- Wait for the log message containing `needle` to reach `vim.notify`.
  --- @param needle string
  --- @return boolean
  local function wait_notice(needle)
    return vim.wait(5000, function()
      for _, notice in ipairs(notices) do
        if string.find(notice.msg, needle, 1, true) then
          return true
        end
      end
      return false
    end, 10)
  end

  describe("[_is_wsl]", function()
    it("detects WSL from the compiled feature flag", function()
      stub_has({ unix = 1, wsl = 1 })
      assert_true(actions._is_wsl())
    end)

    it("reports false on a Windows build of nvim", function()
      -- Even with the WSL environment variables of a parent process present,
      -- nvim running on Windows itself must go through `vim.ui.open`.
      stub_has({ win32 = 1, wsl = 0 })
      vim.env.WSL_DISTRO_NAME = "Ubuntu-22.04"
      assert_false(actions._is_wsl())
    end)

    it("falls back to WSL_DISTRO_NAME when the flag says no", function()
      stub_has({ unix = 1, wsl = 0 })
      vim.env.WSL_DISTRO_NAME = "Ubuntu-22.04"
      stub_release("6.8.0-generic")
      assert_true(actions._is_wsl())
    end)

    it("falls back to the kernel release when the flag says no", function()
      stub_has({ unix = 1, wsl = 0 })
      vim.env.WSL_DISTRO_NAME = nil
      stub_release("5.15.153.1-microsoft-standard-WSL2")
      assert_true(actions._is_wsl())
    end)

    it("reports false on a plain Linux system", function()
      stub_has({ unix = 1, wsl = 0 })
      vim.env.WSL_DISTRO_NAME = nil
      stub_release("6.8.0-generic")
      assert_false(actions._is_wsl())
    end)
  end)

  describe("[_wsl_openers]", function()
    local URL = "https://github.com/example/repo"

    it("lists wslview before powershell.exe when both are installed", function()
      stub_executable({ "wslview", "powershell.exe" })
      local openers = actions._wsl_openers(URL)
      assert_eq(#openers, 2)
      assert_eq(openers[1].name, "wslview")
      assert_same(openers[1].cmd, { "wslview", URL })
      assert_eq(openers[2].name, "powershell.exe")
    end)

    it("skips an opener that is not installed", function()
      stub_executable({ "powershell.exe" })
      local openers = actions._wsl_openers(URL)
      assert_eq(#openers, 1)
      assert_eq(openers[1].name, "powershell.exe")
    end)

    it("lists nothing when neither opener is installed", function()
      stub_executable({})
      assert_same(actions._wsl_openers(URL), {})
    end)

    it("quotes the url for the PowerShell script parser", function()
      -- `powershell.exe -Command` compiles its argument as a script, so the
      -- url must arrive as a single-quoted literal with each `'` doubled.
      stub_executable({ "powershell.exe" })
      local openers = actions._wsl_openers("https://e.com/a'1")
      assert_same(openers[1].cmd, {
        "powershell.exe",
        "-NoProfile",
        "-NonInteractive",
        "-Command",
        "Start-Process 'https://e.com/a''1'",
      })
    end)
  end)

  describe("[open] on WSL", function()
    local URL = "https://github.com/example/repo"

    before_each(function()
      actions._is_wsl = function()
        return true
      end
    end)

    it("opens with wslview when it succeeds", function()
      stub_executable({ "wslview", "powershell.exe" })
      local spawned = stub_system({ { code = 0 } })
      actions.open(URL)
      assert_eq(#spawned, 1)
      assert_same(spawned[1].cmd, { "wslview", URL })
      assert_true(spawned[1].opts.text)
      assert_true(spawned[1].opts.detach)
      assert_eq(#notices, 0)
    end)

    it("falls back to powershell.exe when wslview fails", function()
      stub_executable({ "wslview", "powershell.exe" })
      local spawned = stub_system({ { code = 3, stderr = "no interop" }, { code = 0 } })
      actions.open(URL)
      assert_eq(#spawned, 2)
      assert_eq(spawned[2].cmd[1], "powershell.exe")
      -- The link did open in the end, so the user hears nothing.
      assert_eq(#notices, 0)
    end)

    it("falls back when the first opener cannot even be started", function()
      stub_executable({ "wslview", "powershell.exe" })
      local spawned = stub_system({ { raise = true }, { code = 0 } })
      actions.open(URL)
      assert_eq(#spawned, 2)
      assert_eq(spawned[2].cmd[1], "powershell.exe")
      assert_eq(#notices, 0)
    end)

    it("reports every candidate when all of them fail", function()
      stub_executable({ "wslview", "powershell.exe" })
      stub_system({ { code = 1, stderr = "boom" }, { code = 2 } })
      actions.open(URL)
      assert_true(wait_notice("failed to open the url on WSL"))
      local msg = notices[1].msg
      assert_true(string.find(msg, "wslview exited with code 1: boom", 1, true) ~= nil, msg)
      assert_true(string.find(msg, "powershell.exe exited with code 2", 1, true) ~= nil, msg)
    end)

    it("reports that no opener is installed when there is none", function()
      stub_executable({})
      actions.open(URL)
      assert_true(wait_notice("wslview and powershell.exe are not installed"))
    end)
  end)

  describe("[open] outside WSL", function()
    local URL = "https://github.com/example/repo"

    before_each(function()
      actions._is_wsl = function()
        return false
      end
    end)

    it("hands the url to vim.ui.open", function()
      local opened = {}
      vim.ui.open = function(path)
        table.insert(opened, path)
        return {}
      end
      actions.open(URL)
      assert_same(opened, { URL })
      assert_eq(#notices, 0)
    end)

    it("reports the error vim.ui.open returns", function()
      -- `vim.ui.open` signals a missing handler through its second return
      -- value instead of raising; silently discarding it leaves the user with
      -- a link that never opened.
      vim.ui.open = function(_)
        return nil, "no handler found"
      end
      actions.open(URL)
      assert_true(wait_notice("failed to open the url: no handler found"))
    end)
  end)
end)
