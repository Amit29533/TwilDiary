import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('release_resources', Path(__file__).with_name('verify-release-resources.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseResourceTests(unittest.TestCase):
    def test_required_bundle_and_production_json(self):
        with tempfile.TemporaryDirectory() as folder:
            bundle = Path(folder) / 'TwilDiary.app'
            with self.assertRaises(ValueError):
                module.verify(bundle)
            bundle.mkdir()
            (bundle / 'demo-attribution.json').write_text('{}')
            module.verify(bundle)

    def test_nested_fixtures_fail_including_the_old_production_core_bundle(self):
        for name in ['workspace.json', 'reference-workspace.json', 'catalog-tv-1.json', 'trakt-sync.json', 'stats-golden.json']:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as folder:
                bundle = Path(folder)
                nested = bundle / 'TwilDiaryCore_TwilDiaryCore.bundle'
                nested.mkdir()
                (nested / name).write_text('{}')
                with self.assertRaisesRegex(ValueError, name):
                    module.verify(bundle)

    def test_test_support_bundle_itself_is_forbidden_even_if_empty(self):
        with tempfile.TemporaryDirectory() as folder:
            bundle = Path(folder)
            (bundle / 'TwilDiaryCore_TwilDiaryTestSupport.bundle').mkdir()
            with self.assertRaisesRegex(ValueError, 'TwilDiaryTestSupport'):
                module.verify(bundle)


if __name__ == '__main__':
    unittest.main()
