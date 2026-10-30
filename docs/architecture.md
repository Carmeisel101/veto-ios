# Architecture

Targets (XcodeGen `project.yml`): `VetoCore` (framework, shared), `Veto` (SwiftUI app), `VetoMessageFilter`
(ILMessageFilterExtension), `VetoTests`. Deployment target iOS 17.0 everywhere, matching the export's `iOS17`.
Swift 6 language mode; tests pass without concurrency warnings from our code.

- **One source of truth:** tokenizer, metadata parser, Core ML adapter and decision logic live only in `VetoCore`.
  The framework bundle also holds the compiled model, `metadata.json` and `vocab.txt`, and is embedded once in the
  app and linked by the extension.
- **Tokenizer decision:** no dependency. `swift-transformers` was not adopted: a ~150-line local WordPiece is enough,
  adds no runtime dependencies, and is proven by golden + edge fixtures (all exact).
  Special-token IDs come from the vocabulary; BERT settings from metadata (`strip_accents: null` follows lowercase).
- **Core ML adapter:** uses `MLModel` with feature names from metadata instead of the generated class (codegen disabled),
  and checks int32 `[1,256]` inputs at load. Output `political_solicitation_probability` is already a sigmoid probability
  (float16, shape `[1]`); values outside [0,1] or non-finite throw.
- **Decision:** `probability >= metadata.threshold`. Never 0.5 unless metadata says so.
- **Fail open:** `VetoClassifier.shouldFilter` returns `false` on any error; the extension returns `.none` when the model
  cannot load or the body is empty, and `.junk` only on a successful above-threshold prediction.
- **Extension action:** IdentityLookup offers `.none/.allow/.junk/.promotion/.transaction` (checked in the iOS 26.2 SDK
  headers). Political solicitation maps to `.junk`. The extension uses `.cpuOnly` compute units for predictability (unmeasured choice).
