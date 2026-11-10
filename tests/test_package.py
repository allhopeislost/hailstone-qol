import importlib.util
from pathlib import Path
import tempfile
import unittest


PACKAGE_TOOL = Path(__file__).resolve().parents[1] / "tools" / "package.py"
spec = importlib.util.spec_from_file_location("qol_package", PACKAGE_TOOL)
package = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(package)


class PackageStagingTests(unittest.TestCase):
    @staticmethod
    def make_source(root, include_ui=True):
        for index, relative in enumerate(package.RUNTIME_FILES):
            if not include_ui and relative.startswith("ui/"):
                continue
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f"runtime-{index}", encoding="utf-8")

    def test_stages_only_declared_runtime_files(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "source"
            stage = Path(temp) / "stage"
            self.make_source(root)

            for relative in ("README.md", "AGENTS.md", "tools/package.py", "tests/test_package.py",
                             "qol-0.1.0.zip", "hailstone-addon.txt"):
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("not runtime", encoding="utf-8")

            staged = package.stage_runtime(root, stage)
            actual = tuple(sorted(path.relative_to(stage).as_posix() for path in stage.rglob("*") if path.is_file()))
            self.assertEqual(tuple(sorted(package.RUNTIME_FILES)), actual)
            self.assertEqual(tuple(package.RUNTIME_FILES), staged)

    def test_fails_if_allowlisted_runtime_file_is_missing(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "source"
            (root / "init.lua").parent.mkdir(parents=True)
            (root / "init.lua").write_text("return true", encoding="utf-8")
            with self.assertRaises(FileNotFoundError):
                package.stage_runtime(root, Path(temp) / "stage")

    def test_rejects_symlinked_runtime_ancestor(self):
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            root = temp / "source"
            linked_ui = temp / "linked-ui"
            self.make_source(root, include_ui=False)
            for relative in package.RUNTIME_FILES:
                if relative.startswith("ui/"):
                    path = linked_ui / relative.removeprefix("ui/")
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text("runtime", encoding="utf-8")
            (root / "ui").symlink_to(linked_ui, target_is_directory=True)

            with self.assertRaisesRegex(FileNotFoundError, "must not use symlinks"):
                package.stage_runtime(root, temp / "stage")


class PackageOutputTests(unittest.TestCase):
    def test_rejects_output_in_source_tree(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "source"
            root.mkdir()
            with self.assertRaisesRegex(ValueError, "outside the source tree"):
                package.resolve_output(root / "release", root)

    def test_rejects_output_symlink_resolving_into_source_tree(self):
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            root = temp / "source"
            (root / "release").mkdir(parents=True)
            alias = temp / "release-alias"
            alias.symlink_to(root / "release", target_is_directory=True)
            with self.assertRaisesRegex(ValueError, "outside the source tree"):
                package.resolve_output(alias, root)


if __name__ == "__main__":
    unittest.main()
