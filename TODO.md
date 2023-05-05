# TODO for Embla Flutter client

* Add widget tests
* Optimize animation redraws, or switch over to APNG for animation when Flutter adds support.
The client currently manually loads all the PNG animation frames into memory and
renders them on a ticker. This kind of basic functionality should not be handled by us
and reflects the immaturity of the Flutter environment. But support is apparently coming...
* Fix broken playback when session button is hammered repeatedly (only issue on iOS)
* Performance profiling
* Confirmation alert on completion of clear query history calls
