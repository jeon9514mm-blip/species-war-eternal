"""Train/evaluate tactic selection against the actual production combat."""
import argparse
import importlib.metadata
import json
import subprocess
from pathlib import Path

import torch
from stable_baselines3 import PPO
from stable_baselines3.common.env_checker import check_env

from godot_env import SpeciesWarCombatEnv, ROOT


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--steps", type=int, default=100_000)
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--resume", type=Path)
    args = parser.parse_args()
    if args.steps < 64:
        parser.error("Use at least 64 steps")
    args.output.mkdir(parents=True, exist_ok=True)
    parsed = subprocess.run([str(Path(args.godot).resolve()), '--headless', '--path', str(ROOT),
                             '--check-only', '--script', 'res://tools/combat_ai/CombatTrainingBridge.gd'],
                            capture_output=True, text=True, encoding='utf-8', timeout=60)
    if parsed.returncode or 'ERROR:' in parsed.stdout + parsed.stderr:
        raise RuntimeError('Training scripts failed to compile: ' + parsed.stdout + parsed.stderr)
    torch.set_num_threads(1)
    env = SpeciesWarCombatEnv(args.godot, args.output / "godot-training.log")
    try:
        check_env(env, warn=True)
        model = PPO.load(args.resume, env=env, device="cpu") if args.resume else PPO(
            "MlpPolicy", env, n_steps=64, batch_size=32, n_epochs=3,
            policy_kwargs={"net_arch": [32, 32]}, seed=args.seed, device="cpu", verbose=1,
        )
        model.learn(total_timesteps=args.steps, reset_num_timesteps=args.resume is None)
        model.save(args.output / "tactic-policy")
        restored = PPO.load(args.output / 'tactic-policy.zip', device='cpu')
        observation, _ = env.reset(seed=args.seed + 1000)
        trace = []
        for _ in range(32):
            action, _ = model.predict(observation, deterministic=True)
            restored_action, _ = restored.predict(observation, deterministic=True)
            assert int(action) == int(restored_action), 'Saved policy changed its prediction'
            observation, reward, terminated, truncated, info = env.step(int(action))
            trace.append(dict(info, reward=reward, observation=observation.tolist()))
            if terminated or truncated:
                break
        report = {
            "framework": "Stable-Baselines3 PPO", "production_combat": True,
            "training_steps": int(model.num_timesteps), "seed": args.seed,
            "gymnasium_check_env": "passed", "production_policy_replaced": False,
            "saved_policy_reload": "passed",
            "status": "integration_smoke_only" if args.steps < 100_000 else "candidate_requires_evaluation",
            "versions": {name: importlib.metadata.version(name) for name in ("stable-baselines3", "gymnasium", "torch", "numpy")},
            "tactics": ["existing_ai", "finish_wounded", "highest_threat", "enemy_support", "elite_focus"],
            "evaluation_trace": trace,
        }
        (args.output / "training-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    finally:
        env.close()
    log = (args.output / "godot-training.log").read_text(encoding="utf-8")
    if "SCRIPT ERROR" in log or "ERROR:" in log:
        raise RuntimeError("Godot emitted errors during training; inspect godot-training.log")
    print("COMBAT_AI_TRAINING_VERIFIED", args.output)


if __name__ == "__main__":
    main()
