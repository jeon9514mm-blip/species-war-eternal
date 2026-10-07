#!/usr/bin/env python3
"""Capture the actual Godot game on an existing desktop or an explicit Xorg server."""

import argparse
from contextlib import contextmanager
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time


ROOT = Path(__file__).resolve().parents[1]
ZONES = ("gray_meadow", "forgotten_mine", "moonrest_forest")
RENDERERS = ("mobile", "forward_plus", "gl_compatibility")


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--godot",
        default=os.environ.get("MAP_CAPTURE_GODOT") or os.environ.get("GODOT_BIN")
        or shutil.which("godot") or shutil.which("godot4"),
        help="Godot executable (MAP_CAPTURE_GODOT, GODOT_BIN, or godot/godot4 on PATH).",
    )
    parser.add_argument("--renderer", choices=RENDERERS,
                        default=os.environ.get("MAP_CAPTURE_RENDERER", "mobile"))
    parser.add_argument("--zone", choices=("all", *ZONES),
                        default=os.environ.get("MAP_CAPTURE_ZONE") or "all")
    parser.add_argument("--output", type=Path,
                        default=os.environ.get("MAP_CAPTURE_OUTPUT"),
                        help="Report directory containing logs and a captures/ subdirectory.")
    parser.add_argument("--display", help="Override DISPLAY; otherwise inherit the desktop display.")
    parser.add_argument("--xorg-config", type=Path,
                        help="Start a temporary Xorg server with this config; requires --display :N.")
    parser.add_argument("--timeout", type=float, default=480,
                        help="Godot timeout in seconds (default: 480).")
    parser.add_argument("--verbose", action="store_true",
                        default=os.environ.get("MAP_CAPTURE_VERBOSE") == "1")
    args = parser.parse_args()
    if not args.godot:
        parser.error("Godot was not found. Supply --godot or set GODOT_BIN.")
    # argparse does not validate string defaults against choices.
    if args.renderer not in RENDERERS or args.zone not in ("all", *ZONES):
        parser.error("Invalid MAP_CAPTURE_RENDERER or MAP_CAPTURE_ZONE value.")
    if args.timeout <= 0:
        parser.error("--timeout must be positive.")
    if os.environ.get("MAP_CAPTURE_RAID_ONLY") == "1":
        parser.error("This helper captures hunt maps; use capture_raid_battles.gd for raids.")
    if args.xorg_config:
        if not args.xorg_config.is_file():
            parser.error("--xorg-config must name an existing file.")
        if not args.display or not re.fullmatch(r":\d+", args.display):
            parser.error("--xorg-config requires an explicit local --display such as :96.")
    if args.output is None:
        args.output = ROOT / "checks/rune-stone-applied"
        if args.renderer == "forward_plus":
            args.output /= "forward-plus"
    args.output = args.output.expanduser().resolve()
    return args


@contextmanager
def display_server(args, env):
    """Only stop servers started here; never replace an existing desktop session."""
    if args.display:
        env["DISPLAY"] = args.display
    if not args.xorg_config:
        yield
        return
    xorg = shutil.which("Xorg")
    if not xorg:
        raise RuntimeError("Xorg is required only when using --xorg-config.")
    display_number = args.display[1:]
    socket = Path("/tmp/.X11-unix") / ("X" + display_number)
    lock = Path("/tmp") / (".X" + display_number + "-lock")
    if socket.exists() or lock.exists():
        raise RuntimeError(f"Display {args.display} is already in use; choose another --display.")
    with (args.output / "xorg.log").open("w", encoding="utf-8") as log:
        server = subprocess.Popen(
            [xorg, args.display, "-config", str(args.xorg_config.resolve()),
             "-logfile", str(args.output / "xorg-server.log"),
             "-nolisten", "tcp", "-noreset", "-ac"],
            env=env, stdout=log, stderr=subprocess.STDOUT,
        )
        try:
            deadline = time.monotonic() + 10
            while not socket.exists():
                if server.poll() is not None or time.monotonic() >= deadline:
                    raise RuntimeError(f"Display failed; see {args.output / 'xorg.log'}")
                time.sleep(0.1)
            yield
        finally:
            if server.poll() is None:
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait()


def main():
    args = arguments()
    args.output.mkdir(parents=True, exist_ok=True)
    captures = args.output / "captures"
    captures.mkdir(exist_ok=True)
    env = os.environ.copy()  # Keep the user's GPU driver and display configuration.
    with tempfile.TemporaryDirectory(prefix="rune-stone-capture-") as temporary:
        temporary_root = Path(temporary)
        for key, directory in (
            ("XDG_CACHE_HOME", "cache"), ("XDG_CONFIG_HOME", "config"),
            ("XDG_DATA_HOME", "data"), ("APPDATA", "appdata"),
            ("LOCALAPPDATA", "localappdata"), ("MAP_CAPTURE_USER_DATA", "saves"),
        ):
            path = temporary_root / directory
            path.mkdir()
            env[key] = str(path)
        env.update(MAP_CAPTURE_ZONE=args.zone, MAP_CAPTURE_RENDERER=args.renderer,
                   MAP_CAPTURE_OUTPUT=str(captures))
        with display_server(args, env):
            command = [args.godot, "--path", str(ROOT),
                       "--rendering-method", args.renderer, "--audio-driver", "Dummy",
                       "--disable-vsync", "--script", "tools/capture_rune_stone.gd"]
            if args.display:
                command += ["--display-driver", "x11"]
            if args.verbose:
                command.append("--verbose")
            command += ["--", "--output", str(captures), "--zone", args.zone]
            log_path = args.output / f"render-{args.zone}-{args.renderer}.log"
            with log_path.open("w", encoding="utf-8") as log:
                subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT,
                               timeout=args.timeout, check=True)
            log_text = log_path.read_text(encoding="utf-8", errors="replace")
            if any(marker in log_text for marker in ("ERROR:", "SHADER ERROR", "SCRIPT ERROR")):
                raise RuntimeError(f"Godot capture reported errors: {log_path}")
            selected_zones = ZONES if args.zone == "all" else (args.zone,)
            for zone in selected_zones:
                for state in ("ready", "combat"):
                    label = f"{zone}-{state}"
                    if f"RUNE_STONE_CAPTURE {label} " not in log_text:
                        raise RuntimeError(f"Missing capture {label}; see {log_path}")
                    if not all((captures / (label + suffix)).is_file() for suffix in (".png", ".json")):
                        raise RuntimeError(f"Missing image or metadata for {label}: {captures}")
    print(f"RUNE_STONE_RENDER_OK {captures}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error)) from error
