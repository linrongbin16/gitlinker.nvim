# Changelog

## [4.12.1](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.12.0...v4.12.1) (2024-03-18)


### Bug Fixes

* **url:** fix url encoding issue ([#226](https://github.com/linrongbin16/gitlinker.nvim/issues/226)) ([4b80c8b](https://github.com/linrongbin16/gitlinker.nvim/commit/4b80c8b067961783e645face5a57a2c20c23f4ed))

## [4.12.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.11.0...v4.12.0) (2024-03-09)


### Features

* **router:** add 'current_branch' router ([#220](https://github.com/linrongbin16/gitlinker.nvim/issues/220)) ([38ac7df](https://github.com/linrongbin16/gitlinker.nvim/commit/38ac7dfde273fd9342a88c4a0d523708d15e409c))

## [4.11.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.10.0...v4.11.0) (2024-03-07)


### Features

* **api:** add 'link' api ([#215](https://github.com/linrongbin16/gitlinker.nvim/issues/215)) ([46dcc5d](https://github.com/linrongbin16/gitlinker.nvim/commit/46dcc5d86929426761c442437432f4a8bdba16ae))

## [4.10.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.9.1...v4.10.0) (2024-02-26)


### Features

* **router:** add 'default_branch' router type ([#207](https://github.com/linrongbin16/gitlinker.nvim/issues/207)) ([7fbefed](https://github.com/linrongbin16/gitlinker.nvim/commit/7fbefed2a723553a67ee9d7d6f56289b43621600))

## [4.9.1](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.9.0...v4.9.1) (2024-01-08)


### Bug Fixes

* **parsing:** fix git url parsing ([#195](https://github.com/linrongbin16/gitlinker.nvim/issues/195)) ([ab44bb7](https://github.com/linrongbin16/gitlinker.nvim/commit/ab44bb7eb3174d963b0ae2224a685f322638c8e6))

## [4.9.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.8.3...v4.9.0) (2024-01-04)


### Features

* make link operation non-blocking ([#183](https://github.com/linrongbin16/gitlinker.nvim/issues/183)) ([a1f4153](https://github.com/linrongbin16/gitlinker.nvim/commit/a1f4153dfe11ded6542b6af21c8e6a506d727440))


### Bug Fixes

* **ci:** fix ci pipeline errors ([#184](https://github.com/linrongbin16/gitlinker.nvim/issues/184)) ([13bd6b1](https://github.com/linrongbin16/gitlinker.nvim/commit/13bd6b1babeeca5dbb82dcb74010fadaf9ecf763))

## [4.8.3](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.8.2...v4.8.3) (2023-12-14)


### Performance Improvements

* **logger:** migrate logger to commons.nvim ([#175](https://github.com/linrongbin16/gitlinker.nvim/issues/175)) ([ea27d70](https://github.com/linrongbin16/gitlinker.nvim/commit/ea27d7014242678307e469419e91dc35c57104ea))

## [4.8.2](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.8.1...v4.8.2) (2023-12-14)


### Bug Fixes

* **windows:** fix file path for Windows ([#173](https://github.com/linrongbin16/gitlinker.nvim/issues/173)) ([3f8cfa5](https://github.com/linrongbin16/gitlinker.nvim/commit/3f8cfa557d9808cb7d1d2804cdf09a6b484a0dc1))


### Performance Improvements

* **refactor:** use 'commons.nvim' library ([#173](https://github.com/linrongbin16/gitlinker.nvim/issues/173)) ([3f8cfa5](https://github.com/linrongbin16/gitlinker.nvim/commit/3f8cfa557d9808cb7d1d2804cdf09a6b484a0dc1))

## [4.8.1](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.8.0...v4.8.1) (2023-12-08)


### Performance Improvements

* **ci:** upload luarocks package ([d7341e6](https://github.com/linrongbin16/gitlinker.nvim/commit/d7341e6024e4591f018eea9aa110978449fbb174))

## [4.8.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.7.1...v4.8.0) (2023-12-01)


### Features

* **command:** support command args complete suggestions ([bbab7ba](https://github.com/linrongbin16/gitlinker.nvim/commit/bbab7bae3f0b1914d405eef1a498743b9c88d163))
* **remote:** support multiple remotes (origin/upstream) ([#166](https://github.com/linrongbin16/gitlinker.nvim/issues/166)) ([bbab7ba](https://github.com/linrongbin16/gitlinker.nvim/commit/bbab7bae3f0b1914d405eef1a498743b9c88d163))

## [4.7.1](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.7.0...v4.7.1) (2023-11-28)


### Bug Fixes

* **default_branch:** use real-time remote ([#163](https://github.com/linrongbin16/gitlinker.nvim/issues/163)) ([15b0d41](https://github.com/linrongbin16/gitlinker.nvim/commit/15b0d414c136e3475629ea1c7d8fa98b615915b5))

## [4.7.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.6.0...v4.7.0) (2023-11-27)


### Features

* **branch:** provide `DEFAULT_BRANCH` and `CURRENT_BRANCH` components ([#159](https://github.com/linrongbin16/gitlinker.nvim/issues/159)) ([7007c7a](https://github.com/linrongbin16/gitlinker.nvim/commit/7007c7a5b5427b510cd4bbfdffb5334654441d4d))


### Bug Fixes

* **config:** fix merged user routers configs ([#158](https://github.com/linrongbin16/gitlinker.nvim/issues/158)) ([3e33ba8](https://github.com/linrongbin16/gitlinker.nvim/commit/3e33ba845dc8d5ed22565c90b01650261c204303))


### Performance Improvements

* **routers:** always add '?display=source' for codeberg ([#156](https://github.com/linrongbin16/gitlinker.nvim/issues/156)) ([0a8925f](https://github.com/linrongbin16/gitlinker.nvim/commit/0a8925f6e85a0d355217f5dd00a8c307c99a46a5))
* **routers:** always add '?plain=1' for github ([#156](https://github.com/linrongbin16/gitlinker.nvim/issues/156)) ([0a8925f](https://github.com/linrongbin16/gitlinker.nvim/commit/0a8925f6e85a0d355217f5dd00a8c307c99a46a5))

## [4.6.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.5.0...v4.6.0) (2023-11-26)


### Features

* **config:** user router types ([#152](https://github.com/linrongbin16/gitlinker.nvim/issues/152)) ([8530e1a](https://github.com/linrongbin16/gitlinker.nvim/commit/8530e1a95da83560fbfddee01cdbe61e9673002e))


### Performance Improvements

* **gitweb:** correct parsing remote url! ([#154](https://github.com/linrongbin16/gitlinker.nvim/issues/154)) ([382b31e](https://github.com/linrongbin16/gitlinker.nvim/commit/382b31e63f09c3c1c45a663e5876ce98d7c87ad9))

## [4.5.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.4.0...v4.5.0) (2023-11-24)


### Features

* **parser:** support `git.samba.org/samba.git` ([d1d2482](https://github.com/linrongbin16/gitlinker.nvim/commit/d1d2482deef2eae6d7b1701707210a0b71d123e2))
* **routers:** support gitweb such as `git.samba.org` ([#149](https://github.com/linrongbin16/gitlinker.nvim/issues/149)) ([d1d2482](https://github.com/linrongbin16/gitlinker.nvim/commit/d1d2482deef2eae6d7b1701707210a0b71d123e2))
* **routers:** support prioritized matching list (undocumented hidden feature) ([d1d2482](https://github.com/linrongbin16/gitlinker.nvim/commit/d1d2482deef2eae6d7b1701707210a0b71d123e2))


### Performance Improvements

* **test:** improve unit tests to cover more use cases ([d1d2482](https://github.com/linrongbin16/gitlinker.nvim/commit/d1d2482deef2eae6d7b1701707210a0b71d123e2))

## [4.4.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.3.0...v4.4.0) (2023-11-23)


### Features

* **routers:** add `codeberg.org` router ([#147](https://github.com/linrongbin16/gitlinker.nvim/issues/147)) ([fb344ab](https://github.com/linrongbin16/gitlinker.nvim/commit/fb344abada764c198db15f80f645495e0a6f80e3))


### Performance Improvements

* **test:** improve test cases ([fb344ab](https://github.com/linrongbin16/gitlinker.nvim/commit/fb344abada764c198db15f80f645495e0a6f80e3))

## [4.3.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.2.0...v4.3.0) (2023-11-22)


### Features

* **bare/worktree:** only check remote branches if remote has 'fetch' config ([#143](https://github.com/linrongbin16/gitlinker.nvim/issues/143)) ([9352c3a](https://github.com/linrongbin16/gitlinker.nvim/commit/9352c3ab6c8dc14c60a980f06cdfc53ff87df686))

## [4.2.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.1.1...v4.2.0) (2023-11-18)


### Features

* **actions:** enable wslview ([#135](https://github.com/linrongbin16/gitlinker.nvim/issues/135)) ([ebb7a73](https://github.com/linrongbin16/gitlinker.nvim/commit/ebb7a7348e5865091ada4cfbf6647f8458c1af7e))

## [4.1.1](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.1.0...v4.1.1) (2023-11-17)


### Bug Fixes

* **parser:** support `ssh://git@git.xyz.abc/project/project.git` ([#132](https://github.com/linrongbin16/gitlinker.nvim/issues/132)) ([bf92aa8](https://github.com/linrongbin16/gitlinker.nvim/commit/bf92aa8a3eac0ccbeb4a219baaa08479f1239487))

## [4.1.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v4.0.0...v4.1.0) (2023-11-17)


### Features

* **url:** support url template ([#128](https://github.com/linrongbin16/gitlinker.nvim/issues/128)) ([48e1a2f](https://github.com/linrongbin16/gitlinker.nvim/commit/48e1a2f0a79105702b2093209888ffb25e143476))


### Bug Fixes

* **command:** fix command range in both manual enter & key mapping ([48e1a2f](https://github.com/linrongbin16/gitlinker.nvim/commit/48e1a2f0a79105702b2093209888ffb25e143476))

## [4.0.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v3.1.0...v4.0.0) (2023-11-17)


### ⚠ BREAKING CHANGES

* **mapping:** drop of default key mappings! ([#126](https://github.com/linrongbin16/gitlinker.nvim/issues/126))

### break

* **mapping:** drop of default key mappings! ([#126](https://github.com/linrongbin16/gitlinker.nvim/issues/126)) ([528c604](https://github.com/linrongbin16/gitlinker.nvim/commit/528c60460db81e7d8df649281a70e673d548a1d4))


### Bug Fixes

* **parser:** support `ssh://git@` protocol ([#124](https://github.com/linrongbin16/gitlinker.nvim/issues/124)) ([53c4efc](https://github.com/linrongbin16/gitlinker.nvim/commit/53c4efc6659b70f4cd4a854885d767f044e3640e))

## [3.1.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v3.0.0...v3.1.0) (2023-11-16)


### Features

* **command:** add `GitLink` ([#120](https://github.com/linrongbin16/gitlinker.nvim/issues/120)) ([065f5c9](https://github.com/linrongbin16/gitlinker.nvim/commit/065f5c9229bc65b844ba6824c9c5ebc4683aa815))


### Bug Fixes

* **spawn:** fix cannot use vimL function in uv loop error ([065f5c9](https://github.com/linrongbin16/gitlinker.nvim/commit/065f5c9229bc65b844ba6824c9c5ebc4683aa815))


### Performance Improvements

* **keys:** deprecate default key mappings ([065f5c9](https://github.com/linrongbin16/gitlinker.nvim/commit/065f5c9229bc65b844ba6824c9c5ebc4683aa815))
* **routers:** add placeholder to avoid loop call ([#121](https://github.com/linrongbin16/gitlinker.nvim/issues/121)) ([e605210](https://github.com/linrongbin16/gitlinker.nvim/commit/e605210941057849491cca4d7f44c0e09f363a69))

## [3.0.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v2.1.0...v3.0.0) (2023-11-16)


### ⚠ BREAKING CHANGES

* **router:** rename 'blob' router to 'browse' as a generic name
* **router:** merge 'src' router into 'browse' router
* **blame:** support more git hosts! ([#118](https://github.com/linrongbin16/gitlinker.nvim/issues/118))

### break

* **router:** merge 'src' router into 'browse' router ([c60618c](https://github.com/linrongbin16/gitlinker.nvim/commit/c60618c35adec9ef0d9e727ec1593d6d0f192ad7))
* **router:** rename 'blob' router to 'browse' as a generic name ([c60618c](https://github.com/linrongbin16/gitlinker.nvim/commit/c60618c35adec9ef0d9e727ec1593d6d0f192ad7))


### Features

* **blame:** support more git hosts! ([#118](https://github.com/linrongbin16/gitlinker.nvim/issues/118)) ([c60618c](https://github.com/linrongbin16/gitlinker.nvim/commit/c60618c35adec9ef0d9e727ec1593d6d0f192ad7))


### Bug Fixes

* **ssh:** fix NPE for windows ([c60618c](https://github.com/linrongbin16/gitlinker.nvim/commit/c60618c35adec9ef0d9e727ec1593d6d0f192ad7))

## [2.1.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v2.0.0...v2.1.0) (2023-11-15)


### Features

* **blame:** support `/blame` url ([#113](https://github.com/linrongbin16/gitlinker.nvim/issues/113)) ([39acdb7](https://github.com/linrongbin16/gitlinker.nvim/commit/39acdb7bb21d78dbbdf70c407aa057f058a4859a))

## [2.0.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v1.3.0...v2.0.0) (2023-11-15)


### ⚠ BREAKING CHANGES

* **routers:** use routers instead of lua patterns! ([#110](https://github.com/linrongbin16/gitlinker.nvim/issues/110))

### Features

* **alias host:** support git alias host via `ssh -ttG` ([c377f61](https://github.com/linrongbin16/gitlinker.nvim/commit/c377f613a1d0a1fb74f40d9832f729eaddb6fa9f))
* **routers:** use routers instead of lua patterns! ([#110](https://github.com/linrongbin16/gitlinker.nvim/issues/110)) ([c377f61](https://github.com/linrongbin16/gitlinker.nvim/commit/c377f613a1d0a1fb74f40d9832f729eaddb6fa9f))

## [1.3.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v1.2.0...v1.3.0) (2023-11-13)


### Features

* **rules:** add 'override_rules' to override default 'pattern_rules' ([#99](https://github.com/linrongbin16/gitlinker.nvim/issues/99)) ([87f10a7](https://github.com/linrongbin16/gitlinker.nvim/commit/87f10a75751502af5e8abb956d9c165697f09ba2))

## [1.2.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v1.1.1...v1.2.0) (2023-11-13)


### Features

* **markdown:** add '?plain=1' for markdown files to link to code instead of preview ([#94](https://github.com/linrongbin16/gitlinker.nvim/issues/94)) ([cf57151](https://github.com/linrongbin16/gitlinker.nvim/commit/cf5715198bf484657aecaf6e370d8ed84f8d7b0f))


### Performance Improvements

* **rules:** fallback to pattern rules if custom_rules not hit ([cf57151](https://github.com/linrongbin16/gitlinker.nvim/commit/cf5715198bf484657aecaf6e370d8ed84f8d7b0f))

## [1.1.1](https://github.com/linrongbin16/gitlinker.nvim/compare/v1.1.0...v1.1.1) (2023-11-13)


### Performance Improvements

* **rules:** easier pattern rules schema ([#92](https://github.com/linrongbin16/gitlinker.nvim/issues/92)) ([a43e326](https://github.com/linrongbin16/gitlinker.nvim/commit/a43e326cb04dcd03f8d78ce405051e898272e169))

## [1.1.0](https://github.com/linrongbin16/gitlinker.nvim/compare/v1.0.2...v1.1.0) (2023-11-13)


### Features

* add highlighting of selected region ([#88](https://github.com/linrongbin16/gitlinker.nvim/issues/88)) ([2e97768](https://github.com/linrongbin16/gitlinker.nvim/commit/2e97768594dd3b540eaf77761f3274dfc564bc94))


### Performance Improvements

* **highlight:** allow customize highlight group 'NvimGitLinkerHighlightTextObject' ([#90](https://github.com/linrongbin16/gitlinker.nvim/issues/90)) ([7ac8301](https://github.com/linrongbin16/gitlinker.nvim/commit/7ac8301423e87f1daadfd171e08acfb630a05709))

## [1.0.2](https://github.com/linrongbin16/gitlinker.nvim/compare/v1.0.1...v1.0.2) (2023-10-23)


### Performance Improvements

* improve unit test coverage ([#85](https://github.com/linrongbin16/gitlinker.nvim/issues/85)) ([d7a8d69](https://github.com/linrongbin16/gitlinker.nvim/commit/d7a8d693b87dc3331e1934b5e46c4e24302c3c68))
* restructure code & improve unit tests coverage ([#81](https://github.com/linrongbin16/gitlinker.nvim/issues/81)) ([29c4edd](https://github.com/linrongbin16/gitlinker.nvim/commit/29c4edd632701ad83679ff3f5ab0778fcd769831))

## [1.0.1](https://github.com/linrongbin16/gitlinker.nvim/compare/v1.0.0...v1.0.1) (2023-10-20)


### Bug Fixes

* **path:** resolve symlink in Windows ([#75](https://github.com/linrongbin16/gitlinker.nvim/issues/75)) ([b292a4f](https://github.com/linrongbin16/gitlinker.nvim/commit/b292a4f78a5c76019a7b1a7c2af31fef5fd0d23d))


### Performance Improvements

* **logger:** reduce logs ([#77](https://github.com/linrongbin16/gitlinker.nvim/issues/77)) ([e055155](https://github.com/linrongbin16/gitlinker.nvim/commit/e05515576c3da05f73e227076471042f9b6b2cf5))

## 1.0.0 (2023-10-20)


### ⚠ BREAKING CHANGES

* **buffer.get_range:** visual mode gets current

### Features

* Accept verbatim host matches alongside patterns ([0443a35](https://github.com/linrongbin16/gitlinker.nvim/commit/0443a353d4c2425a0d7b9be00a6ef18c5b69984a))
* add contribution ([#34](https://github.com/linrongbin16/gitlinker.nvim/issues/34)) ([135d990](https://github.com/linrongbin16/gitlinker.nvim/commit/135d9905b915d96fa3f5101f3ea6480ef5852fcb))
* add plugin name to logger ([#39](https://github.com/linrongbin16/gitlinker.nvim/issues/39)) ([9927cb6](https://github.com/linrongbin16/gitlinker.nvim/commit/9927cb65667d324a5506173d12be8c05decf0e28))
* add utils for job result ([#20](https://github.com/linrongbin16/gitlinker.nvim/issues/20)) ([a5da862](https://github.com/linrongbin16/gitlinker.nvim/commit/a5da862a3e9a88c24003e7ab737659771ec02de4))
* allow file changes with warning ([37e5b2b](https://github.com/linrongbin16/gitlinker.nvim/commit/37e5b2be61bfe8dfc7e21939bd029034311a5349)), closes [#43](https://github.com/linrongbin16/gitlinker.nvim/issues/43)
* ci & ut ([#67](https://github.com/linrongbin16/gitlinker.nvim/issues/67)) ([730cdff](https://github.com/linrongbin16/gitlinker.nvim/commit/730cdffb29d58a366a27403dc4986388d3a5f544))
* drop plenary ([#58](https://github.com/linrongbin16/gitlinker.nvim/issues/58)) ([593ab1b](https://github.com/linrongbin16/gitlinker.nvim/commit/593ab1be494ee13c8bc080c846df60a61f12925c))
* embed logger ([d4700b3](https://github.com/linrongbin16/gitlinker.nvim/commit/d4700b3609ed31829c0f425537aeeb7d7a5b21c5))
* generate repo's homepage ([6a59e9c](https://github.com/linrongbin16/gitlinker.nvim/commit/6a59e9ca450ba8c71f4e83918e8130905c316b62))
* optimize file in rev error message ([#21](https://github.com/linrongbin16/gitlinker.nvim/issues/21)) ([3735844](https://github.com/linrongbin16/gitlinker.nvim/commit/373584484b76a2bef9aa94617ae9792293117c30))
* optimize not in git root error ([#22](https://github.com/linrongbin16/gitlinker.nvim/issues/22)) ([b2b8c5b](https://github.com/linrongbin16/gitlinker.nvim/commit/b2b8c5b4a7a208c0461f132e741bbf5450b7661e))
* support command range ([#60](https://github.com/linrongbin16/gitlinker.nvim/issues/60)) ([2c7a0b0](https://github.com/linrongbin16/gitlinker.nvim/commit/2c7a0b077edc8dc06bde6467f23bd9fe4eb9ae04))
* support gitlab, update doc ([#40](https://github.com/linrongbin16/gitlinker.nvim/issues/40)) ([e6bc82d](https://github.com/linrongbin16/gitlinker.nvim/commit/e6bc82dea97189f6f2f8f2eeb06382a1c0cf2278))


### Bug Fixes

* 'plenary.path' on Windows ([#54](https://github.com/linrongbin16/gitlinker.nvim/issues/54)) ([565f186](https://github.com/linrongbin16/gitlinker.nvim/commit/565f186c187475a0041e10c6b3e04eb4bb9a979a))
* add ~ to the allowed repo path chars ([775c8d5](https://github.com/linrongbin16/gitlinker.nvim/commit/775c8d54c187c43bedd7f22941d039422bd67abd)), closes [#36](https://github.com/linrongbin16/gitlinker.nvim/issues/36)
* add missing return true ([fc72db9](https://github.com/linrongbin16/gitlinker.nvim/commit/fc72db97454496397148ec71ba5bdda1a3bbe9a4))
* allow url generation for changed files ([7a2d359](https://github.com/linrongbin16/gitlinker.nvim/commit/7a2d3596a8e61001a5c4c02dfa7c4be230bb0f0b)), closes [#21](https://github.com/linrongbin16/gitlinker.nvim/issues/21)
* **buffer.get_range:** visual mode gets current ([1c49ccb](https://github.com/linrongbin16/gitlinker.nvim/commit/1c49ccbbe76c562e85dfdcf1e6b70a6684cd7a3d))
* dash in repo name ([#42](https://github.com/linrongbin16/gitlinker.nvim/issues/42)) ([47c822f](https://github.com/linrongbin16/gitlinker.nvim/commit/47c822f9885c43cff5208246b536615e293209c7))
* decode space char before extracting repo path ([0af1fb2](https://github.com/linrongbin16/gitlinker.nvim/commit/0af1fb22a9d0661c3eeb7fdd2bba0d9d681b1186))
* do not error out on multiple remotes ([00cbf99](https://github.com/linrongbin16/gitlinker.nvim/commit/00cbf99d3669de52230eceeb4b0a6c49ea771b40))
* do not pick a remote arbitrarily ([3f29108](https://github.com/linrongbin16/gitlinker.nvim/commit/3f29108b014053a37e9a03f16e262e0dce63ed9c))
* Do not use host in patterns ([a9340a7](https://github.com/linrongbin16/gitlinker.nvim/commit/a9340a7a5592c977c730e918d1c584ef4798675f)), closes [#27](https://github.com/linrongbin16/gitlinker.nvim/issues/27)
* **doc:** `require` statments missing dot ([9201073](https://github.com/linrongbin16/gitlinker.nvim/commit/92010735592ba49679609a1760e99c6529b0e361))
* error when missing remote branch ([#18](https://github.com/linrongbin16/gitlinker.nvim/issues/18)) ([5b00559](https://github.com/linrongbin16/gitlinker.nvim/commit/5b00559e70a4a03490cd11c59f3df00866d589b9))
* extract port from remote uri ([b68d832](https://github.com/linrongbin16/gitlinker.nvim/commit/b68d832fd325ff4aa276f9e0e8519ca310a6881f)), closes [#12](https://github.com/linrongbin16/gitlinker.nvim/issues/12)
* fix logger name ([d3fce1a](https://github.com/linrongbin16/gitlinker.nvim/commit/d3fce1ab905b2a01059447510d1964284dff51f9))
* **hosts/gitlab:** add trailing `/` after project name ([7219b9d](https://github.com/linrongbin16/gitlinker.nvim/commit/7219b9ddd73f4fe1dc56ff0393d02d7048e5f727))
* **hosts:** fix error msg when host not found ([38938b2](https://github.com/linrongbin16/gitlinker.nvim/commit/38938b29e892868bbe316d9d4ed5951d1d80788e)), closes [#16](https://github.com/linrongbin16/gitlinker.nvim/issues/16)
* mapping customization ([#49](https://github.com/linrongbin16/gitlinker.nvim/issues/49)) ([29360ad](https://github.com/linrongbin16/gitlinker.nvim/commit/29360ad9d9b1aabfbe322adcaa2ec067eef002a8))
* mappings ([#51](https://github.com/linrongbin16/gitlinker.nvim/issues/51)) ([85794a7](https://github.com/linrongbin16/gitlinker.nvim/commit/85794a7a5d1dfaed7b5bab6165d291b06b729011))
* reverse target_host matching ([399bac3](https://github.com/linrongbin16/gitlinker.nvim/commit/399bac3242ffc1adb80cb8a17f149ff4a754ba53))
* set git root as cwd ([14c52db](https://github.com/linrongbin16/gitlinker.nvim/commit/14c52db7f91b2234a63d5f786256c35cb30539ed))
* support dashes in repository names ([#41](https://github.com/linrongbin16/gitlinker.nvim/issues/41)) ([80a6154](https://github.com/linrongbin16/gitlinker.nvim/commit/80a615489390cce1e9bf40698d1d8b0bd607782b))
* syntax error in lua for loop ([cc2e3d2](https://github.com/linrongbin16/gitlinker.nvim/commit/cc2e3d25c02d688ed577c7710bb812363a7cecbb))
* uri parsing (closes [#2](https://github.com/linrongbin16/gitlinker.nvim/issues/2)) ([f4fd8a7](https://github.com/linrongbin16/gitlinker.nvim/commit/f4fd8a7db9ba9a43fff2409ccc62ecbe93d2ba5f))
* use '&lt;cmd&gt;' instead of ':' for default mappings ([d28028b](https://github.com/linrongbin16/gitlinker.nvim/commit/d28028ba21e8be2d9f290ba69eb08f96a31fa769))
* visual lines ([#57](https://github.com/linrongbin16/gitlinker.nvim/issues/57)) ([b50ca53](https://github.com/linrongbin16/gitlinker.nvim/commit/b50ca53b666cf61facd0ebdd4767d02d2639f720))
* windows symlink ([#64](https://github.com/linrongbin16/gitlinker.nvim/issues/64)) ([bc1c680](https://github.com/linrongbin16/gitlinker.nvim/commit/bc1c6801b4771d6768c6ec6727d0e7669e6aac5f))


### Performance Improvements

* **git:** use 'uv.spawn' for command line IO ([#70](https://github.com/linrongbin16/gitlinker.nvim/issues/70)) ([35aebb7](https://github.com/linrongbin16/gitlinker.nvim/commit/35aebb7f4f8d30b7863742864a93cbe0224e8975))
* try remote branch first ([59ee024](https://github.com/linrongbin16/gitlinker.nvim/commit/59ee0244f8da0ddfe45850cde0e07d4ed448b0b7)), closes [#34](https://github.com/linrongbin16/gitlinker.nvim/issues/34)
