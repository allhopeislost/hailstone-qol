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
    def test_caps_ceiling(self):
        # packets: the pet chain watches the outgoing pet orders with hs.on_packet
        self.assertEqual(package.CAPS, "read,ui,extend,commands,actions,target,move,packets")

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


DEPLOY_TOOL = Path(__file__).resolve().parents[1] / "tools" / "deploy_local.py"
deploy_spec = importlib.util.spec_from_file_location("qol_deploy", DEPLOY_TOOL)
deploy_local = importlib.util.module_from_spec(deploy_spec)
assert deploy_spec.loader is not None
deploy_spec.loader.exec_module(deploy_local)


class DeployLocalTests(unittest.TestCase):
    def setUp(self):
        self._temp = tempfile.TemporaryDirectory()
        temp = Path(self._temp.name)
        self.source = temp / "source"
        self.home = temp / "home"
        PackageStagingTests.make_source(self.source)
        (self.home / "scripts").mkdir(parents=True)

    def tearDown(self):
        self._temp.cleanup()

    def test_replaces_old_files_with_runtime_files_only(self):
        old = self.home / "scripts" / "qol"
        old.mkdir()
        (old / "init.lua").write_text("old", encoding="utf-8")
        (old / "info.lua").write_text("stale root file", encoding="utf-8")
        target, staged = deploy_local.deploy(self.source, self.home)
        actual = tuple(sorted(p.relative_to(target).as_posix() for p in target.rglob("*") if p.is_file()))
        self.assertEqual(tuple(sorted(package.RUNTIME_FILES)), actual)
        self.assertEqual(tuple(package.RUNTIME_FILES), staged)

    def test_refuses_while_the_manager_has_qol(self):
        (self.home / "addons").mkdir()
        (self.home / "addons" / "installed.txt").write_text(
            "hailstone-addons 1\n\naddon qol script\nversion 0.2.6\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "add-on manager"):
            deploy_local.deploy(self.source, self.home)
        self.assertFalse((self.home / "scripts" / "qol").exists())

    def test_other_managed_addons_do_not_block(self):
        (self.home / "addons").mkdir()
        (self.home / "addons" / "installed.txt").write_text(
            "hailstone-addons 1\n\naddon dpsmeter script\n", encoding="utf-8")
        deploy_local.deploy(self.source, self.home)
        self.assertTrue((self.home / "scripts" / "qol" / "init.lua").is_file())

    def test_refuses_a_folder_that_is_not_this_addon(self):
        other = self.home / "scripts" / "qol"
        other.mkdir()
        (other / "notes.txt").write_text("mine", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "does not look like"):
            deploy_local.deploy(self.source, self.home)
        self.assertTrue((other / "notes.txt").is_file())

    def test_refuses_a_folder_without_scripts(self):
        with self.assertRaisesRegex(ValueError, "not a Hailstone folder"):
            deploy_local.deploy(self.source, self.source)


RELEASE_TOOL = Path(__file__).resolve().parents[1] / "tools" / "release.py"
release_spec = importlib.util.spec_from_file_location("qol_release", RELEASE_TOOL)
release = importlib.util.module_from_spec(release_spec)
assert release_spec.loader is not None
release_spec.loader.exec_module(release)


class ReleaseHelperTests(unittest.TestCase):
    def test_parse_version(self):
        self.assertEqual((0, 2, 10), release.parse_version("0.2.10"))
        self.assertGreater(release.parse_version("0.2.10"), release.parse_version("0.2.9"))
        for bad in ("0.2", "v0.2.7", "0.2.7-rc1", ""):
            with self.assertRaises(ValueError):
                release.parse_version(bad)

    def test_bump_package_version(self):
        text = 'a = 1\nVERSION = "0.2.6"\nb = VERSION\n'
        self.assertEqual('a = 1\nVERSION = "0.3.0"\nb = VERSION\n', release.bump_package_version(text, "0.3.0"))
        with self.assertRaises(ValueError):
            release.bump_package_version("nothing here", "0.3.0")

    def test_notes(self):
        self.assertEqual("## Changes\n\n- One\n- Two\n", release.make_notes(["One", " Two "], False))
        maintenance = release.make_notes(["Moved files"], True)
        self.assertTrue(maintenance.startswith("## Maintenance release\n"))
        self.assertIn("- Moved files", maintenance)
        self.assertNotIn("ermission", release.make_notes(["x"], False) + maintenance)
        with self.assertRaises(ValueError):
            release.make_notes([], False)


if __name__ == "__main__":
    unittest.main()
