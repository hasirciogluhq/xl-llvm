# Changelog

Versions are git tags (`vMAJOR.MINOR.PATCH`; a `-suffix` marks a pre-release).

## Unreleased

## 1.0.0

- `ir/`: `Context` (uniqued types, constants, values, first-error recording), `Module`, `Function`, `Block`, globals, functions, module flags, identified structs, inline asm values.
- `builder/`: `Builder` with the instruction forms listed in FEATURES.md (terminators, arithmetic, compares, conversions, memory, `getelementptr`, `phi`, `select`, `call`, aggregate access, atomics) and operand type checks.
- `printer/`: LLVM IR text with per-function numbering at print time, name escaping and deterministic output.
- `target/`: triple parser and data layouts for x86-64 and arm64 on Linux, macOS and Windows.
- `intrinsics/`: `llvm.trap`, `llvm.memcpy`, `llvm.memset`.
- `tools/`: `Tools.verify`, `optimize`, `bitcode`, `object`, `assembly` over `opt`, `llvm-as` and `llc`.
- Unit and e2e tests for every feature row, `test/features.sh`, and CI on Linux (x86-64, arm64), macOS (arm64, x86-64) and Windows.
- `ir/metadata.xl`: metadata strings, tuples, specialized nodes, named metadata, `metadata` operands; module flags are metadata nodes.
- `debug/`: `DIBuilder` (`DIFile`, `DICompileUnit`, `DIBasicType`, pointer and subroutine types, `DISubprogram`, `DILocalVariable`, `DILocation`, `llvm.dbg.declare`), `Builder.setDebugLocation`, `Function.setSubprogram`.
- `Module.printTo` (a `Stream`) and `printToFile`.
- Differential e2e tests against reference programs built by `xlc` (`test/e2e/ref/`).
- Not supported: `volatile` and atomic `load` / `store`, fast-math flags, `tail` calls, integers wider than 64 bits, vectors, `fp128`, `x86_fp80`, `invoke` and exception-handling personalities.
