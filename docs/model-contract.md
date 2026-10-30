# Model contract (consumed from Veto `dist/coreml`)

Verified against the actual export (v1, 2026-10-29):

| item | value |
|---|---|
| inputs | `input_ids`, `attention_mask`: int32 `[1, 256]` |
| output | `political_solicitation_probability`: float16 `[1]`, sigmoid probability |
| threshold | `metadata.json` → `threshold` (0.86997…); `should_filter = p >= threshold` |
| tokenizer | BERT WordPiece, MiniLM vocab (30,522), lowercase, accents stripped, PAD 0 / UNK 100 / CLS 101 / SEP 102 |
| size | 45.2 MB mlpackage (FP16), min target iOS 17 |

Veto exports `parity_fixtures.json` (texts only) and golden token IDs, but **no Python probabilities**.
`scripts/make-python-reference.py` produces them locally from Veto's real Python inference; the contract would
be better if Veto exported such a fixture itself (it derives from private weights, so it would stay local anyway).
