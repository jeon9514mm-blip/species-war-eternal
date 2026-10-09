using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class RaidPresentationVerification
    {
        public static string Verify()
        {
            int checks=0;float clearance=float.MaxValue,movement=0;var cases=new JArray();
            void Check(bool ok,string label){checks++;if(!ok)throw new InvalidOperationException("Raid presentation: "+label);}
            foreach(string zone in new[]{"gray_meadow","forgotten_mine","moonrest_forest"})
            {
                var idle=new RaidSimulation(zone,50);Check(!RaidMechanicView.Read(idle).Visible,"phase one does not invent mechanics "+zone);
                var positions=idle.Battle.Heroes.Select(h=>h.Position).ToArray();Check(idle.SpreadFormation()&&idle.MovementOrder=="산개","spread accepted "+zone);Check(positions.SequenceEqual(idle.Battle.Heroes.Select(h=>h.Position)),"order never teleports "+zone);
                idle.Paused=true;Check(!idle.SpreadFormation(),"paused spread rejected");idle.ResumeFormation();Check(idle.MovementOrder=="산개","paused follow rejected");idle.Paused=false;idle.ResumeFormation();Check(idle.MovementOrder=="역할 추적","resume roles");idle.Rally(Vector2.zero);Check(idle.MovementOrder=="집결","ground rally supersedes spread");idle.SpreadFormation();
                idle.Boss.Attack=0;foreach(var h in idle.Battle.Heroes)h.AttackRemaining=1000;
                for(int tick=0;tick<300;tick++)
                {
                    idle.Step(.05);var actors=idle.Battle.Heroes.Concat(idle.Battle.Enemies).Where(a=>a.Alive).ToArray();
                    foreach(var actor in actors){float step=Vector2.Distance(actor.Position,actor.PreviousPosition);movement=Mathf.Max(movement,step);Check(step<=.221f,"spread retains bounded movement");Check(RaidFootprint.Floor.Contains(actor.Position),"spread keeps actor inside floor");}
                    for(int i=0;i<actors.Length;i++)for(int j=i+1;j<actors.Length;j++){var axes=RaidSimulation.BodyAxes(actors[i],actors[j]);var d=actors[i].Position-actors[j].Position;float n=new Vector2(d.x/axes.x,d.y/axes.y).magnitude;clearance=Mathf.Min(clearance,n);Check(n>=.999f,"spread keeps body clearance");}
                }
                Check(idle.Battle.Heroes.Any(h=>Vector2.Distance(h.Position,positions[h.Slot])>.5f),"spread physically moved heroes");
                foreach(int phase in new[]{2,3})
                {
                    var raid=new RaidSimulation(zone,50);raid.Boss.Hp=(int)(raid.Boss.MaxHp*(phase==2?.59:.29));raid.AdvancePhase();raid.Paused=true;
                    string expected=zone=="gray_meadow"?"armor":zone=="forgotten_mine"?"crystal":"ritual";
                    var hp=raid.Battle.Heroes.Select(h=>h.Hp).ToArray();int bossHp=raid.Boss.Hp,ticks=raid.Ticks;double elapsed=raid.Elapsed;
                    var root=new GameObject("Explicit raid mechanic fixture");var view=root.AddComponent<RaidMechanicPresentation>();
                    try
                    {
                        view.Initialize(raid);Check(view.View.Visible&&view.View.Kind==expected,"correct mechanic identity "+zone+phase);Check(view.VisibleNodes==view.View.Count,"bounded nodes match actual count");Check(root.GetComponentsInChildren<Collider>(true).Length==0,"decorative nodes do not create collision");Check(view.View.Progress>=0&&view.View.Progress<=1,"bounded mechanic progress");
                        var before=root.GetComponentsInChildren<MeshRenderer>(true).Select(r=>r.transform.localPosition).ToArray();raid.Step(.05);view.Sync();Check(before.SequenceEqual(root.GetComponentsInChildren<MeshRenderer>(true).Select(r=>r.transform.localPosition)),"paused presentation remains still");
                        raid.StartWarning((JObject)raid.Design["phases"][phase-1]);view.Sync();Check(view.View.Muted,"warning dims existing mechanic");
                        Check(raid.Elapsed==elapsed&&raid.Ticks==ticks&&raid.Boss.Hp==bossHp&&raid.Battle.Heroes.Select(h=>h.Hp).SequenceEqual(hp),"observers never settle damage or time");
                        var rebound=new RaidSimulation(zone,50);view.Bind(rebound);Check(view.VisibleNodes==0&&!view.View.Visible,"arena reuse clears previous mechanic");
                        cases.Add(new JObject{{"zone",zone},{"phase",phase},{"mechanic",expected},{"nodes",RaidMechanicView.Read(raid).Count},{"fixture","explicit paused phase, not natural victory"}});
                    }
                    finally{UnityEngine.Object.DestroyImmediate(root);}
                }
            }
            var report=new JObject{{"passed",true},{"comparisons",checks},{"maximum_tick_movement",movement},{"minimum_body_clearance",clearance},{"cases",cases},{"note","Read-only aggregate mechanic visuals, paused state, warning precedence and swept spread movement. No new damage pools or FPS measurement."}};
            File.WriteAllText("../checks/unity-migration-2026-10-08/raid-presentation-cp15.json",report.ToString());return report.ToString();
        }
    }
}
