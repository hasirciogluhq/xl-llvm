# xl-llvm: plan (draft for discussion)

## Goal
xl-llvm is the LLVM library of xlang: a pure `.xl` source package (no native files), installed with the package manager
(`xlang package install github.com/hasirciogluhq/xl-llvm`). Callers (the compiler or any other tool) build IR only by calling its
functions (`Context`, `Module`, `Function`, `Builder`, ...). They never write IR text. The library generates LLVM IR text (`.ll`) from
those calls through its printer and, when asked, hands that text to the LLVM tools to get `.bc`, `.o` or `.s`.

Purpose: a compiler written in xlang that does not depend on the C++ LLVM API or link libLLVM. Scope starts at exactly what `xlc` uses
today (see "Coverage floor") and grows only when a consumer needs more.

## Decision: text IR, not the C++ API or LLVM-C
- Nothing to link: no libLLVM, no C++ runtime. The package is plain source.
- The printed module is a `String`, so every feature is unit-tested by comparing text and e2e-tested by running the LLVM tools on it.
- Costs, accepted: LLVM parses the text again (measurable at `-O0`, small next to optimization and code generation at `-O1` and above);
  errors LLVM finds are reported late against a text line, so the `Builder` checks what it can itself (see "Builder checks"); the text
  syntax changes between LLVM versions, so one version is pinned.

## Layers
```
ir/        Context, types, constants, values, Module, Function, Block, globals, metadata   (pure data, no OS)
builder/   Builder: insertion point, instruction creation, type checks                    (pure)
printer/   the only code that knows the .ll syntax: numbering, name escaping, output      (pure; writes to a std/io writer)
tools/     runs llvm-as / opt / llc (or clang) on a .ll file: verify, .bc, .o, .s       (platform related, std/os/process)
```
Everything except `tools/` works with no LLVM installed. If LLVM changes its text syntax, only `printer/` changes.

## API
```
local ctx: Context = Context()
local mod: Module = Module(&ctx, "main")
mod.setTriple("x86_64-pc-linux-gnu")
local fn: Function = mod.addFunction("main", ctx.fnType(ctx.i32(), []))
local b: Builder = Builder(&ctx)
b.setInsertPoint(fn.addBlock("entry"))
b.ret(ctx.constInt(ctx.i32(), 42))
local text: String = mod.print()?        // or mod.printTo(&writer)?
```
- Same concepts as LLVM (context, module, function, block, builder), designed for xlang: typed handles (a type cannot be passed where a
  value is expected), `Result`, `String`, `Vec<T>`. No one-to-one mapping with the C++ names is promised.
- No global state: everything belongs to a `Context`. A `Context` is single-threaded; separate contexts can be used in parallel.
- Functions can be declared before they are defined and built in any order. The printer assigns `%0, %1, ...` and `!0, !1, ...` at
  print time, so build order never affects numbering.
- **Deterministic output**: the same calls give byte-identical text (no hash-order dependence), so golden tests and build caches work.
- **Errors**: a builder call that fails a check records the first error, naming the call; `print`/`printTo` return it as `Result`.
  Builder calls stay plain (no `Result` per instruction). Tool errors carry the tool's stderr.

### Builder checks
Operand types (binary ops, compares, `store` value vs pointer use, `call` arguments vs function type, `phi` incoming types, `ret` vs
return type), one terminator per block, no instruction after a terminator, every block terminated at print time. Dominance and
use-before-def are left to `opt -verify` in e2e; the builder does not reimplement the verifier.

## Output (first version)
| Need | API |
|---|---|
| In memory (tests, handing IR to another component) | `mod.print() -> Result<String>` |
| File or stdout | `mod.printTo(*Writer)`; a file is a `std/io` writer, no separate file type |
| `.bc` / `.o` / `.s`, verify | `tools/` writes the `.ll` to a temp file and runs the tool; result is a file or a `String` of bytes |

Later, only when a consumer measures a need: piping text into a tool's stdin instead of a temp file, and per-function streaming for
modules that do not fit in memory.

## Feature tracking
Every feature is a row in `FEATURES.md` and is **done only with both tests**:

| Feature | API | Unit test | E2E test | Status |
|---|---|---|---|---|
| `add` / `sub` / `mul` on i32 | `Builder.add` ... | `unit/binary.test.xl` | `e2e/arith.xl` | done |
| `indirectbr` + `blockaddress` | `Builder.indirectBr` | `unit/indirectbr.test.xl` | `e2e/computed_goto.xl` | todo |

- One row per construct as a consumer uses it (an instruction form, a linkage, a metadata kind), not per LangRef section.
- **Unit test** (platform independent): builds the construct through the API and compares `mod.print()` with the expected `.ll`
  (golden strings in the test file, no files, no tools); also checks the builder's rejections.
- **E2E test** (platform related): prints a module using the feature, runs `opt -verify` (so a text error is reported as such), then
  `llc`, links and runs it, and checks exit code or output. Features with no run-time effect (linkage, visibility, module flags, debug
  info) are checked on the tool output instead (symbol table, `llvm-dwarfdump`). Target-dependent features (atomics, inline asm) also get
  compile-only legs for other triples (`llc -mtriple`); running them needs a host of that target.
- `test/features.sh` fails when a `done` row names a missing test or a test has no row.

## Coverage floor: what `xlc` uses today
From a survey of the ~3000 lines that touch `llvm::` in `xlc/src/codegen/llvm` and `driver/link.cpp`. Everything here must be
expressible through xl-llvm; these are the first `FEATURES.md` rows.

| Area | C++ API used | Text it becomes |
|---|---|---|
| Module | triple, data layout, module flags (`Warning`) | `target triple`, `target datalayout`, `!llvm.module.flags` |
| Types | `iN`, void, opaque pointer, array, struct, function | `iN`, `void`, `ptr`, `[N x T]`, `{ T, U }`, `T (A, B)` |
| Constants | int, FP, null, undef, struct, array, zeroinitializer, inbounds GEP, `BlockAddress` | literals, `null`, `undef`, `zeroinitializer`, `getelementptr inbounds`, `blockaddress` |
| Globals, functions | linkage (internal, external, weak, linkonce_odr), hidden visibility, `nounwind`, alignment | `@g = internal global ...`, `define` / `declare`, attributes |
| Builder (~60 calls) | `br`, cond `br`, `indirectbr`, `ret`, `unreachable`, `call`, aligned `load`/`store`, GEP, `phi`, `select`, integer arithmetic and compares, casts, `extractvalue`, `atomicrmw`, `fcmp une` | the matching instruction |
| Intrinsics, asm | `llvm.trap`, `llvm.memcpy`, `llvm.memset`, `InlineAsm` (AT&T and Intel) | `call void @llvm.trap()`, `call ... asm sideeffect inteldialect "...", "..."` |
| Debug info | `DIBuilder`, `DIFile`, `DIType`, `DebugLoc` | `!DIFile`, `!DICompileUnit`, `!DILocation`, ... |
| Pipeline | verify, bitcode, object emit, `PassBuilder` O0..O3 | `opt -verify`, `opt -O<n>`, `llvm-as`, `llc -filetype=obj` |
| Target | `Triple`, default triple, `TargetMachine` | triple string parsed in xlang; host triple from the compile-time OS/arch; `llc -mtriple` |

Out of scope: `writeArchive` (an `ar` writer is a separate package or the compiler's job).

## Problems to settle
1. **Tools and LLVM version** (before M0, its e2e already needs them). Which tools (`opt` + `llc` + system linker, or `clang` for all),
   how they are found (`PATH`, an option, or shipped next to the compiler), and which LLVM version is pinned in `FEATURES.md` and CI.
2. **Data layout.** In the C++ API the `TargetMachine` supplies the datalayout string and `DataLayout` answers size, alignment and field
   offsets. Text IR has neither. xl-llvm needs a table of datalayout strings per supported triple (from the pinned LLVM version) and, if
   the compiler asks for sizes or offsets, its own layout calculation (unit tests for the arithmetic, e2e checks against LLVM's results).
3. **Names and numbering.** Anonymous values and unnamed blocks share one counter per function in definition order; named values are
   escaped (`%"a b"`); metadata is numbered and uniqued. All of it lives in the printer.

## Milestones
- **M0 hello module**: `Context`, `Module`, `Function`, `Builder`, integer types and constants, `define`, `ret`, printer with `print` and
  `printTo`, `tools/` running `opt -verify` and `llc` on a file, `FEATURES.md` and `features.sh`. Build `i32 @main() { ret i32 42 }`,
  verify, compile, link, run.
- **M1 core**: the rest of Module, Types, Constants, Globals/functions and the Builder row, except `atomicrmw`; data layout table.
- **M2 pipeline**: `.bc`, `.s`, `opt -O<n>`, compile-only legs for other triples.
- **M3 atomics, intrinsics, inline asm.**
- **M4 debug info and metadata.**
- **M5 differential**: the same programs built through `xlc` (C++ LLVM) and through xl-llvm behave the same.

## Layout
```
xl-llvm/
  xlang.toml          package manifest (stdlib only, no other dependencies)
  index.xl            public exports
  ir/  builder/  printer/  tools/
  FEATURES.md         the feature table
  test/unit/          *.test.xl, platform independent: printer output, builder checks, triple parser
  test/e2e/           platform related: verify, llc, link, run; tests.txt + run.sh
  test/features.sh    table-versus-tests check
```
Rules as in the other repositories: unit tests platform independent, e2e platform related, the bulk are unit tests, no
`Co-Authored-By` lines.

## Open questions
1. Tools and LLVM version (problem 1).
2. First consumer: e2e programs only, or port one `xlc/src/codegen/llvm` file first (`types.cpp`, 146 lines, is the smallest)?
3. Does the compiler need sizes and offsets from xl-llvm (problem 2), or does it compute layout itself and only pass the datalayout
   string through?
