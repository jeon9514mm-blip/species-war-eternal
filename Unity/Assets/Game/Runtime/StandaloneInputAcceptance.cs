#if DEBUG && !UNITY_EDITOR
using System;
using System.Collections;
using System.IO;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // Explicit development-only player flag; standard launches never install it.
    public sealed class StandaloneInputAcceptance : MonoBehaviour
    {
        bool begun;
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Install()
        {
            if(!Debug.isDebugBuild)return;
            var args=Environment.GetCommandLineArgs();int flag=Array.IndexOf(args,"--eternal-input-qa");
            if(flag<0||flag+1>=args.Length)return;
            string output=Path.GetFullPath(args[flag+1]);
            string build=Path.GetFullPath(Path.Combine(Application.dataPath,".."))+Path.DirectorySeparatorChar;
            if(!output.StartsWith(build,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("Input report must stay inside the review build directory.");
            Editor.NativeInputAcceptance.ReportPath=output;
            new GameObject("Explicit native player input QA").AddComponent<StandaloneInputAcceptance>();
        }
        IEnumerator Start()
        {
            Application.runInBackground=true;QualitySettings.vSyncCount=0;Application.targetFrameRate=60;AudioListener.volume=0;
            yield return new WaitForSecondsRealtime(2);
            Editor.NativeInputAcceptance.Begin();begun=true;
            while(Editor.NativeInputAcceptance.Running)yield return null;
            yield return new WaitForEndOfFrame();
            ScreenCapture.CaptureScreenshot(Path.Combine(Path.GetDirectoryName(Editor.NativeInputAcceptance.ReportPath),"native-input-final.png"));
            yield return new WaitForSecondsRealtime(.5f);
            Application.Quit((bool)JObject.Parse(Editor.NativeInputAcceptance.Status())["passed"]?0:1);
        }
        void Update(){if(begun)Editor.NativeInputAcceptance.Tick();}
    }
}
#endif
