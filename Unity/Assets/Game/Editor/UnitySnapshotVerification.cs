using System;
using System.IO;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class UnitySnapshotVerification
    {
        public static JObject Verify()
        {
            string repo=Directory.GetParent(Application.dataPath).Parent.FullName;
            string folder=Path.GetFullPath(Path.Combine(repo,"checks/unity-migration-2026-10-08/unity-store-fixtures",Guid.NewGuid().ToString("N")));
            if(!folder.StartsWith(repo+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("Fixture escaped repository.");
            Directory.CreateDirectory(folder);string path=Path.Combine(folder,"state.json");int comparisons=0;
            var suffixes=new[]{"",".bak",".tmp",".bak.tmp",".corrupt"};
            try
            {
                var store=new UnitySnapshotStore(path);
                var data=new JObject{{"wallet_gold",100},{"save_version",37},{"precise",.12345678901234567},{"large_integer",9007199254740993L},{"unknown",new JArray("달빛","🌹",true,null)},{"day","2026-10-09"}};
                var first=store.Write(data);var loaded=store.Read();
                if(!first.Ok||!loaded.Ok||loaded.Sequence!=1||!JToken.DeepEquals(loaded.Data,data))throw new InvalidOperationException("Unity snapshot lost original fields/number precision.");comparisons+=4;
                data["wallet_gold"]=200;if(!store.Write(data).Ok||store.Read().Sequence!=2)throw new InvalidOperationException("Unity snapshot replacement failed.");comparisons+=2;
                File.WriteAllText(path,"{broken");var restored=store.Read();
                if(!restored.Ok||restored.Source!="backup"||(int)restored.Data["wallet_gold"]!=100)throw new InvalidOperationException("Unity backup recovery failed.");comparisons+=3;
                if(!store.Write(data).Ok||File.ReadAllText(path+".corrupt")!="{broken")throw new InvalidOperationException("Damaged original not preserved.");comparisons+=2;
                string future="{\"unity_save_version\":2,\"content\":{\"future\":true}}";
                File.WriteAllText(path+".bak",future);string original=File.ReadAllText(path);
                var blocked=store.Write(data);
                if(blocked.Ok||!blocked.Unsupported||File.ReadAllText(path)!=original||File.ReadAllText(path+".bak")!=future)throw new InvalidOperationException("Future Unity backup overwritten.");comparisons+=4;
                File.WriteAllText(path+".bak","{}");File.WriteAllText(path,"{\"save_version\":37,\"wallet_gold\":900}");
                var legacy=store.Write(data);
                if(legacy.Ok||!legacy.ForeignFormat||File.ReadAllText(path)!="{\"save_version\":37,\"wallet_gold\":900}")throw new InvalidOperationException("Unity writer accepted a Godot save destination.");comparisons+=3;
                // Persist the command owner's one awarded snapshot, then restore
                // it into a new owner. A repeated claim must award nothing.
                File.WriteAllText(path,"{}");
                var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);
                var initial=new JObject{{"selected_faction","aurelia"},{"wallet_gold",0},{"unclaimed_gold",123},{"unclaimed_xp",7},{"unknown",new JObject{{"keep",true}}}};
                var owner=new GameStateCommands(catalog,initial,snapshot=>store.Write(snapshot).Ok);
                if(!owner.ClaimHuntingRewards().Ok||owner.SavePending)throw new InvalidOperationException("Command snapshot not saved.");comparisons+=2;
                var revived=new GameStateCommands(catalog,store.Read().Data,snapshot=>store.Write(snapshot).Ok);
                if(revived.WalletGold!=123||revived.ClaimHuntingRewards().Ok||!(bool)revived.Snapshot()["unknown"]["keep"])throw new InvalidOperationException("Reload lost reward settlement or unknown state.");comparisons+=3;
                var report=new JObject{{"passed",true},{"comparisons",comparisons},{"separate_unity_envelope",true},{"atomic_primary_backup_replacement",true},{"legacy_destination_rejected",true},{"precise_numbers_and_unknown_fields_preserved",true},{"reward_reload_no_duplicate_claim",true},{"note","Named temporary repository fixture directory only; no player save path was accessed. Native game startup and production migration UI acceptance remain unverified."}};
                File.WriteAllText(Path.Combine(repo,"checks/unity-migration-2026-10-08/unity-snapshot-store.json"),report.ToString());return report;
            }
            finally
            {
                // Remove only the five exact fixture files created in this test.
                foreach(string suffix in suffixes)if(File.Exists(path+suffix))File.Delete(path+suffix);
                Directory.Delete(folder);
            }
        }
    }
}
