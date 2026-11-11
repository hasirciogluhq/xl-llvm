# xl-llvm: plan (draft for discussion)

## Goal
An xlang package that builds LLVM IR as **text** (`.ll`), the way `xlc` builds it today through the C++ `llvm::` API. Installed later with the
package manager (`xlang package install github.com/hasirciogluhq/xl-llvm`), pure `.xl` source, no native files. Start with exactly what `xlc`
uses, grow feature by feature.

## Decision: text IR, not LLVM-C
- Nothing to link: no libLLVM, no C++ runtime, no static-archive problem. The package is plain source.
- The output is a `String`, so a feature is tested by comparing text (platform independent unit test) and by running the result (e2e).
- LLVM parses `.ll` fast; parse time is negligible next to optimization and code generation.
- A second backend (LLVM-C, in-process verifier) can be added later behind the same `Builder`; it is not part of the first milestones.

## Layers
```
ir/        types, values, constants, instructions as data; the printer turns them into text      (pure, platform independent)
builder/   Builder: insertion point, SSA numbering, block labels, type checks that LLVM would reject
module/    Module: target triple, datalayout, globals, functions, attributes, metadata, debug info
emit/      turns text into artifacts by running LLVM tools: .ll -> .bc/.o/.s (llc, opt, clang), verify (llvm-as, opt -verify)   (platform related)
```
`ir/`, `builder/` and `module/` never touch the OS. Only `emit/` starts processes (through `std/os/process`).

## Feature tracking (the core of the design)
Every IR feature is a row in `FEATURES.md`, and a feature is **done only with both tests**:

| Feature | LangRef section | API | Unit test | E2E test | Status |
|---|---|---|---|---|---|
| `add` / `sub` / `mul` on i32 | Binary Operations | `Builder.add` … | `unit/binary.test.xl: add_i32` | `e2e/arith.xl` | done |
| `indirectbr` + `blockaddress` | Terminator Instructions | `Builder.indirectBr` | `unit/indirectbr.test.xl` | `e2e/computed_goto.xl` | todo |

- **Unit test** (platform independent): builds the construct with the `Builder` and compares the printed text with the expected `.ll`
  (golden strings in the test file, no files). Also checks the builder's own rejections (type mismatch, terminator twice, use before def).
- **E2E test** (platform related): builds a module with the feature, has `llc` accept it (`llvm-as` / `opt -verify` first, so a text error
  is reported as such), links it with `xlc`, runs it, checks the exit code or output. Runs on every host OS and CPU in CI. Features that
  differ per target (atomics, inline asm, calling conventions, TLS, data layout) get an e2e entry per target (`--target`).
- A check script (`test/features.sh`) fails when a `done` row names a test that does not exist, or a test has no row. The table cannot
  drift from the tests.
- The first rows are copied from the survey below. New rows come from the LangRef (https://llvm.org/docs/LangRef.html), section by section.

## Survey: what `xlc` uses today (first scope; ~3000 lines touching `llvm::` in `xlc/src/codegen/llvm`, `driver/link.cpp`)
| Area | C++ API used | Text IR it becomes |
|---|---|---|
| Module | `Module`, triple, data layout, module flags (`Warning`) | `target triple`, `target datalayout`, `!llvm.module.flags` |
| Types | `getInt{1,8,32,64,N}Ty`, `getVoidTy`, `PointerType::getUnqual`, `ArrayType`, `StructType`, `FunctionType` | `iN`, `void`, `ptr`, `[N x T]`, `{ T, U }`, `T (A, B)` |
| Constants | `ConstantInt/FP`, null, undef, struct, array, zeroinitializer, `getInBoundsGetElementPtr`, `BlockAddress` | literals, `null`, `undef`, `zeroinitializer`, `getelementptr inbounds`, `blockaddress` |
| Globals, functions | `GlobalVariable`, `Function::Create`, linkage (internal, external, weak, linkonce_odr), hidden visibility, `nounwind`, alignment | `@g = internal global …`, `define`/`declare`, attributes |
| Builder (~60 calls) | `br`, `condbr`, `indirectbr`, `ret`, `unreachable`, `call`, aligned `load`/`store`, `gep`, `phi`, `select`, int arithmetic and compares, casts, `extractvalue`, `atomicrmw`, `memcpy`, `memset`, `fcmp une` | the instruction of the same name |
| Intrinsics, asm | `llvm.trap`, `InlineAsm` (AT&T and Intel) | `call void @llvm.trap()`, `call … asm sideeffect inteldialect "…", "…"` |
| Debug info | `DIBuilder`, `DIFile`, `DIType`, `DebugLoc` | `!DIFile`, `!DICompileUnit`, `!DILocation` metadata |
| Pipeline | verify, bitcode, object emit, `PassBuilder` O0..O3 | `llvm-as`/`opt -verify`, `opt -O2`, `llc -filetype=obj`, `llvm-as` for `.bc` |
| Target | `Triple`, default triple, `TargetMachine` | triple string parsed in xlang (arch, vendor, os, env); `llc -mtriple` |
| Archives | `writeArchive` | out of scope here: an `ar` writer is a separate package or xlc's job |

## Problems to settle
1. **Which LLVM tools, and where from.** `emit/` needs `llc`/`opt`/`llvm-as` (or `clang`). Options: found on `PATH`, a path option, or
   shipped next to `xlc`. Decide before M2.
2. **LLVM version.** Text syntax changes between versions (opaque pointers, intrinsic names). Pin one version in `FEATURES.md` and CI,
   print it in the module header comment, and name it in the package version policy.
3. **SSA numbering and names.** Anonymous `%0, %1…` must be numbered in order, named values escaped (`%"a b"`). The printer owns this, so
   builders never format names by hand.
4. **Type checks.** LLVM rejects ill-typed IR late and with a text position. The `Builder` checks operand types as it builds and reports
   the builder call, not the text line. These checks are unit tests too.
5. **Metadata and debug info** numbering (`!0, !1…`) and uniquing; deferred to M4 but the printer must leave room for it.

## Milestones
- **M0 hello module** (unit + e2e): types, `define`, `ret`, constants, printer; build `i32 @main() { ret i32 42 }`, `llc`, link, run.
- **M1 core instructions**: everything in the Builder row above except atomics and asm; each with its unit and e2e rows.
- **M2 emit and tools**: `emit/` for `.bc`, `.o`, `.s`, verify step, tool lookup (problem 1), per-target e2e legs.
- **M3 atomics, intrinsics, inline asm, TLS, calling conventions.**
- **M4 debug info and metadata.**
- **M5 differential e2e**: the same small programs built through `xlc` (C++) and through xl-llvm behave the same.

## Layout
```
xl-llvm/
  xlang.toml          package manifest (no dependencies; depends on the stdlib only)
  index.xl            public exports
  ir/  builder/  module/  emit/
  FEATURES.md         the feature table
  test/unit/          *.test.xl, platform independent: printer output, builder checks, triple parser
  test/e2e/           platform related: llc/llvm-as, link, run, per target; tests.txt + run.sh
  test/features.sh    table-versus-tests consistency check
```
Rules as in the other repositories: unit tests platform independent, e2e platform related; the bulk are unit tests; no `Co-Authored-By`.

## Open questions
1. Do we guarantee one LLVM version (pinned) or a range (text compatibility tests per version)?
2. Which tool does `emit/` call first: `clang` (one tool, also links) or `llc` + `xlc` for linking?
3. First consumer: e2e programs only, or start porting one `xlc/src/codegen/llvm` file (`types.cpp`, 146 lines, is the smallest)?
4. Is the `FEATURES.md` row granularity right (one row per instruction form), or per LangRef section?
