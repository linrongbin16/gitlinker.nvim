local cwd = vim.fn.getcwd()

describe("gitlinker.git", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  --- Run `args` and fail loudly when it exits non-zero: a silently broken
  --- fixture would otherwise surface as a confusing assertion error later.
  --- @param args string[]
  local function sh(args)
    local out = vim.fn.system(args)
    assert_eq(vim.v.shell_error, 0, string.format("%s => %s", table.concat(args, " "), out))
  end

  before_each(function()
    vim.api.nvim_command("cd " .. cwd)
    vim.opt.swapfile = false
    vim.cmd([[ edit lua/gitlinker.lua ]])
  end)

  local wait_async = require("spec.testutil").wait_async
  local git = require("gitlinker.git")
  local path = require("gitlinker.path")
  local gitlinker = require("gitlinker")
  pcall(gitlinker.setup, {})

  describe("[git]", function()
    it("_get_remote", function()
      wait_async(function()
        local r, err = git._get_remote(cwd)
        print(string.format("_get_remote:%s, err:%s\n", vim.inspect(r), vim.inspect(err)))
        if r then
          assert_eq(type(r), "table")
          assert_true(#r > 0)
          assert_true(err == nil)
        else
          assert_eq(type(err), "string")
        end
      end)
    end)
    it("get_remote_url", function()
      wait_async(function()
        local remote, remote_err = git.get_branch_remote(cwd)
        print(
          string.format(
            "get_branch_remote:%s, err:%s\n",
            vim.inspect(remote),
            vim.inspect(remote_err)
          )
        )
        if remote then
          assert_eq(type(remote), "string")
          assert_true(string.len(remote) > 0)
          local r, err = git.get_remote_url(remote, cwd)
          print(string.format("get_remote_url:%s, err:%s\n", vim.inspect(r), vim.inspect(err)))
          if r then
            assert_eq(type(r), "string")
            assert_true(string.len(r) > 0)
            assert_true(err == nil)
          else
            assert_eq(type(err), "string")
          end
        else
          assert_eq(type(remote_err), "string")
        end
      end)
    end)
    it("_get_rev(@{u})", function()
      wait_async(function()
        local rev, err = git._get_rev("@{u}", cwd)
        print(string.format("_get_rev:%s, err:%s\n", vim.inspect(rev), vim.inspect(err)))
        if rev then
          assert_eq(type(rev), "string")
          assert_true(string.len(rev) > 0)
          assert_true(err == nil)
        else
          assert_eq(type(err), "string")
        end
      end)
    end)
    it("_get_rev with an unknown revspec reports an error", function()
      wait_async(function()
        local rev, err = git._get_rev("definitely-not-a-real-rev-xyz", cwd)
        print(string.format("_get_rev(bad):%s, err:%s\n", vim.inspect(rev), vim.inspect(err)))
        -- `git rev-parse` exits non-zero but still echoes the argument on
        -- stdout, so this must rely on the exit code rather than stdout.
        assert_true(rev == nil)
        assert_eq(type(err), "string")
        assert_true(string.len(err) > 0)
      end)
    end)
    it("is_file_in_rev", function()
      -- `path.buffer_relpath` calls Vimscript functions (`getcwd`, `resolve`),
      -- which cannot run in the fast event context the coroutine resumes in
      -- after `git` exits. Compute it here, exactly like `linker.make_linker`
      -- does when it hops back with `async.await(1, vim.schedule)`.
      local bufpath = path.buffer_relpath(vim.api.nvim_get_current_buf(), cwd)
      wait_async(function()
        -- Fail instead of returning on a missing prerequisite: a silent
        -- `return` would report a passing test that never asserted anything,
        -- which is how this whole suite used to go green.
        local remote, remote_err = git.get_branch_remote(cwd)
        assert_true(remote ~= nil, "this test needs a git remote: " .. tostring(remote_err))
        local remote_name = remote --[[@as string]]

        local remote_url, remote_url_err = git.get_remote_url(remote_name, cwd)
        assert_true(
          remote_url ~= nil,
          "this test needs a git remote url: " .. tostring(remote_url_err)
        )

        -- Prefer the revision `linker.make_linker` would use, but a shallow
        -- detached clone (CI) has no remote-tracking refs at all. Any commit
        -- works here: `is_file_in_rev` only needs a revision naming a tree.
        local rev, rev_err = git.get_closest_remote_compatible_rev(remote_name, cwd)
        if rev == nil then
          rev, rev_err = git._get_rev("HEAD", cwd)
        end
        assert_true(rev ~= nil, "this test needs a git revision: " .. tostring(rev_err))
        local rev_name = rev --[[@as string]]

        assert_true(
          bufpath ~= nil,
          "this test needs the buffer to live inside the git repository: " .. vim.inspect(cwd)
        )
        local actual, err = git.is_file_in_rev(bufpath --[[@as string]], rev_name, cwd)
        print(string.format("is_file_in_rev:%s, err:%s\n", vim.inspect(actual), vim.inspect(err)))
        if actual then
          assert_true(actual)
          assert_true(err == nil)
        else
          assert_eq(type(err), "string")
        end
      end)
    end)
    it("is_file_in_rev reports an error for a missing file", function()
      wait_async(function()
        local rev, rev_err = git._get_rev("HEAD", cwd)
        assert_true(rev ~= nil, "this test needs a git repository at HEAD: " .. tostring(rev_err))
        local actual, err = git.is_file_in_rev("no/such/file-xyz.lua", rev --[[@as string]], cwd)
        print(
          string.format(
            "is_file_in_rev(missing):%s, err:%s\n",
            vim.inspect(actual),
            vim.inspect(err)
          )
        )
        assert_true(actual == nil)
        assert_eq(type(err), "string")
      end)
    end)
    it("resolve_host", function()
      wait_async(function()
        local actual, err = git.resolve_host("github.com", cwd)
        print(string.format("resolve_host:%s, err:%s\n", vim.inspect(actual), vim.inspect(err)))
        assert_eq(actual, "github.com")
        assert_true(err == nil)
      end)
    end)
    it("resolve_host reports a missing host instead of running ssh", function()
      wait_async(function()
        -- A local path remote (`/tmp/repo`, `../other`) parses without a host.
        -- Handing that `nil` to `ssh -ttG` used to surface ssh's usage text as
        -- the error message, so the guard has to answer before ssh runs.
        local actual, err = git.resolve_host(nil, cwd)
        print(
          string.format("resolve_host(nil):%s, err:%s\n", vim.inspect(actual), vim.inspect(err))
        )
        assert_true(actual == nil)
        assert_eq(type(err), "string")
        assert_true(err:find("no host", 1, true) ~= nil, "unexpected error: " .. err)
        -- An empty host means the same thing as a missing one.
        local empty_actual, empty_err = git.resolve_host("", cwd)
        assert_true(empty_actual == nil)
        assert_eq(empty_err, err)
      end)
    end)
    it("get_default_branch", function()
      wait_async(function()
        local actual, err = git.get_default_branch("origin", cwd)
        print(string.format("default branch:%s, err:%s\n", vim.inspect(actual), vim.inspect(err)))
        if actual then
          assert_eq(type(actual), "string")
          assert_true(err == nil)
        else
          assert_eq(type(err), "string")
        end
      end)
    end)
    it("get_current_branch", function()
      wait_async(function()
        local actual, err = git.get_current_branch(cwd)
        print(string.format("current branch:%s, err:%s\n", vim.inspect(actual), vim.inspect(err)))
        if actual then
          assert_eq(type(actual), "string")
          assert_true(err == nil)
        else
          assert_eq(type(err), "string")
        end
      end)
    end)
    it("get_root", function()
      wait_async(function()
        local actual, err = git.get_root(cwd)
        print(string.format("get_root:%s, err:%s\n", vim.inspect(actual), vim.inspect(err)))
        if actual then
          assert_eq(type(actual), "string")
          assert_true(err == nil)
        else
          assert_eq(type(err), "string")
        end
      end)
    end)
    it("returns an error instead of raising when cwd does not exist", function()
      wait_async(function()
        local actual, err = git.get_root("/definitely-not-a-real-dir-xyz")
        print(
          string.format("get_root(bad cwd):%s, err:%s\n", vim.inspect(actual), vim.inspect(err))
        )
        assert_true(actual == nil)
        assert_eq(type(err), "string")
      end)
    end)
    it("distinguishes a spawn failure from a failing command", function()
      wait_async(function()
        -- A missing cwd makes vim.system raise before the command ever runs.
        local root, spawn_err = git.get_root("/definitely-not-a-real-dir-xyz")
        assert_true(root == nil)
        assert_eq(type(spawn_err), "string")
        assert_true(string.find(spawn_err, "ENOENT", 1, true) ~= nil)

        local result = git.GitResult:new()
        assert_eq(result.code, 0)
        assert_true(result:ok())
        assert_false(result:spawn_failed())

        -- A real exit status must never look like a spawn failure. `255` and
        -- `-1` are what a plainly failed command reports.
        for _, code in ipairs({ 1, 128, 255, -1 }) do
          local failed = git.GitResult:new()
          failed.code = code
          assert_false(failed:ok())
          assert_false(failed:spawn_failed())
        end

        local spawn_failed = git.GitResult:new()
        spawn_failed.code = git.GitResult.SPAWN_FAILED
        assert_false(spawn_failed:ok())
        assert_true(spawn_failed:spawn_failed())

        -- The sentinel is INT32_MIN, far outside the exit-status range shells
        -- produce, and exactly representable as a Lua number.
        assert_eq(git.GitResult.SPAWN_FAILED, -2147483648)
        assert_true(git.GitResult.SPAWN_FAILED < 0)
        assert_true(git.GitResult.SPAWN_FAILED ~= -1)
        assert_eq(tonumber(tostring(git.GitResult.SPAWN_FAILED)), -2147483648)
        assert_eq(tonumber(string.format("%d", git.GitResult.SPAWN_FAILED)), -2147483648)
      end)
    end)
    it("silent_failed covers a failing command and an empty success", function()
      wait_async(function()
        -- Succeeded, but printed nothing: there is no value to hand back.
        local silent = git.GitResult:new()
        assert_eq(silent.code, 0)
        assert_true(silent:ok())
        assert_true(silent:silent_failed())

        -- Succeeded with output: usable.
        local ok = git.GitResult:new()
        ok.stdout = { "some-value" }
        assert_true(ok:ok())
        assert_false(ok:silent_failed())

        -- Failed, with or without output: unusable.
        for _, code in ipairs({ 1, 128, 255, git.GitResult.SPAWN_FAILED }) do
          local failed = git.GitResult:new()
          failed.code = code
          failed.stdout = { "stale output" }
          assert_false(failed:ok())
          assert_true(failed:silent_failed())
        end

        -- `git cat-file -e` reports success by exiting 0 without printing
        -- anything, so it must keep checking ok() alone; silent_failed() would
        -- turn every successful probe into a failure.
        local probe = git.GitResult:new()
        assert_true(probe:ok())
        assert_true(probe:silent_failed())
        local exists, probe_err =
          git.is_file_in_rev("lua/gitlinker/git.lua", "HEAD", vim.fn.getcwd())
        assert_true(exists)
        assert_true(probe_err == nil)
      end)
    end)
  end)

  describe("[get_default_branch]", function()
    --- @type string
    local repo

    --- Create a repository whose remote-tracking HEAD is a symref to
    --- `remote`/`branch`, the shape `git clone` leaves behind.
    --- @param remote string  the remote name, which git allows to hold a `/`.
    --- @param branch string  the branch name, which commonly holds a `/`.
    local function make_repo(remote, branch)
      repo = vim.fn.tempname()
      vim.fn.mkdir(repo, "p")
      sh({ "git", "init", "--quiet", "-b", "main", repo })
      sh({ "git", "-C", repo, "config", "user.email", "test@example.com" })
      sh({ "git", "-C", repo, "config", "user.name", "test" })
      sh({ "git", "-C", repo, "config", "commit.gpgsign", "false" })
      sh({ "git", "-C", repo, "commit", "--quiet", "--allow-empty", "--message", "init" })
      sh({ "git", "-C", repo, "remote", "add", remote, "https://github.com/acme/demo.git" })
      local ref = string.format("refs/remotes/%s/%s", remote, branch)
      sh({ "git", "-C", repo, "update-ref", ref, "HEAD" })
      sh({
        "git",
        "-C",
        repo,
        "symbolic-ref",
        string.format("refs/remotes/%s/HEAD", remote),
        ref,
      })
    end

    after_each(function()
      if repo then
        vim.fn.delete(repo, "rf")
        repo = nil
      end
    end)

    it("keeps a branch name that contains a slash", function()
      make_repo("origin", "release/v5")
      wait_async(function()
        -- `git rev-parse --abbrev-ref origin/HEAD` prints `origin/release/v5`.
        -- Splitting that on `/` and taking the last piece returned `v5`, which
        -- built a link to a branch that does not exist.
        local actual, err = git.get_default_branch("origin", repo)
        assert_eq(actual, "release/v5")
        assert_true(err == nil)
      end)
    end)

    it("keeps a remote name that contains a slash", function()
      make_repo("team/up", "release/v5")
      wait_async(function()
        -- The printed ref is `team/up/release/v5`. Only stripping the whole
        -- remote name leaves `release/v5` behind; splitting on `/` would lose
        -- the remote as well as the first half of the branch.
        local actual, err = git.get_default_branch("team/up", repo)
        assert_eq(actual, "release/v5")
        assert_true(err == nil)
      end)
    end)

    it("hands back the output untouched when it names no remote branch", function()
      make_repo("origin", "release/v5")
      sh({ "git", "-C", repo, "tag", "v1" })
      sh({
        "git",
        "-C",
        repo,
        "symbolic-ref",
        "refs/remotes/origin/HEAD",
        "refs/tags/v1",
      })
      wait_async(function()
        -- A symref pointing outside the remote is printed bare, as `v1`. That
        -- is not prefixed with `origin/`, so it must not be cut to an empty
        -- string either.
        local actual, err = git.get_default_branch("origin", repo)
        assert_eq(actual, "v1")
        assert_true(err == nil)
      end)
    end)
  end)

  describe("[get_closest_remote_compatible_rev]", function()
    --- @type string
    local repo

    --- Create a repository with one commit and the given remotes, then mark
    --- `HEAD` as tracked by every entry of `tracked` (`"<remote>/<branch>"`).
    --- The commits fetched from a remote are the only thing the compatibility
    --- check looks at, so `tracked` decides which revs it may hand back.
    --- @param remotes string[]
    --- @param tracked string[]
    local function make_repo(remotes, tracked)
      repo = vim.fn.tempname()
      vim.fn.mkdir(repo, "p")
      sh({ "git", "init", "--quiet", "-b", "main", repo })
      sh({ "git", "-C", repo, "config", "user.email", "test@example.com" })
      sh({ "git", "-C", repo, "config", "user.name", "test" })
      sh({ "git", "-C", repo, "config", "commit.gpgsign", "false" })
      sh({ "git", "-C", repo, "commit", "--quiet", "--allow-empty", "--message", "init" })
      for _, remote in ipairs(remotes) do
        sh({ "git", "-C", repo, "remote", "add", remote, "https://github.com/acme/demo.git" })
      end
      for _, ref in ipairs(tracked) do
        sh({ "git", "-C", repo, "update-ref", "refs/remotes/" .. ref, "HEAD" })
      end
    end

    --- Create a repository with `count` commits on `main`, an `origin` remote,
    --- and `refs/remotes/origin/main` pointing at `HEAD~distance`.
    --- `git remote add` also writes the fetch refspec, which is what turns the
    --- compatibility check from a pass-through into a real reachability test.
    --- @param count integer
    --- @param distance integer  `0` means the remote already has `HEAD`.
    local function make_linear_repo(count, distance)
      repo = vim.fn.tempname()
      vim.fn.mkdir(repo, "p")
      sh({ "git", "init", "--quiet", "-b", "main", repo })
      sh({ "git", "-C", repo, "config", "user.email", "test@example.com" })
      sh({ "git", "-C", repo, "config", "user.name", "test" })
      sh({ "git", "-C", repo, "config", "commit.gpgsign", "false" })
      for i = 1, count do
        sh({ "git", "-C", repo, "commit", "--quiet", "--allow-empty", "--message", "c" .. i })
      end
      sh({ "git", "-C", repo, "remote", "add", "origin", "https://github.com/acme/demo.git" })
      local tracked = distance == 0 and "HEAD" or ("HEAD~" .. distance)
      sh({ "git", "-C", repo, "update-ref", "refs/remotes/origin/main", tracked })
    end

    --- `vim.fn.system` is off limits inside `wait_async` (fast event context),
    --- so expected revisions have to be resolved before entering it.
    --- @param revspec string
    --- @return string
    local function rev_of(revspec)
      local out = vim.fn.system({ "git", "-C", repo, "rev-parse", revspec .. "^{commit}" })
      assert_eq(vim.v.shell_error, 0, revspec .. " => " .. tostring(out))
      return vim.trim(out)
    end

    after_each(function()
      if repo then
        vim.fn.delete(repo, "rf")
        repo = nil
      end
    end)

    it("hands back a rev that the remote really tracks", function()
      make_repo({ "origin" }, { "origin/main" })
      wait_async(function()
        local head, head_err = git._get_rev("HEAD", repo)
        assert_true(head ~= nil, "this test needs a commit: " .. tostring(head_err))
        local actual, err = git.get_closest_remote_compatible_rev("origin", repo)
        assert_eq(actual, head)
        assert_true(err == nil)
      end)
    end)

    it("does not let a remote name match the prefix of another one", function()
      make_repo({ "ori", "origin" }, { "origin/main" })
      wait_async(function()
        -- `git branch --remotes` prints `refs/remotes/origin/main`, which holds
        -- the substring `ori`. Matching the remote as an unanchored Lua pattern
        -- treated that as "`ori` tracks this commit" and linked a rev the
        -- remote does not have.
        local actual, err = git.get_closest_remote_compatible_rev("ori", repo)
        assert_true(actual == nil)
        assert_eq(type(err), "string")
      end)
    end)

    it("treats the pattern characters of a remote name literally", function()
      make_repo({ "o+", "origin" }, { "origin/main" })
      wait_async(function()
        -- `o+` is a Lua pattern matching runs of `o`, so `origin/main` used to
        -- satisfy it as well.
        local actual, err = git.get_closest_remote_compatible_rev("o+", repo)
        assert_true(actual == nil)
        assert_eq(type(err), "string")
      end)
    end)

    it("refuses a remote name that does not exist", function()
      make_repo({ "origin" }, { "origin/main" })
      wait_async(function()
        -- `git config remote.zzz.fetch` exits 1 whether the key is absent from
        -- an existing remote or the remote itself is missing. Reading that as
        -- "no fetch refspec configured" used to let every candidate through,
        -- so the check handed back the HEAD rev for a remote it never asked.
        local actual, err = git.get_closest_remote_compatible_rev("zzz", repo)
        assert_true(actual == nil)
        assert_true(
          type(err) == "string" and err:find("does not exist", 1, true) ~= nil,
          "unexpected error: " .. vim.inspect(err)
        )
      end)
    end)

    it("keeps the check strict when the commit is not in the remote yet", function()
      -- A remote with a fetch refspec configured, but none of its branches
      -- pointing at `HEAD`: the conservative branch must not fall back to the
      -- local history, otherwise every commit would get a 404 permalink.
      make_repo({ "origin" }, {})
      wait_async(function()
        local actual, err = git.get_closest_remote_compatible_rev("origin", repo)
        assert_true(actual == nil)
        assert_true(
          type(err) == "string" and err:find("failed to get closest revision", 1, true) ~= nil,
          "unexpected error: " .. vim.inspect(err)
        )
      end)
    end)

    it("finds the rev of a remote whose name holds pattern characters", function()
      make_repo({ "o+", "origin" }, { "o+/main", "origin/main" })
      wait_async(function()
        local head, head_err = git._get_rev("HEAD", repo)
        assert_true(head ~= nil, "this test needs a commit: " .. tostring(head_err))
        local actual, err = git.get_closest_remote_compatible_rev("o+", repo)
        assert_eq(actual, head)
        assert_true(err == nil)
      end)
    end)

    it("walks back to the newest commit the remote has", function()
      -- The old implementation probed `HEAD`, `HEAD~1` .. `HEAD~50` with one
      -- `git branch --contains` each; this covers the middle of that range.
      make_linear_repo(20, 7)
      local expected = rev_of("HEAD~7")
      wait_async(function()
        local actual, err = git.get_closest_remote_compatible_rev("origin", repo)
        assert_eq(actual, expected)
        assert_true(err == nil)
      end)
    end)

    it("finds the deepest commit still within the search window", function()
      make_linear_repo(60, 50)
      local expected = rev_of("HEAD~50")
      wait_async(function()
        local actual, err = git.get_closest_remote_compatible_rev("origin", repo)
        assert_eq(actual, expected)
        assert_true(err == nil)
      end)
    end)

    it("gives up once the remote is further away than the search window", function()
      make_linear_repo(60, 51)
      wait_async(function()
        -- No `refs/remotes/origin/main`..`HEAD~50` overlap, and there is no
        -- `origin` ref to fall back to, so the search must report a failure
        -- instead of linking an arbitrary revision.
        local actual, err = git.get_closest_remote_compatible_rev("origin", repo)
        assert_true(actual == nil)
        assert_true(
          type(err) == "string" and err:find("failed to get closest revision", 1, true) ~= nil,
          "unexpected error: " .. vim.inspect(err)
        )
      end)
    end)

    it("ignores a merged branch tip that the remote also has", function()
      -- `--boundary` lists the parents of merged-in branches too, and their
      -- order is unspecified: only the first parent of a walked commit is the
      -- answer. Here the remote has the side branch tip but not `HEAD`'s
      -- ancestry, so returning the merged tip would link the wrong commit.
      repo = vim.fn.tempname()
      vim.fn.mkdir(repo, "p")
      sh({ "git", "init", "--quiet", "-b", "main", repo })
      sh({ "git", "-C", repo, "config", "user.email", "test@example.com" })
      sh({ "git", "-C", repo, "config", "user.name", "test" })
      sh({ "git", "-C", repo, "config", "commit.gpgsign", "false" })
      for i = 1, 6 do
        sh({ "git", "-C", repo, "commit", "--quiet", "--allow-empty", "--message", "c" .. i })
      end
      sh({ "git", "-C", repo, "checkout", "--quiet", "-b", "side", "HEAD~2" })
      for i = 1, 2 do
        sh({ "git", "-C", repo, "commit", "--quiet", "--allow-empty", "--message", "s" .. i })
      end
      local side_tip = rev_of("HEAD")
      sh({ "git", "-C", repo, "checkout", "--quiet", "main" })
      sh({ "git", "-C", repo, "merge", "--quiet", "--no-ff", "--message", "merge", "side" })
      sh({ "git", "-C", repo, "remote", "add", "origin", "https://github.com/acme/demo.git" })
      sh({ "git", "-C", repo, "update-ref", "refs/remotes/origin/side", side_tip })
      -- `c4`, the commit the side branch was cut from: it is the first parent
      -- of a walked commit, unlike the merged tip which `--boundary` also
      -- reports.
      local expected = rev_of("HEAD~3")
      wait_async(function()
        local actual, err = git.get_closest_remote_compatible_rev("origin", repo)
        assert_eq(actual, expected)
        assert_true(err == nil)
      end)
    end)
  end)

  describe("[get_branch_remote]", function()
    --- @type string
    local repo

    --- What the stubbed picker answers, and the prompts it was handed.
    --- @type integer
    local answer
    --- @type string[][]
    local prompts

    --- @type fun(prompt:string[]):integer
    local saved_inputlist

    --- Create a repository with one commit and the given remotes.
    --- @param remotes string[]
    local function make_repo(remotes)
      repo = vim.fn.tempname()
      vim.fn.mkdir(repo, "p")
      sh({ "git", "init", "--quiet", "-b", "main", repo })
      sh({ "git", "-C", repo, "config", "user.email", "test@example.com" })
      sh({ "git", "-C", repo, "config", "user.name", "test" })
      sh({ "git", "-C", repo, "config", "commit.gpgsign", "false" })
      sh({ "git", "-C", repo, "commit", "--quiet", "--allow-empty", "--message", "init" })
      for _, remote in ipairs(remotes) do
        sh({ "git", "-C", repo, "remote", "add", remote, "https://github.com/acme/demo.git" })
      end
    end

    before_each(function()
      answer = 1
      prompts = {}
      -- The picker blocks on a real keystroke; answer for it instead, and keep
      -- the prompt so a case can check what the user was offered.
      saved_inputlist = vim.fn.inputlist
      vim.fn.inputlist = function(prompt)
        table.insert(prompts, prompt)
        return answer
      end
    end)

    after_each(function()
      vim.fn.inputlist = saved_inputlist
      if repo then
        vim.fn.delete(repo, "rf")
        repo = nil
      end
    end)

    it("hands back the only remote without asking", function()
      make_repo({ "origin" })
      wait_async(function()
        local actual, err = git.get_branch_remote(repo)
        assert_eq(actual, "origin")
        assert_true(err == nil)
        assert_eq(#prompts, 0)
      end)
    end)

    it("asks which remote to use when there is more than one", function()
      make_repo({ "origin", "upstream" })
      answer = 2
      wait_async(function()
        local actual, err = git.get_branch_remote(repo)
        assert_eq(actual, "upstream")
        assert_true(err == nil)
        assert_eq(#prompts, 1)
        -- The list shows what each index stands for: a bare index would make
        -- the user pick blind.
        local prompt = table.concat(prompts[1], "\n")
        assert_true(prompt:find("1. origin (https://github.com/acme/demo.git)", 1, true) ~= nil)
        assert_true(prompt:find("2. upstream (https://github.com/acme/demo.git)", 1, true) ~= nil)
      end)
    end)

    it("reports a cancelled picker", function()
      make_repo({ "origin", "upstream" })
      answer = 0
      wait_async(function()
        local actual, err = git.get_branch_remote(repo)
        assert_true(actual == nil)
        assert_eq(type(err), "string")
        assert_true(err:find("user cancelled", 1, true) ~= nil, "unexpected error: " .. err)
      end)
    end)

    it("reports a repository without any remote", function()
      make_repo({})
      wait_async(function()
        local actual, err = git.get_branch_remote(repo)
        assert_true(actual == nil)
        assert_eq(type(err), "string")
        assert_eq(#prompts, 0)
      end)
    end)
  end)
end)
