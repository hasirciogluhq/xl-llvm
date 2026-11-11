# Features

One row per supported IR feature. A row is `done` only when both its unit test (platform independent, `test/unit/`) and its e2e test (platform related, `test/e2e/`) exist and pass. The tools layer is platform related by nature: its rows have no unit test (`n/a`). `test/features.sh` checks that every `done` row names existing tests and that every test file belongs to a row. Rows come from the [LLVM LangRef](https://llvm.org/docs/LangRef.html), one per construct as a consumer uses it.

**LLVM version.** The text syntax follows LLVM 18 and newer (opaque pointers, `-passes=`). CI runs LLVM 18 on Linux and the newest release on macOS and Windows; every e2e test also runs against the developer's LLVM (23 at the time of writing). A feature that prints differently in two versions is recorded here with the version that needs it.

| Feature | LangRef section | API | Unit test | E2E test | Status |
|---|---|---|---|---|---|
| Context, uniqued types, `iN` / `half` / `float` / `double` / `ptr` / `void` | [Type system](https://llvm.org/docs/LangRef.html#type-system) | `Context.intType`, `floatType`, `ptr`, `voidType` | `types.test.xl` | `hello.xl` | done |
| Array, literal and packed struct, identified struct, function type, `...` | [Aggregate types](https://llvm.org/docs/LangRef.html#aggregate-types) | `arrayType`, `structType`, `namedStruct`, `setBody`, `fnType` | `types.test.xl` | `memory.xl` | done |
| Integer and float constants, `null`, `undef`, `poison`, `zeroinitializer` | [Constants](https://llvm.org/docs/LangRef.html#constants) | `constInt`, `constBool`, `constFloat`, `null`, `undef`, `poison`, `zero` | `constants.test.xl` | `floats.xl` | done |
| Struct and array constants, `c"..."` strings, constant `getelementptr inbounds` | [Complex constants](https://llvm.org/docs/LangRef.html#complex-constants) | `constStruct`, `constArray`, `constString`, `constGep` | `constants.test.xl` | `memory.xl`, `calls.xl` | done |
| Module header: name, `target triple`, `target datalayout` | [Module structure](https://llvm.org/docs/LangRef.html#module-structure) | `Module`, `setTriple`, `setDataLayout`, `print` | `module.test.xl` | `hello.xl` | done |
| Triple parser, data layouts of x86-64 and arm64 on Linux, macOS and Windows | [Data layout](https://llvm.org/docs/LangRef.html#data-layout) | `parseTriple`, `dataLayout`, `setTarget`, `hostTriple` | `target.test.xl` | `hello.xl` | done |
| Global variables: linkage, visibility, `constant`, `unnamed_addr`, section, align, `thread_local` | [Global variables](https://llvm.org/docs/LangRef.html#global-variables) | `addGlobal`, `setInitializer`, `setConstant`, `setGlobalLinkage`, ... | `module.test.xl` | `linkage.xl` | done |
| Functions: declarations, definitions, linkage, visibility, attributes, section, align | [Functions](https://llvm.org/docs/LangRef.html#functions) | `addFunction`, `getOrDeclare`, `Function.setLinkage`, `addAttr`, ... | `module.test.xl` | `linkage.xl` | done |
| Quoted names, deterministic numbering of unnamed values and blocks | [Identifiers](https://llvm.org/docs/LangRef.html#identifiers) | `setName`, `addBlock` | `module.test.xl`, `control.test.xl` | `arith.xl` | done |
| Module flags | [Module flags](https://llvm.org/docs/LangRef.html#module-flags-metadata) | `addFlag` | `module.test.xl` | `hello.xl` | done |
| `ret`, `br`, conditional `br`, `unreachable` | [Terminators](https://llvm.org/docs/LangRef.html#terminator-instructions) | `ret`, `retVoid`, `br`, `condBr`, `unreachable` | `control.test.xl` | `arith.xl` | done |
| `switch` | [switch](https://llvm.org/docs/LangRef.html#switch-instruction) | `switchTo` | `control.test.xl` | `control.xl` | done |
| `indirectbr` and `blockaddress` | [indirectbr](https://llvm.org/docs/LangRef.html#indirectbr-instruction) | `indirectBr`, `Module.blockAddress` | `control.test.xl` | `control.xl` | done |
| Integer arithmetic, shifts, bitwise, `nuw` / `nsw` / `exact` / `disjoint` | [Binary operations](https://llvm.org/docs/LangRef.html#binary-operations) | `add` ... `bitXor`, `bin` | `binary.test.xl` | `arith.xl` | done |
| Floating-point arithmetic, `fneg`, `freeze` | [Floating-point operations](https://llvm.org/docs/LangRef.html#floating-point-operations) | `fadd` ... `frem`, `fneg`, `freeze` | `binary.test.xl` | `floats.xl` | done |
| `icmp`, `fcmp`, `select` | [icmp](https://llvm.org/docs/LangRef.html#icmp-instruction) | `icmp`, `fcmp`, `select` | `compare_cast.test.xl`, `memory.test.xl` | `floats.xl` | done |
| Conversions: `trunc` `zext` `sext` `fptrunc` `fpext` `fptoui` `fptosi` `uitofp` `sitofp` `ptrtoint` `inttoptr` `bitcast` | [Conversion operations](https://llvm.org/docs/LangRef.html#conversion-operations) | `cast`, `trunc`, `zext`, `sext`, ... | `compare_cast.test.xl` | `floats.xl` | done |
| `alloca`, aligned `load` and `store` | [Memory access](https://llvm.org/docs/LangRef.html#memory-access-and-addressing-operations) | `alloca`, `load`, `store` | `memory.test.xl` | `memory.xl` | done |
| `getelementptr` (`inbounds` or plain) | [getelementptr](https://llvm.org/docs/LangRef.html#getelementptr-instruction) | `gep` | `memory.test.xl` | `memory.xl` | done |
| `extractvalue`, `insertvalue` | [Aggregate operations](https://llvm.org/docs/LangRef.html#aggregate-operations) | `extractValue`, `insertValue` | `memory.test.xl` | `atomics.xl` | done |
| `phi` | [phi](https://llvm.org/docs/LangRef.html#phi-instruction) | `phi`, `addIncoming` | `control.test.xl` | `arith.xl` | done |
| `call`: direct, indirect, `void`, variadic | [call](https://llvm.org/docs/LangRef.html#call-instruction) | `call`, `callFn` | `memory.test.xl` | `calls.xl` | done |
| `atomicrmw`, `cmpxchg`, `fence` and the orderings | [Atomic operations](https://llvm.org/docs/LangRef.html#atomicrmw-instruction) | `atomicRmw`, `cmpXchg`, `fence` | `atomics_asm.test.xl` | `atomics.xl` | done |
| Inline assembly, AT&T and Intel dialect | [Inline assembler](https://llvm.org/docs/LangRef.html#inline-assembler-expressions) | `Context.inlineAsm` | `atomics_asm.test.xl` | `asm.xl` | done |
| `llvm.trap`, `llvm.memcpy`, `llvm.memset` | [Intrinsics](https://llvm.org/docs/LangRef.html#intrinsic-functions) | `trap`, `memcpy`, `memset` | `atomics_asm.test.xl` | `memory.xl` | done |
| Builder checks: operand types, `call` arguments, `ret`, one terminator per block, every block terminated | [Verifier](https://llvm.org/docs/LangRef.html#verifier) | `Context.fail`, `Module.print` | `control.test.xl`, `binary.test.xl` | `tools.xl` | done |
| Verify with `opt`, optimize with `opt -O<n>` | [opt](https://llvm.org/docs/CommandGuide/opt.html) | `Tools.verify`, `Tools.optimize` | n/a | `tools.xl` | done |
| Bitcode, object and assembly output (`llvm-as`, `llc`), compile-only legs for other triples | [llc](https://llvm.org/docs/CommandGuide/llc.html) | `Tools.bitcode`, `object`, `assembly` | n/a | `tools.xl` | done |
| Metadata: strings, tuples, specialized nodes (`!Kind(field: value)`), named metadata, module flags, `metadata` call operands | [Metadata](https://llvm.org/docs/LangRef.html#metadata) | `Metadata`, `Module.addNamed`, `addFlag` | `metadata.test.xl` | `debug.xl` | done |
| Debug info: `DIFile`, `DICompileUnit`, `DIBasicType`, `DISubprogram`, `DILocalVariable`, `DILocation`, `llvm.dbg.declare`, `!dbg` on instructions | [Debug info](https://llvm.org/docs/SourceLevelDebugging.html) | `DIBuilder`, `Builder.setDebugLocation`, `Function.setSubprogram` | `debug.test.xl` | `debug.xl` | done |
| Output to a stream or a file | | `Module.printTo`, `printToFile` | n/a | `tools.xl` | done |
| Differential: the same programs written in xlang and built by `xlc` behave like the IR built here (exit status and output) | | `test/e2e/ref/` | n/a | `arith.xl`, `control.xl`, `floats.xl`, `memory.xl`, `calls.xl` | done |

Not supported (no API, no row): `volatile` and atomic `load` / `store`, fast-math flags, `tail` calls, integers wider than 64 bits, vectors, `fp128` and `x86_fp80`, `invoke` and exception-handling personalities. Adding one is a new row with both tests.
