# xl-llvm

A light LLVM library for [xlang](https://github.com/hasirciogluhq/xlang), written in xlang. A compiler or any other tool calls its functions (context, module, function, builder) and the library generates LLVM IR text (`.ll`) behind them. It is a plain package: a directory of `.xl` source with `index.xl` at its root, versioned by git tags, installed with the xlang package manager. It links no LLVM library and needs no C++ runtime.

**Status: empty package.** The template, configuration and project files are in place; the design is in [PLAN.md](PLAN.md) and the feature table in [FEATURES.md](FEATURES.md). No API exists yet.

## Install

```
xlang package install github.com/hasirciogluhq/xl-llvm
```

This adds the newest stable release to `xlang.toml` and `xlang.lock` (`@v1.2.0` pins a tag). Then `import ... from "github.com/hasirciogluhq/xl-llvm"`. With the standalone compiler, pass the directory yourself: `xlc app.xl -M xl-llvm=<path to this repository>`, then `import ... from "xl-llvm"`. Releases are git tags (`vMAJOR.MINOR.PATCH`); the release workflow tests the tag, builds a program against the packed archive and publishes the archive with its checksum. See the package system in [xlang-docs](https://github.com/hasirciogluhq/xlang-docs) (`compiler/packages`).

## Layout

```
index.xl          public exports (empty for now)
xlang.toml        package manifest
FEATURES.md       one row per supported IR feature, with its unit and e2e test
PLAN.md           design and milestones
test/
  unit/           `*.test.xl`, platform independent: printed text compared with the expected `.ll`
  e2e/            platform related: LLVM tools, linking, running the result
  consume/        a program that imports the package; CI and the release build it against the sources and the archive
  features.sh     checks that FEATURES.md and the tests agree
.github/          CI and release workflows, and the script that installs the compiler
```

## Tests

Unit tests are platform independent and the bulk of the suite; e2e tests are platform related and run on every host in CI. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[Apache License 2.0](LICENSE).
