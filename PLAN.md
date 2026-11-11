# xl-llvm: plan (draft for discussion)

## Goal
An xlang API over LLVM, the way the C++ `llvm::` API is used by `xlc` today. Written in xlang, so a compiler written in xlang
(later) can build IR, run passes and emit objects without C++. Start with exactly what `xlc` uses, grow on demand.

## Constraint that shapes everything: C ABI only
xlang has no C++ ABI (no name mangling, no templates, no inline members). `IRBuilder<>`, `Triple`, `ArrayRef`, `raw_ostream`,
`Error` are C++ only. The only stable LLVM surface is **LLVM-C** (`llvm-c/*.h`, exported by `libLLVM`). So:

- Layer 0 `llvm/c/`: raw `@library("LLVM") declare fn LLVM…` bindings, one file per header (Core, Target, TargetMachine,
  Transforms/PassBuilder, BitWriter, DebugInfo, Analysis). Opaque handles are `*void` aliases (`type Value = *void`).
- Layer 1 `llvm/`: safe, small types on top (`Context`, `Module`, `Builder`, `Type`, `Value`, `Function`, `BasicBlock`),
  names without the `LLVM` prefix, `String`/`Vec<T>` in signatures (std pyramid rule), error as `Result`.
- Layer 0 is generated or hand-written from the headers and never hand-edited in layer 1.

## What xlc uses today (survey of `xlc/src`, ~3000 lines touching `llvm::`)
| Area | Used API | LLVM-C equivalent | Gap |
|---|---|---|---|
| Context/Module | `LLVMContext`, `Module`, `setTargetTriple`, `setDataLayout`, `Module::Warning` flags | `LLVMContextCreate`, `LLVMModuleCreateWithNameInContext`, `LLVMSetTarget`, `LLVMSetModuleDataLayout`, `LLVMAddModuleFlag` | none |
| Types | `Type::getInt{1,8,32,64,N}Ty`, `getVoidTy`, `PointerType::getUnqual`, `ArrayType::get`, `StructType::get`, `FunctionType::get` | `LLVMIntTypeInContext`, `LLVMVoidTypeInContext`, `LLVMPointerTypeInContext`, `LLVMArrayType2`, `LLVMStructTypeInContext`, `LLVMFunctionType` | none (opaque pointers) |
| Constants | `ConstantInt::get`, `ConstantFP::get`, `getNullValue`, `UndefValue`, `ConstantStruct/Array/AggregateZero`, `ConstantExpr::getInBoundsGetElementPtr`, `BlockAddress::get` | `LLVMConstInt`, `LLVMConstReal`, `LLVMConstNull`, `LLVMGetUndef`, `LLVMConstStructInContext`, `LLVMConstArray2`, `LLVMConstInBoundsGEP2`, `LLVMBlockAddress` | none |
| Globals/functions | `Function::Create`, `GlobalVariable`, linkage (Internal, External, WeakAny, LinkOnceODR), `HiddenVisibility`, `Attribute::NoUnwind`, `setAlignment` | `LLVMAddFunction`, `LLVMAddGlobal`, `LLVMSetLinkage`, `LLVMSetVisibility`, `LLVMCreateEnumAttribute`+`LLVMAddAttributeAtIndex`, `LLVMSetAlignment` | none |
| Builder (~60 calls) | `SetInsertPoint`, `GetInsertBlock`, `CreateBr/CondBr/IndirectBr/Ret/RetVoid/Unreachable`, `CreateCall`, `CreateAlignedLoad/Store`, `CreateInBoundsGEP`, `CreatePHI`, `CreateSelect`, int arithmetic and compares, casts (`ZExt SExt Trunc PtrToInt IntToPtr UIToFP SIToFP`), `ExtractValue`, `AtomicRMW`, `MemCpy`, `MemSet`, `FCmpUNE` | `LLVMBuild*` family | `IsNotNull`, `AlignedLoad` are two-step helpers in layer 1 |
| Intrinsics / asm | `Intrinsic::trap`, `getOrInsertDeclaration`, `InlineAsm::get` (AT&T/Intel) | `LLVMGetIntrinsicDeclaration`, `LLVMLookupIntrinsicID`, `LLVMGetInlineAsm` | none |
| Debug info | `DIBuilder`, `DIFile`, `DIType`, `DebugLoc` | `LLVMCreateDIBuilder`, `LLVMDIBuilderCreate*`, `LLVMSetCurrentDebugLocation2` | covered, check coverage when needed |
| Verify / emit | `verifyModule`, `WriteBitcodeToFile`, `addPassesToEmitFile`, legacy `PassManager` | `LLVMVerifyModule`, `LLVMWriteBitcodeToFile`, `LLVMTargetMachineEmitToFile` | none |
| Passes | `PassBuilder::buildPerModuleDefaultPipeline(O0..O3)` | `LLVMRunPasses(m, "default<O2>", tm, opts)` | none |
| Target | `TargetRegistry`, `createTargetMachine`, `InitializeAll*`, `sys::getDefaultTargetTriple`, `Triple` | `LLVMInitializeAll*`, `LLVMGetTargetFromTriple`, `LLVMCreateTargetMachine`, `LLVMGetDefaultTargetTriple` | `Triple` parsing is C++ only: write a small triple parser in xlang (arch/os/env split) |
| Archives | `object::writeArchive` (GNU/Darwin) | none in LLVM-C | write an `ar` writer in xlang, or keep the C++ helper until then |

Reading: **nothing blocks a C-API port**; two small gaps (`Triple`, `writeArchive`) are solved in xlang code.

## Problems to settle before coding
1. **Linking libLLVM from xlang.** `@library("LLVM")` on Linux links static archives only (`-nostdlib -static`); libLLVM is huge and
   has many component archives. Options: static component list via `llvm-config --libs`, or let the driver learn a dynamic
   mode. On macOS/Windows a dylib/DLL works through the existing path. Needs a decision; it is the real work.
2. **C++ runtime.** libLLVM static archives need libstdc++/libc++. xlang's static, no-libc link cannot supply it. Probably the
   binary that uses xl-llvm links through `clang`/`ld` with the C++ runtime (a driver option), or we use the dynamic libLLVM-C.
3. **Handle safety.** Raw `*void` handles are easy to mix up. Layer 1 uses distinct wrapper structs (`struct Value { p: *void }`)
   so `Type` cannot be passed as `Value`.
4. **Ownership.** `Context` owns everything; `Module` and `TargetMachine` have drop glue (`LLVMDisposeModule`, …). Messages from
   LLVM (`char*`) copied into `String`, then `LLVMDisposeMessage`.
5. **LLVM version.** Pin to the version xlc builds against (`llvm-config --version`) and record it; the C API is stable but
   not frozen (e.g. `LLVMBuildGEP` → `LLVMBuildGEP2`).

## Milestones
- M0 *hello module*: bindings for Context/Module/Types/Function/Builder `ret`; build a module that returns 42, emit an object, link
  with xlc, run it (e2e). Settles problems 1 and 2.
- M1 *xlc-equivalent core*: everything in the table above except debug info and archives.
- M2 *driver pieces*: `Triple` parser, archive writer, passes, bitcode and object emit.
- M3 *debug info*.
- M4 *differential test*: emit the same module from the C++ `xlc` and from xl-llvm and compare the printed IR (`LLVMPrintModuleToString`).

## Layout (proposed)
```
xl-llvm/
  index.xl            re-exports the public layer
  c/                  layer 0: raw LLVM-C declarations, one file per header
  core/ target/ passes/ debuginfo/   layer 1
  test/unit/          pure logic (triple parser, ar writer, name mapping)   — platform independent
  test/e2e/           builds IR, emits, links, runs                         — platform related
```
Follows the repo rules: unit tests platform independent, e2e platform related; no `Co-Authored-By`.

## Open questions for the discussion
1. Raw C bindings only, or also the layer-1 wrapper from the start?
2. Dynamic `libLLVM` (simple) or static components (self-contained xlc)?
3. Who is the first consumer: a toy compiler in the e2e, or a real port of one `xlc/src/codegen/llvm` file?
4. Bindings by hand or generated from `llvm-c/*.h` (needs a header parser; a small script outside the repo)?
