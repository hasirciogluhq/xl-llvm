# xl-llvm

An LLVM library for [xlang](https://github.com/hasirciogluhq/xlang), written in xlang. Build modules, functions and instructions with `Context`, `Module`, `Function` and `Builder` calls, and print the result as LLVM IR.

**Status: empty package.** The design is in [PLAN.md](PLAN.md); supported features are listed in [FEATURES.md](FEATURES.md).

## Install

```
xl install github.com/hasirciogluhq/xl-llvm
```

```
import ... from "github.com/hasirciogluhq/xl-llvm"
```

## Tests

Unit tests are platform independent; e2e tests are platform related. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[Apache License 2.0](LICENSE).
