using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class CombatReadabilityVerification
    {
        public static string Verify()
        {
            int checks=0;void Check(bool ok,string label){checks++;if(!ok)throw new InvalidOperationException("Combat readability: "+label);}
            foreach(string zone in new[]{"gray_meadow","forgotten_mine","moonrest_forest"})
            {
                Check(Resources.Load<Texture2D>(HuntEnvironmentPresentation.Resource(zone))!=null,"zone painting "+zone);
                var raid=new RaidSimulation(zone,50);var view=RaidResponseView.Read(raid);Check(!view.Visible,"idle raid does not invent a mechanic "+zone);
                var warning=(JObject)raid.Design["phases"][0];raid.StartWarning(warning);double remaining=raid.TelegraphRemaining;int ticks=raid.Ticks,version=raid.WarningVersion;var hp=raid.Battle.Heroes.Select(h=>h.Hp).ToArray();
                view=RaidResponseView.Read(raid);Check(view.Timed&&view.Kind=="warning"&&Math.Abs(view.Remaining-remaining)<.0001,"primary authoritative timer "+zone);
                raid.SecondWarning=RaidFootprint.Create("curse",raid.Boss.Position,Array.Empty<Vector2>(),new JObject());raid.SecondProfile=new JObject{{"name","Synthetic earlier wave"},{"telegraph",2.0}};raid.SecondWaveRemaining=.15;
                view=RaidResponseView.Read(raid);Check(view.Kind=="secondary"&&Math.Abs(view.Remaining-.15)<.0001,"earlier second wave takes priority "+zone);
                Check(raid.Ticks==ticks&&raid.WarningVersion==version&&raid.TelegraphRemaining==remaining&&raid.Battle.Heroes.Select(h=>h.Hp).SequenceEqual(hp),"observer does not mutate combat "+zone);
            }
            var practice=new RaidSimulation("gray_meadow",50);practice.BeginCounterPractice();practice.AutoEvade=false;
            while(practice.TelegraphRemaining>.5)practice.Step(.05);var counter=RaidResponseView.Read(practice);Check(counter.Kind=="counter"&&counter.Timed&&Math.Abs(counter.Remaining-practice.TelegraphRemaining)<.0001,"actual counter-window priority");
            var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);var payload=NativePlayerSession.NewPayload(catalog,"aurelia");var state=new GameStateCommands(catalog,payload,_=>true);var heroes=state.DeployedHeroes();
            var hunt=new[]{new ChainSkill(heroes[0],"a1"),new ChainSkill(heroes[1],"a2")};var regional=new[]{new ChainSkill(heroes[2],"ultimate"),new ChainSkill(heroes[3],"a1")};
            Check(state.SetUnityChain(hunt,false).Ok&&state.SetUnityRaidChain("gray_meadow",regional,true).Ok,"separate chain commits");
            var snapshot=state.Snapshot();Check((bool)snapshot["unity_chain_enabled"]==false&&(bool)snapshot["unity_raid_chains"]["gray_meadow"]["enabled"],"separate enabled flags");
            Check(!state.SetUnityRaidChain("invalid",regional,true).Ok&&!state.SetUnityRaidChain("gray_meadow",new[]{new ChainSkill("veliria","a1")},true).Ok,"invalid region and opposite faction rejected");
            var reloaded=new GameStateCommands(catalog,snapshot,_=>true);var simulation=new HuntingSimulation(1,9514,reloaded);Check(simulation.Chain.Restore(hunt,false)&&simulation.Chain.Entries.Count==2,"short chain restores exact length");string before=string.Join(",",simulation.Chain.Entries);
            Check(!simulation.Chain.Restore(new[]{hunt[0],hunt[0]},true)&&before==string.Join(",",simulation.Chain.Entries)&&!simulation.Chain.Enabled,"invalid restore leaves chain intact");
            var report=new JObject{{"passed",true},{"comparisons",checks},{"actual_user_saves_read",false},{"note","Three painting resources, earliest-warning/actual counter cues are read-only; separate regional chain storage and atomic exact-length restoration. No FPS benchmark."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/combat-readability.json",report.ToString());return report.ToString();
        }
    }
}
