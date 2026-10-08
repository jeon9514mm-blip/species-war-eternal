using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // Native hunting integration fixture. No player persistence or original save
    // mutation. A single simulation remains alive when inspecting other panels.
    public sealed class HuntingSimulation
    {
        public readonly CombatEncounter Battle;
        public readonly OriginalCombatCatalog Catalog;
        public int PacksCleared, Kills, Stage=1, Gold, Xp, Ticks;
        public double Elapsed, NextPack;
        public string Zone="gray_meadow",Formation="balanced";
        public bool Paused, Defeated;
        public readonly int ReviewLevel;
        readonly JObject legacy;
        readonly List<Combatant> bodies=new();
        readonly Dictionary<int,(Combatant target,string action)> intents=new();
        readonly Dictionary<int,double> behaviorRemaining=new();
        readonly Dictionary<int,int> personalities=new();
        readonly Dictionary<string,Vector2> homes=new();
        readonly Dictionary<int,int> assignedTargets=new();
        int serial;
        public Action<BattleEvent> OnEvent;
        public HuntingSimulation(int reviewLevel=20,int seed=9514)
        {
            ReviewLevel=reviewLevel;
            Catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);
            legacy=JObject.Parse(OriginalCatalog.Required("legacy-catalogs").text);
            Battle=new CombatEncounter(seed);
            Battle.OnEvent=HandleEvent;
            SetParty(Catalog.HeroIds.Take(10).ToArray());
            SpawnPack();
        }
        public void SetParty(IReadOnlyList<string> ids)
        {
            if(ids.Count<1||ids.Count>10||ids.Distinct().Count()!=ids.Count||ids.Any(id=>!Catalog.HeroIds.Contains(id)))throw new ArgumentException("Party requires 1–10 distinct original heroes.");
            Battle.Heroes.Clear();Battle.Kits.Clear();homes.Clear();intents.Clear();
            for(int i=0;i<ids.Count;i++)
            {
                string id=ids[i];var h=Catalog.Hero(id);var identity=(JObject)h["identity_profile"];
                string role=(string)h["role_group"],row=i<4?"front":i<7?"middle":"rear";
                int baseHp=role=="탱커"?560:role=="서포터"?405:role=="컨트롤러"?390:360;
                int defense=role=="탱커"?18:role=="서포터"?9:role=="컨트롤러"?8:6;
                int hp=Math.Max(120,(int)((baseHp+ReviewLevel*42)*LegacyCombatRules.Number(identity,"hp_mult",1)));
                int attack=Math.Max(12,(int)((24+ReviewLevel*5)*LegacyCombatRules.Number(identity,"attack_mult",1)));
                if(role=="딜러")attack=(int)(attack*1.18);else if(role=="탱커")attack=(int)(attack*.84);
                var formation=(JObject)legacy["catalogs"]["formation"]["data"]["PROFILES"][Formation];
                hp=(int)Math.Round(hp*LegacyCombatRules.Number(formation,"hp",1),MidpointRounding.AwayFromZero);
                attack=(int)Math.Round(attack*LegacyCombatRules.Number(formation,"attack",1),MidpointRounding.AwayFromZero);
                double angle=i*Math.PI*2/ids.Count;
                var origin=new Vector2(-3+(float)Math.Cos(angle)*3.2f,(float)Math.Sin(angle)*4.8f);
                var a=new Combatant{Id=id,Serial=++serial,Slot=i,Hp=hp,MaxHp=hp,Attack=attack,Defense=defense+(int)LegacyCombatRules.Number(identity,"defense_bonus"),Role=role,Style=(string)identity["ai_style"]??"balanced",Row=row,Position=origin,PreviousPosition=origin,Range=(string)h["reach"]=="melee"?(row=="front"?1:2):(role=="서포터"||role=="컨트롤러"||row=="rear"?3:2),AttackIntervalMultiplier=LegacyCombatRules.Number(identity,"attack_interval_mult",1)/LegacyCombatRules.Number(formation,"speed",1),UltimateGainMultiplier=LegacyCombatRules.Number(identity,"ult_gain_mult",1),AttackRemaining=.1+i*.11};
                Battle.Heroes.Add(a);homes[id]=origin;
                Battle.Kits[id]=new HeroKitState(Catalog,id,0,origin);
                Battle.Kits[id].Cooldowns["a1"]=i*.12;Battle.Kits[id].Cooldowns["a2"]=1.2+i*.12;
            }
        }
        void HandleEvent(BattleEvent e)
        {
            if(e.Kind=="death"&&Battle.Enemies.Any(a=>a.Serial==e.TargetSerial))Kills++;
            OnEvent?.Invoke(e);
        }
        public void SpawnPack()
        {
            if(Battle.Enemies.Any(e=>e.Alive))return;
            Battle.Enemies.Clear();behaviorRemaining.Clear();personalities.Clear();intents.Clear();Battle.EncounterSerial++;
            var zone=(JObject)legacy["zones"][Zone];int power=(int)zone["power"],difficulty=(int)zone["difficulty"];
            string[] ids=Zone=="gray_meadow"?new[]{"goblin","wild_dog","bristle_boar","wind_crow"}:Zone=="forgotten_mine"?new[]{"mine_orc","iron_mole","crystal_spider","lava_bat"}:new[]{"moon_wolf","forest_wraith","mushroom","night_raven","frost_deer"};
            var roles=(JArray)zone["wave_pattern"];
            for(int i=0;i<12;i++)
            {
                string role=(string)roles[(i+Battle.EncounterSerial)%roles.Count];
                double hpScale=(1.55+i%2*.18+difficulty*.08)*(role=="brute"?1.22:role=="support"?.82:1);
                int hp=Math.Max(40,(int)(power*hpScale)),attack=Math.Max(4,(int)(power/12d*(.88+Math.Min(i,4)*.04)));
                bool elite=Stage>=3&&Stage%3==0&&i==0;if(elite){hp=(int)(hp*1.32);attack=(int)(attack*1.16);}
                if(role=="ranged")attack=(int)(attack*1.1);else if(role=="assassin")attack=(int)(attack*(Zone=="moonrest_forest"?1.22:1.18));
                if(role=="brute"&&Zone=="forgotten_mine")hp=(int)(hp*1.18);else if(role=="support"&&Zone=="forgotten_mine")attack=(int)(attack*.82);
                int lane=i%3,col=i/3;
                var position=new Vector2(2.5f+col*2.1f,(lane-1)*3.8f+(col%2)*.6f);
                if(Battle.EncounterSerial%2==0)position.x=-position.x;
                var probe=new Combatant{Id=ids[(i+Battle.EncounterSerial)%ids.Length],Position=position};
                // Choose a clear entrance before the actor is visible. Never
                // spawn inside the expedition or teleport an active combatant.
                if(!ClearAt(probe,position))
                {
                    bool found=false;
                    for(int attempt=0;attempt<160;attempt++)
                    {
                        var candidate=new Vector2(-10.8f+attempt%16*1.4f,-6+attempt/16*1.3f);
                        if(!ClearAt(probe,candidate))continue;position=candidate;found=true;break;
                    }
                    if(!found)break;
                }
                Battle.Enemies.Add(new Combatant{Id=ids[(i+Battle.EncounterSerial)%ids.Length],Serial=++serial,Slot=i,Hp=hp,MaxHp=hp,Attack=attack,EnemyRow=role=="brute"||role=="skirmisher"?0:role=="assassin"?1:2,Archetype=role,Elite=elite,Position=position,PreviousPosition=position,AttackRemaining=.6+i*.08});
                behaviorRemaining[serial]=1+Battle.Random.NextDouble()*7;personalities[serial]=Battle.Random.Next(4);
            }
            OnEvent?.Invoke(new BattleEvent("pack",null,"",null));
        }
        public void Step(double dt)
        {
            if(Paused||Defeated||dt<=0||!double.IsFinite(dt))return;
            dt=Math.Min(dt,.05);Ticks++;Elapsed+=dt;Battle.TickStatuses(dt);
            bodies.Clear();bodies.AddRange(Battle.Heroes.Where(a=>a.Alive));bodies.AddRange(Battle.Enemies.Where(a=>a.Alive));
            foreach(var a in bodies)a.PreviousPosition=a.Position;
            MoveHeroes((float)dt);MoveEnemies((float)dt);
            foreach(var h in Battle.Heroes.Where(a=>a.Alive))AdvanceHero(h,dt);
            foreach(var e in Battle.Enemies.Where(a=>a.Alive))AdvanceEnemy(e,dt);
            if(!Battle.Heroes.Any(a=>a.Alive)){Defeated=true;OnEvent?.Invoke(new BattleEvent("defeat",null,"",null));return;}
            if(!Battle.Enemies.Any(a=>a.Alive))
            {
                if(NextPack<=0)
                {
                    PacksCleared++;Stage=1+PacksCleared/5;var zone=(JObject)legacy["zones"][Zone];
                    // Review-only ledger. Not a migration substitute for the live
                    // hunt claim/equipment/economy service or a player save.
                    Gold+=(int)zone["gold"];Xp+=(int)zone["xp"];NextPack=1.2;
                    OnEvent?.Invoke(new BattleEvent("loot",null,"",null,(int)zone["gold"]));
                }
                NextPack-=dt;if(NextPack<=0)SpawnPack();
            }
        }
        Vector2 Separation(Combatant actor,bool alliesOnly)
        {
            Vector2 force=Vector2.zero;
            foreach(var other in bodies)
            {
                if(other==actor||alliesOnly&&!Battle.Heroes.Contains(other))continue;
                var delta=actor.PreviousPosition-other.PreviousPosition;
                var axes=BodyAxes(actor,other);var ellipse=new Vector2(delta.x/axes.x,delta.y/axes.y);float length=ellipse.magnitude;
                if(length>=1)continue;
                if(length<.001f)delta=new Vector2(actor.Serial>other.Serial?1:-1,.3f);else delta.Normalize();
                force+=delta*(1-length)*2.5f;
            }
            return Vector2.ClampMagnitude(force,1.5f);
        }
        void MoveHeroes(float dt)
        {
            assignedTargets.Clear();
            foreach(var h in Battle.Heroes.Where(a=>a.Alive))
            {
                if(intents.ContainsKey(h.Serial)){h.Velocity=Vector2.zero;continue;}
                var candidates=CombatTargeting.Rank(Battle,h,null,null,false);
                var target=candidates.OrderBy(e=>Vector2.SqrMagnitude(h.Position-e.Position)*.16+CombatTargeting.BaseScore(h,e,e.Slot)+assignedTargets.GetValueOrDefault(e.Serial)*1.25).FirstOrDefault();
                if(target!=null)assignedTargets[target.Serial]=assignedTargets.GetValueOrDefault(target.Serial)+1;
                Vector2 goal=target?.Position??homes[h.Id],delta=goal-h.Position;
                float stop=target==null?.1f:(float)CombatTargeting.Reach(h)*.90f;
                var velocity=delta.magnitude>stop?delta.normalized*1.8f:Vector2.zero;
                velocity+=Separation(h,false);h.Velocity=Vector2.Lerp(h.Velocity,Vector2.ClampMagnitude(velocity,2.2f),dt*8);
                h.Position=MoveLegally(h,h.Velocity*dt);
            }
        }
        Combatant EnemyTarget(Combatant e,bool reachable)
        {
            double range=EnemyReach(e);var alive=Battle.Heroes.Where(h=>h.Alive&&(!reachable||Vector2.Distance(h.Position,e.Position)<=range)).ToList();
            if(alive.Count==0)return null;
            var taunt=alive.Where(h=>h.Taunt>0).ToList();
            var pool=taunt.Count>0?taunt:alive.Where(h=>e.Archetype=="assassin"?h.Role=="서포터":e.Archetype=="ranged"?h.Row=="rear":h.Role=="탱커").ToList();
            if(pool.Count==0)pool=alive;
            return pool.FirstOrDefault(h=>h.Id==e.TargetId)??pool.OrderBy(h=>Vector2.SqrMagnitude(h.Position-e.Position)).First();
        }
        static double EnemyReach(Combatant e)=>e.Archetype=="ranged"?1.65:e.Archetype=="support"?1.8:e.Archetype=="assassin"?.82:.92;
        void MoveEnemies(float dt)
        {
            foreach(var e in Battle.Enemies.Where(a=>a.Alive))
            {
                if(e.Stun>0||intents.ContainsKey(e.Serial)){e.Velocity=Vector2.zero;continue;}
                var target=EnemyTarget(e,false);e.TargetId=target?.Id??"";if(target==null)continue;
                behaviorRemaining[e.Serial]-=dt;if(behaviorRemaining[e.Serial]<=0){behaviorRemaining[e.Serial]=1+Battle.Random.NextDouble()*7;personalities[e.Serial]=Battle.Random.Next(4);}
                Vector2 delta=target.Position-e.Position,velocity=delta.magnitude>EnemyReach(e)*.9?delta.normalized*1.25f:Vector2.zero;
                var alignment=Vector2.zero;var center=Vector2.zero;int nearby=0;
                foreach(var other in Battle.Enemies)if(other!=e&&other.Alive&&Vector2.Distance(e.PreviousPosition,other.PreviousPosition)<3){alignment+=other.Velocity;center+=other.PreviousPosition;nearby++;}
                if(nearby>0&&delta.magnitude>EnemyReach(e)){velocity+=alignment/nearby*.15f+(center/nearby-e.Position)*.08f;}
                int personality=personalities[e.Serial];
                if(personality==0&&e.HpRatio<.3&&delta.magnitude<2)velocity-=delta.normalized*.6f;
                else if(personality==2)velocity*=.7f;
                else if(personality==3&&delta.magnitude>EnemyReach(e))velocity+=new Vector2(-delta.y,delta.x).normalized*Mathf.Sin((float)Elapsed+e.Serial)*.18f;
                velocity+=Separation(e,false);e.Velocity=Vector2.Lerp(e.Velocity,Vector2.ClampMagnitude(velocity,1.8f),dt*8);e.Position=MoveLegally(e,e.Velocity*dt);
            }
        }
        void AdvanceHero(Combatant h,double dt)
        {
            if(intents.TryGetValue(h.Serial,out var intent))
            {
                h.Windup-=dt;if(h.Windup>0)return;intents.Remove(h.Serial);
                if(intent.action=="basic")
                {
                    if(CombatTargeting.CanAttack(Battle,h,intent.target))
                    {Battle.DamageEnemy(h,intent.target,h.Attack,"basic");HeroKitExecution.Event(Battle,h,"basic",intent.target);Battle.GainUltimate(h,10);}
                }
                else HeroKitExecution.Cast(Battle,h,intent.action,intent.target);
                h.AttackRemaining=(.78+h.Slot%3*.08)*h.AttackIntervalMultiplier;h.Windup=-1;return;
            }
            if(h.AttackRemaining>0)return;
            string action=HeroKitExecution.PreferredSlot(Battle,h);var p=action=="basic"?null:Battle.Kits[h.Id].Profiles[action];
            var target=CombatTargeting.Rank(Battle,h,p).FirstOrDefault();
            if(target==null&&(action=="basic"||LegacyCombatRules.NeedsEnemy(p)))return;
            intents[h.Serial]=(target,action);h.Windup=.18;Battle.Emit("windup",h,action,target);
        }
        void AdvanceEnemy(Combatant e,double dt)
        {
            if(e.Stun>0){intents.Remove(e.Serial);e.Windup=-1;e.AttackRemaining=Math.Max(e.AttackRemaining,.22);return;}
            if(intents.TryGetValue(e.Serial,out var intent))
            {
                if(intent.target==null||!intent.target.Alive||Vector2.Distance(e.Position,intent.target.Position)>EnemyReach(e))
                {intents.Remove(e.Serial);e.Windup=-1;e.AttackRemaining=.22;return;}
                e.Windup-=dt;if(e.Windup>0)return;
                intents.Remove(e.Serial);Battle.DamageHero(e,intent.target,e.Attack);e.AttackRemaining=1.2;e.Windup=-1;return;
            }
            if(e.AttackRemaining>0)return;var target=EnemyTarget(e,true);if(target==null)return;
            intents[e.Serial]=(target,"basic");e.Windup=.22;Battle.Emit("windup",e,"basic",target);
        }
        static Vector2 Clamp(Vector2 p)=>new(Mathf.Clamp(p.x,-11.5f,11.5f),Mathf.Clamp(p.y,-6.5f,6.5f));
        bool IsHero(Combatant actor)=>Battle.Heroes.Contains(actor);
        public Vector2 BodyAxes(Combatant left,Combatant right)
        {
            bool a=IsHero(left),b=IsHero(right);
            return a&&b?new Vector2(1.50f,2.65f):a||b?new Vector2(.68f,1.15f):new Vector2(.62f,1.05f);
        }
        public bool ClearAt(Combatant actor,Vector2 position)
        {
            foreach(var other in Battle.Heroes.Concat(Battle.Enemies))
            {
                if(other==actor||!other.Alive)continue;var axes=BodyAxes(actor,other);var delta=position-other.Position;
                if(new Vector2(delta.x/axes.x,delta.y/axes.y).sqrMagnitude<.999f)return false;
            }
            return true;
        }
        Vector2 MoveLegally(Combatant actor,Vector2 step)
        {
            if(step.sqrMagnitude<.00000001f)return actor.Position;
            foreach(float angle in new[]{0f,.45f,-.45f,.9f,-.9f,1.35f,-1.35f})
            {
                float c=Mathf.Cos(angle),s=Mathf.Sin(angle);var rotated=new Vector2(step.x*c-step.y*s,step.x*s+step.y*c);
                var goal=Clamp(actor.Position+rotated);
                if(ClearAt(actor,goal))return goal;
            }
            actor.Velocity=Vector2.zero;return actor.Position;
        }
    }
}
