using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Eternal.UnityMigration
{
    // Playable volume-art pilot sharing actual hunting rules. Its fixture
    // rewards live only in memory; production profiles are never loaded here.
    public sealed class RoyalGroveDevelopmentStage : MonoBehaviour
    {
        static readonly string[] PilotHeroes={"leonhardt","elisia","mira"};
        static readonly string[] PilotMonsters={"fallen_elf","fallen_dwarf","fallen_werewolf"};
        readonly Dictionary<int,AureliaVolumeActor> actors=new();
        readonly Dictionary<int,Combatant> combatants=new();
        readonly List<BattleEvent> events=new();
        readonly HashSet<int> present=new();
        readonly List<int> stale=new();
        HuntingSimulation simulation;
        RoyalGroveHuntHud hud;
        RoyalGroveCombatFeedback feedback;
        GameObject world;
        Camera view;
        string selected="leonhardt",notice="";
        float noticeTime,zoom=1,hudTime;
        double accumulator;
        Vector3 cameraFocus=new(0,0,3);
        public HuntingSimulation Simulation=>simulation;
        public Camera BattleCamera=>view;
        public int NativeActorCount=>actors.Count;
        void Start()
        {
            world=new GameObject("Owned royal grove hunting world");world.transform.SetParent(transform,false);
            Own("Royal grove volume architecture").AddComponent<RoyalGroveEnvironment>().Build();
            view=Own("Royal grove battle camera").AddComponent<Camera>();view.tag="MainCamera";view.orthographic=true;view.orthographicSize=19;
            view.transform.position=cameraFocus+new Vector3(0,26,-34);view.transform.LookAt(cameraFocus);
            view.backgroundColor=new Color(.13f,.19f,.22f);view.allowHDR=true;
            view.GetUniversalAdditionalCameraData().renderPostProcessing=true;view.gameObject.AddComponent<AudioListener>();
            var sun=Own("Warm grove sun").AddComponent<Light>();sun.type=LightType.Directional;sun.intensity=1.15f;sun.color=new Color(1,.94f,.83f);
            sun.transform.rotation=Quaternion.Euler(46,-33,0);sun.shadows=LightShadows.Soft;sun.shadowStrength=.75f;
            var fill=Own("Cool grove fill").AddComponent<Light>();fill.type=LightType.Directional;fill.intensity=.35f;fill.color=new Color(.56f,.76f,1);fill.transform.rotation=Quaternion.Euler(75,155,0);
            var atmosphere=Own("Grove atmosphere").AddComponent<Volume>();atmosphere.isGlobal=true;atmosphere.sharedProfile=Resources.Load<VolumeProfile>("Eternal/Materials/BattlePost");
            feedback=Own("Grove confirmed combat feedback").AddComponent<RoyalGroveCombatFeedback>();feedback.Initialize(view);
            CreateHunt();
            hud=gameObject.AddComponent<RoyalGroveHuntHud>();
            hud.Initialize(view,simulation,SelectHero,Cast,Move,()=>simulation.StopManualMovement(),()=>simulation.ResumeMovement(),SetZoom,TogglePause,Restart);
            hud.Refresh(selected);
        }
        GameObject Own(string name){var go=new GameObject(name);go.transform.SetParent(world.transform,false);return go;}
        void CreateHunt()
        {
            var catalog=new OriginalCombatCatalog(OriginalCatalog.Required("hero-catalog").text);
            JObject fixture=ReviewStateFixture.Create(catalog);
            fixture["deployed_hero_ids"]=new JArray(PilotHeroes);fixture["wallet_gold"]=0;fixture["wallet_gems"]=0;
            fixture["unclaimed_gold"]=0;fixture["unclaimed_xp"]=0;
            var state=new GameStateCommands(catalog,fixture,_=>true);
            simulation=new HuntingSimulation(20,9514,state,new HuntEncounterOptions(PilotMonsters,18));
            simulation.Chain.Enabled=true;simulation.OnEvent=Observe;accumulator=0;
            ReconcileActors();
        }
        void Observe(BattleEvent battleEvent)
        {
            events.Add(battleEvent);
            if(battleEvent.Kind=="loot")
            {
                int xp=(int)HuntingSimulation.Canonical["zones"][simulation.Zone]["xp"];
                var result=simulation.PlayerState.SettleReviewHuntPack(simulation.PacksCleared,battleEvent.Amount,xp);
                if(result.Ok){simulation.RefreshHeroGrowth();notice="무리 격파 · 골드 +"+battleEvent.Amount.ToString("N0");}
                else{notice=result.Message;simulation.Paused=true;}
                noticeTime=3;
            }
            else if(battleEvent.Kind=="defeat"){notice="원정대 전멸 · 다시 사냥으로 재정비";noticeTime=60;}
        }
        void ReconcileActors()
        {
            present.Clear();combatants.Clear();
            foreach(var actor in simulation.Battle.Heroes.Concat(simulation.Battle.Enemies))
            {
                present.Add(actor.Serial);combatants[actor.Serial]=actor;
                if(actors.ContainsKey(actor.Serial))continue;
                bool monster=!simulation.Battle.Kits.ContainsKey(actor.Id);
                var model=Own(actor.Id+" #"+actor.Serial).AddComponent<AureliaVolumeActor>();model.Initialize(actor.Id,monster);
                model.transform.position=new Vector3(actor.Position.x,0,actor.Position.y);
                var heading=monster?simulation.ExpeditionCenter-actor.Position:Vector2.up;
                if(heading.sqrMagnitude>.001f)model.transform.rotation=Quaternion.LookRotation(new Vector3(heading.x,0,heading.y));
                actors.Add(actor.Serial,model);
            }
            stale.Clear();foreach(var pair in actors)if(!present.Contains(pair.Key))stale.Add(pair.Key);
            foreach(int serial in stale){Destroy(actors[serial].gameObject);actors.Remove(serial);}
        }
        void Update()
        {
            if(simulation==null)return;
            float frame=Mathf.Min(Time.unscaledDeltaTime,.25f);bool paused=simulation.Paused;
            if(!paused&&!simulation.Defeated)accumulator+=frame;
            int steps=0;while(accumulator>=.05&&steps++<5&&!simulation.Paused&&!simulation.Defeated){simulation.Step(.05);accumulator-=.05;}
            paused=simulation.Paused;
            if(accumulator>=.05)accumulator%=.05;
            ReconcileActors();float alpha=paused||simulation.Defeated?1:Mathf.Clamp01((float)(accumulator/.05));
            foreach(var pair in actors)
            {
                var actor=combatants[pair.Key];var model=pair.Value;
                Vector2 p=Vector2.Lerp(actor.PreviousPosition,actor.Position,alpha);model.transform.position=new Vector3(p.x,0,p.y);
                if(actor.Alive&&!paused&&actor.Velocity.sqrMagnitude>.006f)model.Face(actor.Velocity,frame);
            }
            foreach(var item in events)
            {
                if(item.Kind=="windup"&&actors.TryGetValue(item.SourceSerial,out var source))
                {
                    if(combatants.TryGetValue(item.TargetSerial,out var target))source.Face(target.Position-combatants[item.SourceSerial].Position,.20f);
                    source.Attack(item.Slot,item.Slot=="ultimate"?.9f:item.Slot=="basic"?.46f:.65f);
                }
                if((item.Kind=="damage"||item.Kind=="critical"||item.Kind=="hero_hit")&&actors.TryGetValue(item.TargetSerial,out var hit))hit.Hit();
                if(item.Kind=="death"&&actors.TryGetValue(item.TargetSerial,out var dead))dead.Die();
                feedback.Observe(item,simulation.Battle);
            }
            events.Clear();
            foreach(var pair in actors)pair.Value.Advance(frame,combatants[pair.Key].Alive?combatants[pair.Key].Velocity.magnitude:0,paused);
            var selectedActor=simulation.Battle.Heroes.FirstOrDefault(h=>h.Id==selected);
            feedback.Advance(paused?0:frame,simulation.Battle,selectedActor);
            if(!paused)noticeTime=Mathf.Max(0,noticeTime-frame);
            hudTime+=frame;if(hudTime>=.10){hudTime=0;hud.Refresh(selected,noticeTime>0?notice:"");}
        }
        void LateUpdate()
        {
            if(view==null||simulation==null)return;
            Vector3 target=zoom>1?new Vector3(simulation.ExpeditionCenter.x,0,simulation.ExpeditionCenter.y):new Vector3(0,0,3);
            float dt=Mathf.Min(Time.unscaledDeltaTime,.1f);cameraFocus=Vector3.Lerp(cameraFocus,target,1-Mathf.Exp(-5*dt));
            view.orthographicSize=Mathf.Lerp(view.orthographicSize,19/zoom,1-Mathf.Exp(-9*dt));
            view.transform.position=cameraFocus+new Vector3(0,26,-34);view.transform.LookAt(cameraFocus);
        }
        void SelectHero(string id){if(PilotHeroes.Contains(id)){selected=id;hud.Refresh(selected);}}
        void Cast(string slot)
        {
            if(simulation.ManualCast(selected,slot)){notice=(string)simulation.Battle.Kits[selected].Profiles[slot]["skill"];noticeTime=1.8f;}
            hud.Refresh(selected,noticeTime>0?notice:"");
        }
        void Move(Vector2 screenDirection)
        {
            var right=view.transform.right;var up=view.transform.up;
            var direction=new Vector2(right.x,right.z).normalized*screenDirection.x+new Vector2(up.x,up.z).normalized*screenDirection.y;
            simulation.SetManualMovement(direction);
        }
        void SetZoom(float value){if(value==1||value==1.5f||value==2||value==3)zoom=value;}
        void TogglePause(){simulation.Paused=!simulation.Paused;simulation.StopManualMovement();hud.Refresh(selected);}
        void Restart()
        {
            if(simulation!=null)simulation.OnEvent=null;
            foreach(var model in actors.Values)if(model!=null)Destroy(model.gameObject);actors.Clear();combatants.Clear();events.Clear();
            feedback.Clear();notice="";noticeTime=0;selected="leonhardt";CreateHunt();hud.BindSimulation(simulation);hud.Refresh(selected);
        }
        void OnApplicationFocus(bool focused){if(!focused){simulation?.StopManualMovement();if(simulation!=null)simulation.Paused=true;}}
        void OnDestroy(){if(simulation!=null)simulation.OnEvent=null;if(world!=null)Destroy(world);}
    }
}
