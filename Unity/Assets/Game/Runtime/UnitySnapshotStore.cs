using System;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    public sealed class UnitySnapshotResult
    {
        public bool Ok,Unsupported,ForeignFormat;
        public string Status,Raw,Source;
        public long Sequence;
        public JObject Data;
    }
    // Separate Unity envelope. Callers must supply its explicit destination;
    // this class never searches for or writes to a Godot save location.
    public sealed class UnitySnapshotStore
    {
        const int Version=1;
        readonly string path;
        public UnitySnapshotStore(string destination){path=Path.GetFullPath(destination);}
        static UnitySnapshotResult Fail(string status,bool unsupported=false)=>new(){Status=status,Unsupported=unsupported};
        public UnitySnapshotResult Read()
        {
            bool exists=false;
            foreach(string suffix in new[]{"",".bak",".tmp"})
            {
                exists|=File.Exists(path+suffix);var result=Candidate(path+suffix);
                if(result.Unsupported||result.ForeignFormat)return result;
                if(result.Ok){result.Source=suffix==""?"primary":suffix==".bak"?"backup":"temporary";return result;}
            }
            return Fail(exists?"corrupt":"missing");
        }
        public UnitySnapshotResult Write(JObject content)
        {
            var candidates=new[]{"",".bak",".tmp"}.Select(s=>Candidate(path+s)).ToArray();
            if(candidates.Any(c=>c.Unsupported))return Fail("unsupported_version",true);
            if(candidates.Any(c=>c.ForeignFormat))return new UnitySnapshotResult{Status="legacy_destination_rejected",ForeignFormat=true};
            long sequence=candidates.Where(c=>c.Ok).Select(c=>c.Sequence).DefaultIfEmpty(0).Max();
            if(sequence==long.MaxValue)return Fail("sequence_exhausted");
            string canonical=Canonical(content);
            var envelope=new JObject{{"unity_save_version",Version},{"sequence",sequence+1},{"content",content.DeepClone()},{"sha256",LegacySaveCodec.Hash(canonical)}};
            string serialized=envelope.ToString(Formatting.None);
            if(Encoding.UTF8.GetByteCount(serialized)>LegacySaveCodec.MaxBytes)return Fail("too_large");
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(path));WriteFlushed(path+".tmp",serialized);
                if(!Candidate(path+".tmp").Ok)return Fail("verification_failed");
                var primary=candidates[0];
                if(primary.Ok)
                {
                    WriteFlushed(path+".bak.tmp",primary.Raw);
                    if(!Candidate(path+".bak.tmp").Ok)return Fail("backup_verification_failed");
                    Replace(path+".bak.tmp",path+".bak");
                }
                else if(File.Exists(path)&&!File.Exists(path+".corrupt"))File.Copy(path,path+".corrupt");
                Replace(path+".tmp",path);
                return new UnitySnapshotResult{Ok=true,Status="saved",Sequence=sequence+1};
            }
            catch(IOException){return Fail("write_failed");}
            catch(UnauthorizedAccessException){return Fail("write_failed");}
        }
        static void WriteFlushed(string destination,string text)
        {
            using var file=new FileStream(destination,FileMode.Create,FileAccess.Write,FileShare.None);
            byte[] bytes=new UTF8Encoding(false,true).GetBytes(text);file.Write(bytes,0,bytes.Length);file.Flush(true);
        }
        static void Replace(string source,string destination)
        {
            if(File.Exists(destination))File.Replace(source,destination,null);
            else File.Move(source,destination);
        }
        static UnitySnapshotResult Candidate(string source)
        {
            if(!File.Exists(source))return Fail("missing");
            string raw;
            try
            {
                using var file=new FileStream(source,FileMode.Open,FileAccess.Read,FileShare.Read);
                if(file.Length>LegacySaveCodec.MaxBytes)return Fail("too_large");
                using var text=new StreamReader(file,new UTF8Encoding(false,true),true);raw=text.ReadToEnd();
            }
            catch(IOException){return Fail("read_failed");}
            catch(UnauthorizedAccessException){return Fail("read_failed");}
            catch(DecoderFallbackException){return Fail("invalid_json");}
            try
            {
                using var text=new StringReader(raw);
                using var reader=new JsonTextReader(text){DateParseHandling=DateParseHandling.None,FloatParseHandling=FloatParseHandling.Double,MaxDepth=128};
                var root=JToken.ReadFrom(reader) as JObject;if(root==null)return Fail("invalid_json");
                if(root["unity_save_version"]==null&&(root["save_version"]!=null||root["_save_integrity"]!=null))return new UnitySnapshotResult{Status="legacy_format",ForeignFormat=true};
                while(reader.Read())if(reader.TokenType!=JsonToken.Comment)return Fail("invalid_json");
                var version=root["unity_save_version"];if(version?.Type!=JTokenType.Integer&&version?.Type!=JTokenType.Float)return Fail("invalid_version");
                double number=version.Value<double>();if(!double.IsFinite(number)||number<1||number%1!=0)return Fail("invalid_version");
                if(number>Version)return Fail("unsupported_version",true);
                if(root["content"] is not JObject content||root["sha256"]?.Type!=JTokenType.String)return Fail("invalid_integrity");
                if(LegacySaveCodec.Hash(Canonical(content))!=(string)root["sha256"])return Fail("checksum_mismatch");
                if(root["sequence"]?.Type!=JTokenType.Integer)return Fail("invalid_sequence");
                long sequence=root["sequence"].Value<long>();if(sequence<1)return Fail("invalid_sequence");
                return new UnitySnapshotResult{Ok=true,Status="loaded",Sequence=sequence,Raw=raw,Data=content};
            }
            catch(JsonException){return Fail("invalid_json");}
            catch(FormatException){return Fail("invalid_json");}
            catch(OverflowException){return Fail("invalid_sequence");}
            catch(InvalidCastException){return Fail("invalid_sequence");}
        }
        public static string Canonical(JToken value)
        {
            JToken Ordered(JToken token)
            {
                if(token is JObject obj){var result=new JObject();foreach(var p in obj.Properties().OrderBy(p=>p.Name,StringComparer.Ordinal))result.Add(p.Name,Ordered(p.Value));return result;}
                if(token is JArray array)return new JArray(array.Select(Ordered));
                return token.DeepClone();
            }
            return Ordered(value).ToString(Formatting.None);
        }
    }
}
