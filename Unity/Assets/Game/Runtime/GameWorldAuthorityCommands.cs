using System;
using System.Linq;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using L=Eternal.UnityMigration.LegacyFeatureCatalog;

namespace Eternal.UnityMigration
{
    public sealed partial class GameStateCommands
    {
        void NormalizeWorldGateway()
        {
            var gateway=Map(data,"world_server_gateway");string mode=(string)gateway["mode"];
            gateway["mode"]=mode=="remote_server"?mode:"local_authority";
            gateway["connected"]=mode!="remote_server";gateway["failure_streak"]=0;gateway["gateway_version"]=5;
        }
        static string GatewayError(JObject state)
        {
            var gateway=L.Object(state["world_server_gateway"]);
            return (string)gateway["mode"]=="remote_server"?"원격 서버 어댑터 미구현":gateway["connected"]?.Type==JTokenType.Boolean&&!L.Flag(gateway["connected"])?"로컬 권한 연결 끊김":"";
        }
        public StateCommandResult WarCommand(string action,int x=-1,int y=-1,string context="",long expectedRevision=-1,long now=0,string requestId="",string expectedFaction="")=>Commit(state=>
        {
            string gate=GatewayError(state);if(gate.Length>0)return StateCommandResult.Fail(gate);
            if(expectedFaction.Length>0&&expectedFaction!=Faction)return StateCommandResult.Fail("진영이 변경되었습니다.");
            var authority=Map(state,"world_authority");var receipts=Map(authority,"processed_commands");
            long serial=L.N(authority["last_command_id"],0,CurrencyCap-1)+1;
            string id=requestId.Length>0?requestId:"unity-"+serial;if(id.Length>128)return StateCommandResult.Fail("명령 ID를 확인하세요.");
            string fingerprint=new JArray(Faction,action,x,y,context,expectedRevision).ToString(Formatting.None);
            if(receipts[id] is JObject old)
            {
                if((string)old["unity_fingerprint"]!=fingerprint)return StateCommandResult.Fail("다른 명령에 사용된 ID입니다.");
                var replay=StateCommandResult.Success((string)old["reason"]??"이미 처리한 명령");replay.Details=(JObject)L.Object(old["details"]).DeepClone();replay.Details["replayed"]=true;return replay;
            }
            var result=WarCommandDraft(state,action,x,y,context,expectedRevision,now);
            if(!result.Ok)return result;
            authority["authority_version"]=6;authority["last_command_id"]=serial;authority["last_revision"]=state["faction_war"]?["revision"]??result.Details["revision"]??0;
            receipts[id]=new JObject{{"accepted",true},{"reason",result.Message},{"details",result.Details.DeepClone()},{"unity_fingerprint",fingerprint},{"faction",Faction}};
            var log=L.Array(authority["command_log"]);log.Insert(0,new JObject{{"id",id},{"kind",action},{"accepted",true},{"faction",Faction},{"at",now>0?now:L.Now}});while(log.Count>40)log.RemoveAt(log.Count-1);authority["command_log"]=log;
            while(receipts.Count>256)receipts.Properties().First().Remove();
            var gateway=Map(state,"world_server_gateway");gateway["failure_streak"]=0;gateway["last_error"]="";gateway["unity_last_success_unix"]=now>0?now:L.Now;
            return result;
        });
        public JObject WorldConnectionStatus()
        {var gateway=L.Object(data["world_server_gateway"]);return new JObject{{"mode",gateway["mode"]??"local_authority"},{"connected",L.Flag(gateway["connected"])},{"error",GatewayError(data)},{"retry_seconds",Math.Min(15,Math.Pow(2,Math.Min(4,L.N(gateway["failure_streak"]))))},{"revision",data["faction_war"]?["revision"]??0}};}
        public StateCommandResult SetWorldConnection(bool connected)=>Commit(state=>
        {
            var gateway=Map(state,"world_server_gateway");if(connected&&(string)gateway["mode"]=="remote_server")return StateCommandResult.Fail("원격 서버 재접속 어댑터 미구현");
            gateway["connected"]=connected;gateway["last_error"]=connected?"":"로컬 권한 연결 끊김";
            if(connected){gateway["failure_streak"]=0;gateway["unity_last_success_unix"]=L.Now;}
            else gateway["failure_streak"]=Math.Min(10,L.N(gateway["failure_streak"])+1);
            // Current state is authoritative. Cached snapshots are never imported.
            return StateCommandResult.Success(connected?"로컬 권한 재연결 완료":"로컬 권한 연결 중지");
        });
        public StateCommandResult WorldClockSample(double measuredOffset,bool first=false)=>Commit(state=>
        {
            if(!double.IsFinite(measuredOffset))return StateCommandResult.Fail("시간 표본이 유효하지 않습니다.");
            var authority=Map(state,"world_authority");double current=L.F(authority["server_time_offset_seconds"]);
            authority["unity_clock_warning"]=Math.Abs(current-measuredOffset)>8;
            authority["server_time_offset_seconds"]=first?measuredOffset:current+Math.Clamp(measuredOffset-current,-.75,.75);
            return StateCommandResult.Success("권한 시간 확인");
        });
    }
}
