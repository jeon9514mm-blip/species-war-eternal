using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;
using UnityEngine.Rendering;

namespace Eternal.UnityMigration.Editor
{
    public static class AndroidApkBuilder
    {
        public const string PackageId="com.specieswar.eternal";
        public const string Version="0.1.20";
        public const string Output="Builds/Android/EternalUnity-0.1.20-arm64.apk";
        [MenuItem("Eternal/Android/Configure test APK")]
        public static void Configure()
        {
            PlayerSettings.bundleVersion=Version;
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android,PackageId);
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android,ScriptingImplementation.IL2CPP);
            PlayerSettings.SetManagedStrippingLevel(NamedBuildTarget.Android,ManagedStrippingLevel.Low);
            PlayerSettings.Android.targetArchitectures=AndroidArchitecture.ARM64;
            PlayerSettings.Android.minSdkVersion=AndroidSdkVersions.AndroidApiLevel26;
            PlayerSettings.Android.targetSdkVersion=AndroidSdkVersions.AndroidApiLevel36;
            PlayerSettings.Android.bundleVersionCode=20;
            PlayerSettings.Android.useCustomKeystore=false;
            PlayerSettings.Android.splitApplicationBinary=false;
            PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.Android,false);
            PlayerSettings.SetGraphicsAPIs(BuildTarget.Android,new[]{GraphicsDeviceType.Vulkan,GraphicsDeviceType.OpenGLES3});
            PlayerSettings.defaultInterfaceOrientation=UIOrientation.AutoRotation;
            PlayerSettings.allowedAutorotateToPortrait=false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown=false;
            PlayerSettings.allowedAutorotateToLandscapeLeft=true;
            PlayerSettings.allowedAutorotateToLandscapeRight=true;
            EditorUserBuildSettings.buildAppBundle=false;
            EditorUserBuildSettings.exportAsGoogleAndroidProject=false;
            EditorUserBuildSettings.development=false;
            EditorUserBuildSettings.androidCreateSymbols=AndroidCreateSymbols.Disabled;
            EditorUserBuildSettings.androidBuildSubtarget=MobileTextureSubtarget.ASTC;
            AssetDatabase.SaveAssets();
        }
        [MenuItem("Eternal/Android/Build signed test APK")]
        public static void Build()
        {
            Configure();
            // The Android label is scoped to this build. Keep the existing
            // desktop company/product identity and its save directory intact.
            string company=PlayerSettings.companyName,product=PlayerSettings.productName;
            try
            {
                PlayerSettings.companyName="Species War";PlayerSettings.productName="종의전쟁: 이터널";
                BuildConfiguredApk();
            }
            finally{PlayerSettings.companyName=company;PlayerSettings.productName=product;AssetDatabase.SaveAssets();}
        }
        static void BuildConfiguredApk()
        {
            if(!BuildPipeline.IsBuildTargetSupported(BuildTargetGroup.Android,BuildTarget.Android))throw new InvalidOperationException("Android Build Support is not installed for this Editor.");
            Directory.CreateDirectory(Path.GetDirectoryName(Output));
            var report=BuildPipeline.BuildPlayer(new BuildPlayerOptions{scenes=new[]{"Assets/Scenes/Eternal.unity"},locationPathName=Output,target=BuildTarget.Android,options=BuildOptions.CompressWithLz4HC|BuildOptions.DetailedBuildReport});
            var summary=report.summary;
            var rows=new JArray(report.steps.SelectMany(s=>s.messages).Where(m=>m.type==LogType.Error||m.type==LogType.Exception||m.type==LogType.Warning).Select(m=>new JObject{{"type",m.type.ToString()},{"message",m.content}}));
            var result=new JObject{{"result",summary.result.ToString()},{"errors",summary.totalErrors},{"warnings",summary.totalWarnings},{"duration_seconds",summary.totalTime.TotalSeconds},{"output",Output},{"package",PackageId},{"version",Version},{"version_code",20},{"architecture","arm64-v8a"},{"scripting_backend","IL2CPP"},{"min_sdk",26},{"target_sdk",36},{"development_build",false},{"signing","Android default debug signing; sideload test only"},{"texture_target","ASTC"},{"messages",rows},{"device_run_verified",false}};
            if(summary.result==BuildResult.Succeeded)
            {
                using var sha=SHA256.Create();using var stream=File.OpenRead(Output);
                result["sha256"]=BitConverter.ToString(sha.ComputeHash(stream)).Replace("-","").ToLowerInvariant();result["bytes"]=stream.Length;
            }
            Directory.CreateDirectory("../checks/unity-migration-2026-10-08");File.WriteAllText("../checks/unity-migration-2026-10-08/android-build-cp20.json",result.ToString());
            if(summary.result!=BuildResult.Succeeded)throw new InvalidOperationException("Android APK build failed. See android-build-cp20.json and the Editor build log.");
            Debug.Log("ETERNAL_APK_BUILT "+Output);
        }
    }
}
