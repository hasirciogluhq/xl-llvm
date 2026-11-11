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

Everything except `tools/` works with no LLVM installed. The output is deterministic: the same calls give byte-identical text. A builder call that fails a check (operand types, `call` arguments, `ret`, a terminator per block) records the first error; `print` returns it. Supported features and their tests are in [FEATURES.md](FEATURES.md).

`ir/` also holds metadata (`Metadata`, nodes numbered by the printer) and `debug/` holds `DIBuilder` (compile unit, types, subprograms, variables, locations, `llvm.dbg.declare`).

## Design

- **Text IR, not the C++ API or LLVM-C.** Nothing to link: no libLLVM, no C++ runtime; the package is plain source. The module prints to a `String`, so every feature is unit-tested by comparing text and e2e-tested by running the LLVM tools on it. Costs: LLVM parses the text again, errors LLVM finds are reported late against a text line (so the `Builder` checks what it can itself), and the text syntax changes between LLVM versions (`printer/` is the only place that knows it).
- **Handles, no global state.** Types, values and metadata nodes are indices into tables of one `Context` (single-threaded; separate contexts can run in parallel). Types are uniqued structurally. Functions may be declared before they are defined and built in any order; the printer assigns `%0`, `%1`, ... and `!0`, `!1`, ... at print time (metadata by first use), so build order never changes the text. Output is deterministic: the same calls give byte-identical text.
- **Errors.** A builder call that fails a check records the first error, naming the call, and returns a harmless value; `Module.print` returns it as `Result`. The checks are operand types, `call` arguments, `phi` types, `ret`, one terminator per block and nothing after it. Dominance and use-before-definition are left to `opt -passes=verify` (`Tools.verify`).
- **Tools and LLVM version.** `opt`, `llc` and `llvm-as` are found on `PATH` or in a directory given to `Tools`; the e2e tests link with `clang` on the `.ll` file. LLVM 18 is the oldest supported release; CI runs 18 on Linux and the newest on macOS and Windows.
- **Data layout.** A table of the LLVM 18 strings for x86-64 and arm64 on Linux, macOS and Windows (MSVC) in `target/`; newer LLVM accepts them. Another triple prints no layout and LLVM fills in its own. Size and offset calculation is the caller's job.
- **API types.** Names, texts and lists are `String`, `*String` and `Vec<T>`; handles that need methods (`Function`, `Block`) are classes, plain handles (`Type`, `Value`, `Md`) are structs. The shorthands are `int1`..`int64`, `float32`, `float64` because `i32` and `f64` are type names in xlang.
- **Tests.** Every feature is a row in FEATURES.md and is done only with a unit test (platform independent: builds through the API and compares the printed text) and an e2e test (platform related: `opt -passes=verify`, `llc`, link, run, plus compile-only legs for six triples and a differential leg against `xlc`).

### Language gaps found while building it

For the language, not worked around: no way to iterate a `Vec` (`for x in v`; every loop is `for i in 0..v.length()` with `v.get(i)`), no `?` for `Result`, a payload bound by `switch` is a copy (so every kept `String` is cloned), a `switch` that returns in every arm still warns `W0701`, `Vec<T>` arguments are moved on use (a list needed twice is built twice), `f().x = v` evaluates `f()` twice, and `str`, `declare`, `local`, `global`, `from` cannot be used as method or variable names.

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
