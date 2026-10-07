v43.2 image asset repair patch

Apply to the ROOT of the extracted v43 project so assets/ and scripts/ merge in place.
This patch restores the 28 missing runtime motion atlases and SpriteFrames and updates the two motion controllers for optimized atlas resolution.
After applying, open project.godot in Godot 4.7.2 and allow import to finish.
