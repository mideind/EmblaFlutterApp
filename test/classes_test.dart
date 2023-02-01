// These are the tests for the project's non-widget classes.

import 'package:test/test.dart';
import 'package:flutter/material.dart';

import 'package:embla/animations.dart';
import 'package:embla/audio.dart';
import 'package:embla/hotword.dart';
import 'package:embla/jsexec.dart';
import 'package:embla/loc.dart';
import 'package:embla/prefs.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  testAnimations();
//   testAudio();
  testHotword();
  testJSExec();
  testLocationTracker();
  testPrefs();
}

// animations.dart
void testAnimations() async {
  test("Should have 100 animation frames", () async {
    await preloadAnimationFrames();
    expect(animationFrames.length, 100);
  });
}

// audio.dart
void testAudio() async {
  test("AudioPlayer should be singleton", () async {
    expect(AudioPlayer() == AudioPlayer(), true);
  });
  test("AudioPlayer should preload sound files on instantiation", () async {
    expect(AudioPlayer().audioFileCache, isNotEmpty);
  });
}

// hotword.dart
void testHotword() async {
  test("Hotword should be singleton", () {
    expect(HotwordDetector() == HotwordDetector(), true);
  });
}

// jsexec.dart
void testJSExec() async {
  test("JSExecutor should be singleton", () {
    expect(JSExecutor() == JSExecutor(), true);
  });
//   test("JSExecutor should run JavaScript code without issue", () async {
//     JSExecutor executor = JSExecutor();
//     expect(await executor.run("2+2"), 4);
//   });
}

// loc.dart
void testLocationTracker() async {
  test("LocationTracker should be singleton", () {
    expect(LocationTracker() == LocationTracker(), true);
  });
}

// prefs.dart
void testPrefs() async {
  test("Prefs should be singleton", () {
    expect(Prefs() == Prefs(), true);
  });

  test("Prefs should return null for unset non-bool-value keys", () {
    var p = Prefs();
    expect(p.stringForKey("test"), null);
    expect(p.floatForKey("test2"), null);
  });

//   test("Prefs should return same value for key as previously set", () {
//     var p = Prefs();
//     p.setStringForKey("test", "test");
//     expect(p.stringForKey("test") == "test", true);
//     p.setBoolForKey("test2", true);
//     expect(p.boolForKey("test2") == true, true);
//     p.setStringForKey("test", "test");
//     expect(p.stringForKey("test") == "test", true);
//   });
}
