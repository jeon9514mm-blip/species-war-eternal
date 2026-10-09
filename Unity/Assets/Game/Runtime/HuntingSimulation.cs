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
        static readonly Lazy<OriginalCombatCatalog> catalogCache=new(()=>new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text));
        static readonly Lazy<JObject> legacyCache=new(()=>JObject.Parse(OriginalCatalog.Required("legacy-catalogs").text));
        internal static JObject Canonical=>legacyCache.Value;
        static readonly float[] slideAngles={0f,.45f,-.45f,.9f,-.9f,1.35f,-1.35f};
        public readonly CombatEncounter Battle;
        public readonly OriginalCombatCatalog Catalog;
        public readonly GameStateCommands PlayerState;
        readonly HuntEncounterOptions encounterOptions;
        bool ExpandedWorld=>encounterOptions!=null||PlayerState?.UnityPlayer==true;
        public PartySkillChain Chain {get;private set;}
        public int ManualSkillCasts {get;private set;}
        public int PacksCleared, Kills, Stage=1, Gold, Xp, Ticks;
        public double Elapsed, NextPack;
        public string Zone="gray_meadow",Formation="balanced";
        public bool Paused, Defeated;
        public bool ManualMovementActive {get;private set;}
        public Vector2 ManualDirection {get;private set;}
        public bool SetManualMovement(Vector2 direction)
        {
            if(Paused||Defeated||PlayerState?.UnityPlayer==true&&PlayerState.HasDeferredUnityLoot||!float.IsFinite(direction.x)||!float.IsFinite(direction.y))return false;
            ManualMovementActive=true;ManualDirection=Vector2.ClampMagnitude(direction,1);return true;
        }
        public void StopManualMovement(){ManualDirection=Vector2.zero;}
        public void ResumeMovement(){if(Paused||Defeated)return;ManualMovementActive=false;ManualDirection=Vector2.zero;}
        public readonly int ReviewLevel;
        readonly JObject legacy;
        readonly List<Combatant> bodies=new();
        readonly Dictionary<int,(Combatant target,string action)> intents=new();
        readonly Dictionary<int,double> behaviorRemaining=new();
        readonly Dictionary<int,int> personalities=new();
        readonly Dictionary<string,Vector2> homes=new();
        readonly Dictionary<int,int> assignedTargets=new();
        readonly Dictionary<int,(Combatant target,double lockUntil,Vector2 offset)> movementPlans=new();
        readonly Dictionary<int,Vector2> reservations=new();
        readonly HashSet<int> meleeHeroes=new();
        readonly HashSet<int> engagementEnemies=new();
        Vector2 formationOrigin;
        public Vector2 ExpeditionCenter {get;private set;}
        public Vector2 EngagementHeading {get;private set;}=Vector2.right;
        public int EngagementEnemyCount=>engagementEnemies.Count;
        readonly Dictionary<int,int> enemyHits=new();
        readonly Dictionary<int,double> enemySkillNext=new();
        readonly Dictionary<int,(Combatant source,Combatant target,double remaining,double next)> bleeds=new();
        public int MonsterSkills {get;private set;}
        public (string title,double remaining) MonsterWarning
        {
            get{var enemy=Battle.Enemies.Where(e=>e.Alive&&e.Stun<=0&&intents.TryGetValue(e.Serial,out var intent)&&intent.action!="basic").OrderBy(e=>e.Windup).FirstOrDefault();return enemy==null?default:(FallenMonsterCatalog.Name(enemy.Id)+" · "+FallenMonsterCatalog.Skill(enemy.Id),Math.Max(0,enemy.Windup));}
        }
        int serial;
        public Action<BattleEvent> OnEvent;
        public HuntingSimulation(int reviewLevel=20,int seed=9514,GameStateCommands playerState=null,HuntEncounterOptions encounterOptions=null)
        {
            this.encounterOptions=encounterOptions;
            ReviewLevel=reviewLevel;
            PlayerState=playerState;
            Catalog=catalogCache.Value;
            legacy=Canonical;
            Battle=new CombatEncounter(seed);
            Battle.OnEvent=HandleEvent;
            var party=playerState?.DeployedHeroes();
            SetParty(party!=null&&party.Count>0?party:playerState!=null?Catalog.HeroIds.Where(playerState.IsFactionHero).Take(3).ToArray():Catalog.HeroIds.Take(10).ToArray());
            SpawnPack();
        }
        public void SetParty(IReadOnlyList<string> ids)
        {
            if(ids.Count<1||ids.Count>10||ids.Distinct().Count()!=ids.Count||ids.Any(id=>!Catalog.HeroIds.Contains(id)||PlayerState!=null&&!PlayerState.IsFactionHero(id)))throw new ArgumentException("Party requires 1–10 distinct original faction-valid heroes.");
            if(PlayerState!=null)Formation=PlayerState.Formation;
            Battle.Heroes.Clear();Battle.Kits.Clear();homes.Clear();intents.Clear();movementPlans.Clear();meleeHeroes.Clear();bleeds.Clear();
            for(int i=0;i<ids.Count;i++)
            {
                string id=ids[i];var h=Catalog.Hero(id);var identity=(JObject)h["identity_profile"];
                string role=(string)h["role_group"],row=LegacyHeroLayout.Row(i);
                int baseHp=role=="탱커"?560:role=="서포터"?405:role=="컨트롤러"?390:360;
                int defense=role=="탱커"?18:role=="서포터"?9:role=="컨트롤러"?8:6;
                int hp=Math.Max(120,(int)((baseHp+ReviewLevel*42)*LegacyCombatRules.Number(identity,"hp_mult",1)));
                int attack=Math.Max(12,(int)((24+ReviewLevel*5)*LegacyCombatRules.Number(identity,"attack_mult",1)));
                if(role=="딜러")attack=(int)(attack*1.18);else if(role=="탱커")attack=(int)(attack*.84);
                var formation=(JObject)legacy["catalogs"]["formation"]["data"]["PROFILES"][Formation];
                hp=(int)Math.Round(hp*LegacyCombatRules.Number(formation,"hp",1),MidpointRounding.AwayFromZero);
                attack=(int)Math.Round(attack*LegacyCombatRules.Number(formation,"attack",1),MidpointRounding.AwayFromZero);
                var origin=HuntFormationLayout.Position(Formation,i,ids.Count);
                var a=new Combatant{Id=id,Serial=++serial,Slot=i,Hp=hp,MaxHp=hp,Attack=attack,Defense=defense+(int)LegacyCombatRules.Number(identity,"defense_bonus"),Role=role,Style=(string)identity["ai_style"]??"balanced",Row=row,Position=origin,PreviousPosition=origin,Range=LegacyHeroLayout.Range(h,i),AttackIntervalMultiplier=LegacyCombatRules.Number(identity,"attack_interval_mult",1)/LegacyCombatRules.Number(formation,"speed",1),UltimateGainMultiplier=LegacyCombatRules.Number(identity,"ult_gain_mult",1),AttackRemaining=.1+i*.11};
                if(PlayerState!=null)GameStateCommands.RefreshCombatant(a,PlayerState.CombatProfile(id,i,ids));
                Battle.Heroes.Add(a);homes[id]=origin;if((string)h["reach"]=="melee")meleeHeroes.Add(a.Serial);
                Battle.Kits[id]=new HeroKitState(Catalog,id,PlayerState?.HeroTree(id).utility??0,origin);
                Battle.Kits[id].Cooldowns["a1"]=i*.12;Battle.Kits[id].Cooldowns["a2"]=1.2+i*.12;
            }
            formationOrigin=Vector2.zero;foreach(var hero in Battle.Heroes)formationOrigin+=homes[hero.Id];formationOrigin/=Battle.Heroes.Count;
            Chain=new PartySkillChain(Battle);Chain.ConfigureDefault();
            if(PlayerState!=null){Formation=PlayerState.Formation;Battle.CriticalChance=PlayerState.GuardianBonus("crit");}
        }
        public void RefreshHeroGrowth()
        {
            if(PlayerState==null)return;var ids=Battle.Heroes.Select(h=>h.Id).ToArray();
            foreach(var actor in Battle.Heroes)
            {
                GameStateCommands.RefreshCombatant(actor,PlayerState.CombatProfile(actor.Id,actor.Slot,ids));var kit=Battle.Kits[actor.Id];kit.Utility=PlayerState.HeroTree(actor.Id).utility;
                foreach(string slot in new[]{"a1","a2","ultimate"})kit.Profiles[slot]=Catalog.AdjustedSkill(actor.Id,slot,kit.Utility);
            }
            Formation=PlayerState.Formation;Battle.CriticalChance=PlayerState.GuardianBonus("crit");
        }
        public bool CanManualCast(string heroId,string slot)=>ManualContext(heroId,slot,out _,out _);
        bool ManualContext(string heroId,string slot,out Combatant hero,out Combatant target)
        {
            hero=null;target=null;
            if(Paused||Defeated||PlayerState?.UnityPlayer==true&&PlayerState.HasDeferredUnityLoot||slot!="a1"&&slot!="a2"&&slot!="ultimate")return false;
            hero=Battle.Heroes.FirstOrDefault(h=>h.Id==heroId&&h.Alive&&h.Stun<=0);
            if(hero==null||!HeroKitExecution.CanUse(Battle,hero,slot))return false;
            var profile=Battle.Kits[hero.Id].Profiles[slot];target=CombatTargeting.Rank(Battle,hero,profile).FirstOrDefault();
            return !LegacyCombatRules.NeedsEnemy(profile)||target!=null&&CombatTargeting.CanAttack(Battle,hero,target);
        }
        public bool ManualCast(string heroId,string slot)
        {
            if(!ManualContext(heroId,slot,out var hero,out var target))return false;
            // A manual click uses the same resource/target/settlement rules and
            // replaces this hero's outstanding automatic intent only on success.
            Battle.Emit("windup",hero,slot,target);
            if(!HeroKitExecution.Cast(Battle,hero,slot,target))return false;
            intents.Remove(hero.Serial);hero.Windup=-1;hero.AttackRemaining=Math.Max(hero.AttackRemaining,.24);ManualSkillCasts++;return true;
        }
        public void RestoreUnityProgress(string zone,int packs)
        {
            if(Ticks!=0||PacksCleared!=0||!new[]{"gray_meadow","forgotten_mine","moonrest_forest"}.Contains(zone))throw new InvalidOperationException("Progress restores only a new native hunt.");
            PacksCleared=Math.Clamp(packs,0,int.MaxValue-1);Stage=1+PacksCleared/5;Zone=PlayerState?.UnityPlayer==true?HuntStageWorld.Zone(Stage):zone;Battle.Enemies.Clear();SpawnPack();
        }
        void HandleEvent(BattleEvent e)
        {
            if(e.Kind=="death"&&Battle.Enemies.Any(a=>a.Serial==e.TargetSerial))Kills++;
            Chain?.Observe(e);
            OnEvent?.Invoke(e);
        }
        public void SpawnPack()
        {
            if(Battle.Enemies.Any(e=>e.Alive))return;
            Battle.Enemies.Clear();behaviorRemaining.Clear();personalities.Clear();intents.Clear();enemyHits.Clear();enemySkillNext.Clear();Battle.EncounterSerial++;
            if(PlayerState?.UnityPlayer==true)Zone=HuntStageWorld.Zone(Stage);
            var zone=(JObject)legacy["zones"][Zone];int power=(int)zone["power"],difficulty=(int)zone["difficulty"];
            string[] ids=Zone=="gray_meadow"?new[]{"goblin","wild_dog","bristle_boar","wind_crow"}:Zone=="forgotten_mine"?new[]{"mine_orc","iron_mole","crystal_spider","lava_bat"}:new[]{"moon_wolf","forest_wraith","mushroom","night_raven","frost_deer"};
            if(PlayerState?.UnityPlayer==true)ids=FallenMonsterCatalog.Wave(Zone);
            if(encounterOptions!=null)ids=encounterOptions.Monsters.ToArray();
            var roles=(JArray)zone["wave_pattern"];
            bool expanded=ExpandedWorld;int population=encounterOptions?.Population??(expanded?FallenMonsterCatalog.Population(Stage):12);
            for(int i=0;i<population;i++)
            {
                string role=(string)roles[(i+Battle.EncounterSerial)%roles.Count];
                string monster=ids[(i+Battle.EncounterSerial)%ids.Length];bool fallen=FallenMonsterCatalog.Contains(monster);
                if(fallen)role=FallenMonsterCatalog.Archetype(monster);
                double hpScale=(1.55+i%2*.18+difficulty*.08)*(role=="brute"?1.22:role=="support"?.82:1);
                int hp=Math.Max(40,(int)(power*hpScale)),attack=Math.Max(4,(int)(power/12d*(.88+Math.Min(i,4)*.04)));
                bool elite=Stage>=3&&Stage%3==0&&i==0;if(elite){hp=(int)(hp*1.32);attack=(int)(attack*1.16);}
                if(role=="ranged")attack=(int)(attack*1.1);else if(role=="assassin")attack=(int)(attack*(Zone=="moonrest_forest"?1.22:1.18));
                if(role=="brute"&&Zone=="forgotten_mine")hp=(int)(hp*1.18);else if(role=="support"&&Zone=="forgotten_mine")attack=(int)(attack*.82);
                if(monster=="fallen_dwarf")hp=(int)(hp*1.12);
                if(monster=="fallen_ogre")hp=(int)(hp*1.2);
                // More targets without doubling the first-stage damage wall.
                if(expanded){hp=Math.Max(40,(int)(hp*.8));attack=Math.Max(4,(int)(attack*.8));}
                var position=expanded?HuntFormationLayout.ExpandedEntrance(i,Battle.EncounterSerial,population):HuntFormationLayout.Entrance(i,Battle.EncounterSerial);
                var probe=new Combatant{Id=monster,Position=position};
                // Choose a clear entrance before the actor is visible. Never
                // spawn inside the expedition or teleport an active combatant.
                if(!ClearAt(probe,position))
                {
                    bool found=false;
                    for(int attempt=0;attempt<160;attempt++)
                    {
                        // Start the search near this entrance, avoiding a shared
                        // top-left fallback queue for all blocked arrivals.
                        int cell=(attempt+i*13+Battle.EncounterSerial*7)%160;
                        var candidate=new Vector2(-10.8f+cell%16*1.4f,-6+cell/16*1.3f);
                        if(!ClearAt(probe,candidate))continue;position=candidate;found=true;break;
                    }
                    if(!found)break;
                }
                Battle.Enemies.Add(new Combatant{Id=monster,Serial=++serial,Slot=i,Hp=hp,MaxHp=hp,Attack=attack,Defense=monster=="fallen_dwarf"?4:monster=="fallen_ogre"?6:0,EnemyRow=role=="brute"||role=="skirmisher"?0:role=="assassin"?1:2,Archetype=role,Elite=elite,Position=position,PreviousPosition=position,AttackRemaining=.6+i*.08});
                behaviorRemaining[serial]=1+Battle.Random.NextDouble()*7;personalities[serial]=Battle.Random.Next(4);
            }
            OnEvent?.Invoke(new BattleEvent("pack",null,"",null));
        }
        public void Step(double dt)
        {
            if(Paused||Defeated||PlayerState?.UnityPlayer==true&&PlayerState.HasDeferredUnityLoot||dt<=0||!double.IsFinite(dt))return;
            dt=Math.Min(dt,.05);Ticks++;Elapsed+=dt;Battle.TickStatuses(dt);
            TickMonsterBleeds(dt);
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
            assignedTargets.Clear();reservations.Clear();Vector2 center=Vector2.zero;int living=0;
            foreach(var hero in Battle.Heroes)if(hero.Alive){center+=hero.PreviousPosition;living++;reservations[hero.Serial]=hero.PreviousPosition;}
            if(living>0)center/=living;
            ExpeditionCenter=center;HuntExpeditionPlan.Select(Battle,center,engagementEnemies);
            EngagementHeading=HuntExpeditionPlan.Direction(Battle,center,engagementEnemies);
            foreach(var h in Battle.Heroes.Where(a=>a.Alive))
            {
                if(ManualMovementActive)
                {
                    if(h.Stun>0){h.Velocity=Vector2.zero;continue;}
                    if(ManualDirection.sqrMagnitude>.0001f){intents.Remove(h.Serial);h.Windup=-1;}
                    h.Position=MoveManualLegally(h,ManualDirection*(4.4f*dt));h.Velocity=(h.Position-h.PreviousPosition)/dt;reservations[h.Serial]=h.Position;continue;
                }
                if(h.Stun>0||intents.ContainsKey(h.Serial)){h.Velocity=Vector2.zero;continue;}
                var candidates=CombatTargeting.Rank(Battle,h,null,null,false);
                // Keep a common front while permitting an already reachable foe
                // to be finished. Original role scores and firing stations remain.
                candidates=candidates.Where(e=>engagementEnemies.Contains(e.Serial)||CombatTargeting.CanAttack(Battle,h,e)).ToList();
                bool retained=movementPlans.TryGetValue(h.Serial,out var plan)&&plan.target.Alive&&candidates.Contains(plan.target);
                var target=retained&&Elapsed<plan.lockUntil&&CombatTargeting.CanAttack(Battle,h,plan.target)?plan.target:candidates.OrderBy(e=>Vector2.SqrMagnitude(h.Position-e.Position)*.16+CombatTargeting.BaseScore(h,e,e.Slot)+assignedTargets.GetValueOrDefault(e.Serial)*(h.Style=="finisher"?.18:1.25)-(retained && e==plan.target ? .35 : 0)-(CombatTargeting.CanAttack(Battle,h,e)?4:0)).FirstOrDefault();
                if(target!=null)assignedTargets[target.Serial]=assignedTargets.GetValueOrDefault(target.Serial)+1;
                Vector2 goal=homes[h.Id];
                if(target!=null)
                {
                    bool same=retained&&plan.target==target;
                    goal=HuntPositionPlanner.Goal(this,h,target,meleeHeroes.Contains(h.Serial),center,reservations,plan.offset,same);
                    movementPlans[h.Serial]=(target,same?plan.lockUntil:Elapsed+.45,goal-target.Position);
                }
                else {movementPlans.Remove(h.Serial);goal=center+homes[h.Id]-formationOrigin;}
                if(target==null||!CombatTargeting.CanAttack(Battle,h,target))goal=HuntExpeditionPlan.CohesiveGoal(goal,center);
                reservations[h.Serial]=goal;Vector2 delta=goal-h.Position;
                var velocity=delta.magnitude>.10f?delta.normalized*(1.8f*Mathf.Clamp01(delta.magnitude/.72f)):Vector2.zero;
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
        static double EnemyReach(Combatant e)=>e.Id=="fallen_lich"?3.6:e.Id=="fallen_elf"?3.2:e.Id=="fallen_ogre"?1.25:e.Archetype=="ranged"?1.65:e.Archetype=="support"?1.8:e.Archetype=="assassin"?.82:.92;
        void MoveEnemies(float dt)
        {
            foreach(var e in Battle.Enemies.Where(a=>a.Alive))
            {
                if(e.Stun>0||intents.ContainsKey(e.Serial)){e.Velocity=Vector2.zero;continue;}
                var target=EnemyTarget(e,false);e.TargetId=target?.Id??"";if(target==null)continue;
                behaviorRemaining[e.Serial]-=dt;if(behaviorRemaining[e.Serial]<=0){behaviorRemaining[e.Serial]=1+Battle.Random.NextDouble()*7;personalities[e.Serial]=Battle.Random.Next(4);}
                float moveSpeed=e.Id=="fallen_harpy"?2f:e.Id=="fallen_werewolf"?1.9f:e.Id=="fallen_ogre"?.82f:e.Id=="fallen_lich"?1f:e.Id=="fallen_dwarf"?.95f:1.25f;
                Vector2 delta=target.Position-e.Position,velocity=delta.magnitude>EnemyReach(e)*.9?delta.normalized*moveSpeed:Vector2.zero;
                var alignment=Vector2.zero;var center=Vector2.zero;int nearby=0;
                foreach(var other in Battle.Enemies)if(other!=e&&other.Alive&&Vector2.Distance(e.PreviousPosition,other.PreviousPosition)<3){alignment+=other.Velocity;center+=other.PreviousPosition;nearby++;}
                if(nearby>0&&delta.magnitude>EnemyReach(e)){velocity+=alignment/nearby*.15f+(center/nearby-e.Position)*.08f;}
                int personality=personalities[e.Serial];
                if(personality==0&&e.HpRatio<.3&&delta.magnitude<2)velocity-=delta.normalized*.6f;
                else if(personality==2)velocity*=.7f;
                else if(personality==3&&delta.magnitude>EnemyReach(e))velocity+=new Vector2(-delta.y,delta.x).normalized*Mathf.Sin((float)Elapsed+e.Serial)*.18f;
                velocity+=Separation(e,false);e.Velocity=Vector2.Lerp(e.Velocity,Vector2.ClampMagnitude(velocity,e.Id=="fallen_werewolf"||e.Id=="fallen_harpy"?2.2f:1.8f),dt*8);e.Position=MoveLegally(e,e.Velocity*dt);
            }
        }
        void AdvanceHero(Combatant h,double dt)
        {
            if(h.Stun>0){intents.Remove(h.Serial);h.Windup=-1;h.AttackRemaining=Math.Max(h.AttackRemaining,.18);return;}
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
            string action=Chain.Choose(h,HeroKitExecution.PreferredSlot(Battle,h));var p=action=="basic"?null:Battle.Kits[h.Id].Profiles[action];
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
                intents.Remove(e.Serial);int actual=Battle.DamageHero(e,intent.target,e.Attack);enemyHits[e.Serial]=enemyHits.GetValueOrDefault(e.Serial)+1;
                if(e.Id=="fallen_vampire")Battle.Heal(e,e,(int)(actual*.30),"lifesteal");
                if(intent.action!="basic")
                {
                    enemySkillNext[e.Serial]=Elapsed+8;
                    if(actual>0&&intent.target.Alive){ApplyMonsterSkill(e,intent.target);MonsterSkills++;Battle.Emit("monster_skill",e,intent.action,intent.target,actual);}
                }
                e.AttackRemaining=e.Id=="fallen_ogre"?1.9:e.Id=="fallen_lich"?1.6:e.Id=="fallen_dwarf"?1.65:e.Id=="fallen_werewolf"?1.0:1.2;e.Windup=-1;return;
            }
            if(e.AttackRemaining>0)return;var target=EnemyTarget(e,true);if(target==null)return;
            bool skill=ExpandedWorld&&Stage>=100&&FallenMonsterCatalog.Contains(e.Id)&&enemyHits.GetValueOrDefault(e.Serial)>=2&&Elapsed>=enemySkillNext.GetValueOrDefault(e.Serial);
            string action=skill?FallenMonsterCatalog.Skill(e.Id):"basic";
            intents[e.Serial]=(target,action);e.Windup=skill?(e.Id=="fallen_ogre"?1.05:.75):e.Id=="fallen_dwarf"||e.Id=="fallen_ogre"?.38:e.Id=="fallen_werewolf"?.32:.22;Battle.Emit("windup",e,action,target);
        }
        void ApplyMonsterSkill(Combatant enemy,Combatant hero)
        {
            double duration=Stage>=500?2.2:1.5;
            if(enemy.Id=="fallen_elf"){hero.ApplyStatus("weaken",duration);if(Stage>=500)hero.ApplyStatus("stun",.45);}
            else if(enemy.Id=="fallen_dwarf"){if(Stage>=250)hero.ArmorBreak=Math.Max(hero.ArmorBreak,3);else hero.ApplyStatus("weaken",duration);if(Stage>=1000)hero.ApplyStatus("stun",.6);}
            else if(enemy.Id=="fallen_vampire"){hero.ApplyStatus("weaken",duration);Battle.Heal(enemy,enemy,Math.Max(1,enemy.Attack/2),"siphon");}
            else if(enemy.Id=="fallen_werewolf")
            {if(Stage>=250){hero.Bleed=3;bleeds[hero.Serial]=(enemy,hero,3,1);}else hero.ApplyStatus("weaken",duration);}
            else if(enemy.Id=="fallen_ogre"){hero.ApplyStatus("weaken",duration);if(Stage>=250)hero.ApplyStatus("stun",.5);}
            else if(enemy.Id=="fallen_lich")
            {
                hero.ApplyStatus("weaken",duration);
                if(Stage>=500){var ally=Battle.Enemies.Where(e=>e.Alive&&e!=enemy&&Vector2.Distance(e.Position,enemy.Position)<4).OrderBy(e=>e.Hp/(double)e.MaxHp).FirstOrDefault();if(ally!=null)Battle.Heal(enemy,ally,Math.Max(1,enemy.Attack/2),"spectral_mend");}
            }
            else if(enemy.Id=="fallen_harpy"){hero.ApplyStatus("weaken",duration);if(Stage>=250){hero.Bleed=3;bleeds[hero.Serial]=(enemy,hero,3,1);}}
        }
        void TickMonsterBleeds(double dt)
        {
            foreach(int serial in bleeds.Keys.ToArray())
            {
                var dot=bleeds[serial];if(!dot.target.Alive){bleeds.Remove(serial);continue;}
                dot.remaining-=dt;dot.next-=dt;
                if(dot.next<=.00001){Battle.DamageHero(dot.source,dot.target,Math.Max(1,(int)(dot.source.Attack*.22)));dot.next+=1;}
                if(dot.remaining<=.00001||!dot.target.Alive)bleeds.Remove(serial);else bleeds[serial]=dot;
            }
        }
        Vector2 Clamp(Vector2 p)=>ExpandedWorld?HuntStageWorld.Clamp(p):new Vector2(Mathf.Clamp(p.x,-11.5f,11.5f),Mathf.Clamp(p.y,-6.5f,6.5f));
        bool IsHero(Combatant actor)=>Battle.Heroes.Contains(actor);
        public Vector2 BodyAxes(Combatant left,Combatant right)
        {
            bool a=IsHero(left),b=IsHero(right);
            if(encounterOptions?.VolumeBodies==true)
            {
                float clearance=a && b ? 1.20f : (a || b ? .95f : .90f);
                if(left.Id=="fallen_werewolf"||right.Id=="fallen_werewolf")clearance+=.16f;
                return new Vector2(clearance,clearance);
            }
            if(left.Id=="fallen_ogre"||right.Id=="fallen_ogre")return new Vector2(1.1f,1.65f);
            if(left.Id=="fallen_harpy"||right.Id=="fallen_harpy")return new Vector2(.9f,1.25f);
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
        Vector2 MoveManualLegally(Combatant actor,Vector2 step)
        {
            if(step.sqrMagnitude<.00000001f)return actor.Position;
            foreach(float angle in slideAngles)
            {
                float c=Mathf.Cos(angle),s=Mathf.Sin(angle);var goal=Clamp(actor.Position+new Vector2(step.x*c-step.y*s,step.x*s+step.y*c));
                if(!ClearAt(actor,goal))continue;bool clear=true;
                foreach(var other in bodies)
                {
                    if(other==actor||!other.Alive)continue;var axes=BodyAxes(actor,other);var start=actor.Position-other.Position;var delta=goal-actor.Position;
                    start=new Vector2(start.x/axes.x,start.y/axes.y);delta=new Vector2(delta.x/axes.x,delta.y/axes.y);
                    float t=delta.sqrMagnitude<.000001f?0:Mathf.Clamp01(-Vector2.Dot(start,delta)/delta.sqrMagnitude);
                    if((start+delta*t).sqrMagnitude<.999f){clear=false;break;}
                }
                if(clear)return goal;
            }
            return actor.Position;
        }
        Vector2 MoveLegally(Combatant actor,Vector2 step)
        {
            if(step.sqrMagnitude<.00000001f)return actor.Position;
            foreach(float angle in slideAngles)
            {
                float c=Mathf.Cos(angle),s=Mathf.Sin(angle);var rotated=new Vector2(step.x*c-step.y*s,step.x*s+step.y*c);
                var goal=Clamp(actor.Position+rotated);
                if(ClearAt(actor,goal))return goal;
            }
            actor.Velocity=Vector2.zero;return actor.Position;
        }
    }
}
