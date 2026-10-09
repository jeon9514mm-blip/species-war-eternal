using System;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Eternal.UnityMigration.Editor
{
    public static class NativeGameInstaller
    {
        [MenuItem("Eternal/Create native game entry")]
        public static string Create()
        {
            if(EditorApplication.isPlaying||SceneManager.GetActiveScene().isDirty)throw new InvalidOperationException("Stop Play and save the current scene first.");
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
            new GameObject("Eternal player entry").AddComponent<EternalBootstrap>();
            EditorSceneManager.SaveScene(SceneManager.GetActiveScene(),"Assets/Scenes/Eternal.unity");
            EditorBuildSettings.scenes=new[]{new EditorBuildSettingsScene("Assets/Scenes/Eternal.unity",true)};AssetDatabase.SaveAssets();
            return "Assets/Scenes/Eternal.unity · native faction entry and separate Unity profiles; review scene is preserved.";
        }
    }
}
