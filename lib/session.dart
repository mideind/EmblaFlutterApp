/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020-2023 Miðeind ehf. <mideind@mideind.is>
 * Original author: Sveinbjorn Thordarson
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

/// Main session view

import 'dart:async';

import 'package:embla/loc.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;
import 'package:wakelock/wakelock.dart' show Wakelock;
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_settings/open_settings.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:embla_core/embla_core.dart';

import './animations.dart' show animationFrames;
import './common.dart';
import './hotword.dart' show HotwordDetector;
import './menu.dart' show MenuRoute;
import './prefs.dart' show Prefs;
import './jsexec.dart' show JSExecutor;
import './theme.dart';
import './button.dart';
import './util.dart' show readServerAPIKey;
import './info.dart' show getClientType, getVersion, getUniqueIdentifier;

// UI String constants
const kIntroMessage = 'Segðu „Hæ, Embla“ eða smelltu á hnappinn til þess að tala við Emblu.';
const kIntroNoHotwordMessage = 'Smelltu á hnappinn til þess að tala við Emblu.';
const kServerErrorMessage = 'Villa kom upp í samskiptum við netþjón.';
const kNoInternetMessage = 'Ekki næst samband við netið.';
const kNoMicPermissionMessage = 'Mig vantar heimild til að nota hljóðnema.';

// Hotword detection button accessibility labels
const kDisableHotwordDetectionLabel = 'Slökkva á raddvirkjun';
const kEnableHotwordDetectionLabel = 'Kveikja á raddvirkjun';

// Animation framerate
const int msecPerFrame = (1000 ~/ 24);
const Duration durationPerFrame = Duration(milliseconds: msecPerFrame);

BuildContext? sessionContext;

// Main widget for session view
class SessionRoute extends StatefulWidget {
  const SessionRoute({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => SessionRouteState();
}

class SessionRouteState extends State<SessionRoute> with SingleTickerProviderStateMixin {
  EmblaSession session = EmblaSession(EmblaSessionConfig());
  EmblaSessionConfig config = EmblaSessionConfig();
  Timer? animationTimer;
  String text = '';
  String? imageURL;
  late StreamSubscription<FGBGType> appStateSubscription;

  @protected
  @mustCallSuper
  @override
  void initState() {
    super.initState();

    // This is needed to make animations work when hot reloading during development
    Animate.restartOnHotReload = (kDebugMode == true);

    text = introMsg();

    // Start observing app state (foreground, background, active, inactive)
    appStateSubscription = FGBGEvents.stream.listen((event) async {
      if (event == FGBGType.foreground) {
        config.apiKey = readServerAPIKey();
        config.fetchToken();
        // App went into foreground
        requestMicPermissionAndStartHotwordDetection();
      } else {
        // App went into background - FGBGType.background
        if (session.isActive()) {
          await session.stop();
        } else {
          HotwordDetector().stop();
          AudioPlayer().stop();
        }
      }
    });

    requestMicPermissionAndStartHotwordDetection();
  }

  @protected
  @mustCallSuper
  @override
  void dispose() {
    appStateSubscription.cancel();
    animationTimer?.cancel();
    super.dispose();
  }

  // Intro message varies depending on whether hotword detection is enabled
  String introMsg() {
    return Prefs().boolForKey('hotword_activation') ? kIntroMessage : kIntroNoHotwordMessage;
  }

  // Start hotword detection
  Future<void> requestMicPermissionAndStartHotwordDetection() async {
    await Permission.microphone.isGranted.then((bool isGranted) {
      if (isGranted == false) {
        dlog("Cannot start hotword detection, microphone permission refused");
        AudioPlayer().playNoMic(Prefs().stringForKey("voice_id") ?? kDefaultVoiceID);
        showMicPermissionErrorAlert(sessionContext!);
      } else if (Prefs().boolForKey('hotword_activation') == true) {
        HotwordDetector().start(hotwordHandler);
      }
    });
  }

  // Show alert dialog explaining that microphone permission has not been granted
  void showMicPermissionErrorAlert(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Villa í talgreiningu'),
          content: const Text(kNoMicPermissionMessage),
          actions: <Widget>[
            TextButton(
              child: const Text('Allt í lagi'),
              onPressed: () {
                Navigator.of(context).pop();
                OpenSettings.openPrivacySetting();
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> isConnectedToInternet() async {
    final ConnectivityResult connectivityResult = await Connectivity().checkConnectivity();
    return (connectivityResult != ConnectivityResult.none);
  }

  // Set text field string (and optionally, an associated image)
  void msg(String s, {String? imgURL}) {
    setState(() {
      text = s;
      imageURL = imgURL;
    });
  }

  /// Hotword detection handling
  void hotwordHandler() {
    dlog("Hotword detected");
    start();
  }

  /// Create session configuration
  Future<EmblaSessionConfig> configureSession() async {
    final String server = Prefs().stringForKey("ratatoskur_server") ?? kDefaultRatatoskurServer;
    final cfg = EmblaSessionConfig(server: server);

    // Settings
    cfg.apiKey = readServerAPIKey();
    cfg.voiceID = Prefs().stringForKey("voice_id") ?? kDefaultVoiceID;
    cfg.voiceSpeed = Prefs().doubleForKey("voice_speed") ?? kDefaultVoiceSpeed;
    cfg.private = Prefs().boolForKey("private");
    cfg.queryServer = Prefs().stringForKey("query_server") ?? kDefaultQueryServer;
    cfg.clientID = await getUniqueIdentifier();
    cfg.clientType = await getClientType();
    cfg.clientVersion = await getVersion();

    // Handlers
    cfg.onStartStreaming = handleStartStreaming;
    cfg.onSpeechTextReceived = handleTextReceived;
    cfg.onQueryAnswerReceived = handleQueryResponse;
    // cfg.onStartAnswering;
    cfg.onDone = handleDone;
    cfg.onError = handleError;

    cfg.getLocation = () {
      return LocationTracker().location;
    };

    return cfg;
  }

  /// Start session
  void start() async {
    if (session.isActive()) {
      dlog('Session start called during active pre-existing session!');
      return;
    }

    // Make sure we have microphone permission
    if (await Permission.microphone.isGranted == false) {
      AudioPlayer().playNoMic(Prefs().stringForKey('voice_id') ?? kDefaultVoiceID);
      showMicPermissionErrorAlert(sessionContext!);
      return;
    }

    // Check for internet connectivity
    if (await isConnectedToInternet() == false) {
      msg(kNoInternetMessage);
      AudioPlayer().playSound('conn', Prefs().stringForKey("voice_id")!);
      return;
    }

    // OK, the conditions are right, let's start the session.
    HotwordDetector().stop();
    config = await configureSession();
    session = EmblaSession(config);

    try {
      session.start();

      // Clear text and set off animation timer
      setState(() {
        text = '';
        imageURL = null;
        Waveform().setDefaultSamples();
        animationTimer?.cancel();
        animationTimer = Timer.periodic(durationPerFrame, (Timer t) => ticker());
      });
    } catch (e) {
      dlog('Error starting session: ${e.toString()}');
      session.stop();
    }
  }

  // User cancelled ongoing session by pressing the button
  void cancel() {
    dlog('User initiated cancellation of session');
    session.cancel();
    msg(introMsg());
  }

  // Session button pressed
  void toggle() async {
    if (session.isActive() == false) {
      start();
    } else {
      cancel();
    }
  }

  // Ticker to animate session button
  void ticker() {
    if (session.state == EmblaSessionState.answering) {
      setState(() {
        currFrame += 1;
        if (currFrame >= animationFrames.length) {
          currFrame = 0; // Reset animation to first frame
        }
      });
    } else if (session.state == EmblaSessionState.streaming) {
      setState(() {
        Waveform().addSample(AudioRecorder().signalStrength());
      });
    }
  }

  /// Embla session handlers ///

  void handleStartStreaming() {
    // Trigger redraw
    msg("");
  }

  void handleTextReceived(String transcript, bool isFinal) {
    msg(transcript);
  }

  // Process response from query server
  void handleQueryResponse(dynamic resp) async {
    // if (resp == null || (resp['error'] != null)) {
    //   dlog("Received bad query response: $resp");
    //   return;
    // }

    // Update text field with response
    String t = "${resp["q"]}\n\n${resp["answer"]}";
    if (resp['source'] != null && resp['source'] != '') {
      t = "$t (${resp['source']})";
    }
    msg(t, imgURL: resp['image']);

    // Open URL handling
    if (resp['open_url'] != null && resp['open_url'] != '') {
      session.stop();
      dlog("Opening URL ${resp['open_url']}");
      launchUrl(Uri.parse(resp['open_url']), mode: LaunchMode.externalApplication);
    }
    // Execute Javascript payload
    else if (resp['command'] != null && resp['command'] != '') {
      // Evaluate JS
      String s = await JSExecutor().run(resp['command']);
      msg(s);
      // Request speech synthesis of result, play audio and terminate session
      await EmblaSpeechSynthesizer.synthesize(s, config.apiKey!, (dynamic m) {
        if (m == null || (m is Map) == false || m['audio_url'] == null) {
          dlog("Error synthesizing audio. Response from server was: $m");
          session.stop();
          AudioPlayer().playSound('err');
          msg(kServerErrorMessage);
        } else {
          AudioPlayer().stop();
          AudioPlayer().playURL(m['audio_url'], (bool err) {
            session.stop();
          });
        }
      });
    }
  }

  void handleError(String errMsg) {
    var errStr = kDebugMode ? errMsg : kServerErrorMessage;
    msg(errStr);
    AudioPlayer().playSound('err');
  }

  void handleDone() {
    setState(() {
      animationTimer?.cancel();
      currFrame = kFullLogoFrame;
      if (text == '') {
        text = introMsg();
      }
    });

    if (Prefs().boolForKey('hotword_activation') == true) {
      HotwordDetector().start(hotwordHandler);
    }
  }

  @override
  Widget build(BuildContext context) {
    sessionContext = context;

    // Hotword toggle button properties depend on whether hotword detection is enabled
    final bool hwActive = Prefs().boolForKey('hotword_activation');
    final String hotwordIcon = hwActive ? 'mic' : 'mic-slash';
    final String hotwordLabel =
        hwActive ? kDisableHotwordDetectionLabel : kEnableHotwordDetectionLabel;

    // Show menu route
    void pushMenu() {
      session.stop();
      HotwordDetector().stop();
      Wakelock.disable();

      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => const MenuRoute(),
        ),
      ).then((val) {
        // Make sure we rebuild main route when menu route is popped in navigation
        // stack. This ensures that the state of the voice activation button is
        // updated to reflect potential changes in Settings, etc.
        if (text == '') {
          msg(introMsg());
        }
        // Re-enable wakelock when returning to main route
        Wakelock.enable();
        // Resume hotword detection (if enabled)
        if (Prefs().boolForKey('hotword_activation') == true) {
          HotwordDetector().start(hotwordHandler);
        }
      });
    }

    // Handle tap on microphone icon to toggle hotword activation
    void toggleHotwordActivation() {
      setState(() {
        final bool on = Prefs().boolForKey('hotword_activation');
        Prefs().setBoolForKey('hotword_activation', !on);
        if (session.state == EmblaSessionState.idle) {
          msg(introMsg());
        }
      });
      if (Prefs().boolForKey('hotword_activation')) {
        HotwordDetector().start(hotwordHandler);
      } else {
        HotwordDetector().stop();
      }
    }

    return Scaffold(
      // Top navigation bar
      appBar: AppBar(
          bottomOpacity: 0.0,
          elevation: 0.0,
          // Toggle hotword activation button (left)
          leading: Semantics(
              label: hotwordLabel,
              child: IconButton(
                icon: ImageIcon(img4theme(hotwordIcon, context)),
                onPressed: toggleHotwordActivation,
              )),
          // Hamburger menu button (right)
          actions: <Widget>[
            Semantics(
                label: 'Sýna valblað',
                child: IconButton(icon: ImageIcon(img4theme('menu', context)), onPressed: pushMenu))
          ]),
      // Main view contents
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          // Session text widget
          Expanded(flex: 6, child: SessionTextAreaWidget(text, imageURL)),
          // Session button widget
          Expanded(flex: 8, child: SessionButtonWidget(context, session, toggle)),
        ],
      ),
    );
  }
}

/// Widget for the top scrollable text area, which
/// can also (optionally) display an image.
class SessionTextAreaWidget extends StatelessWidget {
  final String text;
  final String? imageURL;

  const SessionTextAreaWidget(this.text, this.imageURL, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Widget> subWidgets = [
      FractionallySizedBox(widthFactor: 1.0, child: Text(text, style: sessionTextStyle))
    ];
    if (imageURL != null) {
      // TODO: Surely there's image caching somewhere?
      subWidgets.add(Image.network(imageURL!));
    }
    return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
            child: Column(
              children: subWidgets,
            )));
  }
}
