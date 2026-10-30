"""Tests for check_repo_safety.py. Run: python3 -m unittest scripts/test_check_repo_safety.py

Fake secrets are assembled at runtime so this file never contains a real-looking secret.
"""
import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location(
    "check_repo_safety", pathlib.Path(__file__).with_name("check_repo_safety.py"))
safety = importlib.util.module_from_spec(spec)
spec.loader.exec_module(safety)


class PathTests(unittest.TestCase):
    def test_private_artifacts_are_forbidden(self):
        for path in ("ModelArtifacts/veto.mlpackage/Manifest.json", "x/model.mlmodel", "a/b.mlmodelc/c",
                     "ModelArtifacts/metadata.json", "ModelArtifacts/python_reference.json",
                     "Config/Local.xcconfig", "Veto.xcodeproj/project.pbxproj", "a/xcuserdata/u.xcuserstate",
                     "cert.p12", "profile.mobileprovision", "weights.safetensors", "chat.db", ".env",
                     "build/Veto.app/x", "perf-results/run.json", "Veto.ipa"):
            self.assertIsNotNone(safety.forbidden_path_reason(path), path)

    def test_public_files_are_allowed(self):
        for path in ("Config/Local.xcconfig.example", "ModelArtifacts/tokenizer/vocab.txt",
                     "ModelArtifacts/tokenizer/golden_tokenization.json",
                     "VetoTests/Fixtures/synthetic_metadata.json", "project.yml", "VetoCore/x.swift"):
            self.assertIsNone(safety.forbidden_path_reason(path), path)


class ContentTests(unittest.TestCase):
    def found(self, text, path="docs/x.md"):
        return safety.content_problems(path, text)

    def test_secrets_are_detected(self):
        self.assertTrue(self.found("-----BEGIN " + "RSA PRIVATE KEY-----"))
        self.assertTrue(self.found("key = AKIA" + "A" * 16))
        self.assertTrue(self.found("token ghp_" + "a" * 36))

    def test_team_ids(self):
        self.assertTrue(self.found("DEVELOPMENT_TEAM = " + "Q1W2E3R4T5"))
        self.assertFalse(self.found("DEVELOPMENT_TEAM = ABCDE12345"))
        self.assertFalse(self.found("DEVELOPMENT_TEAM = XXXXXXXXXX"))
        self.assertFalse(self.found("DEVELOPMENT_TEAM ="))
        self.assertTrue(self.found("CN=Apple Development: Jane Doe (" + "Q1W2E3R4T5)"))

    def test_home_paths(self):
        self.assertTrue(self.found("/Users/" + "jane/Code/x"))
        self.assertTrue(self.found("/home/" + "jane/x"))
        self.assertFalse(self.found("/path/to/veto/dist"))

    def test_emails_and_phones(self):
        self.assertTrue(self.found("write to jane" + "@mail.com"))
        self.assertFalse(self.found("write to dev.meisel+veto@gmail.com"))
        self.assertTrue(self.found("call (415) 867-5309"))
        self.assertTrue(self.found("call 415-867-5309"))
        self.assertFalse(self.found("call (415) 555-0123"))
        self.assertFalse(self.found("threshold 0.8699771761894226 and 12345678"))

    def test_fixture_urls_must_be_reserved(self):
        fixture = "VetoTests/Fixtures/edge.json"
        self.assertTrue(safety.content_problems(fixture, "see https://real-site.org/x"))
        self.assertFalse(safety.content_problems(fixture, "see https://vote-now.example/Ab12"))
        self.assertFalse(safety.content_problems(fixture, "see https://www.Example.com/path"))
        self.assertFalse(safety.content_problems("docs/x.md", "see https://github.com/x"))


class PrivacyTests(unittest.TestCase):
    def found(self, text, path="VetoCore/X.swift"):
        return safety.privacy_problems(path, text)

    def test_network_code_is_rejected(self):
        self.assertTrue(self.found("let s = URLSession.shared"))
        self.assertTrue(self.found("import Network"))
        self.assertTrue(self.found("import FirebaseAnalytics"))
        self.assertTrue(self.found('let u = "https://api.real.com"'))
        self.assertTrue(self.found("let c = NWConnection()", path="VetoMessageFilter/E.swift"))

    def test_clean_code_passes(self):
        self.assertFalse(self.found("import CoreML\nimport Foundation\nlet x = 1"))
        self.assertFalse(self.found("let u = URLSession.shared", path="VetoTests/T.swift"))

    def test_network_config_and_dependencies(self):
        self.assertTrue(safety.privacy_problems("VetoMessageFilter/Info.plist", "ILMessageFilterExtensionNetworkURL"))
        self.assertTrue(safety.privacy_problems("Package.swift", "// pkg"))
        self.assertTrue(safety.privacy_problems("project.yml", "packages:\n  Foo:"))
        self.assertFalse(safety.privacy_problems("project.yml", "targets:\n  Veto:"))


class GitignoreTests(unittest.TestCase):
    def test_required_entries(self):
        good = "\n".join(safety.REQUIRED_IGNORES)
        self.assertEqual(safety.gitignore_problems(good), [])
        self.assertTrue(safety.gitignore_problems(good.replace("ModelArtifacts/metadata.json", "")))


if __name__ == "__main__":
    unittest.main()
