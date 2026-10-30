# Contributing to veto-ios

Thanks for your interest! veto-ios is the iOS runtime for [Veto](README.md): a Swift tokenizer, Core ML
inference, a small SwiftUI test app, and a Message Filter Extension. Model training, evaluation and Core ML
export live in the separate `veto` repository, and are out of scope here.

Please read the **privacy rules** first. They matter more here than in most projects.

## Privacy rules (non-negotiable)

Veto is built from people's private text messages.

- **Never commit, paste or attach real messages**, phone numbers, email addresses, names of private individuals,
  or screenshots of Messages. This applies to code, tests, docs, issues, PR descriptions and comments.
- **Use synthetic data** in tests and examples. Made-up values are fine; use reserved ones such as `555-01XX`
  phone numbers and `.example` domains. The committed golden and edge-case fixtures are invented.
- **Never commit a trained model or anything derived from one.** These are gitignored and must stay that way:
  `ModelArtifacts/veto.mlpackage/`, `ModelArtifacts/metadata.json` and `ModelArtifacts/python_reference.json`.
  Only the public vocabulary and the invented fixtures under `ModelArtifacts/tokenizer/` and `VetoTests/Fixtures/`
  are committed.
- **Don't commit signing details.** `Config/Local.xcconfig` (your Team ID and bundle ID prefix) is gitignored.
- **No analytics, crash-reporting, advertising or remote-inference SDKs**, and no network calls. Classification
  happens entirely on the device.
- **Logging must never include message text.** Log error types or aggregate numbers only.
- When reporting a bug, **describe or rewrite** the message instead of pasting it, with placeholders for names,
  numbers and links.

### Automated checks

Every pull request, and every push to `main`, runs two jobs in GitHub Actions
(`.github/workflows/ci.yml`). Both must pass before merging:

- **No private data committed** (`scripts/check_repo_safety.py --all-history`): fails if the current tree **or any
  commit in history** contains a trained model or Core ML package, model metadata, local signing configuration,
  certificates or provisioning profiles, a Messages database, private keys or API tokens, a signing Team ID, an
  absolute home-directory path, a real phone number or email address, or a fixture URL outside reserved example
  domains. It also fails if source code adds networking APIs, analytics/crash/ad SDKs, a message-filter network URL
  or a third-party dependency, or if `.gitignore` stops protecting the private artifacts. Deleting a file in a later
  commit does not hide it, because history is scanned. The script prints paths and line numbers, never contents.
- **Build and test** (`xcodebuild test` on the iOS Simulator): builds the app and extension and runs the tests that
  don't need a private model. The model tests (`ModelParityTests`) are excluded from CI because every user's model is
  private, so Core ML parity with Python is only verified locally. Run them before changing the tokenizer or the
  model adapter.

Run the same checks locally before you push:

```bash
python3 scripts/check_repo_safety.py --all-history
python3 -m unittest scripts/test_check_repo_safety.py
git status && git diff --stat --cached      # eyeball what is staged
```

If a check flags something intentional (for example a deliberate change to the no-network rule), update
`scripts/check_repo_safety.py` and the docs in the same pull request and explain why.

If you accidentally commit private data, email dev.meisel+veto@gmail.com right away so the history can be rewritten.
Deleting the file in a later commit is not enough.

## Getting set up

Follow [docs/getting-started-xcode.md](docs/getting-started-xcode.md). In short:

```bash
brew install xcodegen
scripts/import-veto-model.sh /path/to/veto/dist/coreml   # needs your own model export
open Veto.xcodeproj
```

You need your own model export from the `veto` repository. Without one the project still builds, tests that
need the model are skipped, and the extension fails open.

## Making changes

1. **Open an issue first** for anything bigger than a small fix, so we can agree on the approach before you invest time.
2. **Branch** from `main` with a short descriptive name, such as `fix/accent-folding` or `feature/status-screen`.
3. **Keep PRs focused.** One logical change per PR.
4. **Write tests** for new behavior and bug fixes, using synthetic data only.
5. **Run the tests** before you push:
   ```bash
   xcodegen generate
   xcodebuild test -project Veto.xcodeproj -scheme Veto \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
   ```
   Use any installed simulator name. Tests that need the private model skip themselves when it's absent.
6. **Update the docs** (`README.md`, `docs/`) when you change behavior, setup steps or the model contract.

`Veto.xcodeproj` is generated from `project.yml` and is not committed. Add new source files on disk, then run
`xcodegen generate`; don't commit the `.xcodeproj`.

### Tokenizer changes need exact parity

The Swift tokenizer must reproduce the Python tokenizer **exactly**: `input_ids` and `attention_mask` must match
the golden fixtures from `veto` element for element. This is the one correctness property everything else depends on.

- If a golden test fails, fix the tokenizer. Never edit the expected values to make a test pass.
- New edge cases should come from the real reference tokenizer (Veto's `tokenizer.json`), not from guesses about
  how BERT behaves. See `VetoTests/Fixtures/edge_tokenization.json`.
- Keep tokenizer behavior driven by the exported metadata and vocabulary rather than hardcoded values.

### Fail-open is a requirement

A runtime problem must never cause a legitimate message to be filtered. Model load failures, tokenizer errors,
unexpected Core ML output or inference errors must all result in "do not filter". Changes to
`VetoClassifier` or the extension need a test covering the failure path.

### Code style

- Swift 6 language mode, iOS 17+ deployment target for every target (keep them consistent).
- Match the surrounding code: small focused files, clear names, short comments only where behavior isn't obvious.
- One source of truth for classification logic: it lives in `VetoCore` and is shared by the app and the extension.
  Don't duplicate it per target.
- Keep dependencies minimal and say why in the PR if you add one. Don't add network or telemetry code.
- Don't hardcode values that the model export already provides (threshold, sequence length, feature names).

### Commit messages

Short imperative summaries; a conventional prefix is welcome: `feat:`, `fix:`, `docs:`, `test:`, `chore:`,
`refactor:`. Example: `fix: strip combining marks before WordPiece`.

## Areas where help is especially useful

- **Measuring the extension on real devices** (load time, memory, latency, behavior under iOS limits), using Release
  builds. Report numbers, not message content.
- **A status screen** showing whether the extension ran and what it decided, without storing message text.
- **Tokenizer edge cases** from additional scripts and languages, with fixtures generated from the reference tokenizer.
- **Docs and device-testing notes** for newer Xcode and iOS versions.

## Scope

In scope: the Swift runtime, tokenizer, Core ML integration, the test app, the Message Filter Extension, tests and docs.

Out of scope: model training or conversion (that belongs in `veto`), backend servers, remote inference, accounts,
analytics, and App Store or TestFlight distribution (see [docs/distribution.md](docs/distribution.md)).

## Reporting bugs

Open an issue with: what you did, what you expected, what happened, your Xcode and iOS versions, and whether you
used a simulator or a device. Remove any private message content from logs and screenshots before posting.

## Security

If you find a privacy or security problem, such as a path where message text could leak, please report it privately
by email to **dev.meisel+veto@gmail.com** instead of opening a public issue.

## Contact

Questions, or anything you'd rather not post publicly? Email **dev.meisel+veto@gmail.com**. Please don't include
private message content in your email either.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
