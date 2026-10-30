#!/usr/bin/env bash
# Import a locally exported Veto deployment bundle (the `veto export coreml` output directory).
#   scripts/import-veto-model.sh /path/to/veto/dist/coreml
# Copies the private model + metadata into ModelArtifacts/ (gitignored), the public tokenizer
# files into ModelArtifacts/tokenizer/, reports the contract, and regenerates the Xcode project.
set -euo pipefail

SRC="${1:?usage: $0 /path/to/veto/dist/coreml}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/ModelArtifacts"

for f in veto.mlpackage metadata.json tokenizer/vocab.txt tokenizer/golden_tokenization.json tokenizer/tokenizer_config.json; do
  [ -e "$SRC/$f" ] || { echo "error: missing $SRC/$f (is this a Veto dist/coreml directory?)" >&2; exit 1; }
done

python3 - "$SRC/metadata.json" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
need = ["model_version", "threshold", "max_sequence_length", "input_names", "output_names", "tokenizer"]
missing = [k for k in need if k not in m]
if missing: sys.exit(f"error: metadata.json missing keys: {missing}")
if m["input_names"] != ["input_ids", "attention_mask"]: sys.exit(f"error: unexpected inputs {m['input_names']}")
t = m["tokenizer"]
print(f"model version : {m['model_version']}  (base: {m.get('base_model')})")
print(f"threshold     : {m['threshold']}")
print(f"sequence len  : {m['max_sequence_length']}")
print(f"tokenizer     : {t['type']}, lowercase={t['lowercase']}, vocab={t.get('vocab_size')}")
print(f"io            : {m['input_names']} -> {m['output_names']}")
print(f"min target    : {m.get('minimum_deployment_target')}")
PY

mkdir -p "$DEST/tokenizer"
rm -rf "$DEST/veto.mlpackage"
cp -R "$SRC/veto.mlpackage" "$DEST/veto.mlpackage"
cp "$SRC/metadata.json" "$DEST/metadata.json"
cp "$SRC/tokenizer/vocab.txt" "$SRC/tokenizer/golden_tokenization.json" "$SRC/tokenizer/tokenizer_config.json" "$DEST/tokenizer/"

# Safety: the private artifacts must be ignored by git.
for f in ModelArtifacts/veto.mlpackage ModelArtifacts/metadata.json; do
  git -C "$ROOT" check-ignore -q "$f" || { echo "error: $f is not gitignored; refusing to continue" >&2; exit 1; }
done

if command -v xcodegen >/dev/null; then
  (cd "$ROOT" && xcodegen generate)
else
  echo "note: install XcodeGen (brew install xcodegen) and run 'xcodegen generate'"
fi
echo "Imported. Optional parity reference: see docs/model-contract.md (make-python-reference.py)."
