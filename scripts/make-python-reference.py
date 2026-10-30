"""Generate local Python reference predictions for Core ML parity tests.

Runs Veto's real Python inference over Veto's committed, invented parity texts and writes
ModelArtifacts/python_reference.json (gitignored: probabilities derive from the private model).

Usage (from the veto repo's environment):
    uv run --project /path/to/veto python scripts/make-python-reference.py /path/to/veto /path/to/veto-ios
"""
import json
import sys
from pathlib import Path

veto_repo, ios_repo = Path(sys.argv[1]), Path(sys.argv[2])
from veto.export.fixtures import load_fixtures
from veto.inference import VetoClassifier

clf = VetoClassifier.load(veto_repo / "models" / "veto")
examples = load_fixtures()
probs = clf.predict_proba([e["text"] for e in examples])
meta = json.loads((veto_repo / "dist/coreml/metadata.json").read_text())
out = {
    "note": "Local reference from Veto Python inference. Derived from private weights; do not commit.",
    "threshold": clf.threshold,
    "examples": [
        {"category": e["category"], "text": e["text"], "probability": p, "should_filter": p >= clf.threshold}
        for e, p in zip(examples, probs)
    ],
}
dest = ios_repo / "ModelArtifacts" / "python_reference.json"
dest.parent.mkdir(exist_ok=True)
dest.write_text(json.dumps(out, indent=1))
print(f"wrote {len(examples)} examples; metadata threshold {meta['threshold']} vs python {clf.threshold}")
