# 영웅 30명 · 원화와 전체 스킬

[완전 독립형 HTML 갤러리](hero-gallery.html)를 내려받아 브라우저에서 여세요. 한 파일에30명 전신 원화와120개 스킬 설명이 포함됩니다. 진영·역할 필터, 이름/직업/스킬 검색, 영웅 바로 가기, 상세 수치 전체 펼치기를 지원합니다.

[원화30장과 스킬 설명 ZIP 다운로드](hero-art-and-skills-30.zip) — 3,157,357bytes. 한글 영웅명+ID로 된30개 PNG, 이미지 링크가 연결된 전체 스킬 Markdown, 원본 데이터JSON, 파일명 목록이 들어 있습니다. HTML과 전체16자세 아틀라스는 포함하지 않습니다. ZIP시간/순서/권한 메타데이터를 고정하고 두 번 생성한 바이트와 SHA-256이 일치하는지 검사합니다.

[이미지와 설명 전체 목록](hero-skills.md) · [실제 카탈로그 데이터](hero-catalog.json) · [누락/이미지 무결성 검사](validation.json). 개별30명 이미지도 `art/<hero>.png`에 있습니다.

이미지는 기존 고해상도 `assets/art-direction/full-body-v2/<hero>/poses.png`의 `frames.json`에 등록된 첫 대기 자세1개를 Godot의 native `Image.get_region(Rect2i)`로 내보냈습니다. 리사이즈·리터치·효과·색 변경·새 픽셀 생성 없이 기술적으로 프레임을 분리하며 원본 아틀라스는 바꾸지 않습니다. 저장한PNG를 다시 읽어 추출 영역과 RGBA byte array가 같음을30명 모두 확인하고 원본 영역/내보낸PNG의RGBA해시를 기록했습니다. HTML은 추출PNG를 그대로 내장해 인터넷 없이 열리며, 원본 전체시트 링크만GitHub에 연결합니다. 이미지30개 총3,122,294bytes, HTML4,334,838bytes입니다.

스킬은 실제 `HeroRosterCatalog`의4슬롯을 Godot에서 그대로 내보냅니다. 숫자는 등록 기본값이며 고유 특성·레벨·장비·스킬트리·상황 보정 후의 실전 값이 아닙니다. 고유 프로필은 별도 상세에 표시합니다. 기존 effect설명이 반올림한 비율은 상세 수치에서 원래 값을 확인할 수 있습니다. 새로운 피해 속성/저항 규칙을 만들지 않습니다.

재현: 격리된 프로필로 Godot `--headless --path . --script res://tools/export_hero_catalog.gd` 실행 후 `python tools/build_hero_catalog.py`. Main·저장·실제 플레이어 경제를 실행하지 않습니다. 내보내기는30명원본영역RGBA일치/PNG왕복일치를검사하고 빌더는30명ID/각4슬롯/120스킬ID/15명씩2진영/누락없음/null없음/PNG해시/SVG영역/HTML내장이미지30개를 검사합니다. [브라우저 검수](browser-qa.json)에서 전체30명/120스킬, 이름 검색1명/4스킬, 녹스페라 탱커 필터2명/8스킬, 바로 가기, 데스크톱1280px와 모바일390px 가로 넘침 없음, 콘솔 오류 없음을 확인했습니다. [모바일 화면](gallery-mobile.jpg).
