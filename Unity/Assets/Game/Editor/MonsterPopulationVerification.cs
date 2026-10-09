using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class MonsterPopulationVerification
    {
        public static string Verify()
        {
            int checks=0;void Check(bool ok,string message){checks++;if(!ok)throw new InvalidOperationException("Monster population: "+message);}
            var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);var rows=new JArray();
            foreach(int stage in new[]{1,499,500,999,1000,1500})
            foreach(int seed in new[]{19,9514,3107})
            {
                var state=new GameStateCommands(catalog,NativePlayerSession.NewPayload(catalog,"aurelia"),_=>true);
                var sim=new HuntingSimulation(10,seed,state);sim.Stage=stage;sim.Battle.Enemies.Clear();sim.SpawnPack();
                Check(sim.Battle.Enemies.Count==FallenMonsterCatalog.Population(stage),"exact requested population "+stage);
                Check(FallenMonsterCatalog.Ids.All(id=>sim.Battle.Enemies.Any(e=>e.Id==id)),"seven painted species available in each band");
                foreach(var enemy in sim.Battle.Enemies){Check(HuntStageWorld.Clamp(enemy.Position)==enemy.Position,"inside map");Check(sim.ClearAt(enemy,enemy.Position),"spawn clear of party and other arrivals");}
                for(int tick=0;tick<120;tick++)sim.Step(.05);
                foreach(var enemy in sim.Battle.Enemies.Where(e=>e.Alive))Check(sim.ClearAt(enemy,enemy.Position),"legal approach after movement");
                rows.Add(new JObject{{"stage",stage},{"seed",seed},{"population",sim.Battle.Enemies.Count},{"species",new JArray(sim.Battle.Enemies.Select(e=>e.Id).Distinct())}});
            }
            foreach(string id in new[]{"fallen_ogre","fallen_lich","fallen_harpy"})
            {
                var atlas=OriginalCatalog.Atlas(id);var texture=OriginalCatalog.Texture(id);var surface=OriginalReliefMesh.Load(id);
                Check(texture!=null&&texture.width==1024&&texture.height==1024&&texture.alphaIsTransparency,"game-ready RGBA atlas "+id);
                Check(atlas.attack.frames.Length==3&&atlas.motion.frames.Length==7&&surface.Body.triangles.Length>0,"authored poses and relief geometry "+id);
                foreach(var pose in atlas.attack.frames.Concat(atlas.motion.frames))Check(pose.region[0]>=0&&pose.region[1]>=0&&pose.region[0]+pose.region[2]<=texture.width+.01f&&pose.region[1]+pose.region[3]<=texture.height+.01f,"atlas crop bounds "+id);
            }
            var legacy=new HuntingSimulation(10,19);Check(legacy.Battle.Enemies.Count==12,"original review fixture preserved");
            foreach(int stage in new[]{1,500,1000})
            {
                var payload=NativePlayerSession.NewPayload(catalog,"aurelia");int cleared=(stage-1)*5;payload["unity_pack_total"]=cleared;
                var state=new GameStateCommands(catalog,payload,_=>true);int count=FallenMonsterCatalog.Population(stage);long gold=state.WalletGold;
                Check(!state.SettleUnityPack(cleared+1,10,10,count+1).Ok&&state.WalletGold==gold,"reject oversized stage wave without mutation");
                Check(state.SettleUnityPack(cleared+1,10,10,count).Ok&&state.WalletGold==gold+10&&state.UnityPacks==cleared+1,"expanded pack rewards accepted");
                var settled=state.Snapshot().ToString();Check(!state.SettleUnityPack(cleared+1,10,10,count).Ok&&state.Snapshot().ToString()==settled,"duplicate expanded pack cannot award again");
            }
            var report=new JObject{{"passed",true},{"comparisons",checks},{"waves",rows},{"note","Spawn/body clearance, six seconds of legal movement, stage-band population and actual imported painted assets. This is not a frame-rate benchmark or long-run difficulty certification."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/monster-population-cp19.json",report.ToString());return report.ToString();
        }
    }
}
