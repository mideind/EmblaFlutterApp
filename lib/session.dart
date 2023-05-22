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
// import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;
import 'package:wakelock/wakelock.dart' show Wakelock;
import 'package:flutter_fgbg/flutter_fgbg.dart' show FGBGEvents, FGBGType;
import 'package:permission_handler/permission_handler.dart';
import 'package:open_settings/open_settings.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';

import 'package:embla_core/embla_core.dart';

import './animations.dart';
import './common.dart';
import './hotword.dart' show HotwordDetector;
import './menu.dart' show MenuRoute;
import './prefs.dart' show Prefs;
import './jsexec.dart' show JSExecutor;
import './theme.dart';
import './button.dart';
import './loc.dart' show LocationTracker;
import './util.dart';
import './info.dart' show getClientType, getMarketingVersion, getUniqueDeviceIdentifier;

// UI String constants
const kIntroMessage = 'Segðu „Hæ, Embla“ eða smelltu á hnappinn til þess að tala við Emblu.';
const kIntroNoHotwordMessage = 'Smelltu á hnappinn til þess að tala við Emblu.';
const kServerErrorMessage = 'Villa kom upp í samskiptum við netþjón.';
const kNoInternetMessage = 'Ekki næst samband við netið.';
const kNoMicPermissionMessage = 'Emblu vantar heimild til að nota hljóðnema.';

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
  EmblaSession? session;
  late EmblaSessionConfig config;
  Timer? animationTimer;
  String text = '';
  String? imageURL;
  late StreamSubscription<FGBGType> appStateSubscription;
  bool inBackground = false;
  bool inMenu = false;

  @protected
  @mustCallSuper
  @override
  void initState() {
    super.initState();

    // This is needed to make animations work when hot reloading during development
    Animate.restartOnHotReload = (kDebugMode == true);

    configureSession().then((c) {
      config = c;
      config.fetchToken();
      session = EmblaSession(config);
    });

    text = introMsg();

    // Start observing app state (foreground, background)
    appStateSubscription = FGBGEvents.stream.listen((event) async {
      if (event == FGBGType.foreground) {
        dlog("App went into foreground");
        inBackground = false;
        config.apiKey = readServerAPIKey();
        config.fetchToken();
        // App went into foreground
        await requestMicPermissionAndStartHotwordDetection();
      } else {
        // App went into background - FGBGType.background
        dlog("App went into background");
        inBackground = true;
        if (session!.isActive()) {
          await session!.stop();
        } else {
          if (HotwordDetector().isActive()) {
            await HotwordDetector().stop();
          }
          AudioPlayer().stop();
        }
      }
    });

    // Start observing connectivity changes. If we lose connectivity while
    // a session is active, stop the session and let the user know that
    // the device has gone offline.
    Connectivity().onConnectivityChanged.listen((ConnectivityResult event) async {
      dlog("Connectivity changed: $event");
      if (event == ConnectivityResult.none && session != null && session!.isActive()) {
        await session!.stop();
        AudioPlayer().playSound(
            'conn', Prefs().stringForKey("voice_id")!, null, Prefs().doubleForKey("voice_speed")!);
        setState(() {
          msg(kNoInternetMessage);
        });
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

  // Start hotword detection after gaining microphone permission
  Future<void> requestMicPermissionAndStartHotwordDetection() async {
    await Permission.microphone.isGranted.then((bool isGranted) async {
      if (isGranted == false) {
        dlog("Cannot start hotword detection, microphone permission refused");
        AudioPlayer().playNoMic(Prefs().stringForKey("voice_id") ?? kDefaultVoiceID);
        showMicPermissionErrorAlert(sessionContext!);
      } else if (Prefs().boolForKey('hotword_activation') == true &&
          inBackground == false &&
          inMenu == false) {
        await HotwordDetector().start(hotwordHandler);
      }
    });
  }

  // Show alert dialog explaining that microphone permission has not been granted
  void showMicPermissionErrorAlert(BuildContext context) async {
    AudioPlayer().playNoMic(Prefs().stringForKey("voice_id") ?? kDefaultVoiceID);
    showAlertDialog(
      context: context,
      barrierDismissible: false,
      title: 'Heimild vantar',
      message: kNoMicPermissionMessage,
      actions: [
        const AlertDialogAction(key: 'ok', label: 'Allt í lagi'),
      ],
    ).then(
      (value) {
        OpenSettings.openPrivacySetting();
      },
    );
  }

  Future<bool> isConnectedToInternet() async {
    return (await Connectivity().checkConnectivity() != ConnectivityResult.none);
  }

  // Set text field string (and optionally, an associated image)
  void msg(String s, {String? imgURL}) {
    setState(() {
      // TODO: Capitalization really should be handled server-side
      text = s.sentenceCapitalized();
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
    cfg.privateMode = Prefs().boolForKey("privacy_mode");
    cfg.queryServer = Prefs().stringForKey("query_server") ?? kDefaultQueryServer;
    cfg.engine = (Prefs().stringForKey("asr_engine") ?? kDefaultASREngine).toLowerCase();
    cfg.clientID = await getUniqueDeviceIdentifier();
    cfg.clientType = await getClientType();
    cfg.clientVersion = await getMarketingVersion();

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
    if (session!.isActive()) {
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
      AudioPlayer().playSound(
          'conn', Prefs().stringForKey("voice_id")!, null, Prefs().doubleForKey("voice_speed")!);
      return;
    }

    // OK, the conditions are right, let's start the session.
    await HotwordDetector().stop();
    config = await configureSession();
    session = EmblaSession(config);

    try {
      session!.start();

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
      await session!.stop();
    }
  }

  // User cancelled ongoing session by pressing the button
  void cancel() {
    dlog('User initiated cancellation of session');
    session!.cancel();
    msg(introMsg());
  }

  // Session button pressed
  void toggle() async {
    if (session!.isActive() == false) {
      start();
    } else {
      cancel();
    }
  }

  // Ticker to animate session button
  void ticker() {
    if (session!.state == EmblaSessionState.answering) {
      setState(() {
        currFrame += 1;
        if (currFrame >= animationFrames.length) {
          currFrame = 0; // Reset animation to first frame
        }
      });
    } else if (session!.state == EmblaSessionState.streaming) {
      setState(() {
        Waveform().addSample(AudioRecorder().signalStrength());
      });
    }
  }

  /// Embla session handlers ///

  /// Session handshake completed and audio streaming has begun
  void handleStartStreaming() {
    // Trigger redraw
    msg("");
  }

  // ASR text received
  void handleTextReceived(String transcript, bool isFinal, Map<String, dynamic> data) {
    if (isFinal) {
      AudioPlayer().playSessionConfirm();
    }
    msg(transcript);
  }

  // Process query response from query server
  void handleQueryResponse(dynamic resp) async {
    // if (resp == null || resp['error'] != null) {
    //   dlog("Received bad query response: $resp");
    //   return;
    // }

    // Update text field with response
    String t = "${resp["q"]}\n\n${resp["answer"]}";
    if (resp['source'] != null && resp['source'] != '') {
      t += " (${resp['source']})";
    }
    msg(t, imgURL: resp['image']);

    // Open URL handling
    if (resp['open_url'] != null) {
      final String url = resp['open_url'];
      bool validURL = Uri.tryParse(url)?.hasAbsolutePath ?? false;
      if (validURL) {
        await session!.stop();
        dlog("Opening URL $url");
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        dlog("Invalid open_url '$url' received from server.");
      }
    }
    // Execute Javascript payload
    else if (resp['command'] != null && resp['command'] != '') {
      // Evaluate JS
      String s = await JSExecutor().run(resp['command']);
      msg(s);
      // Request speech synthesis of result, play audio and terminate session
      await EmblaAPI.synthesizeSpeech(s, config.apiKey!,
              voiceID: config.voiceID,
              voiceSpeed: config.voiceSpeed,
              apiURL: "${config.ratatoskurServer}/rat/v1/tts")
          .then((dynamic m) async {
        if (m == null) {
          dlog("Error synthesizing audio. Response from server was: $m");
          await session!.stop();
          AudioPlayer().playSound(
              'err', Prefs().stringForKey("voice_id")!, null, Prefs().doubleForKey("voice_speed")!);
          msg(kServerErrorMessage);
        } else {
          AudioPlayer().stop();
          AudioPlayer().playURL(m, (bool err) async {
            await session!.stop();
          });
        }
      });
    }
  }

  // Session error handler
  void handleError(String errMsg) async {
    var errStr = kDebugMode ? errMsg : kServerErrorMessage;
    msg(errStr);

    if (Prefs().boolForKey('hotword_activation') == true &&
        inBackground == false &&
        inMenu == false) {
      await HotwordDetector().start(hotwordHandler);
    }
  }

  // Session completion handler
  void handleDone() async {
    setState(() {
      animationTimer?.cancel();
      currFrame = kFullLogoAnimationFrame;
      if (text == '') {
        text = introMsg();
      }
    });

    if (Prefs().boolForKey('hotword_activation') == true &&
        inBackground == false &&
        inMenu == false) {
      await HotwordDetector().start(hotwordHandler);
    }
  }

  @override
  Widget build(BuildContext context) {
    sessionContext = context;

    // Hotword toggle button properties depend on whether hotword detection is enabled
    final bool hwdEnabled = Prefs().boolForKey('hotword_activation');
    final String hotwordIcon = hwdEnabled ? 'mic' : 'mic-slash';
    final String hotwordLabel =
        hwdEnabled ? kDisableHotwordDetectionLabel : kEnableHotwordDetectionLabel;

    // Show menu route
    void pushMenu() async {
      inMenu = true;
      if (session!.isActive()) {
        await session!.stop();
      }
      if (HotwordDetector().isActive()) {
        await HotwordDetector().stop();
      }
      await Wakelock.disable();
      // ignore: use_build_context_synchronously
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => const MenuRoute(),
        ),
      ).then((val) async {
        inMenu = false;
        // Make sure we rebuild main route when menu route is popped in navigation
        // stack. This ensures that the state of the hotword activation button is
        // updated to reflect potential changes in Settings, etc.
        if (text == '') {
          msg(introMsg());
        }
        setState(() {});
        // Re-enable wakelock when returning to main route
        await Wakelock.enable();
        // Resume hotword detection (if enabled)
        if (Prefs().boolForKey('hotword_activation') == true) {
          await HotwordDetector().start(hotwordHandler);
        }
      });
    }

    // Handle tap on microphone icon to toggle hotword activation
    void toggleHotwordActivation() async {
      setState(() {
        final bool on = Prefs().boolForKey('hotword_activation');
        Prefs().setBoolForKey('hotword_activation', !on);
        if (session!.state == EmblaSessionState.idle) {
          msg(introMsg());
        }
      });
      if (Prefs().boolForKey('hotword_activation')) {
        if (session!.isActive() == false) {
          await HotwordDetector().start(hotwordHandler);
        }
      } else {
        await HotwordDetector().stop();
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
      FractionallySizedBox(widthFactor: 1.0, child: SelectableText(text, style: sessionTextStyle))
    ];
    if (imageURL != null) {
      subWidgets.add(Image.network(imageURL!)); // This is automatically cached for us
    }
    // Wrap the scroll view in a ShaderMask to create a linear gradient fade effect
    return ShaderMask(
        shaderCallback: (Rect rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Purple color is not used concretely, only for the fractions of the vector
            colors: [Colors.purple, Colors.transparent, Colors.transparent, Colors.purple],
            stops: [0.0, 0.05, 0.95, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstOut,
        child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 0),
            child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: subWidgets,
                ))));
  }
}
