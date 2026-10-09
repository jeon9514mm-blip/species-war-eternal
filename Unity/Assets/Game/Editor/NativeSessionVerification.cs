using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration.Editor
{
    public static class NativeSessionVerification
    {
        public static string Verify()
        {
            int checks=0;void Check(bool ok,string label){checks++;if(!ok)throw new InvalidOperationException("Native session: "+label);}
            string scratch=Path.Combine("Temp","native-session-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(scratch);
            var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);
            foreach(string faction in new[]{"aurelia","noxfera"})
            {
                var payload=NativePlayerSession.NewPayload(catalog,faction);payload["unknown_extension"]=new JObject{{"한국어","원본 보존"},{"date","2026-10-09T00:00:00Z"}};
                var store=new NativeSessionStore(Path.Combine(scratch,faction+".json"),faction);Check(store.Read().Status=="missing","fresh missing");Check(store.Write(payload),"initial write");
                var reader=new NativeSessionStore(store.PathName,faction);var read=reader.Read();Check(read.Ok&&read.Revision==1&&JToken.DeepEquals(read.Payload,payload),"intact UTF8 payload");
                var session=new NativePlayerSession(catalog,read.Payload,reader);var state=session.State;var deployed=state.DeployedHeroes();
                Check(deployed.Count==10&&((JObject)payload["hero_progress"]).Count==15,"original faction roster");Check(deployed.All(state.IsFactionHero)&&state.WalletGold==500,"starting faction and wallet");
                Check(state.SetUnityChain(new[]{new ChainSkill(deployed[0],"a2"),new ChainSkill(deployed[1],"a1")},false).Ok,"persistent chain");
                var next=deployed.Take(9).ToArray();Check(state.SetUnityParty(next,"assault").Ok&&state.DeployedHeroes().Count==10,"queued party retains current battle");
                Check(state.SettleUnityPack(1,35,100).Ok,"pack reward");Check(state.WalletGold==535&&state.DeployedHeroes().Count==9&&state.Formation=="assault","reward then queued party");
                Check(deployed.Sum(id=>state.HeroProgress(id).xp)==100&&state.HeroProgress(deployed[9]).xp>0,"old party receives exact XP");
                long revision=reader.Revision;string before=state.Snapshot().ToString();Check(!state.SettleUnityPack(1,35,100).Ok&&!state.SettleUnityPack(3,35,100).Ok,"duplicate and skipped pack rejected");Check(before==state.Snapshot().ToString()&&reader.Revision==revision,"rejections do not write");
                Check(!state.SetUnityZone("moonrest_forest").Ok&&state.UnityZone=="gray_meadow","manual travel replaced by stage theme");var attempt=state.ReserveUnityRaid("moonrest_forest");long nonce=(long)attempt.Details["attempt"];
                Check(attempt.Ok&&!state.SettleUnityRaid("gray_meadow",nonce).Ok,"raid nonce binds region");Check(state.SettleUnityRaid("moonrest_forest",nonce).Ok&&state.WalletGold==2935,"exact native raid reward");Check(!state.SettleUnityRaid("moonrest_forest",nonce).Ok,"raid settles once");
                var reload=new NativeSessionStore(store.PathName,faction);var restored=reload.Read();Check(restored.Ok&&JToken.DeepEquals(restored.Payload,state.Snapshot()),"all commands survive disk reload");
                var hunt=new HuntingSimulation(1,9514,state);hunt.RestoreUnityProgress(state.UnityZone,state.UnityPacks);Check(hunt.Zone=="gray_meadow"&&hunt.PacksCleared==1&&hunt.Battle.Heroes.Count==9,"restored live hunt");
                var raid=new RaidSimulation("gray_meadow",1,9514,state.DeployedHeroes(),state);Check(raid.StateBound&&raid.Battle.Heroes.Count==9,"raid uses actual party");
                Check(!raid.BeginCounterPractice(),"rewarded raid cannot force counter practice");
                var stale=new NativeSessionStore(store.PathName,faction);var old=stale.Read();Check(reload.Write(restored.Payload),"later revision");Check(!stale.Write(old.Payload),"stale writer rejected");
                string good=File.ReadAllText(store.PathName),backup=File.ReadAllText(store.PathName+".bak");File.WriteAllText(store.PathName,"broken image");
                var recovery=new NativeSessionStore(store.PathName,faction);var recovered=recovery.Read();Check(recovered.Ok&&recovered.Source=="backup","backup recovery");Check(recovery.Write(recovered.Payload),"recovered write");Check(Directory.GetFiles(scratch,faction+".json.preserved-*.json").Any(p=>File.ReadAllText(p)=="broken image"),"damaged primary preserved");
                var future=JObject.Parse(good);future["version"]=NativeSessionStore.Version+1;File.WriteAllText(store.PathName,future.ToString());
                var blocked=new NativeSessionStore(store.PathName,faction);Check(blocked.Read().Unsupported&&!blocked.Write(payload),"future profile blocks fallback and overwrite");Check(File.ReadAllText(store.PathName)==future.ToString(),"future bytes unchanged");
                File.WriteAllText(store.PathName,good);File.WriteAllText(store.PathName+".bak",backup);
                var imported=Path.GetFullPath(Path.Combine(scratch,faction+"-import-"+Guid.NewGuid().ToString("N")+".json"));File.WriteAllText(imported+".bak",good);File.SetLastWriteTimeUtc(imported+".bak",DateTime.UtcNow.AddMinutes(1));Check(NativeSessionStore.LatestPath(scratch,faction)==imported,"import discovered from backup alone");
                var legacy=(JObject)payload.DeepClone();legacy.Remove("unity_player_profile");legacy["idle_stage"]=154;legacy["current_zone_id"]="forgotten_mine";string original=legacy.ToString();
                var converted=NativePlayerSession.ImportPayload(catalog,legacy);Check((int)converted["unity_pack_total"]==765&&(string)converted["unity_hunt_zone"]=="forgotten_mine","original stage and zone mapping");Check(legacy.ToString()==original&&JToken.DeepEquals(converted["unknown_extension"],legacy["unknown_extension"]),"import clones original intact");
            }
            bool writable=false;int writes=0;var seed=NativePlayerSession.NewPayload(catalog,"aurelia");var failed=new GameStateCommands(catalog,seed,_=>{writes++;return writable;});
            Check(failed.SettleUnityPack(1,35,22).Ok&&failed.SavePending&&failed.WalletGold==535,"failed persistence retains credited snapshot");Check(!failed.SettleUnityPack(2,35,22).Ok&&writes==1,"pending storage barrier");writable=true;Check(failed.RetrySave()&&!failed.SavePending&&failed.WalletGold==535&&writes==2,"retry writes once without duplicate credit");
            var report=new JObject{{"passed",true},{"comparisons",checks},{"synthetic_disk_profiles",true},{"real_user_profiles_read",false},{"note","Native Unity persistence, queued party/XP, exact pack and raid nonces, original stage/zone import, corruption/future/stale writer protection. No performance benchmark."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/unity-native-session.json",report.ToString());return report.ToString();
        }
    }
}
