"""Summarize preserved observations without turning unknown failures into passes."""
import json,re
from pathlib import Path
repo=Path(__file__).resolve().parents[3]
audit=repo/'checks/game-audit-2026-10-07';visual=repo/'checks/mobile25d-spec-2026-10-07'
def read(path):return json.loads(path.read_text(encoding='utf-8'))
all_tests=read(audit/'all-runtime-regressions-final.json');effective={r['test']:r for r in all_tests['results']}
reruns=[]
for name in ['final-focused-regressions.json','final-raid-floor-regressions.json','final-feedback-regressions.json']:
    path=visual/name
    if path.exists():
        data=read(path);reruns.append({'file':name,'passed':data['passed'],'total':data['total']})
        for row in data['results']:effective[row['test']]=row
baseline={r['test']:r for r in read(audit/'baseline-comparison.json')['results']}
failed=[]
for name,row in sorted(effective.items()):
    if row['passed']:continue
    errors=[line for line in row['output'].splitlines() if 'ERROR:' in line or 'FAIL:' in line][:3]
    failed.append({'test':name,'also_failed_original_commit':name in baseline and not baseline[name]['passed'],'first_errors':errors,'timeout':'timed out' in row['output']})
performance=read(visual/'review-mobile/performance.json')
observations=read(visual/'captures/observations.json')
summary={'date':'2026-10-08','baseline_commit':'0b559b37c7bf95da2a17897227b2ddb7867a9202','whole_sweep':{'passed':all_tests['passed'],'total':all_tests['total'],'note':'Whole sweep ran during implementation; subsequent focused reruns supersede their matching rows only.'},'focused_reruns':reruns,'latest_known_results':{'passed':sum(r['passed'] for r in effective.values()),'total':len(effective),'all_green':all(r['passed'] for r in effective.values())},'failures':failed,'gpu':{k:performance[k] for k in ['device','renderer','engine','android_measured','profiles']},'observations':{'ui_captures':len(observations['screens']),'hunt_samples':len(observations['hunt_samples']),'raid_samples':len(observations['raid_samples']),'hero_overlap_samples':sum(row['body_overlaps']['hero_hero']>0 for row in observations['hunt_samples'])},'python_tests':{'passed':50,'total':50},'static_and_architecture':'passed; see validation-final.json'}
(audit/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
profiles='\n'.join('| '+row['label']+' | %.2f | %.2f | %.1f MB | %d |'%(row['mean_fps'],row['p95_frame_ms'],row['texture_bytes']/1e6,row['enemy_alive']) for row in performance['profiles'])
rows='\n'.join('| '+r['test']+' | '+('원본에서도 실패 확인' if r['also_failed_original_commit'] else '기대치/실행 경로 추가 재현 필요')+' | '+('시간 초과' if r['timeout'] else '; '.join(r['first_errors']).replace('|','/')[:190])+' |' for r in failed)
text=f'''# 전체 점검·개선 기록 — 2026-10-08

기준 코드 {summary['baseline_commit']}. 실제 사용자 저장 대신 임시 APPDATA/XDG로 실행했습니다. 사용자 요청의 10개 그래픽/움직임 사양을 적용하며 전투·화면·보상·저장·성능·과거 회귀를 함께 점검했습니다. [최신 사양/화면/영상](../mobile25d-spec-2026-10-07/README.md).

## 발견 후 수정

| 문제 | 수정·근거 |
|---|---|
| 사냥 숫자의 낮은 표시 순서와 조기 퇴장 | 숫자z105/보상z106, 잘못 병렬 연결된 hold/퇴장을 .32+.28=.60초로 수정. 실제 GPU 숫자와 .39/.59/.61초 수명 검사 통과 |
| 카메라 호흡/줌과 레이드 터치 좌표 불일치 | 카메라의 실제 역투영으로 이동 명령 변환, 경고/선택/2D arena도 매 프레임 같은 투영. RaidDesign/RaidTouch 통과 |
| 큰 보스 머리와 영웅 추격이 화면 경계를 넘음 | 보스 머리/바닥/컨텍스트 여백 동시 보정. 영웅 세로 추격1.85로 제한, 크기86.4 유지. StableFacing 통과 |
| 전장 외곽의 빈 배경과 바닥 중복 그리기 | PBR 석판 plane80×60, 숨겨진 이전 바닥 draw 제거. 석재 UV 밀도 유지 |
| 동일 atlas의 공격/대기에서 털이 이전 cell을 사용 | atlas 경로 대신 실제 cell region으로 캐시. 16몬스터/보스의 실제 메시/털/공유 텍스처 검사 |
| 불필요한 대형 기존 텍스처 상시 로드 | 기존 영웅6boards/몬스터sheets를 요청 시 로드. 같은 GPU 측정의 약188MB→112MB |
| CPU 위치 계획/경로/공격 검사 반복 | 위치계획.10–.12초, exact segment cache+AABB broadphase, 타깃 단건 검사, body solve8회+기존 rescue. 동일360스텝 진단에서35.10→19.94ms/step. 실제 독립 교전/유효 이동 회귀 통과 |
| 일반 사냥의 프레임당 계산 부담 | 전경 시뮬레이션 누적 시간20Hz. 렌더/입력은 계속 갱신. 최대50ms 판정 간격은 명시적 동작 변경 |
| 순식간에 종료하는 검사 audio 정리 누락 | BM fixture audio shutdown/정리 대기. 재검사 통과. 다른 오래된 fixture의 종료 누수는 통과로 바꾸지 않음 |
| multipart 검사 안전 경로 요구 불충족 | 격리 폴더 이름에 art-pilot 포함. 이후 오래된 observe_game/hold_demo API 의존은 별도 미해결 |

## 성능과 남은 우선순위

GTX1050/Windows, Mobile, 효과 켜짐. Android 실기기는 측정하지 않았습니다. **60fps 미달**입니다. [원본 측정 JSON](../mobile25d-spec-2026-10-07/review-mobile/performance.json).

| 프로필 | 평균fps | p95 frame ms | texture memory | 살아있는 일반 적 |
|---|---|---|---|---|
{profiles}

1. 화면 품질: 참고 이미지와 비교한 원화 명암·발광 문양·보상 광기둥의 밀도/재질 조화. 수치 적용을 시각 품질 달성으로 대신하지 않음.
2. 성능: CPU simulation spike와 약500 draw calls 줄이기. Forward+ SDFGI의 추가 메모리는 Mobile 예산에 포함하지 않음. 실제 휴대폰의 GPU/발열/배터리와 장시간 측정 필요.
3. 검사 유지: 구세대 세로 UI, 장애물17개, 이전 atlas/스켈레톤, 삭제한 스킬 VFX, 고정 world height를 전제로 한 검사와 현재 사양을 대조. 검사 삭제나 임의 완화로 통과시키지 않음.
4. 경제/전투 후보: forest 장기 clear, offline reward fixture, field save barrier, dead-boss callbacks의 실패 원인을 최신 실제 플레이 경로에서 추가 재현. 이번 변경만의 신규 버그라고 단정하지 않음. Ledger/GameplayReliability/도전·보상 관련 현재 검사 통과 기록도 함께 보존.

## 검증과 한계

전체234개 실행: 최초 {all_tests['passed']}/234 통과. 이후 집중 재검사 파일은 summary.json에 기록하며 해당 이름의 결과만 갱신합니다. 최신 확인 결과는 **{summary['latest_known_results']['passed']}/{len(effective)}**, 전부 통과한 상태가 아닙니다. Python50/50·static/resources/architecture 통과. 초기 구문508/509 중 LandingScreens 엔진 프로세스 종료는 단독 재검사 통과했으며 변경 소스는 별도 최종 검사 기록에 남깁니다.

[전체 실행 원본](all-runtime-regressions-final.json), [전체 구문 원본](all-regressions-final.json), [이전 커밋에서 재현 비교](baseline-comparison.json), [요약](summary.json). 원본 비교는 이전 커밋의 코드/검사와 변경되지 않은 기존 에셋·import cache를 사용했습니다. 신규 mobile 에셋은 이전 코드에서 참조하지 않습니다.

실제 GPU 관찰: UI {summary['observations']['ui_captures']}화면, 양 진영10인 사냥600표본, 레이드{summary['observations']['raid_samples']}표본. **영웅 몸체 겹침 표본 {summary['observations']['hero_overlap_samples']}건**. 무기/털/공격 원화의 투명 외곽 접촉은 몸체 판정과 다릅니다. 30초 관찰을 모든 조건의 무겹침 보장으로 표시하지 않습니다. 버튼 사각형 교차는 스크롤/부모/모달의 의도된 겹침도 포함하므로 자동 검출만으로 UI 버그라 하지 않습니다.

## 남은 실패 목록

| 검사 | 이전 코드 비교 | 최초 오류/상태 |
|---|---|---|
{rows}
'''
(audit/'README.md').write_text(text,encoding='utf-8')
status_path=repo/'DEVELOPMENT_STATUS.json';status=read(status_path)
status.update({'workstream':'user_spec_mobile25d_and_whole_game_audit','status':'implemented_with_documented_quality_and_performance_limits','all_historical_tests_executed':True,'combat_movement_rules_changed':True,'combat_damage_rules_changed':False,'android_tests':0})
status['latest_mobile25d']={'date':'2026-10-08','heroes':30,'ordinary_monsters':13,'raid_bosses':3,'hero_display_pixels':86.4,'circle_radius_pixels':120,'circle_step_degrees':36,'hero_triangles':6600,'hero_hair_cards':300,'monster_body_triangles':3000,'monster_fur_layers':4,'shared_texture_size':1024,'renderer':'mobile','fully_skinned_anatomical_3d':False,'contact_global_time_scale':.1,'contact_seconds':.06,'foreground_hunt_simulation_hz':20,'sixty_fps_verified':False,'android_measured':False,'graphics_reference_quality_approved':False,'focused_reruns':reruns,'whole_sweep':summary['whole_sweep'],'latest_known_results':summary['latest_known_results'],'actual_measurements':'checks/mobile25d-spec-2026-10-07/review-mobile/performance.json','review':'checks/mobile25d-spec-2026-10-07/README.md','audit':'checks/game-audit-2026-10-07/README.md'}
status_path.write_text(json.dumps(status,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('REVIEW_REPORT_OK',summary['latest_known_results'])
