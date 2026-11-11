# Features

One row per supported IR feature. A row is `done` only when both its unit test (platform independent) and its e2e test (platform related) exist and pass. `test/features.sh` checks that every `done` row names existing tests and every test has a row. New rows come from the [LLVM LangRef](https://llvm.org/docs/LangRef.html), section by section.

| Feature | LangRef section | API | Unit test | E2E test | Status |
|---|---|---|---|---|---|
