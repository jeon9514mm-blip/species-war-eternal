#!/usr/bin/env python3
"""Summarize measured Godot combat rows; never convert check counts to completion."""
import argparse
import json
from pathlib import Path


def render(report):
    lines = [
        "# V27 실제 전투 밸런스 측정",
        "",
        "각 행은 실제 전투 함수로 진행한 60초 표본이다. 처치 수는 몬스터 개체 수가 아닌 무리 격파 수이다.",
        "오프라인 추정치는 같은 시작 전투력·시간의 결과이며 실제 온라인과 같거나 88%라는 뜻이 아니다.",
        "",
        "| 진영 | 사냥터 | 인원 | 레벨 / 장비 | 시드 | 무리 격파 | 온라인 골드 | 방치 골드 | 방치/온라인 | 재정비 |",
        "|---|---|---:|---|---:|---:|---:|---:|---:|---:|",
    ]
    for row in report["rows"]:
        faction = {"aurelia": "아우렐리아", "noxfera": "녹스페라"}[row["faction"]]
        zone = {"gray_meadow": "회색 초원", "forgotten_mine": "잊힌 광산", "moonrest_forest": "달잠 숲"}[row["zone"]]
        ratio = f'{row["offline_online_gold_ratio"]:.3f}' if row["online_gold"] else "정의 불가"
        lines.append(
            f'| {faction} | {zone} | {row["party_size"]} | {row["hero_level"]} / +{row["equipment_level"]} | '
            f'{row["seed"]} | {row["encounters_cleared"]} | {row["online_gold"]} | '
            f'{row["offline_gold_estimate"]} | {ratio} | {row["recoveries"]} |'
        )
    lines += [
        "",
        "## 실제 영웅 능력치",
        "",
        "10인 편성, 동일 레벨·일반 장비 기준. 역할별 피해·치유·제어 가치는 별도 실전 검증이 필요하다.",
        "",
        "| 진영 | 영웅 | 역할 | HP | 공격 | 방어 | 공격 주기 배율 |",
        "|---|---|---|---:|---:|---:|---:|",
    ]
    for hero in report["heroes"]:
        lines.append(
            f'| {hero["faction"]} | {hero["hero_id"]} | {hero["role"]} | {hero["max_hp"]} | '
            f'{hero["attack"]} | {hero["defense"]} | {hero["attack_interval_mult"]:.2f} |'
        )
    lines += ["", f'검사 실패: {len(report["failures"])}건. 체크 개수는 개발 완성도가 아니다.', ""]
    for failure in report["failures"]:
        lines.append("- " + failure)
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    report = json.loads(args.input.read_text(encoding="utf-8"))
    args.output.write_text(render(report), encoding="utf-8")


if __name__ == "__main__":
    main()
