"""Shared source/test discovery for the organized Godot project."""
from pathlib import Path

REGRESSION_DIRECTORY = Path("tests/regression")
IGNORED_DIRECTORIES = {".git", ".godot", "__pycache__"}


def source_scripts(root: Path) -> list[Path]:
    return sorted(path for path in root.rglob("*.gd")
                  if not IGNORED_DIRECTORIES.intersection(path.relative_to(root).parts))


def regression_tests(root: Path) -> list[Path]:
    """Executable regressions only; support hosts/bases are not entrypoints."""
    return sorted((root / REGRESSION_DIRECTORY).rglob("*Test.gd"))


def select_tests(root: Path, names: list[str] | None = None) -> list[Path]:
    available = regression_tests(root)
    if not available:
        raise ValueError("No regression scripts found in tests/regression")
    if names is None:
        return available
    selected = []
    for name in names:
        # Preserve the existing filename CLI while also accepting documented
        # project-relative and res:// paths; neither can escape the test list.
        normalized = name.removeprefix("res://").replace("\\", "/")
        matches = [path for path in available
                   if normalized in (path.name, path.relative_to(root).as_posix())]
        if len(matches) != 1:
            raise ValueError("Unknown or ambiguous regression script: " + name)
        if matches[0] not in selected:
            selected.append(matches[0])
    return selected


def resource_path(root: Path, path: Path) -> str:
    return "res://" + path.relative_to(root).as_posix()


def test_resource(root: Path, name: str) -> str:
    return resource_path(root, select_tests(root, [name])[0])
