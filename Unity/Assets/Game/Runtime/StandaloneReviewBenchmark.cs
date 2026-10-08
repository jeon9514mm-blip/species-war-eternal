using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Profiling;

namespace Eternal.UnityMigration
{
    // Explicit development-player QA only. Normal launches do not install a
    // benchmark component, change the resolution, write reports or quit.
    public sealed class StandaloneReviewBenchmark : MonoBehaviour
    {
        readonly List<double> frames=new(4000);
        readonly JArray results=new();
        readonly JArray captures=new();
        readonly List<string> errors=new();
        string destination;
        HuntingMigrationReview review;
        readonly Stopwatch clock=new();
        long previous;
        bool sampling;
        int catches,startingFrames;
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Install()
        {
            if(Application.isEditor||!UnityEngine.Debug.isDebugBuild)return;
            var args=Environment.GetCommandLineArgs();int flag=Array.IndexOf(args,"--eternal-benchmark");
            if(flag<0||flag+1>=args.Length)return;
            string output=Path.GetFullPath(args[flag+1]);
            // Output must stay beside this built player, never in player-save
            // storage or at an arbitrary path supplied to the executable.
            string builds=Path.GetFullPath(Path.Combine(Application.dataPath,".."))+Path.DirectorySeparatorChar;
            if(!output.StartsWith(builds,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("Benchmark report must stay in the player build directory.");
            var component=new GameObject("Explicit standalone review benchmark").AddComponent<StandaloneReviewBenchmark>();component.destination=output;
        }
        IEnumerator Start()
        {
            Application.logMessageReceived+=Log;
            Application.runInBackground=true;QualitySettings.vSyncCount=0;Application.targetFrameRate=60;AudioListener.volume=0;
            var args=Environment.GetCommandLineArgs();
            int Dimension(string flag,int fallback){int at=Array.IndexOf(args,flag);return at>=0&&at+1<args.Length&&int.TryParse(args[at+1],out int value)?Math.Clamp(value,640,3840):fallback;}
            Screen.SetResolution(Dimension("--eternal-review-width",1600),Dimension("--eternal-review-height",900),FullScreenMode.Windowed);
            while((review=FindAnyObjectByType<HuntingMigrationReview>())==null||review.Simulation==null)yield return null;
            if((bool?)review.ReviewState.Snapshot()["native_review_fixture"]!=true)throw new InvalidOperationException("Standalone QA requires the isolated review state.");
            yield return Segment("hunting",30);
            foreach(string zone in new[]{"gray_meadow","forgotten_mine","moonrest_forest"})
            {review.StartRaid(zone);yield return Segment(zone,18);}
            review.EndRaid();
            var report=new JObject{{"completed",true},{"unity",Application.unityVersion},{"development_player",UnityEngine.Debug.isDebugBuild},{"width",Screen.width},{"height",Screen.height},{"graphics_api",SystemInfo.graphicsDeviceType.ToString()},{"gpu",SystemInfo.graphicsDeviceName},{"target_fps",60},{"segments",results},{"captures",captures},{"errors",new JArray(errors)},{"real_player_io",false},{"note","Whole rendered frame intervals measured with Stopwatch in a standalone Windows development player; includes frame pacing. This is one desktop, not mobile performance proof. Memory values are Unity allocated/reserved bytes plus process working set, not texture-only GPU usage. Screenshot capture and initial scene warmup are excluded. Raid restarts after victory are deliberately included. Empty screenshot samples fail acceptance; manual pixel review is still required."}};
            Directory.CreateDirectory(Path.GetDirectoryName(destination));File.WriteAllText(destination,report.ToString());
            UnityEngine.Debug.Log("ETERNAL_STANDALONE_BENCHMARK_COMPLETE "+destination);Application.Quit(errors.Count==0?0:1);
        }
        IEnumerator Segment(string name,float duration)
        {
            // First visible frames warm shaders and produce an evidence image.
            yield return new WaitForSecondsRealtime(2);
            yield return new WaitForEndOfFrame();
            Capture(name+".png");
            float paintedDeadline=Time.realtimeSinceStartup+4;
            while(Time.realtimeSinceStartup<paintedDeadline)
            {
                yield return new WaitForEndOfFrame();
                if(review.Feedback.PaintedImpactQuads>0){Capture(name+"-painted-skills.png");break;}
            }
            yield return new WaitForSecondsRealtime(1);
            frames.Clear();catches=review.CatchupLimitHits;startingFrames=review.RenderedFrames;
            clock.Restart();previous=0;sampling=true;
            float end=Time.realtimeSinceStartup+duration;int restarts=0;
            while(Time.realtimeSinceStartup<end)
            {
                if(review.Raid!=null&&!review.Raid.Running){review.StartRaid(name);restarts++;}
                yield return null;
            }
            sampling=false;clock.Stop();var ordered=frames.OrderBy(v=>v).ToArray();
            double Percent(double p)=>ordered.Length==0?0:ordered[Math.Min(ordered.Length-1,(int)Math.Ceiling(ordered.Length*p)-1)];
            long working=Process.GetCurrentProcess().WorkingSet64;
            results.Add(new JObject{{"mode",name},{"samples",frames.Count},{"elapsed_seconds",clock.Elapsed.TotalSeconds},{"rendered_frames",review.RenderedFrames-startingFrames},{"mean_frame_ms",frames.Count==0?0:frames.Average()},{"median_frame_ms",Percent(.5)},{"p95_frame_ms",Percent(.95)},{"p99_frame_ms",Percent(.99)},{"maximum_frame_ms",Percent(1)},{"frames_over_25_ms",frames.Count(v=>v>25)},{"frames_over_50_ms",frames.Count(v=>v>50)},{"unity_allocated_bytes",Profiler.GetTotalAllocatedMemoryLong()},{"unity_reserved_bytes",Profiler.GetTotalReservedMemoryLong()},{"process_working_set_bytes",working>0?(JToken)new JValue(working):JValue.CreateNull()},{"reused_hero_views",review.ReusedHeroViews},{"catchup_limit_hits",review.CatchupLimitHits-catches},{"raid_restarts",restarts},{"packs_cleared",review.Simulation.PacksCleared},{"review_component",review.FrameCost.Snapshot()},{"feedback_component",review.Feedback.FrameCost.Snapshot()}});
        }
        void LateUpdate()
        {
            if(!sampling)return;long now=clock.ElapsedTicks;if(previous==0){previous=now;return;}double milliseconds=(now-previous)*1000d/Stopwatch.Frequency;previous=now;
            if(milliseconds>0)frames.Add(milliseconds);
        }
        void Capture(string filename)
        {
            var texture=ScreenCapture.CaptureScreenshotAsTexture();
            try
            {
                int nonempty=0;for(int y=1;y<9;y++)for(int x=1;x<16;x++)
                {var pixel=texture.GetPixel(texture.width*x/16,texture.height*y/9);if(Mathf.Max(pixel.r,Mathf.Max(pixel.g,pixel.b))>.03f)nonempty++;}
                captures.Add(new JObject{{"file",filename},{"sampled_visible_pixels",nonempty},{"sample_count",120},{"painted_impact_quads",review.Feedback.PaintedImpactQuads},{"painted_ground_seal_visible",review.Feedback.PaintedGroundSealVisible}});
                if(nonempty<12)errors.Add("Empty screen capture: "+filename+". Hidden/minimized players cannot establish rendered performance.");
                File.WriteAllBytes(Path.Combine(Path.GetDirectoryName(destination),filename),texture.EncodeToPNG());
            }
            finally{Destroy(texture);}
        }
        void Log(string message,string stack,LogType type)
        {if((type==LogType.Error||type==LogType.Exception||type==LogType.Assert)&&errors.Count<30)errors.Add(message);}
        void OnDestroy(){Application.logMessageReceived-=Log;}
    }
}
