# Contributing to xl-llvm

`xl-llvm` is licensed under the [Apache License 2.0](LICENSE). Unless you state otherwise, any contribution you submit is licensed under the same terms (Apache-2.0 §5).

## Rules

- **Pure `.xl` source**, installed with `xl install`. The stdlib is its only dependency.
- **Callers never write IR text.** The library generates it behind its functions; only the printer knows the text syntax.
- **Every feature has a row in [FEATURES.md](FEATURES.md)** and is done only with both a unit test and an e2e test. `test/features.sh` checks that the table and the tests agree.
- **Unit tests are platform independent, e2e tests are platform related.** `test/unit/*.test.xl` builds IR and compares the printed text with the expected `.ll`; it never touches the OS (no files, processes, clocks, environment). `test/e2e/` holds what needs the host: running LLVM tools, linking, executing the result, per target. Most tests are unit tests; the e2e table stays the small, heavy part.
- **Stdlib style applies:** the library is a pyramid (`String`, `Vec<T>`, `Option`, `Result` over raw pointers), signatures take `*String` to borrow and return `String` to give, names carry no module prefix, comments are English and cite the LLVM LangRef section.
- Use the newest syntax the language offers; if the language lacks a form you need, open an issue instead of working around it.

## Workflow

1. Fork, branch from `main`, keep the change focused.
2. Run the tests of what you changed, then the full suites once. The standard library is a checkout of
   [xl-std](https://github.com/hasirciogluhq/xl-std) (`XL_STD`, default `../xl-std`; CI uses the tag in `XL_STD_REF` of `ci.yml`), and
   the e2e tests need LLVM 18 or newer on `PATH` (or in `LLVM_BIN`):
   ```
   xlc index.xl --check -M std=$XL_STD --import std -DfeatureDefaultAllocator=true
   test/unit/run.sh
   test/e2e/run.sh
   test/features.sh
   ```
3. Add or update the tests, the `FEATURES.md` row and the matching pages in [xlang-docs](https://github.com/hasirciogluhq/xlang-docs).
4. Open a pull request against `main` and fill in the template.

## Security and conduct

Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md). Participation is governed by the [Code of Conduct](CODE_OF_CONDUCT.md).
