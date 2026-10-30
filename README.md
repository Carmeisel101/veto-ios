<div align="center">

<img src="docs/assets/icon.png" alt="Veto app icon" width="128" height="128">

# Veto for iOS

**Filter unsolicited political texts on your iPhone. Entirely on-device.**

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
![Platform: iOS 17+](https://img.shields.io/badge/platform-iOS%2017%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![Status: prototype](https://img.shields.io/badge/status-prototype-yellow)
![No network](https://img.shields.io/badge/network-none-lightgrey)

[Getting started](docs/getting-started-xcode.md) ·
[How it works](docs/architecture.md) ·
[Contributing](CONTRIBUTING.md) ·
[Contact](#contact)

</div>

---

Veto is a classifier for **unsolicited political outreach in SMS**: campaign ads, donation requests, get-out-the-vote
texts and similar. This repository is its **iOS runtime**: a Swift tokenizer, Core ML inference, a small SwiftUI test
app, and a Message Filter Extension that sends matching texts to your Spam list.

Training, evaluation and Core ML export live in the separate [`veto`](https://github.com/Carmeisel101/veto)
repository. This repository only consumes that project's exported bundle.

> **Status: working prototype.** The tokenizer and model match the Python reference exactly in automated tests, and
> the app runs on a real iPhone. End-to-end filtering of real incoming messages and extension performance on devices
> are still being validated. Veto is **build-from-source only**: there is no App Store or TestFlight release (see
> [Distribution](docs/distribution.md)).

## Contents

- [How it works](#how-it-works)
- [Privacy](#privacy)
- [Quick start](#quick-start)
- [Build and test](#build-and-test)
- [Tokenizer parity](#tokenizer-parity)
- [Known limitations](#known-limitations)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [Contact](#contact)
- [License and credits](#license-and-credits)

## How it works

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
allow    filter (Spam)
```

| Piece | Role |
|---|---|
| `VetoCore` | Shared framework: tokenizer, metadata parser, Core ML adapter and decision logic. One source of truth for the app and the extension. |
| `Veto` | SwiftUI test app: classify text, see probability and threshold, model and app versions, load timings. |
| `VetoMessageFilter` | `ILMessageFilterExtension` that classifies messages iOS hands it. |
| `VetoTests` | Tokenizer parity, metadata, threshold, fail-open and (with a local model) Python↔Core ML parity tests. |

Two properties are non-negotiable:

- **Exact tokenization.** The Swift tokenizer must reproduce the Python tokenizer's `input_ids` and `attention_mask`
  for every golden fixture.
- **Fail open.** Any runtime problem (model won't load, tokenizer error, unexpected output) means the message is
  *not* filtered. A bug can never hide a legitimate message.

## Privacy

- **On-device only.** Classification happens on your iPhone. Message text is never sent to a server by Veto.
- **No analytics, crash reporting, advertising or network SDKs.** No third-party Swift packages at all. The extension
  declares no network URL.
- **No message logging.** On failure only the error type is logged.
- **Limited view of your Messages.** iOS calls the extension only for texts it deems eligible (SMS/MMS from senders
  not in your Contacts). The app cannot read your Messages database.
- **No trained model in this repository.** Models are trained on private messages and are gitignored. Bring your own.

## Quick start

> You need your own Veto model export. See the [`veto`](https://github.com/Carmeisel101/veto) repository to train one.

**Prerequisites:** a Mac with Xcode 26 (developed on 26.3), [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`), and an iPhone running iOS 17 or later.

```bash
# 1. Import your exported model (validates it, copies it into gitignored ModelArtifacts/, generates the project)
scripts/import-veto-model.sh /path/to/veto/dist/coreml

# 2. Open the project and run the Veto scheme on a simulator
open Veto.xcodeproj
```

Without a model the project still builds. The app reports "model unavailable" and the extension allows every message.

To run on your own iPhone and turn on the filter, follow
[docs/getting-started-xcode.md](docs/getting-started-xcode.md) (signing and installation) and then
[docs/device-testing.md](docs/device-testing.md) (enabling the filter and sending test messages). A free Apple ID is
enough; the install lasts about 7 days before you need to rebuild.

## Build and test

```bash
xcodegen generate
xcodebuild test -project Veto.xcodeproj -scheme Veto \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- **CI** runs the safety scan (no private data, secrets or network code anywhere in history) and the model-free tests; see [CONTRIBUTING.md](CONTRIBUTING.md#automated-checks).
- **Always run:** tokenizer, golden parity (70 fixtures), edge-case parity (31), metadata, threshold and fail-open tests.
- **Need your model (skipped otherwise):** Core ML load, Python↔Core ML parity and latency. For parity, generate the
  reference once from the `veto` environment:
  ```bash
  uv run --project /path/to/veto python scripts/make-python-reference.py /path/to/veto .
  ```
  This writes the gitignored `ModelArtifacts/python_reference.json` using Veto's real Python inference.

## Tokenizer parity

`VetoCore/Tokenization` is a local BERT WordPiece implementation: clean text → CJK isolation → accent stripping →
lowercasing → whitespace/punctuation split → WordPiece → `[CLS]`/`[SEP]` → truncate → pad. Veto's golden fixtures are
the authority, and new edge cases should come from the reference tokenizer, never from assumptions. Details are in
[docs/architecture.md](docs/architecture.md).

## Known limitations

- **Unverified end to end.** Filtering of real incoming messages by the extension on a device is still being confirmed.
- **Extension performance is unmeasured.** In the app on one iPhone (Debug build) model load took about 1.5 s and the
  first classification about 0.8 s. iOS limits extension memory and run time, so Release-build measurements inside the
  extension are still needed ([device testing](docs/device-testing.md)).
- **Spam only.** iOS offers fixed categories; Veto uses Spam. There's no custom "Political" folder, and iOS only
  invokes filters for unknown senders. Messages that arrived before you enabled the filter aren't re-sorted.
- **Model size.** About 43 MB, embedded once in `VetoCore.framework` and shared by the app and the extension.
- **Threshold edge case.** The exported threshold sits exactly at one validation score (noted in the Veto docs), and
  FP16 inference can flip that one case.
- **Build from source only.** See [docs/distribution.md](docs/distribution.md).

## Documentation

| Doc | What's in it |
|---|---|
| [getting-started-xcode.md](docs/getting-started-xcode.md) | Xcode, signing and installing on your iPhone |
| [device-testing.md](docs/device-testing.md) | Enabling the filter and testing with messages |
| [architecture.md](docs/architecture.md) | Targets, tokenizer decision, Core ML adapter, fail-open |
| [model-contract.md](docs/model-contract.md) | The interface consumed from the Veto export |
| [distribution.md](docs/distribution.md) | Why it's build-from-source and what may change |

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first; its privacy rules are not optional.
In short: use synthetic data only, never commit a trained model, keep the tokenizer exactly in step with the golden
fixtures, and keep the filter fail-open.

## Contact

Questions, or anything you'd rather not post publicly? Email **dev.meisel+veto@gmail.com**. Please don't include
private message content in your email.

## License and credits

Released under the [MIT License](LICENSE). The tokenizer vocabulary comes from `sentence-transformers/all-MiniLM-L6-v2`
(Apache-2.0); see [NOTICE](NOTICE). Trained Veto models are not distributed with this repository.
