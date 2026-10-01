#!/usr/bin/env python3
"""Build and verify a cumulative binary patch against the original project ZIP.

Stage new project files first; existing tracked files use their working-tree
contents. Untracked files are deliberately omitted. The ZIP is never modified.
Only publish while other editors have stopped changing the project.

Example:
    python tools/build_checkpoint.py --base original-v25.zip \
        --project . --output /path/to/checkpoint.patch
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath


EXCLUDED = {".git", ".godot"}


class CheckpointError(Exception):
    """A checkpoint could not be safely built or verified."""


def git_env() -> dict[str, str]:
    # Do not inherit repository redirection, external filters, or user hooks.
    env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    env.update({"GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull,
                "GIT_ATTR_NOSYSTEM": "1", "GIT_TERMINAL_PROMPT": "0",
                "LC_ALL": "C"})
    return env


def git(cwd: Path, *args: str, stdout=None) -> bytes:
    result = subprocess.run(
        ["git", *args], cwd=cwd, env=git_env(),
        stdout=subprocess.PIPE if stdout is None else stdout, stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode:
        error = result.stderr.decode("utf-8", "replace").strip()
        raise CheckpointError(f"git {' '.join(args)} failed: {error}")
    return result.stdout if stdout is None else b""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_parts(value: str) -> tuple[str, ...]:
    if not value or "\x00" in value or "\\" in value or value.startswith("/"):
        raise CheckpointError(f"Unsafe archive or tracked path: {value!r}")
    parts = tuple(value.rstrip("/").split("/"))
    if any(part in {"", ".", ".."} for part in parts) or re.match(r"^[A-Za-z]:", parts[0]):
        raise CheckpointError(f"Unsafe archive or tracked path: {value!r}")
    return parts


def validate_link(relative: str, target: str) -> None:
    if not target or "\x00" in target or "\\" in target or target.startswith("/"):
        raise CheckpointError(f"Unsafe symlink {relative!r} -> {target!r}")
    if re.match(r"^[A-Za-z]:", target):
        raise CheckpointError(f"Unsafe symlink {relative!r} -> {target!r}")
    stack = list(PurePosixPath(relative).parent.parts)
    for part in target.split("/"):
        if part in {"", "."}:
            continue
        if part == "..":
            if not stack:
                raise CheckpointError(f"Symlink escapes project: {relative!r} -> {target!r}")
            stack.pop()
        else:
            stack.append(part)
    if any(part in EXCLUDED for part in stack):
        raise CheckpointError(f"Symlink targets excluded metadata: {relative!r} -> {target!r}")


def check_parents(root: Path, relative: str) -> None:
    current = root
    for part in safe_parts(relative)[:-1]:
        current /= part
        if current.is_symlink():
            raise CheckpointError(f"Refusing a path below a symlink: {relative!r}")


def validate_tree_links(root: Path) -> None:
    # A lexically safe target can still escape through another symlink and
    # a later '..'. Validate the complete chain after all links are present.
    for directory, subdirectories, filenames in os.walk(root, followlinks=False):
        subdirectories[:] = [name for name in subdirectories if name not in EXCLUDED]
        for name in subdirectories + filenames:
            path = Path(directory) / name
            if not path.is_symlink():
                continue
            try:
                resolved = path.resolve(strict=False)
                relative = resolved.relative_to(root)
            except (ValueError, RuntimeError) as error:
                raise CheckpointError(f"Symlink chain escapes the project or loops: {path}") from error
            if any(part in EXCLUDED for part in relative.parts):
                raise CheckpointError(f"Symlink chain targets excluded metadata: {path}")


def extract_base(archive: Path, destination: Path) -> str:
    """Extract one top-level project folder, without following archive symlinks."""
    destination.mkdir(parents=True)
    with zipfile.ZipFile(archive) as source:
        records = [(info, safe_parts(info.filename)) for info in source.infolist()]
        roots = {parts[0] for _, parts in records}
        if len(roots) != 1:
            raise CheckpointError("Base ZIP must contain exactly one top-level project folder")
        root_name = next(iter(roots))
        seen: set[str] = set()
        links: list[tuple[str, str]] = []
        for info, parts in records:
            if len(parts) == 1:
                if not info.is_dir():
                    raise CheckpointError("Base ZIP contains a file outside the project folder")
                continue
            relative = "/".join(parts[1:])
            if any(part in EXCLUDED for part in parts[1:]):
                continue
            if relative in seen:
                raise CheckpointError(f"Duplicate archive path: {relative!r}")
            seen.add(relative)
            check_parents(destination, relative)
            output = destination.joinpath(*parts[1:])
            mode = info.external_attr >> 16
            kind = stat.S_IFMT(mode)
            if info.is_dir():
                if kind not in {0, stat.S_IFDIR}:
                    raise CheckpointError(f"Invalid archive directory: {relative!r}")
                output.mkdir(parents=True, exist_ok=True)
            elif kind == stat.S_IFLNK:
                target = os.fsdecode(source.read(info))
                validate_link(relative, target)
                links.append((relative, target))
            elif kind in {0, stat.S_IFREG}:
                output.parent.mkdir(parents=True, exist_ok=True)
                with source.open(info) as reader, output.open("xb") as writer:
                    shutil.copyfileobj(reader, writer)
                output.chmod(0o755 if mode & 0o111 else 0o644)
            else:
                raise CheckpointError(f"Unsupported archive file type: {relative!r}")
        # Create links last: no archive member can write through one.
        for relative, target in links:
            check_parents(destination, relative)
            output = destination / relative
            output.parent.mkdir(parents=True, exist_ok=True)
            if os.path.lexists(output):
                raise CheckpointError(f"Archive symlink conflicts with another member: {relative!r}")
            output.symlink_to(target)
    validate_tree_links(destination)
    return root_name


def tracked_files(project: Path) -> tuple[bytes, list[str], list[str]]:
    index = git(project, "ls-files", "--stage", "-z")
    paths, excluded = [], []
    for record in index.split(b"\0"):
        if not record:
            continue
        header, raw_path = record.split(b"\t", 1)
        mode, _, stage = header.split(b" ")
        relative = os.fsdecode(raw_path)
        parts = safe_parts(relative)
        if stage != b"0":
            raise CheckpointError(f"Resolve the index conflict first: {relative!r}")
        if mode == b"160000":
            raise CheckpointError(f"Submodules must be materialized before checkpointing: {relative!r}")
        if any(part in EXCLUDED for part in parts):
            excluded.append(relative)
        else:
            paths.append(relative)
    if not paths:
        raise CheckpointError("The project has no tracked files; stage the project first")
    return index, paths, excluded


def file_record(path: Path) -> dict:
    mode = path.lstat().st_mode
    if stat.S_ISLNK(mode):
        value = os.fsencode(os.readlink(path))
        return {"mode": "120000", "size": len(value), "sha256": hashlib.sha256(value).hexdigest()}
    if not stat.S_ISREG(mode):
        raise CheckpointError(f"Unsupported project file type: {path}")
    return {"mode": "100755" if mode & 0o111 else "100644",
            "size": path.stat().st_size, "sha256": sha256_file(path)}


def source_records(project: Path, paths: list[str]) -> tuple[dict, list[str]]:
    result, missing = {}, []
    for relative in paths:
        check_parents(project, relative)
        source = project / relative
        if not os.path.lexists(source):
            missing.append(relative)
            continue
        if source.is_symlink():
            validate_link(relative, os.readlink(source))
        result[relative] = file_record(source)
    return result, missing


def tree_records(root: Path) -> dict:
    result = {}

    def visit(directory: Path) -> None:
        for path in sorted(directory.iterdir()):
            if path.name in EXCLUDED:
                continue
            if path.is_dir() and not path.is_symlink():
                visit(path)
            else:
                result[path.relative_to(root).as_posix()] = file_record(path)

    visit(root)
    return result


def copy_target(project: Path, paths: list[str], destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    for relative in paths:
        source, output = project / relative, destination / relative
        check_parents(project, relative)
        if not os.path.lexists(source):
            continue
        output.parent.mkdir(parents=True, exist_ok=True)
        if source.is_symlink():
            target = os.readlink(source)
            validate_link(relative, target)
            output.symlink_to(target)
        elif source.is_file():
            shutil.copyfile(source, output)
            output.chmod(0o755 if source.stat().st_mode & 0o111 else 0o644)
        else:
            raise CheckpointError(f"Tracked file has an unsupported working-tree type: {relative!r}")
    validate_tree_links(destination)


def compare_records(expected: dict, actual: dict, label: str) -> None:
    missing = sorted(expected.keys() - actual.keys())
    extra = sorted(actual.keys() - expected.keys())
    changed = sorted(key for key in expected.keys() & actual.keys() if expected[key] != actual[key])
    if missing or extra or changed:
        raise CheckpointError(f"{label}: missing={missing[:8]!r}, extra={extra[:8]!r}, changed={changed[:8]!r}")


def prepare_git(root: Path) -> None:
    git(root, "init", "--quiet")
    for key, value in {
        "user.name": "Checkpoint Builder", "user.email": "checkpoint@localhost",
        "core.autocrlf": "false", "core.fileMode": "true", "core.symlinks": "true",
        "core.attributesFile": os.devnull, "core.hooksPath": os.devnull,
        "commit.gpgsign": "false",
    }.items():
        git(root, "config", key, value)
    # The highest-priority attributes preserve the actual bytes, even if a
    # project .gitattributes requests newline conversion or clean filters.
    (root / ".git/info/attributes").write_text(
        "* -text -filter -ident -working-tree-encoding !diff\n", encoding="utf-8")
    git(root, "add", "--all", "--force", "--", ".")
    git(root, "commit", "--quiet", "--allow-empty", "-m", "Original uploaded project")


def publish_file(source: Path, destination: Path) -> None:
    descriptor, name = tempfile.mkstemp(prefix=f".{destination.name}.", dir=destination.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, "wb") as writer, source.open("rb") as reader:
            shutil.copyfileobj(reader, writer)
            writer.flush()
            os.fsync(writer.fileno())
        temporary.chmod(0o644)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def build(base: Path, project: Path, output: Path) -> dict:
    if not base.is_file():
        raise CheckpointError(f"Base ZIP does not exist: {base}")
    git_root = Path(os.fsdecode(git(project, "rev-parse", "--show-toplevel")).rstrip("\n")).resolve()
    if git_root != project:
        raise CheckpointError(f"--project must be the Git repository root: {git_root}")
    if output == base or output == project or project in output.parents:
        raise CheckpointError("Write the checkpoint outside the project and do not overwrite the base ZIP")
    index, paths, excluded = tracked_files(project)
    initial_records, missing = source_records(project, paths)
    base_hash = sha256_file(base)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="pixel-rpg-checkpoint-") as temporary:
        work = Path(temporary)
        baseline, snapshot, roundtrip = work / "baseline", work / "snapshot", work / "roundtrip"
        root_name = extract_base(base, baseline)
        base_records = tree_records(baseline)
        prepare_git(baseline)
        copy_target(project, paths, snapshot)
        expected = tree_records(snapshot)
        compare_records(initial_records, expected, "Project changed while taking its snapshot")
        for item in baseline.iterdir():
            if item.name == ".git":
                continue
            if item.is_dir() and not item.is_symlink():
                shutil.rmtree(item)
            else:
                item.unlink()
        copy_target(snapshot, list(expected), baseline)
        git(baseline, "add", "--all", "--force", "--", ".")
        patch = work / "checkpoint.patch"
        with patch.open("wb") as stream:
            git(baseline, "diff", "--cached", "--binary", "--full-index", "--no-ext-diff",
                "--no-textconv", "--no-renames", "--src-prefix=a/", "--dst-prefix=b/", stdout=stream)
        extract_base(base, roundtrip)
        if patch.stat().st_size:
            git(roundtrip, "apply", "--check", "--whitespace=nowarn", str(patch))
            git(roundtrip, "apply", "--whitespace=nowarn", str(patch))
        actual = tree_records(roundtrip)
        compare_records(expected, actual, "Patch round-trip verification failed")
        final_index, final_paths, _ = tracked_files(project)
        final_records, final_missing = source_records(project, final_paths)
        if final_index != index or final_missing != missing:
            raise CheckpointError("Project index or file set changed during the build; retry after editing stops")
        compare_records(expected, final_records, "Project changed during verification; retry after editing stops")
        if sha256_file(base) != base_hash:
            raise CheckpointError("The base ZIP changed during the build")
        changed = sum(base_records.get(path) != expected.get(path)
                      for path in base_records.keys() | expected.keys())
        tree_digest = hashlib.sha256(json.dumps(expected, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        manifest = {
            "schema_version": 1,
            "created_utc": datetime.now(timezone.utc).isoformat(),
            "base_zip": {"name": base.name, "sha256": base_hash, "size": base.stat().st_size,
                         "top_level_directory": root_name, "file_count": len(base_records)},
            "project": {"name": project.name, "git_head": git(project, "rev-parse", "HEAD").decode().strip(),
                        "tracked_candidates": len(paths), "excluded_paths": excluded,
                        "deleted_tracked_paths": missing, "file_count": len(expected),
                        "total_file_bytes": sum(record["size"] for record in expected.values()),
                        "tree_sha256": tree_digest},
            "patch": {"name": output.name, "sha256": sha256_file(patch), "size": patch.stat().st_size,
                      "changed_files": changed},
            "verification": {"git_apply_check": bool(patch.stat().st_size),
                             "git_apply": bool(patch.stat().st_size),
                             "empty_patch": not bool(patch.stat().st_size),
                             "exact_paths_sha256_sizes_modes": True, "verified_files": len(actual)},
            "files": expected,
        }
        manifest_file = work / "manifest.json"
        manifest_file.write_text(json.dumps(manifest, ensure_ascii=True, indent=2, sort_keys=True) + "\n",
                                 encoding="utf-8")
        # Both files are prepared and validated before publication. The patch
        # itself is replaced last, atomically, and its sidecar records its hash.
        publish_file(manifest_file, Path(str(output) + ".manifest.json"))
        publish_file(patch, output)
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--base", type=Path, required=True, help="Original uploaded ZIP with one top-level folder")
    parser.add_argument("--project", type=Path, required=True, help="Project Git repository root")
    parser.add_argument("--output", type=Path, required=True, help="Patch filename outside the project")
    args = parser.parse_args()
    try:
        output = args.output.expanduser().resolve()
        manifest = build(args.base.expanduser().resolve(), args.project.expanduser().resolve(), output)
    except (CheckpointError, OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"Checkpoint was not published: {error}", file=sys.stderr)
        return 1
    print(json.dumps({"patch": str(output), "manifest": str(output) + ".manifest.json",
                      "files_verified": manifest["verification"]["verified_files"],
                      "changed_files": manifest["patch"]["changed_files"],
                      "patch_bytes": manifest["patch"]["size"],
                      "patch_sha256": manifest["patch"]["sha256"]}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
