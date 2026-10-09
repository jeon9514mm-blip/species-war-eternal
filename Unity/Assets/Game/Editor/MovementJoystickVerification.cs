using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration.Editor
{
    public static class MovementJoystickVerification
    {
        public static string Verify()
        {
            int checks=0;float minClearance=float.MaxValue,maxMove=0;
            void Check(bool ok,string label){checks++;if(!ok)throw new InvalidOperationException("Joystick: "+label);}
            void Inspect(Combatant[] actors,Func<Combatant,Combatant,Vector2> axes)
            {
                foreach(var a in actors){float move=Vector2.Distance(a.Position,a.PreviousPosition);maxMove=Mathf.Max(maxMove,move);Check(move<=.221f,"bounded physical movement");}
                for(int i=0;i<actors.Length;i++)for(int j=i+1;j<actors.Length;j++){var size=axes(actors[i],actors[j]);var d=actors[i].Position-actors[j].Position;float n=new Vector2(d.x/size.x,d.y/size.y).magnitude;minClearance=Mathf.Min(minClearance,n);Check(n>=.999f,"body clearance");}
            }
            foreach(string zone in new[]{"gray_meadow","forgotten_mine","moonrest_forest"})
            {
                var raid=new RaidSimulation(zone,50);raid.Boss.Attack=0;foreach(var hero in raid.Battle.Heroes)hero.AttackRemaining=1000;
                Check(!raid.SetManualMovement(new Vector2(float.NaN,0)),"reject nonfinite raid input");
                foreach(var dir in new[]{Vector2.left,Vector2.up,Vector2.right,Vector2.down})
                {
                    var before=raid.Battle.Heroes.Select(h=>h.Position).ToArray();Check(raid.SetManualMovement(dir*4)&&raid.ManualDirection.magnitude<=1.001f,"clamp raid stick");
                    for(int i=0;i<40;i++){raid.Step(.05);Inspect(raid.Battle.Heroes.Concat(raid.Battle.Enemies).Where(a=>a.Alive).ToArray(),RaidSimulation.BodyAxes);}
                    Check(raid.Battle.Heroes.Select((h,i)=>Vector2.Distance(h.Position,before[i])).Average()>.1f,"raid moves through legal path");
                }
                raid.StopManualMovement();var held=raid.Battle.Heroes.Select(h=>h.Position).ToArray();for(int i=0;i<10;i++)raid.Step(.05);
                Check(held.SequenceEqual(raid.Battle.Heroes.Select(h=>h.Position)),"raid release stops, no automatic escape");
                Check(raid.ManualMovementActive&&raid.DodgeCooldown==0&&raid.DodgeRemaining==0,"manual is not artificial invulnerability");
                raid.Paused=true;Check(!raid.SetManualMovement(Vector2.right),"paused input rejected");raid.StopManualMovement();Check(raid.ManualDirection==Vector2.zero,"paused release clears input");raid.Paused=false;raid.ResumeFormation();Check(!raid.ManualMovementActive,"role order resumes");
            }
            var hunt=new HuntingSimulation(20);foreach(var hero in hunt.Battle.Heroes){hero.AttackRemaining=1000;hero.Hp=hero.MaxHp=1000000;}foreach(var enemy in hunt.Battle.Enemies)enemy.Attack=0;
            Check(!hunt.SetManualMovement(new Vector2(float.PositiveInfinity,0)),"reject nonfinite hunt input");
            foreach(var dir in new[]{Vector2.right,Vector2.up,Vector2.left,Vector2.down})
            {Check(hunt.SetManualMovement(dir*3)&&hunt.ManualDirection.magnitude<=1.001f,"clamp hunt stick");for(int i=0;i<40;i++){hunt.Step(.05);Inspect(hunt.Battle.Heroes.Concat(hunt.Battle.Enemies).Where(a=>a.Alive).ToArray(),hunt.BodyAxes);}}
            hunt.StopManualMovement();var hold=hunt.Battle.Heroes.Select(h=>h.Position).ToArray();for(int i=0;i<10;i++)hunt.Step(.05);Check(hold.SequenceEqual(hunt.Battle.Heroes.Select(h=>h.Position)),"hunt release stops");hunt.Paused=true;Check(!hunt.SetManualMovement(Vector2.left),"paused hunt rejects");hunt.StopManualMovement();hunt.Paused=false;hunt.ResumeMovement();Check(!hunt.ManualMovementActive,"hunt automatic tracking resumes");
            var report=new JObject{{"passed",true},{"comparisons",checks},{"max_tick_movement",maxMove},{"minimum_clearance",minClearance},{"note","Four-direction real simulation movement, clamping, collisions, hold/release, pause and resumed automatic tracking. No dodge teleport or invulnerability; not a performance benchmark."}};File.WriteAllText("../checks/unity-migration-2026-10-08/joystick-cp15.json",report.ToString());return report.ToString();
        }
    }
}
