"""Gymnasium bridge to the real Godot combat, in an isolated training process."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

import gymnasium as gym
import numpy as np

ROOT = Path(__file__).resolve().parents[2]


class SpeciesWarCombatEnv(gym.Env):
    metadata = {"render_modes": []}

    def __init__(self, godot, log_path):
        self.observation_space = gym.spaces.Box(0.0, 1.0, shape=(28,), dtype=np.float32)
        self.action_space = gym.spaces.Discrete(5)
        self._tmp = tempfile.TemporaryDirectory(prefix="species-war-ai-", ignore_cleanup_errors=True)
        env = os.environ.copy()
        for key in ("APPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            path = Path(self._tmp.name) / key
            path.mkdir()
            env[key] = str(path)
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        env["COMBAT_AI_PORT"] = str(port)
        self._log = Path(log_path).open("w", encoding="utf-8")
        self._process = subprocess.Popen(
            [str(Path(godot).resolve()), "--headless", "--path", str(ROOT),
             "--script", "res://tools/combat_ai/CombatTrainingBridge.gd"],
            env=env, stdout=self._log, stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        self._socket = None
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            if self._process.poll() is not None:
                self.close()
                raise RuntimeError("Godot training bridge exited; inspect " + str(log_path))
            try:
                self._socket = socket.create_connection(("127.0.0.1", port), timeout=1)
                break
            except OSError:
                time.sleep(.05)
        if self._socket is None:
            self.close()
            raise TimeoutError("Godot training bridge did not start")
        self._socket.settimeout(60)
        self._reader = self._socket.makefile("rb")
        self.last_info = {}

    def _request(self, command, **args):
        self._socket.sendall((json.dumps(dict(command=command, **args)) + "\n").encode())
        line = self._reader.readline(1024 * 1024)
        if not line:
            raise RuntimeError("Godot training bridge disconnected")
        result = json.loads(line)
        if "error" in result:
            raise RuntimeError(result["error"])
        return result

    def reset(self, *, seed=None, options=None):
        super().reset(seed=seed)
        value = self._request("reset", seed=int(seed if seed is not None else self.np_random.integers(1, 2**31)))
        self.last_info = value["info"]
        return np.asarray(value["observation"], dtype=np.float32), value["info"]

    def step(self, action):
        if not self.action_space.contains(action):
            raise ValueError("Unknown combat tactic")
        value = self._request("step", action=int(action))
        self.last_info = value["info"]
        return (np.asarray(value["observation"], dtype=np.float32), float(value["reward"]),
                bool(value["terminated"]), bool(value["truncated"]), value["info"])

    def close(self):
        if self._socket is not None:
            try:
                if hasattr(self, "_reader"):
                    self._request("close")
                    self._reader.close()
            except (OSError, RuntimeError):
                pass
            self._socket.close()
            self._socket = None
        if self._process.poll() is None:
            try:
                self._process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self._process.terminate()
                self._process.wait(timeout=10)
        self._log.close()
        self._tmp.cleanup()
