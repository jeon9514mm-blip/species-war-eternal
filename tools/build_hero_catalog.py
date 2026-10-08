#!/usr/bin/env python3
"""Build an offline 30-hero gallery from Godot-exported data and unchanged PNGs."""
import base64
from collections import Counter
import hashlib
import html
from html.parser import HTMLParser
from io import BytesIO
import json
from pathlib import Path
import re
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "hero-catalog-2026-10-08"
SLOTS = {"passive": "패시브", "a1": "액티브 1", "a2": "액티브 2", "ultimate": "궁극기"}
KINDS = {"damage": "공격", "lifesteal": "공격 · 흡혈", "heal": "치유", "guard": "피해 감소",
         "stun": "공격 · 기절", "weaken": "공격 약화", "vulnerable": "받는 피해 증가",
         "barrier": "보호막", "passive": "조건부 자동 발동"}
EVENTS = {"basic": "기본 공격", "hit": "피해를 받은 뒤", "cast": "액티브 또는 궁극기 사용"}
CONDITIONS = {"always": "추가 조건 없음", "guarded": "자신에게 피해 감소가 활성화됨",
              "injured_ally": "다친 아군이 있음", "two_injured": "다친 아군이 2명 이상",
              "shielded_ally": "보호막을 가진 아군이 있음", "self_low": "자신의 HP가 50% 이하",
              "target_low": "대상 HP가 35% 이하", "elite": "정예 대상",
              "many_enemies": "레이드를 제외한 생존 적이 2명 이상", "moved": "이동 준비 조건 충족",
              "controlled": "기절한 적이 있음", "weakened": "공격 약화된 적이 있음",
              "vulnerable": "취약한 적이 있음", "debuffed": "기절·약화·취약 중 하나가 있는 적이 있음",
              "same_target": "같은 적을 연속 공격함"}
ACTIONS = {"energy": "자신의 궁극기 게이지 증가", "damage": "공격력 비례 추가 피해",
           "cooldown": "액티브 2 남은 쿨타임 감소", "heal": "자신의 최대 HP 비례 회복",
           "ally_heal": "최저 체력 비율 아군 회복", "shield": "자신에게 보호막",
           "ally_shield": "최저 체력 비율 아군에게 보호막", "guard": "자신의 피해 감소",
           "ally_guard": "최저 체력 비율 아군의 피해 감소"}
LABELS = {"value": "기본 효과 값", "cooldown": "기본 쿨타임", "duration": "효과 지속", "event": "발동 계기",
          "condition": "발동 조건", "action": "패시브 효과", "every": "조건 충족 횟수", "guard_scope": "보호 범위",
          "shield": "보호막", "ally_targets": "아군 대상 상한", "heal_targets": "회복 대상 상한",
          "max_targets": "적 대상 상한", "aoe": "여러 대상 적용", "aoe_scale": "여러 대상 피해 배율",
          "hits": "타격 분할 횟수", "lifesteal": "흡혈 비율", "threshold": "치유 사용 HP 기준",
          "emergency_threshold": "긴급 치유 HP 기준", "emergency_bonus": "긴급 치유 배율",
          "elite_bonus": "정예 대상 피해 배율", "execute_threshold": "처형 대상 HP 기준",
          "execute_bonus": "처형 피해 배율", "status": "추가 상태 효과", "status_duration": "추가 상태 지속",
          "status_bonus": "상태 이상 적 피해 배율", "guarded_bonus": "자신 보호 중 피해 배율",
          "high_hp_threshold": "높은 대상 HP 기준", "high_hp_bonus": "높은 HP 대상 피해 배율",
          "low_hp_damage_bonus": "자신 HP 50% 이하 피해 배율", "low_hp_threshold": "자신 낮은 HP 기준",
          "low_hp_sustain_bonus": "낮은 HP 흡혈량 배율", "moving_bonus": "이동 준비 시 피해 배율",
          "raid_value": "레이드 단일 대상 계수", "heal_value": "추가 회복", "heal_scale": "회복량 배율",
          "self_heal": "자신 회복", "self_guard": "자신 피해 감소 지속", "taunt": "도발 지속",
          "reduce_secondary": "액티브 2 쿨타임 감소", "extra_ultimate": "추가 궁극기 충전",
          "energy": "스킬 추가 궁극기 충전", "hp_cost": "현재 HP 소모", "exclude_self": "자신 제외",
          "self_only": "자신만 대상", "ally_row": "아군 열 제한", "ultimate_role": "궁극기 역할 분류"}
IDENTITY_LABELS = {"hp_mult": "HP 배율", "attack_mult": "공격력 배율", "defense_bonus": "방어 가산",
                   "attack_interval_mult": "기본 공격 간격 배율", "ult_gain_mult": "궁극기 획득 배율",
                   "skill_cooldown_mult": "스킬 쿨타임 배율", "skill_value_mult": "스킬 값 배율",
                   "duration_mult": "지속시간 배율", "sustain_mult": "흡혈 보정 배율"}
SKIP = {"id", "skill", "slot", "type", "role_group", "kind", "effect"}
PERCENT = {"shield", "lifesteal", "threshold", "emergency_threshold", "execute_threshold",
           "high_hp_threshold", "low_hp_threshold", "heal_value", "self_heal", "hp_cost"}
SECONDS = {"cooldown", "duration", "status_duration", "self_guard", "taunt", "reduce_secondary"}


def esc(value):
    return html.escape(str(value), quote=True)


def number(value):
    return f"{float(value):.6g}"


def field_text(key, value, skill):
    if key == "event": return EVENTS[value]
    if key == "condition": return CONDITIONS[value]
    if key == "action": return ACTIONS[value]
    if key == "guard_scope": return {"self": "자신", "party": "생존 아군 전원"}[value]
    if key == "status": return {"weaken": "공격 피해 35% 감소", "vulnerable": "받는 피해 25% 증가", "stun": "기절"}.get(value, value)
    if key == "ally_row": return {"front": "전열", "back": "후열"}.get(value, value)
    if isinstance(value, bool): return "예" if value else "아니오"
    if key == "value":
        if skill["slot"] == "passive":
            action = skill["action"]
            if action == "energy": return "+" + number(value) + " 게이지"
            if action in {"guard", "ally_guard", "cooldown"}: return number(value) + "초"
            if action in {"heal", "ally_heal", "shield", "ally_shield"}: return "대상 최대 HP " + number(value * 100) + "%"
            if action == "damage": return "공격력 " + number(value * 100) + "%"
        if skill["kind"] == "heal": return "대상 최대 HP " + number(value * 100) + "%"
        if float(value) > 0: return "공격력 " + number(value * 100) + "%"
        return "0 · 별도 피해/회복 계수 없음"
    if key == "raid_value": return "공격력 " + number(value * 100) + "%"
    if key in PERCENT:
        prefix = "대상 최대 HP " if key in {"shield", "heal_value"} else "자신 최대 HP " if key == "self_heal" else ""
        return prefix + number(value * 100) + "%"
    if key in SECONDS: return number(value) + "초"
    if key.endswith("_bonus") or key.endswith("_scale"): return number(value) + "배"
    if key in {"max_targets", "heal_targets", "ally_targets"}: return str(value) + "명"
    if key in {"hits", "every"}: return str(value) + "회"
    return number(value) if isinstance(value, (int, float)) else str(value)


def metrics(skill):
    output = []
    for key, value in skill.items():
        if key in SKIP: continue
        assert key in LABELS, f"Untranslated skill field: {key}"
        label = "내부 쿨타임" if key == "cooldown" and skill["slot"] == "passive" else LABELS[key]
        if key == "cooldown" and skill["slot"] == "ultimate":
            output.append(("사용 조건", "궁극기 게이지 100 · 사용 후 게이지 소모"))
        else:
            output.append((label, field_text(key, value, skill)))
    return output


def dl(rows):
    return "<dl>" + "".join(f"<div><dt>{esc(a)}</dt><dd>{esc(b)}</dd></div>" for a, b in rows) + "</dl>"


def skill_html(skill):
    slot = skill["slot"]
    cd = "자동 발동" if slot == "passive" else "게이지 100" if slot == "ultimate" else number(skill["cooldown"]) + "초"
    detail = metrics(skill)
    return f'''<section class="skill" data-slot="{esc(slot)}"><div class="skill-top"><span class="slot {esc(slot)}">{SLOTS[slot]}</span><span class="kind">{esc(KINDS[skill['kind']])}</span><span class="cooldown">{cd}</span></div><h3>{esc(skill['skill'])}</h3><p class="effect">{esc(skill['effect'])}</p><details class="skill-details"><summary>수치 · 대상 · 조건 보기</summary>{dl(detail)}</details></section>'''


CSS = r'''
:root{color-scheme:dark;--bg:#0c1215;--panel:#172024;--line:#344143;--ink:#e5e4de;--muted:#a1b0ad;--bronze:#e8c99a;--moss:#a8b89e}*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:104px}body{margin:0;background:var(--bg);color:var(--ink);font-family:"Malgun Gothic","Apple SD Gothic Neo",system-ui,sans-serif;line-height:1.6}a{color:var(--bronze);text-underline-offset:4px}header{max-width:1240px;margin:auto;padding:44px 24px 24px}.eyebrow{font-size:12px;letter-spacing:2px;color:var(--moss)}h1{font-size:clamp(26px,4vw,44px);margin:10px 0 8px;letter-spacing:-1px}header p{max-width:880px;color:var(--muted);margin:9px 0}.count-pills{display:flex;gap:10px;margin-top:20px}.count-pills span{border:1px solid var(--line);border-radius:30px;padding:6px 14px;font-size:13px}.toolbar{position:sticky;top:0;background:#10181bf2;backdrop-filter:blur(9px);z-index:10;border-block:1px solid var(--line)}.toolbar-inner{max-width:1240px;margin:auto;padding:12px 24px;display:flex;gap:10px;align-items:center;flex-wrap:wrap}input,select,button{font:inherit;font-size:14px;color:var(--ink);background:#202c30;border:1px solid #4b5c5b;border-radius:8px;padding:9px 12px}input{min-width:190px;flex:1}button{cursor:pointer}button:hover{border-color:var(--bronze)}#results{font-size:13px;color:var(--muted);white-space:nowrap}.jump{max-width:1192px;margin:22px auto;padding:0 24px}.jump summary{color:var(--bronze);cursor:pointer;font-size:14px}.jump nav{display:flex;flex-wrap:wrap;gap:7px;padding:14px 0}.jump a{font-size:12px;background:#1a272a;padding:4px 9px;text-decoration:none;border:1px solid #344643;border-radius:5px}.gallery{max-width:1240px;margin:auto;padding:0 24px 50px}.hero-card{margin:0 0 24px;background:var(--panel);border:1px solid var(--line);border-radius:16px;display:grid;grid-template-columns:238px 1fr;overflow:hidden;scroll-margin-top:94px}.hero-card[hidden]{display:none}.portrait{background:radial-gradient(ellipse at 50% 35%,var(--accent),#142124 72%);padding:20px 18px 18px;text-align:center;display:flex;flex-direction:column;align-items:center}.art-frame{height:270px;width:100%;display:flex;align-items:center;justify-content:center}.art-frame svg{height:100%;width:100%;filter:drop-shadow(0 13px 9px #0008)}.portrait h2{font-size:23px;line-height:1.4;margin:15px 0 5px;word-break:keep-all}.role{font-size:13px;color:var(--bronze);margin:0}.race{font-size:12px;color:var(--muted);margin:6px 0}.faction{font-size:11px;border:1px solid #758b8980;border-radius:30px;padding:3px 12px;display:inline-block}.trait{font-size:13px;text-align:left;color:#bfc8c3;padding-top:14px;margin-top:14px;border-top:1px solid #52676455;width:100%}.trait strong{display:block;color:#e0e7dc}.art-link{font-size:11px;display:block;margin-top:12px}.hero-body{padding:22px}.hero-heading{display:flex;align-items:center;justify-content:space-between;margin-bottom:14px;gap:15px}.hero-heading p{margin:0;font-size:12px;color:var(--muted)}.unlock{font-size:11px;white-space:nowrap;color:var(--moss)}.skills{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.skill{padding:15px 16px;background:#10191c;border:1px solid #2d3e3e;border-radius:10px;min-width:0}.skill-top{display:flex;gap:7px;align-items:center;flex-wrap:wrap;font-size:10px}.slot{font-size:11px;border-radius:4px;padding:2px 6px;background:#334448;color:#d9e4df}.slot.passive{background:#2e453e;color:#c5decb}.slot.ultimate{background:#5c442b;color:#f2d9b2}.kind{color:var(--muted)}.cooldown{margin-left:auto;color:#d3c7af}.skill h3{font-size:17px;margin:10px 0 7px;line-height:1.4}.effect{font-size:13px;margin:0 0 13px;color:#d5dcd4;word-break:keep-all;line-height:1.85}.skill-details summary,.identity-details summary{font-size:11px;color:#acbfb6;cursor:pointer}dl{margin:10px 0 0;font-size:11px}dl div{display:grid;grid-template-columns:43% 1fr;gap:8px;border-top:1px solid #30413b;padding:5px 0}dt{color:#9bacaa}dd{margin:0;color:#deded5;overflow-wrap:anywhere}.identity-details{margin-top:17px;border-top:1px solid #394844;padding-top:13px}.identity-details dl{display:grid;grid-template-columns:1fr 1fr;gap:0 20px}.source-note{font-size:10px;color:#81958b;margin:10px 0 0}.empty{padding:80px 0;text-align:center;color:var(--muted)}footer{max-width:1192px;margin:auto;border-top:1px solid var(--line);padding:24px;font-size:12px;color:var(--muted)}.guide{max-width:1192px;margin:0 auto 24px;padding:12px 16px;border-left:3px solid var(--moss);background:#16231f;color:#bacbbf;font-size:12px}details>summary{list-style-position:outside;margin-left:12px}a:focus-visible,button:focus-visible,input:focus-visible,summary:focus-visible,select:focus-visible{outline:2px solid var(--bronze);outline-offset:4px}@media(max-width:840px){.hero-card{grid-template-columns:190px 1fr}.portrait{padding:18px 12px}.art-frame{height:240px}.skills{grid-template-columns:1fr}.hero-body{padding:18px}.portrait h2{font-size:21px}}@media(max-width:570px){header{padding:30px 16px 20px}.toolbar-inner{padding:10px 16px;gap:7px}input{width:100%;flex-basis:100%}select,button{padding:8px;font-size:12px}.gallery{padding-inline:12px}.jump{padding-inline:16px}.hero-card{grid-template-columns:1fr}.portrait{display:grid;grid-template-columns:140px 1fr;gap:0 14px;text-align:left;align-items:start;padding:18px}.art-frame{height:210px;grid-column:1;grid-row:1/8}.portrait h2,.role,.race,.faction,.trait,.art-link{grid-column:2}.portrait h2{margin-top:10px}.faction{justify-self:start}.trait{margin-top:8px;padding-top:8px}.art-link{margin-top:5px}.skills{grid-template-columns:1fr}.identity-details dl{grid-template-columns:1fr}.hero-heading{align-items:start}.guide{margin-inline:16px}.hero-card{scroll-margin-top:143px}html{scroll-padding-top:151px}}@media print{body{background:white;color:black}.toolbar,.jump,header .count-pills,.art-link{display:none}.hero-card{break-inside:avoid;box-shadow:none;border-color:#ccc;background:white}.skill{background:white;color:black}.effect,dd,.hero-heading p,.role,.race{color:#333}.skill-details dl{display:block}.portrait{background:#eee}.portrait h2,.trait{color:#222}footer{break-before:page}.gallery{padding:0}.identity-details{display:none}}
'''
JS = r'''
const cards=[...document.querySelectorAll('.hero-card')];const search=document.querySelector('#search');const faction=document.querySelector('#faction');const role=document.querySelector('#role');const results=document.querySelector('#results');
function filter(){const query=search.value.trim().toLocaleLowerCase('ko-KR');let count=0;for(const card of cards){const show=(!query||card.dataset.search.includes(query))&&(!faction.value||card.dataset.faction===faction.value)&&(!role.value||card.dataset.role===role.value);card.hidden=!show;if(show)count++;}results.textContent=`영웅 ${count}명 · 스킬 ${count*4}개`;document.querySelector('#empty').hidden=count!==0;}
search.addEventListener('input',filter);faction.addEventListener('change',filter);role.addEventListener('change',filter);
document.querySelector('#expand').addEventListener('click',event=>{const open=event.target.dataset.expanded!=='true';document.querySelectorAll('.skill-details').forEach(item=>item.open=open);event.target.dataset.expanded=String(open);event.target.textContent=open?'수치 모두 접기':'수치 모두 펼치기';});
document.querySelectorAll('.jump a').forEach(link=>link.addEventListener('click',()=>{search.value='';faction.value='';role.value='';filter();}));filter();
window.addEventListener('beforeprint',()=>document.querySelectorAll('.skill-details').forEach(item=>item.open=true));
'''


class GalleryParser(HTMLParser):
    def __init__(self):
        super().__init__(); self.ids=[]; self.slots=[]; self.images=[]
    def handle_starttag(self, tag, attrs):
        values=dict(attrs)
        if tag=='article' and values.get('class')=='hero-card':self.ids.append(values['id'])
        if tag=='section' and values.get('class')=='skill':self.slots.append(values.get('data-slot'))
        if tag=='image':self.images.append(values['href'])


def no_null(value):
    if value is None: return False
    if isinstance(value,dict): return all(no_null(v) for v in value.values())
    if isinstance(value,list): return all(no_null(v) for v in value)
    return True


def build_art_zip(heroes, markdown_text, catalog_bytes):
    """Fixed entry order, timestamps, flags and compression; original PNG bytes."""
    entries=[];references=[];names=[]
    for hero in heroes:
        safe_name=re.sub(r'[\\/:*?"<>|]', '_', hero['name'])
        filename=f"art/{safe_name}_{hero['id']}.png"
        source=OUTPUT/'art'/f"{hero['id']}.png"
        image=source.read_bytes()
        entries.append((filename,image));references.append(filename)
        markdown_text=markdown_text.replace(f"(art/{hero['id']}.png)",f"(<{filename}>)")
        names.append(f"{hero['name']}\t{hero['id']}\t{filename}")
    markdown_text=markdown_text.replace('[완전 독립형 HTML 갤러리](hero-gallery.html)', 'HTML 갤러리는 별도 파일로 제공됩니다.')
    entries.extend([('hero-skills.md',markdown_text.encode('utf-8')),('hero-catalog.json',catalog_bytes),
                    ('영웅파일목록.txt',('\n'.join(names)+'\n').encode('utf-8')),
                    ('README.txt','영웅30명 원화와 전체120개 스킬\n\nhero-skills.md를 열면 이미지와 스킬 설명을 함께 볼 수 있습니다.\nart/의30개 PNG는 원본 고해상도 시트의 등록된 대기 프레임을 픽셀 변경 없이 내보낸 이미지입니다.\n파일명은 한글 영웅명과 고유 ID이며, 영웅파일목록.txt에 대응 목록이 있습니다.\nHTML 및 전체16자세 아틀라스는 이 압축 파일에 중복 포함하지 않습니다.\n'.encode('utf-8'))])
    def create():
        output=BytesIO()
        with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
            for filename,data in entries:
                info=zipfile.ZipInfo(filename,date_time=(2026,10,8,0,0,0));info.create_system=3
                info.external_attr=0o100644<<16;info.compress_type=zipfile.ZIP_DEFLATED
                archive.writestr(info,data,compresslevel=6)
        return output.getvalue()
    content=create();assert content==create(),'ZIP metadata or ordering was not reproducible'
    with zipfile.ZipFile(BytesIO(content)) as archive:
        assert archive.testzip() is None and len(archive.namelist())==34
        assert len([name for name in archive.namelist() if name.endswith('.png')])==30
        for filename,expected in entries:assert archive.read(filename)==expected
        for filename in references:assert f'(<{filename}>)' in markdown_text
        assert not any(name.endswith('.html') or name.endswith('poses.png') for name in archive.namelist())
    path=OUTPUT/'hero-art-and-skills-30.zip';path.write_bytes(content)
    return {'file':path.name,'bytes':len(content),'sha256':hashlib.sha256(content).hexdigest(),
            'images':30,'members':34,'korean_hero_names_and_ids':True,'markdown_image_links_valid':True,
            'images_identical_to_extracted_pngs':True,'contains_html':False,'contains_original_atlases':False,
            'fixed_metadata':True,'repeat_build_bytes_identical':True}


def main():
    catalog=json.loads((OUTPUT/'hero-catalog.json').read_text('utf-8'))
    heroes=catalog['heroes'];assert len(heroes)==30 and len({h['id'] for h in heroes})==30
    cards=[];manifest=[];markdown=['# 영웅 30명 · 원화와 스킬 전체', '', '각 영웅의 패시브·액티브 1·액티브 2·궁극기, 총120개입니다. 아래 값은 등록 기본값이며 실제 전투는 고유 특성·성장·장비·상황 보정을 적용합니다.', '', '[완전 독립형 HTML 갤러리](hero-gallery.html) · [전체 원본 데이터](hero-catalog.json)', '']
    repo_url='https://github.com/jeon9514mm-blip/species-war-eternal/blob/jeon9514mm-blip/species-war-eternal/'
    for hero in heroes:
        assert [s['slot'] for s in hero['skills']]==list(SLOTS)
        art=hero['art'];image_path=ROOT/str(art['extracted_path']).removeprefix('res://');image=image_path.read_bytes()
        assert image[:8]==b'\x89PNG\r\n\x1a\n';dimensions=struct.unpack('>II',image[16:24]);assert list(dimensions)==art['extracted_size']
        assert art['rgba_identical_to_source_region'] and art['exported_rgba_sha256']==art['source_region_rgba_sha256']
        region=[0,0,*dimensions];x,y,w,h=region
        sha=hashlib.sha256(image).hexdigest();assert sha==art['extracted_png_sha256']
        hero['gallery_art']={'png':art['extracted_path'],'size':art['extracted_size'],'source_idle_region':art['idle_region'],'image_sha256':sha,'embedded_unchanged':True}
        uri='data:image/png;base64,'+base64.b64encode(image).decode('ascii')
        svg=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}" role="img" aria-label="{esc(hero["name"])} 전신 원화"><image href="{uri}" width="{dimensions[0]}" height="{dimensions[1]}"/></svg>'
        faction_name='아우렐리아' if hero['faction']=='aurelia' else '녹스페라'
        original_path=str(hero['art']['atlas']).removeprefix('res://');original_url=repo_url+original_path
        identity=hero['identity_profile'];identity_rows=[(IDENTITY_LABELS[key],number(value)+'배' if key.endswith('_mult') else number(value)) for key,value in identity.items() if key in IDENTITY_LABELS]
        search_text=' '.join([hero['name'],hero['id'],hero['class'],hero['role'],hero['role_group'],hero['race'],faction_name,*[s['skill']+' '+s['effect'] for s in hero['skills']]]).lower()
        cards.append(f'''<article class="hero-card" id="{esc(hero['id'])}" data-faction="{esc(hero['faction'])}" data-role="{esc(hero['role_group'])}" data-search="{esc(search_text)}"><div class="portrait" style="--accent:{esc(hero['color'])}45"><div class="art-frame">{svg}</div><h2>{esc(hero['name'])}</h2><p class="role">{esc(hero['class'])} · {esc(hero['role_group'])}</p><p class="race">{esc(hero['race'])} · {'근접' if hero['reach']=='melee' else '원거리'}</p><span class="faction">{faction_name}</span><p class="trait"><strong>{esc(identity['identity'])}</strong>{esc(identity['trait'])}</p><a class="art-link" href="{esc(original_url)}" target="_blank" rel="noopener">고해상도 원화 원본 ↗</a></div><div class="hero-body"><div class="hero-heading"><p>{esc(hero['role'])}</p><span class="unlock">해금 {hero['unlock_stage']} 스테이지</span></div><div class="skills">{''.join(skill_html(s) for s in hero['skills'])}</div><details class="identity-details"><summary>고유 전투 보정 보기</summary>{dl(identity_rows)}<p class="source-note">기본 스킬 수치와 별도인 고유 보정 프로필입니다. 스킬트리·장비·레벨 및 전투 상황에 따라 실제 수치는 달라집니다.</p></details></div></article>''')
        manifest.append({'hero':hero['id'],'source':art['extracted_path'],'sha256':sha,'bytes':len(image),'svg_viewbox':region,'original_source':str(art['atlas']),'source_region':art['idle_region'],'rgba_sha256':art['exported_rgba_sha256'],'source_region_rgba_sha256':art['source_region_rgba_sha256'],'rgba_identical_to_source_region':True})
        markdown.extend([f"## {hero['name']}", '', f"{faction_name} · {hero['race']} · {hero['class']} · {hero['role_group']} · {'근접' if hero['reach']=='melee' else '원거리'} · {hero['unlock_stage']}스테이지 해금", '', f"**{identity['identity']}** — {identity['trait']}", '', f"![{hero['name']} 전신 원화](art/{hero['id']}.png)", '', f"[고해상도 원화 전체 시트]({original_url})", ''])
        for skill in hero['skills']:
            markdown.extend([f"### {SLOTS[skill['slot']]} · {skill['skill']}", '', f"**종류:** {KINDS[skill['kind']]}", '', skill['effect'], '', '| 항목 | 등록 값 |', '|---|---|'])
            markdown.extend(f'| {label} | {value} |' for label,value in metrics(skill));markdown.append('')
    jump=''.join(f'<a href="#{esc(h["id"])}">{esc(h["name"].split()[0])}</a>' for h in heroes)
    roles=''.join(f'<option value="{esc(role)}">{esc(role)}</option>' for role in ['탱커','딜러','서포터','컨트롤러'])
    page=f'''<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Species War Eternal · 영웅 30명 원화와 스킬</title><style>{CSS}</style></head><body><header><div class="eyebrow">SPECIES WAR · ETERNAL / HERO COLLECTION</div><h1>영웅 30명, 원화와 모든 스킬</h1><p>아우렐리아와 녹스페라의 영웅을 한곳에서 확인하세요. 각 영웅의 패시브·액티브 2종·궁극기를 실제 게임 등록 데이터로 정리했습니다.</p><div class="count-pills"><span>30명 전신 원화</span><span>120개 스킬</span><span>오프라인 열람</span></div></header><div class="toolbar"><div class="toolbar-inner"><input id="search" type="search" aria-label="영웅 또는 스킬 검색" placeholder="영웅 · 직업 · 스킬 검색"><select id="faction" aria-label="진영"><option value="">모든 진영</option><option value="aurelia">아우렐리아</option><option value="noxfera">녹스페라</option></select><select id="role" aria-label="역할"><option value="">모든 역할</option>{roles}</select><button id="expand" type="button">수치 모두 펼치기</button><span id="results" aria-live="polite">영웅 30명 · 스킬 120개</span></div></div><details class="jump" open><summary>30명 바로 가기</summary><nav>{jump}</nav></details><div class="guide">설명은 등록 기본값입니다. 캐릭터의 고유 보정·레벨·장비·스킬트리와 전투 상황은 별도로 적용됩니다. ‘수치·대상·조건 보기’에서 반올림 전 계수와 상세 조건을 확인할 수 있습니다.</div><main class="gallery">{''.join(cards)}<p id="empty" class="empty" hidden>조건에 맞는 영웅이 없습니다. 검색어나 필터를 바꿔 주세요.</p></main><footer>2026-10-08 · Godot 4.7.2 실제 카탈로그 기준. 이미지30개와 설명을 이 파일 안에 포함해 인터넷 없이 볼 수 있습니다. 원화는 기존 고해상도 시트의 등록된 대기 프레임1개를 Godot에서 그대로 내보냈으며 리사이즈·색상 변경·보정·새 픽셀 생성 없이 원본 영역과 RGBA가 같습니다. ‘고해상도 원화 원본’ 링크만 GitHub 접근이 필요합니다.<br>기절·공격 약화·받는 피해 증가 등은 실제 스킬 종류입니다. Fire/Ice/Light/Dark 연출색을 별도의 피해 속성·저항 규칙으로 추가하지 않았습니다.</footer><script>{JS}</script></body></html>'''
    assert no_null(catalog)
    parser=GalleryParser();parser.feed(page);assert len(parser.ids)==30 and len(set(parser.ids))==30
    assert Counter(parser.slots)==Counter({slot:30 for slot in SLOTS}) and len(parser.images)==30
    for uri,item in zip(parser.images,manifest):assert hashlib.sha256(base64.b64decode(uri.split(',',1)[1])).hexdigest()==item['sha256']
    skill_ids=[s['id'] for h in heroes for s in h['skills']];assert len(skill_ids)==len(set(skill_ids))==120
    assert Counter(h['faction'] for h in heroes)==Counter({'aurelia':15,'noxfera':15})
    (OUTPUT/'hero-gallery.html').write_text(page,encoding='utf-8')
    (OUTPUT/'hero-catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (OUTPUT/'hero-skills.md').write_text('\n'.join(markdown)+'\n',encoding='utf-8')
    zip_artifact=build_art_zip(heroes,'\n'.join(markdown)+'\n',(OUTPUT/'hero-catalog.json').read_bytes())
    previous_validation=json.loads((OUTPUT/'validation.json').read_text('utf-8')) if (OUTPUT/'validation.json').exists() else {}
    validation={'heroes':30,'unique_hero_ids':30,'factions':{'aurelia':15,'noxfera':15},'skills':120,'unique_skill_ids':120,
                'each_slot_count':dict(Counter(parser.slots)),'embedded_images':30,'missing_skill_descriptions':0,
                'missing_image_files':0,'null_values':0,'source_image_pixels_modified':False,'embedded_hashes_match_source':True,'exported_rgba_matches_original_region':True,
                'html_bytes':(OUTPUT/'hero-gallery.html').stat().st_size,'embedded_source_png_bytes':sum(m['bytes'] for m in manifest),
                'standalone':True,'network_requests_required_for_gallery':False,'saves_loaded':0,'browser_visual_review':previous_validation.get('browser_visual_review','pending root review'),
                'zip_artifact':zip_artifact,'images':manifest}
    (OUTPUT/'validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    total=sum(m['bytes'] for m in manifest);html_size=(OUTPUT/'hero-gallery.html').stat().st_size
    (OUTPUT/'README.md').write_text(f'''# 영웅 30명 · 원화와 전체 스킬\n\n[완전 독립형 HTML 갤러리](hero-gallery.html)를 내려받아 브라우저에서 여세요. 한 파일에30명 전신 원화와120개 스킬 설명이 포함됩니다. 진영·역할 필터, 이름/직업/스킬 검색, 영웅 바로 가기, 상세 수치 전체 펼치기를 지원합니다.\n\n[원화30장과 스킬 설명 ZIP 다운로드](hero-art-and-skills-30.zip) — {zip_artifact['bytes']:,}bytes. 한글 영웅명+ID로 된30개 PNG, 이미지 링크가 연결된 전체 스킬 Markdown, 원본 데이터JSON, 파일명 목록이 들어 있습니다. HTML과 전체16자세 아틀라스는 포함하지 않습니다. ZIP시간/순서/권한 메타데이터를 고정하고 두 번 생성한 바이트와 SHA-256이 일치하는지 검사합니다.\n\n[이미지와 설명 전체 목록](hero-skills.md) · [실제 카탈로그 데이터](hero-catalog.json) · [누락/이미지 무결성 검사](validation.json). 개별30명 이미지도 `art/<hero>.png`에 있습니다.\n\n이미지는 기존 고해상도 `assets/art-direction/full-body-v2/<hero>/poses.png`의 `frames.json`에 등록된 첫 대기 자세1개를 Godot의 native `Image.get_region(Rect2i)`로 내보냈습니다. 리사이즈·리터치·효과·색 변경·새 픽셀 생성 없이 기술적으로 프레임을 분리하며 원본 아틀라스는 바꾸지 않습니다. 저장한PNG를 다시 읽어 추출 영역과 RGBA byte array가 같음을30명 모두 확인하고 원본 영역/내보낸PNG의RGBA해시를 기록했습니다. HTML은 추출PNG를 그대로 내장해 인터넷 없이 열리며, 원본 전체시트 링크만GitHub에 연결합니다. 이미지30개 총{total:,}bytes, HTML{html_size:,}bytes입니다.\n\n스킬은 실제 `HeroRosterCatalog`의4슬롯을 Godot에서 그대로 내보냅니다. 숫자는 등록 기본값이며 고유 특성·레벨·장비·스킬트리·상황 보정 후의 실전 값이 아닙니다. 고유 프로필은 별도 상세에 표시합니다. 기존 effect설명이 반올림한 비율은 상세 수치에서 원래 값을 확인할 수 있습니다. 새로운 피해 속성/저항 규칙을 만들지 않습니다.\n\n재현: 격리된 프로필로 Godot `--headless --path . --script res://tools/export_hero_catalog.gd` 실행 후 `python tools/build_hero_catalog.py`. Main·저장·실제 플레이어 경제를 실행하지 않습니다. 내보내기는30명원본영역RGBA일치/PNG왕복일치를검사하고 빌더는30명ID/각4슬롯/120스킬ID/15명씩2진영/누락없음/null없음/PNG해시/SVG영역/HTML내장이미지30개를 검사합니다. 브라우저 시각 검수는 통합 담당이 수행합니다.\n''',encoding='utf-8')
    print(json.dumps({k:v for k,v in validation.items() if k!='images'},ensure_ascii=False))


if __name__=='__main__':
    main()
