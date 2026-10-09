using System;

namespace Eternal.UnityMigration
{
    public static class FallenMonsterCatalog
    {
        public static readonly string[] Ids={"fallen_elf","fallen_dwarf","fallen_vampire","fallen_werewolf","fallen_ogre","fallen_lich","fallen_harpy"};
        public static bool Contains(string id)=>Array.IndexOf(Ids,id)>=0;
        public static string Name(string id)=>id switch{"fallen_elf"=>"타락한 엘프","fallen_dwarf"=>"타락한 드워프","fallen_vampire"=>"타락한 뱀파이어","fallen_werewolf"=>"타락한 늑대인간","fallen_ogre"=>"타락한 오우거","fallen_lich"=>"타락한 리치","fallen_harpy"=>"타락한 하피",_=>id};
        public static string Description(string id)=>id switch
        {
            "fallen_elf"=>"저주받은 활 · 뒤쪽 영웅을 노리는 원거리 궁수 · 사거리 3.2",
            "fallen_dwarf"=>"광맥 중장갑 · 체력 +12% · 방어 +4 · 느린 망치 공격",
            "fallen_vampire"=>"피의 추적 · 후방 보조 영웅 우선 · 실제 입힌 피해의 30% 흡혈",
            "fallen_werewolf"=>"광폭 추격 · 빠른 돌진 · 전조 후 발톱 공격",
            "fallen_ogre"=>"공성 괴력 · 체력 +20% · 방어 +6 · 긴 전조 후 지면 강타와 기절",
            "fallen_lich"=>"망령 술사 · 사거리 3.6 · 쇠약 저주 · 고단계 아군 회복",
            "fallen_harpy"=>"날개 추적 · 빠른 측면 접근 · 갈퀴 출혈과 약화",
            _=>""
        };
        public static string Archetype(string id)=>id=="fallen_elf"?"ranged":id=="fallen_lich"?"support":id=="fallen_dwarf"||id=="fallen_ogre"?"brute":"assassin";
        public static float Height(string id)=>id switch{"fallen_dwarf"=>1.65f,"fallen_werewolf"=>2.15f,"fallen_ogre"=>2.65f,"fallen_lich"=>2.1f,"fallen_harpy"=>2.2f,_=>1.85f};
        public static string Skill(string id)=>id switch{"fallen_elf"=>"저주 화살","fallen_dwarf"=>"갑옷 파쇄","fallen_vampire"=>"흡혈 저주","fallen_werewolf"=>"출혈 발톱","fallen_ogre"=>"지면 강타","fallen_lich"=>"망령 쇠약","fallen_harpy"=>"갈퀴 폭풍",_=>"basic"};
        public static int Population(int stage)=>stage>=1000?32:stage>=500?28:24;
        public static string[] Wave(string zone)=>zone switch
        {
            "forgotten_mine"=>new[]{"fallen_dwarf","fallen_ogre","fallen_dwarf","fallen_werewolf","fallen_lich","fallen_elf","fallen_vampire","fallen_harpy"},
            "moonrest_forest"=>new[]{"fallen_harpy","fallen_lich","fallen_vampire","fallen_elf","fallen_werewolf","fallen_dwarf","fallen_ogre","fallen_harpy"},
            _=>new[]{"fallen_elf","fallen_dwarf","fallen_vampire","fallen_werewolf","fallen_ogre","fallen_lich","fallen_harpy","fallen_elf"}
        };
    }
}
