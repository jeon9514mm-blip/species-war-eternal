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
            var queued=ReviewState.Snapshot()["unity_next_party"] as JObject;
            var chosen=queued?["heroes"] is JArray queuedIds?queuedIds.Values<string>().ToList():new List<string>(ReviewState.DeployedHeroes());var formation=(string)queued?["formation"]??ReviewState.Formation;
            var formations=(JObject)HuntingSimulation.Canonical["catalogs"]["formation"]["data"]["PROFILES"];
            var keys=formations.Properties().Select(p=>p.Name).ToList();var names=keys.Select(k=>(string)formations[k]["name"]).ToList();
            var field=new DropdownField("진형",names,Math.Max(0,keys.IndexOf(formation)));field.labelElement.style.minWidth=40;field.labelElement.style.width=40;field.AddToClassList("roster-filter");modal.Add(field);
            var list=new ScrollView();list.style.flexGrow=1;modal.Add(list);
            var description=Text(list,HuntFormationLayout.Description(formation),12);description.style.whiteSpace=WhiteSpace.Normal;description.style.color=Moss;
            var preview=new VisualElement{name="party-layout-preview"};preview.style.height=148;preview.style.flexShrink=0;preview.style.marginTop=8;preview.style.backgroundColor=new Color(.055f,.085f,.08f);list.Add(preview);
            int selectedOrder=0;
            var orderLabel=Text(list,"",13);orderLabel.style.color=Bronze;
            void DrawParty()
            {
                preview.Clear();selectedOrder=Math.Clamp(selectedOrder,0,Math.Max(0,chosen.Count-1));description.text=HuntFormationLayout.Description(formation);
                orderLabel.text=chosen.Count==0?"최소 1명을 선택하세요.":"편성 "+chosen.Count+" / 10 · "+(selectedOrder+1)+"번 "+(string)Simulation.Catalog.Hero(chosen[selectedOrder])["name"];
                for(int i=0;i<chosen.Count;i++)
                {
                    int index=i;var p=HuntFormationLayout.Position(formation,i,chosen.Count);
                    var slot=new Button(()=>{selectedOrder=index;DrawParty();}){name="party-slot-"+i,tooltip=(i+1)+"번 · "+(string)Simulation.Catalog.Hero(chosen[i])["name"]};
                    slot.style.position=Position.Absolute;slot.style.left=(p.x+8)*27;slot.style.top=60-p.y*10;slot.style.width=slot.style.height=28;slot.style.paddingLeft=slot.style.paddingRight=0;slot.style.paddingTop=slot.style.paddingBottom=0;
                    slot.style.borderTopLeftRadius=slot.style.borderTopRightRadius=slot.style.borderBottomLeftRadius=slot.style.borderBottomRightRadius=14;slot.style.overflow=Overflow.Hidden;
                    slot.style.backgroundColor=i==selectedOrder?Bronze:new Color(.15f,.22f,.21f);slot.style.borderTopColor=slot.style.borderBottomColor=slot.style.borderLeftColor=slot.style.borderRightColor=i==selectedOrder?Bronze:Moss;
                    var art=new Image{sprite=InspectionPortrait(chosen[i]),scaleMode=ScaleMode.ScaleToFit,pickingMode=PickingMode.Ignore};art.style.width=26;art.style.height=26;slot.Add(art);preview.Add(slot);
                    var number=Text(preview,(i+1).ToString(),10);number.pickingMode=PickingMode.Ignore;number.style.position=Position.Absolute;number.style.left=(p.x+8)*27+16;number.style.top=60-p.y*10+15;number.style.color=Parchment;
                }
            }
            field.RegisterValueChangedCallback(e=>{formation=keys[names.IndexOf(e.newValue)];DrawParty();});
            var order=Row(list);
            Button(order,"앞으로",()=>{if(selectedOrder<=0||chosen.Count==0)return;(chosen[selectedOrder],chosen[selectedOrder-1])=(chosen[selectedOrder-1],chosen[selectedOrder]);selectedOrder--;DrawParty();});
            Button(order,"뒤로",()=>{if(selectedOrder+1>=chosen.Count)return;(chosen[selectedOrder],chosen[selectedOrder+1])=(chosen[selectedOrder+1],chosen[selectedOrder]);selectedOrder++;DrawParty();});
            for(int i=0;i<3;i++)
            {
                int preset=i;var row=Row(list);row.style.marginTop=6;
                var save=Button(row,"편성 "+(i+1)+" 저장",()=>{var result=ReviewState.SaveUnityPartyPreset(preset,chosen.ToArray(),formation);message.text=result.Message;PauseForSaveFailure();});save.SetEnabled(Raid==null&&!ReviewState.SavePending);
                Button(row,"불러오기 "+(i+1),()=>
                {
                    if(ReviewState.Snapshot()["unity_party_presets"]?[preset.ToString()] is not JObject stored||stored["heroes"] is not JArray saved){message.text="저장된 편성이 없습니다.";return;}
                    var ids=saved.Values<string>().ToArray();string f=(string)stored["formation"];
                    if(ids.Length<1||ids.Length>10||ids.Distinct().Count()!=ids.Length||ids.Any(id=>!ReviewState.IsFactionHero(id))||!keys.Contains(f)){message.text="이 편성을 다시 저장하세요.";return;}
                    chosen.Clear();chosen.AddRange(ids);formation=f;field.SetValueWithoutNotify(names[keys.IndexOf(f)]);foreach(var toggle in list.Query<Toggle>().ToList())toggle.SetValueWithoutNotify(chosen.Contains((string)toggle.userData));DrawParty();message.text="편성을 불러왔습니다. 편성 저장을 누르면 다음 무리에 적용합니다.";
                });
            }
            foreach(string id in Simulation.Catalog.HeroIds.Where(ReviewState.IsFactionHero))
            {
                string selected=id;var toggle=new Toggle((string)Simulation.Catalog.Hero(id)["name"]+" · Lv"+ReviewState.HeroProgress(id).level){value=chosen.Contains(id),userData=id};toggle.style.marginTop=9;list.Add(toggle);
                toggle.RegisterValueChangedCallback(e=>{if(e.newValue){if(chosen.Count==10){toggle.SetValueWithoutNotify(false);return;}chosen.Add(selected);}else chosen.Remove(selected);DrawParty();});
            }
            DrawParty();
            var apply=Button(modal,"편성 저장",()=>{var result=ReviewState.SetUnityParty(chosen.ToArray(),formation);message.text=result.Message;PauseForSaveFailure();});apply.SetEnabled(Raid==null&&!ReviewState.SavePending);
            Button(modal,"진영 선택 화면",()=>
            {
                if(ReviewState.SavePending){message.text="먼저 다시 저장해 주세요.";return;}
                new GameObject("Eternal faction selection").AddComponent<EternalBootstrap>();Destroy(gameObject);
            });
        }
        void ShowPlayerZones()
        {
            PanelHeader("끝없는 사냥터");var tip=Text(modal,"하나의 확장 맵 · 스테이지에 따라 몬스터와 분위기가 바뀝니다.",12);tip.style.color=Moss;tip.style.whiteSpace=WhiteSpace.Normal;
            var range=Text(modal,"현재 구간 "+HuntStageWorld.Start(Simulation.Stage)+"~"+HuntStageWorld.End(Simulation.Stage)+" · "+HuntStageWorld.Atmosphere(Simulation.Stage),15);range.style.color=Bronze;range.style.marginTop=12;
            Button(modal,"몬스터 도감",ShowFallenMonsters).style.marginTop=8;
            var list=new ScrollView();list.style.flexGrow=1;modal.Add(list);
            foreach(int stage in new[]{1,500,1000,1500})
            {
                string zone=HuntStageWorld.Zone(stage);var region=HuntingSimulation.Canonical["zones"][zone];
                var card=Box(list,"hunt-band-"+stage,new Color(.075f,.10f,.11f));card.style.marginTop=13;card.style.paddingLeft=card.style.paddingRight=10;card.style.paddingTop=card.style.paddingBottom=9;
                var row=Row(card);row.style.alignItems=Align.Center;
                var preview=new Image{image=Resources.Load<Texture2D>(HuntEnvironmentPresentation.Resource(zone)),scaleMode=ScaleMode.ScaleAndCrop};preview.style.width=100;preview.style.height=72;preview.style.marginRight=10;row.Add(preview);
                var copy=new VisualElement();copy.style.flexGrow=1;copy.style.minWidth=0;row.Add(copy);
                Text(copy,HuntStageWorld.Start(stage)+"~"+HuntStageWorld.End(stage)+" · "+HuntStageWorld.Atmosphere(stage),14).style.color=Bronze;
                Text(copy,"골드 "+region["gold"]+" · 경험치 "+region["xp"],12).style.color=Moss;
                Text(copy,"한 무리 "+FallenMonsterCatalog.Population(stage)+"마리 · 타락한 몬스터 7종",12).style.color=Parchment;
            }
            Text(list,"1500부터 세 분위기가 500 스테이지마다 순환합니다. 레이드는 별도 전용 맵에서 진행합니다.",12).style.whiteSpace=WhiteSpace.Normal;
        }
        void ShowFallenMonsters()
        {
            PanelHeader("타락한 몬스터");var scroll=new ScrollView();scroll.style.flexGrow=1;modal.Add(scroll);
            Text(scroll,"원화 몬스터 7종 · 한 무리 24~32마리\n100부터 특수 공격 · 250부터 파쇄·출혈·오우거 기절 · 500부터 리치 회복·엘프 기절 · 1000부터 드워프 기절",12).style.whiteSpace=WhiteSpace.Normal;
            foreach(string id in FallenMonsterCatalog.Ids)
            {
                var card=Box(scroll,"monster-card-"+id,new Color(.075f,.10f,.11f));card.style.marginTop=10;card.style.paddingTop=card.style.paddingBottom=10;
                var row=Row(card);var art=new Image{sprite=InspectionPortrait(id),scaleMode=ScaleMode.ScaleToFit};art.style.width=92;art.style.height=112;row.Add(art);
                var copy=new VisualElement();copy.style.flexGrow=1;copy.style.minWidth=0;row.Add(copy);Text(copy,FallenMonsterCatalog.Name(id),16).style.color=Bronze;
                Text(copy,FallenMonsterCatalog.Description(id),12).style.whiteSpace=WhiteSpace.Normal;Text(copy,"고유 스킬 · "+FallenMonsterCatalog.Skill(id),12).style.color=Moss;
            }
            Button(modal,"사냥터 정보",ShowPlayerZones).style.marginTop=8;
        }
    }
}
