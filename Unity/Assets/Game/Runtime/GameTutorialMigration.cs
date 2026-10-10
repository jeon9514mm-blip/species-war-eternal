using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    public sealed partial class GameStateCommands
    {
        void RefreshTutorial(JObject state,string command)
        {
            if(L.Flag(state["tutorial_completed"]))return;
            var actions=Map(state,"tutorial_actions");
            if(new[]{"LevelHero","UpgradeHero","UpgradeResearch","UpgradeSkill","Ascend","Breakthrough","EnhanceGear","UpgradeGuardian"}.Contains(command))actions["growth"]=true;
            if(command=="ReserveUnityRaid")actions["raid_started"]=true;
            int step=TutorialStep(state);state["tutorial_step"]=step;state["tutorial_completed"]=step>=6;
            if((string)state["tracked_quest_id"]==null||L.Flag(state["quest_claimed"]?[(string)state["tracked_quest_id"]]))
                state["tracked_quest_id"]=new[]{"stage5","raid1","tower5"}.FirstOrDefault(k=>!L.Flag(state["quest_claimed"]?[k]))??"";
        }
        static int TutorialStep(JObject state)
        {
            if(L.Flag(state["tutorial_completed"]))return 6;
            if(!new[]{"aurelia","noxfera"}.Contains((string)state["selected_faction"]))return 0;
            if(L.Array(state["deployed_hero_ids"]).Count==0)return 1;
            if(L.N(state["idle_stage"],1)==1&&L.N(state["idle_stage_kills"])==0&&L.N(state["combat_kills"])==0&&L.N(state["unity_pack_total"])==0)return 2;
            if(Math.Max(L.N(state["idle_stage"],1),1+L.N(state["unity_pack_total"])/5)<2)return 3;
            if(!L.Flag(state["tutorial_actions"]?["growth"]))return 4;
            return !L.Flag(state["tutorial_actions"]?["raid_started"])&&L.Object(state["raid_clears"]).Properties().Sum(p=>L.N(p.Value))==0&&L.N(state["tower_best_floor"])==0?5:6;
        }
        public JObject TutorialStatus()
        {
            int step=TutorialStep(data);string[] text={"진영을 선택하세요.","원정대를 편성하세요.","첫 무리를 처치하세요.","스테이지 2까지 자동 사냥하세요.","영웅 레벨·연구·스킬 또는 장비를 한 번 성장시키세요.","편성을 점검하고 레이드에 출전하세요.","첫 원정 가이드 완료"};
            return new JObject{{"step",step},{"complete",step>=6},{"text",text[step]},{"tracked_quest",data["tracked_quest_id"]??"stage5"}};
        }
    }
}
