# as3utils
utilities for as3-based projects

## PauseableSound
A sound class that does what the flash Sound API should have done in the first place.
Features:
* pause/resume functionality - resumes where it left off
* Auto-pauses itself when app loses focus on Android instead of letting sound keep playing.
* Supports looping and non-looping sounds
* Only allows one instance of a sound to play at a time
* Hides implementation details like SoundTransform, SoundChannel, etc, but still allows you to control volume, pan, etc
