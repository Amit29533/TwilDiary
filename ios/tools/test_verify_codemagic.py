import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("promotion", Path(__file__).with_name("verify-codemagic.py"))
promotion = importlib.util.module_from_spec(spec)
spec.loader.exec_module(promotion)


class PromotionTests(unittest.TestCase):
    def check(self, **updates):
        return dict(id=1, head_sha="source", app={"slug": "codemagic-ci-cd"},
                    name=promotion.CHECK_NAME, status="completed", conclusion="success",
                    html_url="https://example.com/check", **updates)

    def test_success_requires_exact_source_and_official_app(self):
        good = self.check()
        self.assertEqual(promotion.accepted_check([{"check_runs": [good]}], "source"), good)
        for changed in [{"head_sha": "other"}, {"app": {"slug": "github-actions"}}, {"name": "other"}]:
            bad = {**good, **changed}
            with self.assertRaises(ValueError):
                promotion.accepted_check([{"check_runs": [bad]}], "source")

    def test_missing_pending_failed_and_cancelled_are_blocked(self):
        with self.assertRaises(ValueError):
            promotion.accepted_check([], "source")
        for status, conclusion in [("in_progress", None), ("queued", None),
                                   ("completed", "failure"), ("completed", "cancelled")]:
            check = {**self.check(), "status": status, "conclusion": conclusion}
            with self.assertRaises(ValueError):
                promotion.accepted_check([{"check_runs": [check]}], "source")

    def test_newer_failure_overrides_older_success_across_pages(self):
        good = self.check()
        newer = {**good, "id": 2, "conclusion": "failure"}
        with self.assertRaises(ValueError):
            promotion.accepted_check([{"check_runs": [good]}, {"check_runs": [newer]}], "source")


if __name__ == "__main__":
    unittest.main()
