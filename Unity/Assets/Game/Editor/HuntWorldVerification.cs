using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class HuntWorldVerification
    {
        public static string Verify()
        {
            int checks=0;void Check(bool ok,string label){checks++;if(!ok)throw new InvalidOperationException("Hunt world: "+label);}
            foreach(int stage in new[]{1,499,500,999,1000,1499,1500,1999,2000,2499})
                Check(stage>=HuntStageWorld.Start(stage)&&stage<=HuntStageWorld.End(stage),"stage range "+stage);
            Check(HuntStageWorld.Zone(499)=="gray_meadow"&&HuntStageWorld.Zone(500)=="forgotten_mine"&&HuntStageWorld.Zone(999)=="forgotten_mine"&&HuntStageWorld.Zone(1000)=="moonrest_forest"&&HuntStageWorld.Zone(1500)=="gray_meadow","500-stage theme boundaries");
            Check(HuntStageWorld.HalfWidth==23&&HuntStageWorld.HalfDepth==13,"double linear playable dimensions");
            var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);var scenarios=new JArray();
            foreach(string formation in new[]{"balanced","assault","bulwark","volley"})
            {
                for(int count=1;count<=10;count++)
                {
                    var p=Enumerable.Range(0,count).Select(i=>HuntFormationLayout.Position(formation,i,count)).ToArray();
                    for(int i=0;i<count;i++)for(int j=i+1;j<count;j++){var d=p[i]-p[j];Check(new Vector2(d.x/1.5f,d.y/2.65f).sqrMagnitude>=.999f,formation+" initial clearance "+count);}
                }
                var payload=NativePlayerSession.NewPayload(catalog,"aurelia");foreach(var p in ((JObject)payload["hero_progress"]).Properties())p.Value["level"]=50;payload["formation_id"]=formation;
                var state=new GameStateCommands(catalog,payload,_=>true);var sim=new HuntingSimulation(1,9514,state);
                Check(sim.Formation==formation&&sim.Battle.Heroes[0].Position==HuntFormationLayout.Position(formation,0,10),"saved formation creates actual bodies "+formation);
                Check(sim.Battle.Enemies.Count==FallenMonsterCatalog.Population(sim.Stage)&&sim.Battle.Enemies.Where(e=>e.Position.x>0).Count()>=6&&sim.Battle.Enemies.Where(e=>e.Position.x<0).Count()>=6,"distributed expanded entrances "+formation);
                for(int tick=0;tick<1600&&!sim.Defeated;tick++)
                {
                    sim.Step(.05);var actors=sim.Battle.Heroes.Concat(sim.Battle.Enemies).Where(a=>a.Alive).ToArray();
                    foreach(var a in actors){Check(Vector2.Distance(a.Position,a.PreviousPosition)<=.111f,"bounded continuous movement");Check(Mathf.Abs(a.Position.x)<=23.001f&&Mathf.Abs(a.Position.y)<=13.001f,"world bounds");}
                    if(tick%10!=0)continue;
                    for(int i=0;i<actors.Length;i++)for(int j=i+1;j<actors.Length;j++){var axes=sim.BodyAxes(actors[i],actors[j]);var d=actors[i].Position-actors[j].Position;Check(new Vector2(d.x/axes.x,d.y/axes.y).sqrMagnitude>=.998f,"live body clearance");}
                }
                Check(sim.PacksCleared>=2&&!sim.Defeated,"formation hunt advances "+formation);scenarios.Add(new JObject{{"formation",formation},{"packs",sim.PacksCleared},{"seconds",sim.Elapsed}});
            }
            foreach(int stage in new[]{499,999})
            {
                var payload=NativePlayerSession.NewPayload(catalog,"aurelia");int before=(stage-1)*5+4;payload["unity_pack_total"]=before;payload["unity_loot_salt"]="checkpoint14-fixed";
                var state=new GameStateCommands(catalog,payload,_=>true);string oldZone=state.UnityZone;var settled=state.SettleUnityPack(before+1,35,22);
                Check(settled.Ok&&state.UnityZone==HuntStageWorld.Zone(stage+1)&&(string)state.Snapshot()["unity_last_loot"]?["zone"]==oldZone,"boundary pays previous wave before theme advances");
                var sim=new HuntingSimulation(1,9514,state);sim.RestoreUnityProgress(state.UnityZone,state.UnityPacks);Check(sim.Stage==stage+1&&sim.Zone==state.UnityZone,"boundary reload restores next theme");
                string once=state.Snapshot().ToString();Check(!state.SettleUnityPack(before+1,35,22).Ok&&once==state.Snapshot().ToString(),"reward nonce rejects duplicate drops and wallet");
            }
            Check(GameStateCommands.UnityDropRarity(1,.039,0)=="전설"&&GameStateCommands.UnityDropRarity(1,.04,0)=="희귀"&&GameStateCommands.UnityDropRarity(1,.17,0)=="일반"&&GameStateCommands.UnityDropRarity(1,.74,0)=="","source rarity boundary rules");
            var full=NativePlayerSession.NewPayload(catalog,"aurelia");full["unity_loot_salt"]="checkpoint14-fixed";
            JObject Gear(string id)=>OriginalEquipmentRules.Normalize(new JObject{{"id",id},{"slot","weapon"},{"level",1},{"rarity","일반"}});
            full["loot_inventory"]=new JArray(Enumerable.Range(0,200).Select(i=>Gear("bag_"+i)));full["equipment_overflow"]=new JArray(Enumerable.Range(0,3000).Select(i=>Gear("mail_"+i)));
            bool writable=false;int writes=0;var blocked=new GameStateCommands(catalog,full,_=>{writes++;return writable;});var reward=blocked.SettleUnityPack(1,35,22);
            Check(reward.Ok&&reward.SavePending&&blocked.HasDeferredUnityLoot,"full storage retains awarded items during save failure");var ids=((JArray)reward.Details["drops"]).OfType<JObject>().Select(i=>(string)i["id"]).ToArray();Check(ids.Length>0&&ids.Distinct().Count()==ids.Length,"unique receipt identities");
            var held=new HuntingSimulation(1,9514,blocked);held.Step(.05);Check(held.Ticks==0&&!held.CanManualCast(held.Battle.Heroes[0].Id,"a1"),"full storage holds simulation and manual casts");
            string beforeRetry=blocked.Snapshot().ToString();writable=true;Check(blocked.RetrySave()&&writes==2&&beforeRetry==blocked.Snapshot().ToString(),"storage retry never rerolls equipment");
            Check(!blocked.SettleUnityPack(2,35,22).Ok&&!blocked.ReserveUnityRaid("gray_meadow").Ok,"pending equipment prevents additional rewards");
            for(int i=0;i<13;i++)Check(blocked.DecomposeGear("bag_"+i).Ok,"free storage through actual commands");
            Check(blocked.ClaimUnityEquipmentMail().Ok&&!blocked.HasDeferredUnityLoot&&blocked.Inventory().Count==200,"mail receive clears deferred ownership");
            var owned=blocked.Inventory().Concat(blocked.UnityEquipmentMail()).Select(i=>(string)i["id"]).ToArray();Check(ids.All(id=>owned.Count(x=>x==id)==1),"every awarded item has exactly one owner");
            var reloaded=new GameStateCommands(catalog,blocked.Snapshot(),_=>true);Check(!reloaded.HasDeferredUnityLoot&&JToken.DeepEquals(reloaded.Snapshot(),blocked.Snapshot()),"mail and receipts survive reload");
            var party=reloaded.DeployedHeroes().Reverse().Take(9).ToArray();Check(reloaded.SaveUnityPartyPreset(2,party,"volley").Ok,"ordered party preset save");string presetBefore=reloaded.Snapshot().ToString();Check(!reloaded.SaveUnityPartyPreset(3,party,"volley").Ok&&presetBefore==reloaded.Snapshot().ToString(),"invalid preset is atomic");
            var report=new JObject{{"passed",true},{"comparisons",checks},{"formations",scenarios},{"source_drop_policy","Godot EquipmentRules + Main rarity thresholds; one roll per defeated monster, settled with the wave nonce"},{"note","Synthetic domain verification, not a performance benchmark or proof of bespoke map art."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/hunt-world-cp19.json",report.ToString());return report.ToString();
        }
    }
}
