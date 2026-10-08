using System;
using UnityEngine;

namespace Eternal.UnityMigration
{
    // Inspector-independent entry route for reproducible native visual reviews.
    // The shipped fixture starts hunting; a review may start an existing raid
    // and pause at a requested elapsed time without touching player storage.
    [Serializable]
    public sealed class ReviewLaunchSettings
    {
        public string initialRaidZone="";
        public float pauseAfterSeconds;
        public static ReviewLaunchSettings Load()
        {
            var source=Resources.Load<TextAsset>("Eternal/review-launch");
            return source==null?new ReviewLaunchSettings():JsonUtility.FromJson<ReviewLaunchSettings>(source.text)??new ReviewLaunchSettings();
        }
        public bool HasRaid=>initialRaidZone=="gray_meadow"||initialRaidZone=="forgotten_mine"||initialRaidZone=="moonrest_forest";
    }
}
