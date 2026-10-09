using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // Original regional raid rules, with a native fixed-step clock. Review state
    // is isolated: victory is not permission to write a wallet or a player save.
    public sealed class RaidSimulation
    {
        public readonly CombatEncounter Battle;
        public readonly OriginalCombatCatalog Catalog;
        public readonly string Zone;
        public readonly int ReviewLevel;
        public readonly bool StateBound;
        public readonly JObject Design,ZoneData;
        public readonly PartySkillChain Chain;
        public Combatant Boss=>Battle.Enemies[0];
        public int Phase {get;private set;}=1;
        public int GuardHp {get;private set;}
        public int GuardMax,GuardBreaks,AddHp,AddMax,AddCount,AddWaves,DpsTarget,DpsDamage,DpsPassed,DpsFailed,Interrupts,CounterSuccesses,Patterns,EvadedHits,DamageDealt,Ticks;
        public double Elapsed,TelegraphRemaining,SecondWaveRemaining,ControlImmunity,BreakGauge,DpsRemaining,DodgeCooldown,DodgeRemaining;
        public bool Paused,Enraged,AutoEvade=true;
        public bool CounterPractice {get;private set;}
        public string Outcome {get;private set;}="running";
        public string EventText {get;private set;}="보스 패턴을 확인하고 안전 구역으로 이동하세요.";
        public bool Running=>Outcome=="running";
        public RaidFootprint Warning {get;private set;}
        public RaidFootprint SecondWarning;
        public JObject CastProfile {get;private set;}
        public JObject SecondProfile;
        public int WarningVersion {get;private set;}
        public Action<BattleEvent> OnEvent;
        readonly Dictionary<int,(Combatant target,string action)> intents=new();
        readonly Dictionary<string,Vector2> rallyOffsets=new(),dodgeGoals=new();
        int sequence,bossTurns,rage;
        double bossAttack=.8,addAttack,skillSpacing;
        bool rallyActive,counterUsed,spreadActive,manualActive;
        Vector2 manualDirection;
        public bool ManualMovementActive=>manualActive;
        public Vector2 ManualDirection=>manualDirection;
        public string MovementOrder=>manualActive?"직접 이동":rallyActive?"집결":spreadActive?"산개":"역할 추적";
        Vector2 rallyGoal;
        Vector2 partyCenter;
        static readonly float[] slideAngles={0f,.35f,-.35f,.7f,-.7f,1.05f,-1.05f,Mathf.PI/2,-Mathf.PI/2};
        static readonly float[] slideFractions={1f,.5f,.25f};
        public RaidSimulation(string zone="gray_meadow",int reviewLevel=50,int seed=9514,IReadOnlyList<string> party=null,GameStateCommands playerState=null)
        {
            ReviewLevel=reviewLevel;
            StateBound=playerState!=null;
            var source=new HuntingSimulation(reviewLevel,seed,playerState);
            if(party!=null)source.SetParty(party);
            Battle=source.Battle;Catalog=source.Catalog;Chain=source.Chain;Battle.Enemies.Clear();Battle.IsRaid=true;
            var legacy=HuntingSimulation.Canonical;Zone=zone;
            ZoneData=(JObject)legacy["zones"][zone]??throw new ArgumentException("Unknown original raid zone: "+zone);
            Design=(JObject)legacy["catalogs"]["raid"]["data"]["RAIDS"][zone];
            int power=(int)ZoneData["power"];
            string id=zone=="gray_meadow"?"grun":zone=="forgotten_mine"?"morgul":"selene_boss";
            var origin=new Vector2(4.64f,.56f);
            Battle.Enemies.Add(new Combatant{Id=id,Serial=100000,Elite=true,Hp=power*200,MaxHp=power*200,Attack=Math.Max(25,power/3)*10,Position=origin,PreviousPosition=origin});
            for(int i=0;i<Battle.Heroes.Count;i++)
            {var h=Battle.Heroes[i];h.Position=h.PreviousPosition=new Vector2(-7.16f+i%5*1.92f,-1.80f+i/5*3.52f);h.Velocity=Vector2.zero;h.AttackRemaining=.1+i*.11;h.Windup=-1;}
            Battle.OnEvent=e=>{Chain.Observe(e);OnEvent?.Invoke(e);};
            Battle.OnRaidControl=(h,duration)=>ApplyControl(duration,h);
            Battle.RaidDamageSettlement=SettleDamage;
        }
        public double AttackMultiplier=>(1+.12*(Phase-1))*(1+.12*rage)*(Enraged?1.6:1);
        public double AttackInterval=>(.9-.08*(Phase-1))*(Enraged?.75:1);
        public bool ControlWindow=>Boss.Hp<=Boss.MaxHp*.12||((Warning!=null||SecondWarning!=null)&&ControlImmunity<=0);
        public JObject Mechanic=>(JObject)Design["mechanics"][Phase-1];
        JObject PhaseProfile=>(JObject)Design["phases"][Phase-1];
        JObject Pattern(int variant=-1)
        {
            var p=(JObject)((JObject)Design["phases"][Phase-1]).DeepClone();var variants=(JArray)p["variants"];p.Remove("variants");
            if(variant>=0&&variants!=null&&variant%(variants.Count+1)>0)foreach(var item in (JObject)variants[variant%(variants.Count+1)-1])p[item.Key]=item.Value.DeepClone();return p;
        }
        public void Step(double dt)
        {
            if(Paused||!Running||dt<=0||!double.IsFinite(dt))return;dt=Math.Min(dt,.05);
            if(!Battle.Heroes.Any(h=>h.Alive)){Finish("defeat");return;}if(!Boss.Alive){Finish("victory");return;}
            Elapsed=Math.Min(240,Elapsed+dt);Ticks++;if(Elapsed>=240-.00001){Finish("timeout");return;}
            Battle.TickStatuses(dt);ControlImmunity=Math.Max(0,ControlImmunity-dt);DodgeCooldown=Math.Max(0,DodgeCooldown-dt);DodgeRemaining=Math.Max(0,DodgeRemaining-dt);skillSpacing=Math.Max(0,skillSpacing-dt);
            Battle.RaidControlWindow=ControlWindow;Battle.BossTelegraph=Warning!=null||SecondWarning!=null;
            Boss.PreviousPosition=Boss.Position;foreach(var h in Battle.Heroes)h.PreviousPosition=h.Position;
            AdvanceMechanics(dt);if(!Battle.Heroes.Any(h=>h.Alive)){Finish("defeat");return;}
            MoveActors((float)dt);
            if(!CounterPractice)foreach(var h in Battle.Heroes){if(!Boss.Alive)break;if(h.Alive)AdvanceHero(h,dt);}
            if(!Boss.Alive){Finish("victory");return;}
            AdvancePhase();
            if(!Enraged&&Elapsed>=180){Enraged=true;EventText="광폭화 · 공격력과 공격 속도 상승";Battle.Emit("enrage",Boss,"",Boss);}
            if(SecondWarning!=null)
            {SecondWaveRemaining=Math.Max(0,SecondWaveRemaining-dt);if(SecondWaveRemaining<=.00001){ResolvePattern(SecondProfile,SecondWarning,false);SecondWarning=null;SecondProfile=null;WarningVersion++;}}
            if(Warning!=null)
            {
                if(Boss.Stun<=0)TelegraphRemaining=Math.Max(0,TelegraphRemaining-dt);
                if(TelegraphRemaining<=.00001&&Boss.Stun<=0)
                {var shape=Warning;var profile=CastProfile;Warning=null;CastProfile=null;BreakGauge=0;WarningVersion++;ResolvePattern(profile,shape,true);bossAttack=AttackInterval;CounterPractice=false;}
            }
            else if(Boss.Stun<=0)
            {
                bossAttack=Math.Max(0,bossAttack-dt);if(bossAttack<=.00001)
                {
                    bossTurns++;var p=PhaseProfile;int cadence=Math.Max(2,(int)LegacyCombatRules.Number(p,"interval",6)-(Phase-1));
                    if(bossTurns%cadence==0)StartWarning(Pattern(sequence++));
                    else {bossAttack=AttackInterval;var target=SelectTarget(BasicTargetMode());if(target!=null&&Vector2.Distance(target.Position,Boss.Position)<=7.8f&&DodgeRemaining<=0){Battle.Emit("windup",Boss,"basic",target);Battle.DamageHero(Boss,target,(int)(Boss.Attack*AttackMultiplier));}}
                }
            }
            if(!Boss.Alive)Finish("victory");else if(!Battle.Heroes.Any(h=>h.Alive))Finish("defeat");
            Battle.RaidControlWindow=ControlWindow;Battle.BossTelegraph=Warning!=null||SecondWarning!=null;
        }
        void Finish(string outcome)
        {if(!Running)return;Outcome=outcome;CounterPractice=false;Warning=null;SecondWarning=null;CastProfile=null;SecondProfile=null;WarningVersion++;intents.Clear();EventText=outcome=="victory"?"레이드 성공 · 검수 전투 기록":outcome=="timeout"?"제한 시간 종료":"원정대 전멸";Battle.Emit(outcome,Boss,"",Boss);}
        void ActivateMechanic()
        {
            GuardHp=GuardMax=AddHp=AddMax=AddCount=DpsTarget=DpsDamage=0;addAttack=DpsRemaining=0;var p=Mechanic;string kind=(string)p["kind"];
            if(kind=="guard")GuardHp=GuardMax=Math.Max(1,(int)(Boss.MaxHp*LegacyCombatRules.Number(p,"ratio",.1)));
            if(kind=="adds"){AddCount=Math.Max(1,(int)LegacyCombatRules.Number(p,"count",2));AddHp=AddMax=Math.Max(1,(int)(Boss.MaxHp*LegacyCombatRules.Number(p,"ratio",.08)));addAttack=Math.Max(.8,LegacyCombatRules.Number(p,"pulse",3)*.6);}
            if(kind=="dps_check"){DpsRemaining=Math.Max(1,LegacyCombatRules.Number(p,"duration",8));DpsTarget=Math.Max(1,(int)(Boss.MaxHp*LegacyCombatRules.Number(p,"ratio",.08)));}
            EventText="PHASE "+Phase+" · "+(string)p["name"];
        }
        public bool AdvancePhase()
        {
            if(!Running||!Boss.Alive)return false;int next=Boss.HpRatio<=.30?3:Boss.HpRatio<=.60?2:1;
            if(next<=Phase)return false;Phase=next;sequence=0;bossAttack=Math.Max(bossAttack,1.05);ActivateMechanic();Battle.Emit("phase",Boss,"",Boss,Phase);return true;
        }
        void RefreshDecisionState(){Battle.RaidControlWindow=ControlWindow;Battle.BossTelegraph=Warning!=null||SecondWarning!=null;}
        void AdvanceMechanics(double dt)
        {
            if(AddHp>0&&AddCount>0)
            {addAttack=Math.Max(0,addAttack-dt);if(addAttack<=.00001){addAttack=Math.Max(1.2,LegacyCombatRules.Number(Mechanic,"pulse",3));var target=SelectTarget("rear");if(target!=null&&DodgeRemaining<=0)Battle.DamageHero(Boss,target,(int)(Boss.Attack*(.28+.1*AddCount)*AttackMultiplier));}}
            if(DpsRemaining<=0)return;DpsRemaining=Math.Max(0,DpsRemaining-dt);
            if(DpsRemaining<=.00001&&DpsDamage<DpsTarget)
            {DpsRemaining=0;int heal=Math.Min(Boss.MaxHp-Boss.Hp,Math.Max(1,(int)(Boss.MaxHp*LegacyCombatRules.Number(Mechanic,"heal_ratio",.04))));Boss.Hp+=heal;DpsFailed++;rage=Math.Min(2,rage+1);Enraged|=Mechanic["enrage_on_fail"]?.Value<bool>()??false;EventText="월식 의식 실패 · HP +"+heal;Battle.Emit("boss_heal",Boss,"",Boss,heal);}
        }
        // Damage after critical rounding. Original core absorption order is kept.
        int SettleDamage(Combatant enemy,int raw)
        {
            if(!Running||!Boss.Alive||raw<=0)return 0;int remaining=raw,mechanic=0;
            if(AddHp>0)
            {
                int take=Math.Min(AddHp,remaining);AddHp-=take;remaining-=take;mechanic+=take;
                if(AddHp==0){AddCount=0;AddWaves++;Boss.Vulnerable=Math.Max(Boss.Vulnerable,2.5);EventText="수정핵 파괴 · 2.5초 약점 노출";Battle.Emit("shield_break",null,"",Boss,take);}
            }
            bool vulnerable=Boss.Vulnerable>0;
            if(GuardHp>0&&remaining>0)
            {
                int take=Math.Min(GuardHp,remaining);GuardHp-=take;remaining-=take;mechanic+=take;
                if(GuardHp==0){GuardBreaks++;Boss.Vulnerable=Math.Max(Boss.Vulnerable,Math.Max(2,LegacyCombatRules.Number(Mechanic,"vulnerability",3)));EventText="대지 갑주 파괴 · 약점 노출";Battle.Emit("shield_break",null,"",Boss,take);}
            }
            int actual=Math.Min(Boss.Hp,(int)(remaining*(vulnerable?1.25:1)));Boss.Hp-=actual;DamageDealt+=actual+mechanic;
            if(actual>0&&DpsRemaining>0&&DpsTarget>0)
            {DpsDamage=Math.Min(DpsTarget,DpsDamage+actual);if(DpsDamage>=DpsTarget){DpsPassed++;DpsRemaining=0;Boss.Vulnerable=Math.Max(Boss.Vulnerable,3);EventText="월식 의식 파훼 · 3초 약점 노출";Battle.Emit("mechanic_success",null,"",Boss);}}
            return actual+mechanic;
        }
        public bool ApplyControl(double duration,Combatant source=null)
        {
            if(!Running||!Boss.Alive||ControlImmunity>0||duration<=0)return false;
            if(Warning!=null||SecondWarning!=null)
            {
                BreakGauge=Math.Min(100,BreakGauge+Math.Max(18,duration*160));
                if(BreakGauge<99.999){Boss.Stun=Math.Max(Boss.Stun,Math.Min(.2,duration*.25));return true;}
                Boss.Stun=Math.Max(Boss.Stun,Math.Min(duration,1.5));ControlImmunity=6;BreakGauge=0;Warning=null;SecondWarning=null;CastProfile=null;SecondProfile=null;TelegraphRemaining=SecondWaveRemaining=0;bossAttack=AttackInterval;Interrupts++;WarningVersion++;Boss.Vulnerable=Math.Max(Boss.Vulnerable,2);RefreshDecisionState();EventText="무력화 성공 · 약점 노출 2초";Battle.Emit("interrupt",source,"",Boss);return true;
            }
            Boss.Stun=Math.Max(Boss.Stun,Math.Min(duration,1.5));ControlImmunity=6;return true;
        }
        public void StartWarning(JObject profile)
        {
            if(!Running||!Boss.Alive)return;CastProfile=(JObject)profile.DeepClone();TelegraphRemaining=LegacyCombatRules.Number(profile,"telegraph",1.2);BreakGauge=0;counterUsed=false;
            string kind=(string)profile["kind"];var marks=new List<Vector2>();
            if(kind=="moon_mark")marks.AddRange(Battle.Heroes.Where(h=>h.Alive).OrderBy(h=>h.HpRatio).ThenBy(h=>h.Slot).Take(Math.Clamp((int)LegacyCombatRules.Number(profile,"mark_count",2),1,3)).Select(h=>h.Position));
            else if(kind=="front_blast"||kind=="rear_blast")
            {string row=kind=="front_blast"?"front":"rear";var group=Battle.Heroes.Where(h=>h.Alive&&h.Row==row).ToArray();if(group.Length>0){var c=Vector2.zero;foreach(var h in group)c+=h.Position;marks.Add(c/group.Length);}}
            else if(kind=="double_lane"||kind=="cross"||kind=="cone")
            {var h=SelectTarget((string)profile["basic_target"]??"front");if(h!=null)marks.Add(h.Position);}
            Warning=RaidFootprint.Create(kind,Boss.Position,marks,profile);WarningVersion++;RefreshDecisionState();EventText=(string)profile["name"]+" · "+(string)profile["counter"];Battle.Emit("warning",Boss,"",Boss);
        }
        void ResolvePattern(JObject profile,RaidFootprint shape,bool followup)
        {
            if(!Boss.Alive||Boss.Stun>0)return;int damage=0;string kind=(string)profile["kind"];
            foreach(var h in Battle.Heroes)
            {
                if(!Boss.Alive)break;if(!h.Alive)continue;
                if(DodgeRemaining>0||!shape.Contains(h.Position)){EvadedHits++;continue;}
                damage+=Battle.DamageHero(Boss,h,(int)(Boss.Attack*LegacyCombatRules.Number(profile,"multiplier",1.4)*AttackMultiplier));
            }
            Patterns++;EventText=(string)profile["name"]+" · 피해 "+damage;
            if(kind=="earthquake"&&followup&&Boss.Alive&&Battle.Heroes.Any(h=>h.Alive)){SecondWarning=shape;SecondProfile=(JObject)profile.DeepClone();SecondWaveRemaining=.42;BreakGauge=0;WarningVersion++;}
            if((kind=="curse"||kind=="moon_mark")&&Boss.Alive)
            {int heal=Math.Min(Boss.MaxHp-Boss.Hp,Math.Min((int)(Boss.MaxHp*(kind=="moon_mark"?.025:.04)),(int)(damage*(kind=="moon_mark"?.3:.4))));Boss.Hp+=heal;if(heal>0)Battle.Emit("boss_heal",Boss,"",Boss,heal);}
            Battle.Emit("impact",Boss,"",Boss,damage);
        }
        string BasicTargetMode()
        {string mode=(string)PhaseProfile["basic_target"]??"front";return mode=="row_cycle"?(bossTurns%2==0?"rear":"front"):mode;}
        Combatant SelectTarget(string mode)
        {
            var alive=Battle.Heroes.Where(h=>h.Alive).ToArray();if(alive.Length==0)return null;
            var taunt=alive.Where(h=>h.Taunt>0).ToArray();if(taunt.Length>0)return taunt.OrderBy(h=>h.HpRatio).ThenBy(h=>h.Slot).First();
            if(mode=="lowest_hp")return alive.OrderBy(h=>h.HpRatio).ThenBy(h=>h.Slot).First();
            if(mode=="row_cycle")mode=bossTurns%2==0?"rear":"front";
            var row=alive.Where(h=>h.Row==mode).ToArray();return (row.Length>0?row:alive).OrderBy(h=>Vector2.SqrMagnitude(h.Position-Boss.Position)).ThenBy(h=>h.Slot).First();
        }
        void AdvanceHero(Combatant h,double dt)
        {
            if(h.Stun>0){intents.Remove(h.Serial);h.Windup=-1;return;}
            if(intents.TryGetValue(h.Serial,out var intent))
            {
                h.Windup-=dt;if(h.Windup>0)return;intents.Remove(h.Serial);h.Windup=-1;
                if(Boss.Alive&&Vector2.Distance(h.Position,Boss.Position)<=13.4f)
                {
                    if(intent.action=="basic"){int raw=h.Attack+HeroKitExecution.Event(Battle,h,"basic",Boss);Battle.DamageEnemy(h,Boss,raw,"basic");Battle.GainUltimate(h,10);}
                    else if(HeroKitExecution.Cast(Battle,h,intent.action,Boss))skillSpacing=intent.action=="ultimate"?.16:.14;
                }
                h.AttackRemaining=(.78+h.Slot%3*.08)*h.AttackIntervalMultiplier;return;
            }
            if(h.AttackRemaining>0||Vector2.Distance(h.Position,Boss.Position)>13.4f)return;
            string action=skillSpacing>0?"basic":Chain.Choose(h,HeroKitExecution.PreferredSlot(Battle,h));
            intents[h.Serial]=(Boss,action);h.Windup=.18;Battle.Emit("windup",h,action,Boss);
        }
        public bool ManualCast(bool ultimate,string selected=null)
        {
            if(!Running||Paused||!Boss.Alive)return false;
            var candidates=from h in Battle.Heroes where h.Alive&&h.Stun<=0&&(selected==null||selected==h.Id)&&Vector2.Distance(h.Position,Boss.Position)<=13.4f from slot in ultimate?new[]{"ultimate"}:new[]{"a1","a2"} let score=HeroKitExecution.Priority(Battle,h,slot) where score>0 orderby score descending,h.Slot select (h,slot);
            var choice=candidates.FirstOrDefault();if(choice.h==null)return false;bool cast=HeroKitExecution.Cast(Battle,choice.h,choice.slot,Boss);if(!Boss.Alive)Finish("victory");return cast;
        }
        (Combatant hero,string slot) BreakSkillCandidate()
        {
            if(!Running||Paused||CounterPractice||!Boss.Alive||ControlImmunity>0||Warning==null&&SecondWarning==null)return default;
            return (from h in Battle.Heroes where h.Alive&&h.Stun<=0&&Vector2.Distance(h.Position,Boss.Position)<=13.4f
                    from slot in new[]{"a1","a2","ultimate"} where Battle.Kits.TryGetValue(h.Id,out var kit)&&kit.Profiles.TryGetValue(slot,out var profile)&&(string)profile["kind"]=="stun"&&HeroKitExecution.CanUse(Battle,h,slot)
                    orderby LegacyCombatRules.Number(Battle.Kits[h.Id].Profiles[slot],"duration",2) descending,h.Slot select (h,slot)).FirstOrDefault();
        }
        public bool BreakSkillReady=>BreakSkillCandidate().hero!=null;
        public string BreakSkillHint {get{var pick=BreakSkillCandidate();return pick.hero==null?ControlImmunity>0?"제어 면역 중 · 직접 이동으로 회피":"전조 중 사용 가능한 스턴 스킬이 필요합니다.":(string)Catalog.Hero(pick.hero.Id)["name"]+" · "+(string)Battle.Kits[pick.hero.Id].Profiles[pick.slot]["skill"];}}
        public bool CastBreakSkill()
        {
            var pick=BreakSkillCandidate();if(pick.hero==null)return false;
            if(!HeroKitExecution.Cast(Battle,pick.hero,pick.slot,Boss))return false;intents.Remove(pick.hero.Serial);pick.hero.Windup=-1;skillSpacing=.14;
            if(!Boss.Alive)Finish("victory");return true;
        }
        public bool Dodge()
        {
            if(!Running||Paused||DodgeCooldown>0)return false;DodgeCooldown=5;DodgeRemaining=.5;dodgeGoals.Clear();var shape=SecondWarning??Warning;
            foreach(var h in Battle.Heroes.Where(h=>h.Alive)){var destination=shape?.Escape(h.Position)??RaidFootprint.Clamp(h.Position+Vector2.left*2.72f);dodgeGoals[h.Id]=RaidFootprint.Clamp(Vector2.MoveTowards(h.Position,destination,3.6f));intents.Remove(h.Serial);h.Windup=-1;}
            EventText="긴급 회피 · 0.5초 피격 면역";Battle.Emit("dodge",null,"",null);return true;
        }
        // Reference adaptation: deliberate front counter for cone warnings.
        // It shares the authored stun/weakness path and has one use per cast.
        public bool CounterWindowOpen=>Running&&!Paused&&Warning?.Shape=="cone"&&!counterUsed&&ControlImmunity<=0&&TelegraphRemaining>0&&TelegraphRemaining<=.55;
        Combatant CounterCandidate(string selected=null)
        {
            if(!CounterWindowOpen)return null;Combatant candidate=null;
            foreach(var h in Battle.Heroes)
                if(h.Alive&&h.Stun<=0&&(selected==null||selected==h.Id)&&Vector2.Distance(h.Position,Boss.Position)<=7.8f&&Vector2.Angle(Warning.Direction,h.Position-Boss.Position)<=35&&(candidate==null||h.Slot<candidate.Slot))candidate=h;
            return candidate;
        }
        public bool CounterReady=>CounterCandidate()!=null;
        public bool BeginCounterPractice()
        {
            if(StateBound||ReviewLevel!=50||!Running||Paused||CounterPractice)return false;
            JObject profile=null;
            foreach(JObject phase in Design["phases"])
            {
                if((string)phase["kind"]=="cone"){profile=phase;break;}
                if(phase["variants"] is JArray variants)foreach(JObject variant in variants)if((string)variant["kind"]=="cone"){profile=(JObject)phase.DeepClone();profile.Remove("variants");foreach(var p in variant)profile[p.Key]=p.Value.DeepClone();break;}
                if(profile!=null)break;
            }
            if(profile==null)return false;
            // Explicit isolated practice: use an authored cone, temporarily
            // suspend automatic hero attacks and rearm its response window.
            // Ordinary encounters never enter this mode or change balance.
            CounterPractice=true;AutoEvade=false;ControlImmunity=0;Boss.Stun=0;SecondWarning=null;SecondProfile=null;SecondWaveRemaining=0;
            intents.Clear();foreach(var hero in Battle.Heroes)hero.Windup=-1;
            StartWarning(profile);EventText="카운터 훈련 · 보스 정면에서 파란 버튼이 켜지면 카운터";return true;
        }
        public bool Counter(string selected=null)
        {
            var candidate=CounterCandidate(selected);
            if(candidate==null)return false;counterUsed=true;if(!ApplyControl(1,candidate))return false;CounterPractice=false;CounterSuccesses++;EventText="정면 카운터 성공 · 보스 공격 차단";Battle.Emit("counter",candidate,"",Boss);return true;
        }
        public void Rally(Vector2 destination)
        {
            if(!Running||Paused)return;var alive=Battle.Heroes.Where(h=>h.Alive).ToArray();if(alive.Length==0)return;var center=Vector2.zero;foreach(var h in alive)center+=h.Position;center/=alive.Length;
            rallyOffsets.Clear();foreach(var h in alive)rallyOffsets[h.Id]=h.Position-center;rallyGoal=RaidFootprint.Clamp(destination);rallyActive=true;spreadActive=false;manualActive=false;manualDirection=Vector2.zero;
        }
        public void ResumeFormation(){if(!Running||Paused)return;rallyActive=false;spreadActive=false;manualActive=false;manualDirection=Vector2.zero;}
        public bool SpreadFormation()
        {if(!Running||Paused)return false;rallyActive=false;spreadActive=true;manualActive=false;manualDirection=Vector2.zero;return true;}
        public bool SetManualMovement(Vector2 direction)
        {
            if(!Running||Paused||!float.IsFinite(direction.x)||!float.IsFinite(direction.y))return false;
            manualActive=true;rallyActive=spreadActive=false;manualDirection=Vector2.ClampMagnitude(direction,1);return true;
        }
        public void StopManualMovement(){manualDirection=Vector2.zero;}
        // Two spaced ranks use stable party slots. Orders only change goals;
        // existing swept movement, attack windups and evasion remain authoritative.
        public static Vector2 SpreadGoal(Vector2 boss,int slot)
        {
            slot=Math.Clamp(slot,0,9);
            float left=Mathf.Clamp(boss.x-11.5f,RaidFootprint.Floor.xMin+.7f,RaidFootprint.Floor.xMax-8.5f);
            return RaidFootprint.Clamp(new Vector2(left+slot%5*1.95f,slot<5?-1.55f:1.55f));
        }
        static float Reaction(Combatant h)=>h.Role=="서포터"||h.Style=="support"?1.05f:h.Role=="컨트롤러"||h.Style=="controller"||h.Style=="control"?.98f:h.Range>=3?.90f:h.Role=="탱커"||h.Style=="protector"?.64f:h.Style=="aggressive"?.58f:.76f;
        static bool CanEvade(Combatant h)=>h.Role=="서포터"||h.Role=="컨트롤러"||h.Style=="support"||h.Style=="controller"||h.Style=="control"||((h.Role=="탱커"||h.Style=="protector")?h.Slot%3!=0:h.Range<=1&&h.Style=="aggressive"?h.Slot%4!=0:h.Slot%3!=0);
        Vector2 RoleGoal(Combatant h)
        {
            var away=(partyCenter-Boss.Position).normalized;if(away.sqrMagnitude<.01f)away=Vector2.left;var side=new Vector2(-away.y,away.x);
            int hash=17;foreach(char c in h.Id)hash=unchecked(hash*31+c);float sign=(hash&1)==0?-1:1;
            float distance=h.Range>=3?188:h.Range==2?154:116,lateral=(h.Slot%5-2)*26;
            if(h.Role=="탱커"||h.Style=="protector"){distance=112;lateral*=.75f;}
            else if(h.Role=="서포터"||h.Style=="support"){distance=284;lateral+=sign*18;}
            else if(h.Role=="컨트롤러"||h.Style=="controller"||h.Style=="control"){distance=238;lateral+=sign*64;}
            else if(h.Range<=1&&(h.Style=="aggressive"||h.Style=="finisher")){distance=106;lateral+=sign*(h.Style=="aggressive"?52:42);}
            else if(h.Style=="aggressive"){distance=Math.Max(168,distance-28);lateral+=sign*20;}
            else if(h.Style=="finisher"){distance=Math.Min(278,distance+32);lateral+=sign*28;}
            return RaidFootprint.Clamp(Boss.Position+(away*distance+side*lateral)/RaidFootprint.PixelsPerUnit);
        }
        public static Vector2 BodyAxes(Combatant a,Combatant b)=>a.Elite||b.Elite?new Vector2(2.65f,3.35f):new Vector2(1.5f,2.65f);
        bool ClearStep(Combatant actor,Vector2 goal)
        {
            foreach(var other in Battle.Heroes)if(!SweptClear(actor,other,goal))return false;
            foreach(var other in Battle.Enemies)if(!SweptClear(actor,other,goal))return false;
            return true;
        }
        static bool SweptClear(Combatant actor,Combatant other,Vector2 goal)
        {
            if(actor==other||!other.Alive)return true;var axes=BodyAxes(actor,other);
            var end=goal-other.Position;end=new Vector2(end.x/axes.x,end.y/axes.y);
            // A sweep tolerance must not become a fresh penetration allowance
            // on every tick. Keep a separate absolute endpoint clearance.
            if(end.sqrMagnitude<.9995f*.9995f)return false;
            var start=actor.Position-other.PreviousPosition;start=new Vector2(start.x/axes.x,start.y/axes.y);
            var velocity=(goal-actor.Position)-(other.Position-other.PreviousPosition);velocity=new Vector2(velocity.x/axes.x,velocity.y/axes.y);
            float t=velocity.sqrMagnitude>.000001f?Mathf.Clamp01(-Vector2.Dot(start,velocity)/velocity.sqrMagnitude):0;
            return (start+velocity*t).magnitude>=Mathf.Min(.9995f,start.magnitude)-.0000001f;
        }
        Vector2 Walk(Combatant actor,Vector2 goal,float budget,RaidFootprint danger)
        {
            var delta=goal-actor.Position;if(delta.sqrMagnitude<.00001f||budget<=0)return actor.Position;
            float distance=Mathf.Min(budget,delta.magnitude);var direction=delta.normalized;Vector2 best=actor.Position;float score=float.MaxValue;
            foreach(float angle in slideAngles)foreach(float fraction in slideFractions)
            {
                float c=Mathf.Cos(angle),s=Mathf.Sin(angle);var candidate=RaidFootprint.Clamp(actor.Position+new Vector2(direction.x*c-direction.y*s,direction.x*s+direction.y*c)*distance*fraction);
                if(danger!=null&&!danger.Contains(actor.Position)&&danger.Contains(candidate))continue;if(!ClearStep(actor,candidate))continue;
                float next=(candidate-goal).sqrMagnitude-(candidate-actor.Position).sqrMagnitude*4+Mathf.Abs(angle)*.001f;
                if(angle==0&&fraction==1)return candidate;if(next<score){score=next;best=candidate;}
            }
            return best;
        }
        void MoveActors(float dt)
        {
            partyCenter=Vector2.zero;int aliveCount=0;foreach(var h in Battle.Heroes)if(h.Alive){partyCenter+=h.Position;aliveCount++;}partyCenter/=Math.Max(1,aliveCount);
            string movement=(string)Design["movement"];var anchor=new Vector2(7.44f+Mathf.Sin((float)Elapsed*.67f)*2.16f,.12f+Mathf.Cos((float)Elapsed*.93f)*1.56f);
            if(Warning!=null||SecondWarning!=null||Boss.Stun>0)anchor=Boss.Position;
            else {var target=SelectTarget(BasicTargetMode());float chase=movement=="hunter"?6.6f:movement=="stalker"?8.2f:7.4f;if(target!=null&&Vector2.Distance(Boss.Position,target.Position)>chase)anchor=target.Position+new Vector2(movement=="stalker"?5.12f:4.48f,movement=="stalker"?1.36f*Mathf.Sin((float)Elapsed*1.15f):-.24f);}
            float bossSpeed=(movement=="bulwark"?2.64f:movement=="hunter"?3.44f:3.12f)*(Enraged?1.32f:1);
            var next=Walk(Boss,anchor,dt*bossSpeed,null);
            if(!rallyActive&&Warning==null&&SecondWarning==null&&Battle.Heroes.Any(h=>h.Alive&&Vector2.Distance(next,h.Position)>13.4f&&Vector2.Distance(next,h.Position)>Vector2.Distance(Boss.Position,h.Position)))next=Boss.Position;
            Boss.Position=next;Boss.Velocity=(Boss.Position-Boss.PreviousPosition)/dt;
            var shape=SecondWarning??Warning;double remaining=SecondWarning!=null?SecondWaveRemaining:TelegraphRemaining;
            foreach(var h in Battle.Heroes.OrderByDescending(h=>Vector2.Dot(h.Position-Boss.Position,Vector2.left)).ThenBy(h=>h.Slot))
            {
                if(!h.Alive||h.Stun>0){h.Velocity=Vector2.zero;continue;}
                bool dodging=DodgeRemaining>0&&dodgeGoals.ContainsKey(h.Id);
                bool manual=manualActive&&manualDirection.sqrMagnitude>.0001f;
                bool react=!manualActive&&shape!=null&&AutoEvade&&CanEvade(h)&&remaining<=Reaction(h);
                bool escaping=react&&shape.Contains(h.Position);
                var goal=dodging?dodgeGoals[h.Id]:manualActive?h.Position+manualDirection*4:escaping?shape.Escape(h.Position):rallyActive?RaidFootprint.Clamp(rallyGoal+rallyOffsets.GetValueOrDefault(h.Id)):spreadActive?SpreadGoal(Boss.Position,h.Slot):RoleGoal(h);
                if(intents.ContainsKey(h.Serial)&&!dodging&&!escaping&&!manual){h.Velocity=Vector2.zero;continue;}
                if(escaping||dodging||manual){intents.Remove(h.Serial);h.Windup=-1;}
                h.Position=Walk(h,goal,dt*(dodging?7.2f:manual?4.4f*manualDirection.magnitude:escaping?4.4f:3.2f),dodging?null:react?shape:null);h.Velocity=(h.Position-h.PreviousPosition)/dt;
            }
        }
    }
}
