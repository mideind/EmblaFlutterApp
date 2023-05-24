# TODO for Embla Flutter client

* Performance profiling on both iOS and Android (what's the rendering frequency? how does it affect battery life?)
* Fix audio level sampling rate issue in flutter_sound on iOS (fork flutter_sound)
* Add more widget tests
* Optimize animation redraws, or switch over to APNG for animation when Flutter adds support.
The client currently manually loads all the PNG animation frames into memory and
renders them on a ticker. This kind of basic functionality should not be handled by us
and reflects the immaturity of the Flutter environment. Support arrived in Flutter 3.10.0
* Fix broken playback when session button is hammered repeatedly (is this still a thing?)
* Do serious performance profiling
* Confirmation alert or "toast" on completion of clear user data calls. User is not notified
if the operation fails.
* Thoroughly test Bluetooth functionality
* Issue with switching between Wifi and 4G during a session (minor issue)
