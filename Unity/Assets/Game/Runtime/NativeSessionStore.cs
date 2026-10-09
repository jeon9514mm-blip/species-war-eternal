using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    public sealed class NativeSessionRead
    {
        public bool Ok,Unsupported;
        public string Status="missing",Source="";
        public long Revision;
        public JObject Payload;
    }
    // Own Unity profiles only. Original Godot files are never write targets.
    public sealed class NativeSessionStore
    {
        public const string Format="species-war-unity";
        public const int Version=1;
        readonly string faction;
        public readonly string PathName;
        public long Revision {get;private set;}
        public bool LastWriteSucceeded {get;private set;}
        public NativeSessionStore(string path,string faction)
        {
            if(faction!="aurelia"&&faction!="noxfera")throw new ArgumentException("Unknown faction.");
            PathName=Path.GetFullPath(path);this.faction=faction;
        }
        public static string LatestPath(string directory,string faction)
        {
            directory=Path.GetFullPath(directory);
            if(faction!="aurelia"&&faction!="noxfera")throw new ArgumentException("Unknown faction.");
            if(Directory.Exists(directory))
            {
                var files=Directory.GetFiles(directory,faction+"*.json*").Where(p=>Regex.IsMatch(Path.GetFileName(p),"^"+faction+"(-import-[0-9a-f]{32})?\\.json(\\.bak|\\.tmp)?$"));
                var latest=files.OrderByDescending(File.GetLastWriteTimeUtc).ThenBy(p=>p,StringComparer.Ordinal).FirstOrDefault();
                if(latest!=null)return latest.EndsWith(".bak",StringComparison.Ordinal)||latest.EndsWith(".tmp",StringComparison.Ordinal)?latest[..^4]:latest;
            }
            return Path.Combine(directory,faction+".json");
        }
        NativeSessionRead Candidate(string path)
        {
            if(!File.Exists(path))return new NativeSessionRead();
            try
            {
                using var stream=new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.Read);
                if(stream.Length>LegacySaveCodec.MaxBytes)return new NativeSessionRead{Status="too_large"};
                using var text=new StreamReader(stream,new UTF8Encoding(false,true),true);
                using var json=new JsonTextReader(text){DateParseHandling=DateParseHandling.None,MaxDepth=128};
                var envelope=JToken.ReadFrom(json) as JObject;
                while(json.Read())if(json.TokenType!=JsonToken.Comment)return new NativeSessionRead{Status="invalid_json"};
                if(envelope==null||(string)envelope["format"]!=Format)return new NativeSessionRead{Status="invalid_format"};
                long version=GameStateCommands.Integer(envelope["version"],0,0,int.MaxValue);
                if(version>Version)return new NativeSessionRead{Status="unsupported_version",Unsupported=true};
                if(version!=Version||envelope["payload"] is not JObject payload)return new NativeSessionRead{Status="invalid_payload"};
                string digest=(string)envelope["sha256"];envelope.Remove("sha256");
                if(digest==null||digest!=LegacySaveCodec.Hash(envelope.ToString(Formatting.None)))return new NativeSessionRead{Status="checksum_mismatch"};
                if(GameStateCommands.Integer(payload["save_version"],1,1,int.MaxValue)>LegacySaveCodec.Version)return new NativeSessionRead{Status="unsupported_payload",Unsupported=true};
                if((string)payload["selected_faction"]!=faction||(bool?)payload["unity_player_profile"]!=true)return new NativeSessionRead{Status="invalid_profile"};
                return new NativeSessionRead{Ok=true,Status="loaded",Revision=GameStateCommands.Integer(envelope["revision"],0,0,GameStateCommands.CurrencyCap),Payload=(JObject)payload.DeepClone()};
            }
            catch(Exception e)when(e is IOException||e is UnauthorizedAccessException||e is JsonException||e is DecoderFallbackException||e is InvalidCastException||e is FormatException)
            {return new NativeSessionRead{Status="read_failed"};}
        }
        public NativeSessionRead Read()
        {
            var failure=new NativeSessionRead();
            foreach(string suffix in new[]{"",".bak",".tmp"})
            {
                var result=Candidate(PathName+suffix);if(result.Unsupported)return result;
                if(result.Ok){result.Source=suffix.Length==0?"primary":suffix==".bak"?"backup":"temporary";Revision=result.Revision;LastWriteSucceeded=true;return result;}
                if(result.Status!="missing")failure=result;
            }
            return failure;
        }
        public bool Write(JObject payload)
        {
            LastWriteSucceeded=false;
            if((bool?)payload?["unity_player_profile"]!=true||(string)payload["selected_faction"]!=faction||GameStateCommands.Integer(payload["save_version"],1,1,int.MaxValue)>LegacySaveCodec.Version)return false;
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(PathName));
                using var gate=new FileStream(PathName+".lock",FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None);
                var primary=Candidate(PathName);
                if(primary.Unsupported||primary.Ok&&primary.Revision!=Revision)return false;
                if(!primary.Ok&&(File.Exists(PathName)||File.Exists(PathName+".bak")||File.Exists(PathName+".tmp")))
                {
                    long expected=Revision;var recover=Read();LastWriteSucceeded=false;if(!recover.Ok||recover.Revision!=expected){Revision=expected;return false;}
                }
                var envelope=new JObject{{"format",Format},{"version",Version},{"revision",Revision+1},{"payload",payload.DeepClone()}};
                envelope["sha256"]=LegacySaveCodec.Hash(envelope.ToString(Formatting.None));string raw=envelope.ToString(Formatting.None);
                if(Encoding.UTF8.GetByteCount(raw)>LegacySaveCodec.MaxBytes)return false;
                string archive=".preserved-"+Guid.NewGuid().ToString("N");
                if(File.Exists(PathName+".tmp"))File.Move(PathName+".tmp",PathName+archive+".tmp");
                byte[] bytes=new UTF8Encoding(false).GetBytes(raw);
                using(var file=new FileStream(PathName+".tmp",FileMode.CreateNew,FileAccess.Write,FileShare.None)){file.Write(bytes,0,bytes.Length);file.Flush(true);}
                if(primary.Ok)File.Replace(PathName+".tmp",PathName,PathName+".bak");
                else
                {
                    if(File.Exists(PathName))File.Move(PathName,PathName+archive+".json");
                    File.Move(PathName+".tmp",PathName);
                }
                Revision++;LastWriteSucceeded=true;return true;
            }
            catch(Exception e)when(e is IOException||e is UnauthorizedAccessException||e is NotSupportedException)
            {return false;}
        }
    }
}
