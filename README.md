# xl-llvm

An LLVM library for [xlang](https://github.com/hasirciogluhq/xlang), written in xlang. Build modules, functions and instructions with `Context`, `Module`, `Function` and `Builder` calls, and print the result as LLVM IR text. No libLLVM and no C++ runtime: the package is plain `.xl` source.

```
from "std" import String, Vec, Result, println
import * from "xl-llvm"

@entry fn main() -> i32 {
    local ctx: Context = Context()
    local m: Module = Module(&ctx, String("main"))
    setTarget(&m, hostTriple())                        // triple and data layout
    local f: Function = m.addFunction(String("main"), ctx.fnType(ctx.int32(), Vec<Type>()))
    local b: Builder = Builder(&ctx)
    b.setInsertPoint(f.addBlock(String("entry")))
    b.ret(ctx.constInt(ctx.int32(), 42))
    local text: Result<String, String> = m.print()     // the first error recorded while building, or the .ll text
    switch text {
        case Result.Ok(s) { println(&s) }
        case Result.Err(e) { println(&e) }
    }
    return 0
}
```

## Layers

| Folder | Contents | Needs |
|---|---|---|
| `ir/` | `Context`, types, constants, values, `Module`, `Function`, `Block`, instructions as data | nothing |
| `builder/` | `Builder`: insertion point, instruction creation, operand type checks | nothing |
| `printer/` | the only code that knows the `.ll` syntax: numbering, name escaping, output | nothing |
| `target/` | triple parser, data layout table, host triple | nothing |
| `intrinsics/` | declarations of `llvm.trap`, `llvm.memcpy`, `llvm.memset` | nothing |
| `tools/` | `Tools`: runs `opt` (verify, `-O<n>`), `llvm-as` (bitcode), `llc` (object, assembly) | LLVM 18 or newer on `PATH` |

Everything except `tools/` works with no LLVM installed. The output is deterministic: the same calls give byte-identical text. A builder call that fails a check (operand types, `call` arguments, `ret`, a terminator per block) records the first error; `print` returns it. Supported features and their tests are in [FEATURES.md](FEATURES.md); the design is in [PLAN.md](PLAN.md).

## Install

```
xl install github.com/hasirciogluhq/xl-llvm
```

```
import * from "xl-llvm"
```

## Tests

Unit tests are platform independent (`test/unit/run.sh`); e2e tests run LLVM, link and execute the result (`test/e2e/run.sh`); `test/features.sh` checks the feature table against the tests. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[Apache License 2.0](LICENSE).
