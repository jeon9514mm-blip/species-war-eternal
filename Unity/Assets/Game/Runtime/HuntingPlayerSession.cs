using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        NativePlayerSession playerSession;
        bool playerRaidTraining,playerPartyRefresh,savePaused,huntWasPaused,raidWasPaused;
        long playerRaidAttempt;
        StateCommandResult playerRaidReward;
        public bool PersistentPlayer=>playerSession!=null;
        bool CanEditChain=>playerSession==null||Raid!=null&&playerRaidTraining||ReviewState.MutationError.Length==0;
        public void BindPlayerSession(NativePlayerSession session)
        {if(Simulation!=null||session==null||!session.State.UnityPlayer)throw new InvalidOperationException("Bind a native profile before starting the game.");playerSession=session;}
        int PlayerLevel()=>Math.Max(1,(int)Math.Round(ReviewState.DeployedHeroes().Select(id=>(double)ReviewState.HeroProgress(id).level).DefaultIfEmpty(1).Average()));
        HuntingSimulation CreatePlayerHunt()
        {
            var state=playerSession.State;var result=new HuntingSimulation(1,9514,state);
            result.RestoreUnityProgress(state.UnityZone,state.UnityPacks);result.Chain.Enabled=(bool?)state.Snapshot()["unity_chain_enabled"]??true;
            if(state.Snapshot()["unity_chain"] is JArray saved)
                result.Chain.Restore(saved.OfType<JObject>().Select(e=>new ChainSkill((string)e["hero"],(string)e["slot"])).ToArray(),result.Chain.Enabled);
            return result;
        }
        void PauseForSaveFailure()
        {
            if(playerSession==null||!ReviewState.SavePending)return;
            if(!savePaused){huntWasPaused=Simulation.Paused;raidWasPaused=Raid?.Paused??false;}
            savePaused=true;Simulation.Paused=true;if(Raid!=null)Raid.Paused=true;
            huntNotice="저장 대기 · 원정대 메뉴에서 다시 저장해 주세요.";huntNoticeUntil=float.MaxValue;
        }
        void SavePlayerChain()
        {
            if(playerSession==null||Raid!=null&&playerRaidTraining)return;
            var result=Raid==null?ReviewState.SetUnityChain(Simulation.Chain.Entries.ToArray(),Simulation.Chain.Enabled):ReviewState.SetUnityRaidChain(Raid.Zone,Raid.Chain.Entries.ToArray(),Raid.Chain.Enabled);
            if(!result.Ok){huntNotice=result.Message;huntNoticeUntil=Time.unscaledTime+3;}PauseForSaveFailure();
        }
        void RestoreRaidChain()
        {
            if(playerSession==null)return;
            if(ReviewState.Snapshot()["unity_raid_chains"]?[Raid.Zone] is JObject config&&config["entries"] is JArray saved)
                Raid.Chain.Restore(saved.OfType<JObject>().Select(e=>new ChainSkill((string)e["hero"],(string)e["slot"])).ToArray(),(bool?)config["enabled"]??false);
        }
        bool PreparePlayerRaid(string zone,ref int level,bool training)
        {
            if(playerSession==null)return true;
            if(ReviewState.MutationError.Length>0){huntNotice=ReviewState.MutationError;huntNoticeUntil=Time.unscaledTime+3;return false;}
            playerRaidTraining=training;playerRaidReward=null;
            if(training){level=50;return true;}
            var reserved=ReviewState.ReserveUnityRaid(zone);PauseForSaveFailure();if(!reserved.Ok||reserved.SavePending)return false;
            playerRaidAttempt=(long)reserved.Details["attempt"];level=PlayerLevel();return true;
        }
        void RestartPlayerHunt(bool preserveHeroes)
        {
            if(playerSession==null||ReviewState.SavePending)return;
            var previous=Simulation;var fresh=CreatePlayerHunt();
            if(preserveHeroes)
            {
                foreach(var hero in fresh.Battle.Heroes)
                {
                    var old=previous.Battle.Heroes.Find(h=>h.Id==hero.Id);if(old==null)continue;
                    hero.Hp=Math.Clamp((int)Math.Round(old.HpRatio*hero.MaxHp),0,hero.MaxHp);hero.Ultimate=old.Ultimate;
                    var oldKit=previous.Battle.Kits[hero.Id];var kit=fresh.Battle.Kits[hero.Id];foreach(var cooldown in oldKit.Cooldowns)kit.Cooldowns[cooldown.Key]=cooldown.Value;
                }
            }
            if(Raid!=null)EndRaid();ResetViews();ResetSkillPresentation();Simulation=fresh;Simulation.OnEvent=Receive;accumulator=0;visualQueue.Clear();
            huntEnvironment.Bind(Simulation.Zone);
            feedback.SetRaidMode(false);modal.style.display=DisplayStyle.None;BuildParty();RebuildActors();RefreshHud();
        }
        void RefreshPlayerStatus()
        {
            if(playerSession==null)return;
            fixtureLabel.text=Raid!=null&&playerRaidTraining?"패턴 훈련 · Lv50 임시 원정대 · 훈련 보상 없음":(ReviewState.Faction=="aurelia"?"아우렐리아":"녹스페라")+" · 원정대 Lv"+PlayerLevel()+" · "+(ReviewState.SavePending?"저장 대기":"Unity 기록 자동 저장");
            var revive=root.Q<Button>("hunt-revive");if(revive!=null)revive.style.display=Raid==null&&Simulation.Defeated?DisplayStyle.Flex:DisplayStyle.None;
        }
        void ShowPlayerParty()
        {
            PanelHeader("원정대 · 기록");
            var message=Text(modal,"편성은 다음 무리부터 적용합니다. 레이드 중에는 편성을 바꿀 수 없습니다.",12);message.style.whiteSpace=WhiteSpace.Normal;message.style.color=Moss;
            if(ReviewState.SavePending)
            {
                Button(modal,"다시 저장",()=>
                {
                    if(ReviewState.RetrySave()){if(savePaused){Simulation.Paused=huntWasPaused;if(Raid!=null&&Raid.Running)Raid.Paused=raidWasPaused;}savePaused=false;huntNotice="기록을 저장했습니다.";huntNoticeUntil=Time.unscaledTime+3;}ShowPlayerParty();
                });
            }
            var chosen=new List<string>(ReviewState.DeployedHeroes());var formation=ReviewState.Formation;
            var formations=(JObject)HuntingSimulation.Canonical["catalogs"]["formation"]["data"]["PROFILES"];
            var keys=formations.Properties().Select(p=>p.Name).ToList();var names=keys.Select(k=>(string)formations[k]["name"]).ToList();
            var field=new DropdownField("진형",names,Math.Max(0,keys.IndexOf(formation)));field.labelElement.style.minWidth=40;field.labelElement.style.width=40;field.AddToClassList("roster-filter");modal.Add(field);field.RegisterValueChangedCallback(e=>formation=keys[names.IndexOf(e.newValue)]);
            var count=Text(modal,"편성 "+chosen.Count+" / 10",14);count.style.color=Bronze;count.style.marginTop=10;
            var list=new ScrollView();list.style.flexGrow=1;modal.Add(list);
            foreach(string id in Simulation.Catalog.HeroIds.Where(ReviewState.IsFactionHero))
            {
                string selected=id;var toggle=new Toggle((string)Simulation.Catalog.Hero(id)["name"]+" · Lv"+ReviewState.HeroProgress(id).level){value=chosen.Contains(id)};toggle.style.marginTop=9;list.Add(toggle);
                toggle.RegisterValueChangedCallback(e=>{if(e.newValue){if(chosen.Count==10){toggle.SetValueWithoutNotify(false);return;}chosen.Add(selected);}else chosen.Remove(selected);count.text="편성 "+chosen.Count+" / 10";});
            }
            var apply=Button(modal,"편성 저장",()=>{var result=ReviewState.SetUnityParty(chosen.ToArray(),formation);message.text=result.Message;PauseForSaveFailure();});apply.SetEnabled(Raid==null&&!ReviewState.SavePending);
            Button(modal,"진영 선택 화면",()=>
            {
                if(ReviewState.SavePending){message.text="먼저 다시 저장해 주세요.";return;}
                new GameObject("Eternal faction selection").AddComponent<EternalBootstrap>();Destroy(gameObject);
            });
        }
        void ShowPlayerZones()
        {
            PanelHeader("사냥터 이동");var tip=Text(modal,"진행 스테이지와 영웅 성장은 유지됩니다.",12);tip.style.color=Moss;
            foreach(string zone in new[]{"gray_meadow","forgotten_mine","moonrest_forest"})
            {
                string selected=zone;var region=HuntingSimulation.Canonical["zones"][zone];
                var card=Box(modal,"hunt-zone-"+zone,new Color(.075f,.10f,.11f));card.style.marginTop=13;card.style.paddingLeft=card.style.paddingRight=10;card.style.paddingTop=card.style.paddingBottom=9;
                var row=Row(card);row.style.alignItems=Align.Center;
                var preview=new Image{image=Resources.Load<Texture2D>(HuntEnvironmentPresentation.Resource(zone)),scaleMode=ScaleMode.ScaleAndCrop};preview.style.width=100;preview.style.height=72;preview.style.marginRight=10;row.Add(preview);
                var copy=new VisualElement();copy.style.flexGrow=1;copy.style.minWidth=0;row.Add(copy);
                var enter=Button(copy,(string)region["name"]??zone,()=>{var result=ReviewState.SetUnityZone(selected);tip.text=result.Message;PauseForSaveFailure();if(result.Ok&&!result.SavePending)RestartPlayerHunt(true);});enter.style.marginLeft=0;
                enter.SetEnabled(Raid==null&&!ReviewState.SavePending&&Simulation.Zone!=zone);Text(copy,"골드 "+region["gold"]+" · 경험치 "+region["xp"],12).style.color=Moss;
                if(Simulation.Zone==zone)Text(copy,"현재 사냥터",11).style.color=Bronze;
            }
        }
    }
}
