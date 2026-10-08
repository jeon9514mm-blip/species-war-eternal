using System;
using System.IO;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration.Editor
{
    public static class SaveCompatibilityVerification
    {
        public static JObject Verify()
        {
            var oracle=JObject.Parse(File.ReadAllText("Assets/Game/Editor/Fixtures/save-integrity-fixtures.json"));
            int comparisons=0,canonicalCases=0;
            foreach(JObject row in oracle["cases"])
            {
                string raw=(string)row["raw"];var actual=LegacySaveCodec.Parse(raw);var expected=row["expected"];
                void Equal(string key,object a,object b){comparisons++;if(!Equals(a,b))throw new InvalidOperationException("Legacy save "+row["name"]+" "+key+": "+a+" != "+b);}
                Equal("status",actual.Status,(string)expected["status"]);Equal("ok",actual.Ok,(bool?)expected["ok"]??false);
                Equal("unsupported",actual.Unsupported,(bool?)expected["unsupported"]??false);
                if(!actual.Ok)continue;
                Equal("migrated",actual.Migrated,(bool?)expected["migrated"]??false);
                Equal("raw preservation",actual.Raw,raw);
                Equal("complete data",LegacySaveCodec.Canonical(actual.Data),LegacySaveCodec.Canonical(expected["data"]));
                if(row["canonical"]!=null){Equal("Godot canonical",LegacySaveCodec.Canonical(actual.Data),(string)row["canonical"]);canonicalCases++;}
            }
            // Named repository fixture paths only: verify fallback/version guards
            // and prove this importer never changes primary/backup/temporary bytes.
            const string folder="../checks/unity-migration-2026-10-08/codec-fixtures";
            Directory.CreateDirectory(folder);string path=Path.Combine(folder,"legacy-read.json");
            string valid=(string)oracle["cases"][0]["raw"],unsupported="{\"save_version\":38,\"future_unknown_field\":true}";
            void Write(string primary,string backup,string temporary)
            {File.WriteAllText(path,primary);File.WriteAllText(path+".bak",backup);File.WriteAllText(path+".tmp",temporary);}
            Write("{broken",valid,valid);var restored=LegacySaveCodec.Read(path);comparisons++;
            if(!restored.Ok||restored.Source!="backup")throw new InvalidOperationException("Valid legacy backup not selected.");
            if(File.ReadAllText(path)!="{broken"||File.ReadAllText(path+".bak")!=valid||File.ReadAllText(path+".tmp")!=valid)throw new InvalidOperationException("Read-only importer changed fixture files.");comparisons+=3;
            Write(unsupported,valid,valid);if(!LegacySaveCodec.Read(path).Unsupported)throw new InvalidOperationException("Future primary replaced by older backup.");comparisons++;
            Write("{broken",unsupported,valid);if(!LegacySaveCodec.Read(path).Unsupported)throw new InvalidOperationException("Future backup skipped for older temporary.");comparisons++;
            Write(valid,unsupported,unsupported);if(!LegacySaveCodec.Read(path).Ok)throw new InvalidOperationException("Original first-valid read order changed.");comparisons++;
            Write("{broken","[]",valid);var temporary=LegacySaveCodec.Read(path);if(!temporary.Ok||temporary.Source!="temporary")throw new InvalidOperationException("Temporary recovery failed.");comparisons++;
            var large=LegacySaveCodec.Parse(new string(' ',LegacySaveCodec.MaxBytes+1));if(large.Status!="too_large")throw new InvalidOperationException("Legacy size guard missing.");comparisons++;
            var result=new JObject{{"passed",true},{"comparisons",comparisons},{"production_fixture_cases",((JArray)oracle["cases"]).Count},{"exact_canonical_cases",canonicalCases},{"primary_backup_temporary_read_only",true},{"future_version_guard",true},{"note","Synthetic repository fixture files only; no real player save was accessed. This verifies compatibility parsing, not a completed gameplay state migration or Unity write transaction."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/legacy-save-compatibility.json",result.ToString());return result;
        }
    }
}
