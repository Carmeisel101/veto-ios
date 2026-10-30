#!/usr/bin/env python3
"""Fail if private data, secrets or privacy-breaking code made it into the repository.

Standard library only, so it runs anywhere with git and Python 3. It never prints file
contents, only paths and line numbers.

Checks
------
1. Paths: no trained model (Core ML packages, weights), exported model metadata, local signing
   configuration, certificates or provisioning profiles, Messages databases, generated Xcode
   projects, build output or local performance results.
2. Content of text files: no private keys or common API tokens, no signing Team IDs, no
   absolute home-directory paths, no phone numbers or email addresses other than reserved test
   values and the project contact, and fixture URLs only on reserved example domains.
3. Privacy rules for source code: no networking APIs, no analytics/crash/ad SDK imports, no
   message-filter network URL, no third-party Swift packages. (Veto's privacy claims depend on
   this; if a change is intentional, update this script and the docs in the same pull request.)
4. .gitignore still protects the private artifacts.

Modes
-----
  (default)           check the files tracked at HEAD
  --all-history       also check every file ever added or modified in any commit, so a file that
                      was committed and later deleted is still caught (deleting it later does not
                      remove it from Git history)
  --base REF          like --all-history but only for commits in REF..HEAD (for pull requests)
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys

# --- 1. Paths ---------------------------------------------------------------------------------

PRIVATE_PATH_PARTS = (
    ("ModelArtifacts/metadata.json", "is exported model metadata (private)"),
    ("ModelArtifacts/python_reference.json", "is a reference derived from private weights"),
    ("config/local.xcconfig", "is local signing configuration"),
    ("perf-results/", "is a local performance result"),
    ("deriveddata/", "is build output"),
    ("xcuserdata/", "is per-user Xcode state"),
    ("/build/", "is build output"),
)
PRIVATE_SUFFIXES = (
    (".mlpackage", "is a Core ML package (it contains trained weights)"),
    (".mlmodel", "is a Core ML model (trained weights)"),
    (".mlmodelc", "is a compiled Core ML model (trained weights)"),
    (".safetensors", "looks like trained-model weights"),
    (".pt", "looks like trained-model weights"),
    (".pth", "looks like trained-model weights"),
    (".ckpt", "looks like trained-model weights"),
    (".joblib", "looks like trained-model weights"),
    (".onnx", "looks like trained-model weights"),
    (".gguf", "looks like trained-model weights"),
    (".db", "looks like a private database"),
    (".sqlite", "looks like a private database"),
    (".sqlite3", "looks like a private database"),
    (".parquet", "is a data file"),
    (".mobileprovision", "is a provisioning profile"),
    (".provisionprofile", "is a provisioning profile"),
    (".p12", "is a signing certificate/key"),
    (".cer", "is a certificate"),
    (".pem", "is a key or certificate"),
    (".key", "is a key"),
    (".ipa", "is a built app archive"),
    (".xcarchive", "is a built app archive"),
    (".xcresult", "is a test result bundle"),
    (".xcuserstate", "is per-user Xcode state"),
)
PRIVATE_NAMES = (
    ("chat.db", "is a Messages database"),
    (".env", "is a local environment file"),
    ("pytorch_model.bin", "looks like trained-model weights"),
)
# Only the example is allowed; the real file is gitignored.
ALLOWED_PATHS = {"Config/Local.xcconfig.example"}


def forbidden_path_reason(path: str) -> str | None:
    if path in ALLOWED_PATHS:
        return None
    lower = path.lower()
    name = lower.rsplit("/", 1)[-1]
    if ".xcodeproj/" in lower or lower.endswith(".xcodeproj") or ".xcworkspace/" in lower:
        return "is a generated Xcode project (generate it with `xcodegen generate`)"
    if ".mlpackage/" in lower or ".mlmodelc/" in lower:
        return "is inside a Core ML model (it contains trained weights)"
    for part, why in PRIVATE_PATH_PARTS:
        if part.lower() in lower or lower.startswith(part.lower().lstrip("/")):
            return why
    for suffix, why in PRIVATE_SUFFIXES:
        if lower.endswith(suffix):
            return why
    for n, why in PRIVATE_NAMES:
        if name == n:
            return why
    return None


# --- 2. Content -------------------------------------------------------------------------------

MAX_SCAN_BYTES = 2_000_000
RESERVED_TEAM_IDS = {"ABCDE12345", "XXXXXXXXXX", "0123456789"}
ALLOWED_EMAILS = {"dev.meisel+veto@gmail.com"}
RESERVED_HOSTS = ("example", "example.com", "example.org", "example.net", "localhost", "test",
                  "invalid")
FIXTURE_PREFIXES = ("VetoTests/Fixtures/", "ModelArtifacts/tokenizer/golden")

SECRET_PATTERNS = (
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"), "contains a private key"),
    (re.compile(r"\bAKIA[0-9A-Z]{16}\b"), "contains an AWS access key id"),
    (re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,}\b"), "contains a GitHub token"),
    (re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"), "contains a GitHub token"),
    (re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}"), "contains a Slack token"),
    (re.compile(r"\bsk-[A-Za-z0-9]{32,}\b"), "contains an API key"),
    (re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b"), "contains a Google API key"),
)
TEAM_ID = re.compile(r"(?:DEVELOPMENT_TEAM|DevelopmentTeam|TeamIdentifier)\W{1,6}([A-Z0-9]{10})\b")
CERT_NAME = re.compile(r"Apple (?:Development|Distribution): [^\n(]*\(([A-Z0-9]{10})\)")
HOME_PATH = re.compile(r"(?:/Users/[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/|[A-Za-z]:\\Users\\[A-Za-z0-9._-]+\\)")
EMAIL = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
PHONE = re.compile(r"(?<![\d.])(?:\+?1[ .-]?)?\(?([2-9]\d{2})\)?[ .-]([2-9]\d{2})[ .-](\d{4})(?![\d.])")
URL = re.compile(r"https?://([A-Za-z0-9.-]+)", re.IGNORECASE)


def _reserved_host(host: str) -> bool:
    host = host.lower().rstrip(".")
    return any(host == h or host.endswith("." + h) for h in RESERVED_HOSTS)


def content_problems(path: str, text: str) -> list[str]:
    """Problems in one text file, as ``"line N: what"`` strings (never the offending text)."""
    problems: list[str] = []
    is_fixture = path.startswith(FIXTURE_PREFIXES)
    for number, line in enumerate(text.splitlines(), start=1):
        for pattern, why in SECRET_PATTERNS:
            if pattern.search(line):
                problems.append(f"line {number}: {why}")
        for m in TEAM_ID.finditer(line):
            if m.group(1) not in RESERVED_TEAM_IDS:
                problems.append(f"line {number}: contains a signing Team ID")
        if CERT_NAME.search(line):
            problems.append(f"line {number}: contains a signing certificate name")
        if HOME_PATH.search(line):
            problems.append(f"line {number}: contains an absolute home-directory path")
        for m in EMAIL.finditer(line):
            if m.group(0).lower() not in ALLOWED_EMAILS:
                problems.append(f"line {number}: contains an email address")
        for m in PHONE.finditer(line):
            area, exchange, subscriber = m.groups()
            if not (exchange == "555" and subscriber.startswith("01")):  # reserved 555-01XX
                problems.append(f"line {number}: contains a phone number (use 555-01XX)")
        if is_fixture:
            for m in URL.finditer(line):
                if not _reserved_host(m.group(1)):
                    problems.append(f"line {number}: fixture URL is not on a reserved example domain")
    return problems


# --- 3. Privacy rules for source code ---------------------------------------------------------

SOURCE_DIRS = ("VetoCore/", "Veto/", "VetoMessageFilter/")
FORBIDDEN_CODE = (
    (re.compile(r"\bURLSession\b|\bNSURLSession\b|\bNSURLConnection\b|\bCFNetwork\b|\bNWConnection\b"),
     "uses a networking API"),
    (re.compile(r"^\s*(?:@_exported\s+)?import\s+(?:Network|WebKit|SafariServices|StoreKit)\b", re.M),
     "imports a networking/web framework"),
    (re.compile(r"\bWKWebView\b|\bSFSafariViewController\b"), "embeds a web view"),
    (re.compile(r"^\s*import\s+(?:Firebase\w*|Sentry|Crashlytics|Amplitude\w*|Mixpanel|Segment\w*|"
                r"AppsFlyer\w*|Adjust\w*|FBSDK\w*|GoogleMobileAds|Bugsnag|PostHog|Datadog\w*)\b", re.M),
     "imports an analytics/crash/ad SDK"),
    (re.compile(r"https?://(?!(?:[\w.-]*\.)?(?:example\.com|example\.org|example\.net|example)\b)"),
     "contains a hard-coded web URL"),
)
NETWORK_CONFIG_KEYS = ("ILMessageFilterExtensionNetworkURL", "NSAppTransportSecurity",
                       "NSAllowsArbitraryLoads")
DEPENDENCY_FILES = ("Package.swift", "Package.resolved", "Podfile", "Podfile.lock", "Cartfile")


def privacy_problems(path: str, text: str) -> list[str]:
    problems: list[str] = []
    name = path.rsplit("/", 1)[-1]
    if name in DEPENDENCY_FILES:
        problems.append("adds a third-party dependency manifest (Veto ships with no dependencies)")
    if path == "project.yml" and re.search(r"^\s*packages\s*:", text, re.M):
        problems.append("adds Swift package dependencies (Veto ships with no dependencies)")
    if path.endswith((".plist", "project.yml")):
        for key in NETWORK_CONFIG_KEYS:
            if key in text:
                problems.append(f"declares {key} (Veto must not use the network)")
    if path.startswith(SOURCE_DIRS) and path.endswith(".swift"):
        for number, line in enumerate(text.splitlines(), start=1):
            for pattern, why in FORBIDDEN_CODE:
                if pattern.search(line):
                    problems.append(f"line {number}: {why}")
    return problems


# --- 4. .gitignore ----------------------------------------------------------------------------

REQUIRED_IGNORES = (
    "ModelArtifacts/veto.mlpackage/",
    "ModelArtifacts/metadata.json",
    "ModelArtifacts/python_reference.json",
    "Config/Local.xcconfig",
    "*.xcodeproj/",
)


def gitignore_problems(text: str) -> list[str]:
    lines = {line.strip() for line in text.splitlines()}
    return [f".gitignore no longer ignores {entry}" for entry in REQUIRED_IGNORES if entry not in lines]


# --- Git plumbing -----------------------------------------------------------------------------

def git(*args: str, binary: bool = False):
    result = subprocess.run(["git", *args], check=True, capture_output=True)
    return result.stdout if binary else result.stdout.decode("utf-8", "replace")


def as_text(blob: bytes) -> str | None:
    if len(blob) > MAX_SCAN_BYTES or b"\x00" in blob[:8192]:
        return None
    return blob.decode("utf-8", "replace")


def check_file(path: str, blob: bytes, where: str) -> list[str]:
    reason = forbidden_path_reason(path)
    if reason:
        return [f"{where}: {path} {reason}"]
    text = as_text(blob)
    if text is None or path == "scripts/check_repo_safety.py" or path.startswith("scripts/test_check"):
        return []
    found = [f"{where}: {path} {p}" for p in content_problems(path, text)]
    found += [f"{where}: {path} {p}" for p in privacy_problems(path, text)]
    return found


def check_tree() -> list[str]:
    problems: list[str] = []
    for path in git("ls-files").splitlines():
        try:
            blob = git("show", f"HEAD:{path}", binary=True)
        except subprocess.CalledProcessError:
            continue
        problems += check_file(path, blob, "tracked")
        if path == ".gitignore":
            problems += [f"tracked: {p}" for p in gitignore_problems(blob.decode("utf-8", "replace"))]
    return problems


def check_history(rev_range: str | None) -> list[str]:
    problems: list[str] = []
    args = ["log", "--format=%H", "--name-only", "--diff-filter=AM"]
    args += [rev_range] if rev_range else ["--all"]
    seen: set[tuple[str, str]] = set()
    commit = ""
    for line in git(*args).splitlines():
        if not line:
            continue
        if re.fullmatch(r"[0-9a-f]{40}", line):
            commit = line
            continue
        if (commit, line) in seen:
            continue
        seen.add((commit, line))
        try:
            blob = git("show", f"{commit}:{line}", binary=True)
        except subprocess.CalledProcessError:
            continue
        problems += check_file(line, blob, f"commit {commit[:8]}")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--all-history", action="store_true", help="also check every commit")
    group.add_argument("--base", help="also check every commit in BASE..HEAD")
    args = parser.parse_args()

    problems = check_tree()
    if args.all_history:
        problems += check_history(None)
    elif args.base:
        problems += check_history(f"{args.base}..HEAD")

    if not problems:
        print("OK: no private artifacts, secrets or privacy-breaking code found.")
        return 0

    print("REPOSITORY SAFETY CHECK FAILED:\n", file=sys.stderr)
    for line in dict.fromkeys(problems):
        print(f"  - {line}", file=sys.stderr)
    print(
        "\nVeto's models, metadata, signing details and message data are private and must never be\n"
        "committed, and the app must not use the network. For the current tree: `git rm --cached\n"
        "<path>` and fix the code. If a commit in your branch added the problem, removing it in a\n"
        "later commit is NOT enough: rewrite your branch (squash or `git rebase -i`) so it never\n"
        "appears in history, and email dev.meisel+veto@gmail.com if anything private was already\n"
        "pushed. See CONTRIBUTING.md.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
