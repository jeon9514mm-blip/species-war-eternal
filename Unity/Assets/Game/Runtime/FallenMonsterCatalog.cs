using System;

namespace Eternal.UnityMigration
{
    public static class FallenMonsterCatalog
    {
        public static readonly string[] Ids={"fallen_elf","fallen_dwarf","fallen_vampire","fallen_werewolf"};
        public static bool Contains(string id)=>Array.IndexOf(Ids,id)>=0;
        public static string Name(string id)=>id switch{"fallen_elf"=>"타락한 엘프","fallen_dwarf"=>"타락한 드워프","fallen_vampire"=>"타락한 뱀파이어","fallen_werewolf"=>"타락한 늑대인간",_=>id};
        public static string Description(string id)=>id switch
        {
            "fallen_elf"=>"저주받은 활 · 뒤쪽 영웅을 노리는 원거리 궁수 · 사거리 3.2",
            "fallen_dwarf"=>"광맥 중장갑 · 체력 +12% · 방어 +4 · 느린 망치 공격",
            "fallen_vampire"=>"피의 추적 · 후방 보조 영웅 우선 · 실제 입힌 피해의 30% 흡혈",
            "fallen_werewolf"=>"광폭 추격 · 빠른 돌진 · 전조 후 발톱 공격",
            _=>""
        };
        public static string Archetype(string id)=>id=="fallen_elf"?"ranged":id=="fallen_dwarf"?"brute":"assassin";
        public static float Height(string id)=>id=="fallen_dwarf"?1.65f:id=="fallen_werewolf"?2.15f:1.85f;
        public static string Skill(string id)=>id switch{"fallen_elf"=>"저주 화살","fallen_dwarf"=>"갑옷 파쇄","fallen_vampire"=>"흡혈 저주","fallen_werewolf"=>"출혈 발톱",_=>"basic"};
        public static string[] Wave(string zone)=>zone switch
        {
            "forgotten_mine"=>new[]{"mine_orc","iron_mole","fallen_dwarf","fallen_werewolf","fallen_elf","fallen_vampire"},
            "moonrest_forest"=>new[]{"moon_wolf","forest_wraith","fallen_vampire","fallen_elf","fallen_werewolf","fallen_dwarf"},
            _=>new[]{"goblin","wild_dog","fallen_elf","fallen_dwarf","fallen_vampire","fallen_werewolf"}
        };
    }
}
