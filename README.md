# veto-ios

Native iOS runtime for **Veto**, an on-device classifier for unsolicited political outreach in SMS.
Training, evaluation and Core ML export live in the separate Python repository (`veto`); this repository
only consumes its exported deployment bundle and provides the Swift tokenizer, Core ML inference, a
SwiftUI test app, and an iOS Message Filter Extension.

```
Incoming SMS
     │
     ▼
iOS IdentityLookup
     │
     ▼
Veto Message Filter Extension
     │
     ▼
Swift WordPiece Tokenizer
     │
     ▼
input_ids + attention_mask
     │
     ▼
Veto Core ML
     │
     ▼
solicitation probability
     │
     ▼
exported threshold (metadata.json)
   /     \
allow    filter (.junk)
```

## Prerequisites
- Xcode 26 (developed on 26.3), iOS 17+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`): the `.xcodeproj` is generated from `project.yml` and not committed
- A local Veto export (`uv run veto export coreml` in the veto repo → `dist/coreml`)

## Import the model
The trained model is built from private messages and is **never committed** (see Privacy).

```bash
scripts/import-veto-model.sh /path/to/veto/dist/coreml
```
This validates the bundle, copies the model + metadata into `ModelArtifacts/` (gitignored), refreshes the
public tokenizer files, prints version/threshold/tokenizer settings and runs `xcodegen generate`.
Without a model the project still builds; the classifier reports "model unavailable" and the extension
allows every message (fail open).

## Build and test
```bash
xcodebuild test -project Veto.xcodeproj -scheme Veto -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
- Always run: tokenizer, golden parity (70 fixtures) and edge-case parity (31), metadata, threshold, fail-open tests.
- Need the private model (skipped otherwise): Core ML load, Python↔Core ML parity, latency. For parity,
  generate the reference once: `uv run --project /path/to/veto python scripts/make-python-reference.py /path/to/veto .`
  (writes the gitignored `ModelArtifacts/python_reference.json` from Veto's real Python inference).

## Tokenizer parity
`VetoCore/Tokenization` is a local BERT WordPiece implementation (clean text → CJK isolation → accent strip →
lowercase → whitespace/punctuation split → WordPiece → `[CLS]`/`[SEP]` → truncate → pad). The golden fixtures from
Veto are the authority: every `input_ids` and `attention_mask` must match exactly. See `docs/architecture.md`.

## Simulator
New to Xcode signing? Follow [docs/getting-started-xcode.md](docs/getting-started-xcode.md).

Open `Veto.xcodeproj`, run the `Veto` scheme. The Test tab classifies text; About shows model/app versions and load time.

## Physical iPhone and Message Filter setup
See [docs/device-testing.md](docs/device-testing.md). Simulator success does not prove the extension works on-device.

Distribution status (build-from-source only): [docs/distribution.md](docs/distribution.md).

## Privacy model
- Classification is on-device only; message text is never sent anywhere by Veto. No analytics, crash, ad or network SDKs.
- The extension declares no network URL; message text is never logged (only error type on failure).
- iOS calls the extension only for messages it deems eligible (unknown senders); the app cannot read Messages.
- Private artifacts (`veto.mlpackage`, `metadata.json`, `python_reference.json`) are gitignored. Committed:
  public vocabulary, invented golden/edge fixtures.

## Known limitations
- Extension latency/memory on a real iPhone is **unmeasured** (see docs/device-testing.md).
- Model (~43 MB) lives once in the embedded `VetoCore.framework`, shared by app and extension.
- The exported threshold sits exactly at one validation score (noted in Veto's docs); FP16 can flip that edge case.
- Filtered messages go to iOS's Spam list; iOS only invokes filters for unknown senders.

## Contributing and contact
See [CONTRIBUTING.md](CONTRIBUTING.md) (privacy rules first). Questions? Email **dev.meisel+veto@gmail.com**, and
please don't include private message content.
