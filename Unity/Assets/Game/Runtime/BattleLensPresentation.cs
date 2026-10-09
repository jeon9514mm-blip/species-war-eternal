using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Eternal.UnityMigration
{
    // Uses the existing orthographic camera and an owned Volume profile.
    // Combat time, zoom selection, saved settings and the shared asset are untouched.
    public sealed class BattleLensPresentation : MonoBehaviour
    {
        Camera view;Quaternion rest;
        ChromaticAberration chromatic;LensDistortion distortion;FilmGrain grain;
        float until;
        public bool Warning;
        public void Initialize(Camera camera,Volume volume)
        {
            view=camera;rest=view.transform.rotation;var profile=volume.profile;
            T Effect<T>() where T:VolumeComponent {return profile.TryGet<T>(out var found)?found:profile.Add<T>();}
            var bloom=Effect<Bloom>();bloom.intensity.Override(.60f);
            var vignette=Effect<Vignette>();vignette.intensity.Override(.35f);vignette.smoothness.Override(.75f);
            chromatic=Effect<ChromaticAberration>();chromatic.intensity.Override(0);
            distortion=Effect<LensDistortion>();distortion.intensity.Override(0);
            grain=Effect<FilmGrain>();grain.type.Override(FilmGrainLookup.Thin1);grain.intensity.Override(.05f);grain.response.Override(.8f);
        }
        public void Critical(){if(!Warning)until=Time.unscaledTime+.20f;}
        void Update()
        {
            if(view==null)return;
            float pulse=Warning?0:Mathf.Clamp01((until-Time.unscaledTime)/.20f);
            chromatic.intensity.Override(.05f*pulse);distortion.intensity.Override(-.05f*pulse);grain.intensity.Override(.05f+.10f*pulse);
            float roll=(Mathf.PerlinNoise(Time.unscaledTime*23,9)-.5f)*6f*pulse;
            view.transform.rotation=rest*Quaternion.Euler(0,0,roll);
        }
        void OnDisable(){if(view!=null)view.transform.rotation=rest;}
    }
}
