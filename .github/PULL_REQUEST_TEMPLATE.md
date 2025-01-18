## Test Platforms

- [ ] windows
- [ ] macOS
- [ ] linux

## Test Hosts

- [ ] Test on [github.com](https://github.com).
- [ ] Test on [gitlab.com](https://gitlab.com).
- [ ] Test on [bitbucket.org](https://bitbucket.org).
- [ ] Test on [codeberg.org](https://codeberg.org).
- [ ] Test on [git.samba.org](https://git.samba.org).

## Test Functions

- [ ] Use `GitLink(!)` to copy git link (or open in browser).
- [ ] Use `GitLink(!) blame` to copy the `/blame` link (or open in browser).
- [ ] Use `GitLink(!) default_branch` to open the `/main`/`/master` link in browser (or open in browser).
- [ ] Use `GitLink(!) current_branch` to open the current branch link in browser (or open in browser).
- [ ] Copy git link in a symlink directory of git repo.
- [ ] Copy git link in an un-pushed git branch, and receive an expected error.
- [ ] Copy git link in a pushed git branch but edited file, and receive a warning says the git link could be wrong.
- [ ] Copy git link with 'file' and 'rev' parameters.
