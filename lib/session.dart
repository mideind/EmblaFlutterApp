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
import 'dart:math' show min, max;
import 'dart:ui' as ui;

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
import './util.dart' show readServerAPIKey;
import './version.dart' show getClientType, getVersion, getUniqueIdentifier;

// UI String constants
const kIntroMessage = 'Segðu „Hæ, Embla“ eða smelltu á hnappinn til þess að tala við Emblu.';
const kIntroNoHotwordMessage = 'Smelltu á hnappinn til þess að tala við Emblu.';
const kServerErrorMessage = 'Villa kom upp í samskiptum við netþjón.';
const kNoInternetMessage = 'Ekki næst samband við netið.';
const kNoMicPermissionMessage =
    'Ekki tókst að hefja talgreiningu. Emblu vantar heimild til að nota hljóðnema.';

// Waveform configuration
const int kWaveformNumBars = 12; // Number of waveform bars drawn
const double kWaveformBarMarginRatio = 0.22; // Spacing between waveform bars as proportion of width
const double kWaveformDefaultSampleLevel = 0.05; // Slightly above 0 looks better
const double kWaveformMinSampleLevel = 0.025; // Hard limit on lowest level
const double kWaveformMaxSampleLevel = 0.95; // Hard limit on highest level

// Animation framerate
const int msecPerFrame = (1000 ~/ 24);
const Duration durationPerFrame = Duration(milliseconds: msecPerFrame);

// Logo animation status
const kFullLogoFrame = 99;
int currFrame = kFullLogoFrame;

// Session button size (proportional to width/height)
const kRestingButtonPropSize = 0.58;

// Session button accessibility labels
const kRestingButtonLabel = 'Tala við Emblu';
const kExpandedButtonLabel = 'Hætta að tala við Emblu';

// Hotword detection accesibility labels
const kDisableHotwordDetectionLabel = 'Slökkva á raddvirkjun';
const kEnableHotwordDetectionLabel = 'Kveikja á raddvirkjun';

BuildContext? sessionContext;

// Samples (0.0-1.0) used for waveform animation
List<double> audioSamples = populateSamples();

List<double> populateSamples() {
  return List.filled(kWaveformNumBars, kWaveformDefaultSampleLevel, growable: true);
}

void addSample(double level) {
  while (audioSamples.length >= kWaveformNumBars) {
    audioSamples.removeAt(0);
  }
  audioSamples.add(level < kWaveformDefaultSampleLevel ? kWaveformDefaultSampleLevel : level);
}

// Main widget for session view
class SessionRoute extends StatefulWidget {
  const SessionRoute({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => SessionRouteState();
}

class SessionRouteState extends State<SessionRoute> with TickerProviderStateMixin {
  EmblaSession session = EmblaSession(EmblaSessionConfig());
  EmblaSessionConfig config = EmblaSessionConfig();
  Timer? animationTimer;
  String text = '';
  String? imageURL;
  StreamSubscription<FGBGType>? appStateSubscription;

  @protected
  @override
  @mustCallSuper
  void initState() {
    super.initState();

    // This is needed to make animations work when hot reloading during development
    if (kDebugMode) {
      Animate.restartOnHotReload = true;
    }

    text = introMsg();

    requestMicPermissionAndStartHotwordDetection();

    // Start observing app state (foreground, background, active, inactive)
    appStateSubscription = FGBGEvents.stream.listen((event) {
      if (event == FGBGType.foreground) {
        // App went into foreground
        if (Prefs().boolForKey('hotword_activation') == true) {
          HotwordDetector().start(hotwordHandler);
        }
      } else {
        // App went into background - FGBGType.background
        HotwordDetector().stop();
        AudioPlayer().stop();
        session.stop();
      }
    });
  }

  @protected
  @mustCallSuper
  @override
  void dispose() {
    appStateSubscription?.cancel();
    animationTimer?.cancel();
    super.dispose();
  }

  String introMsg() {
    return Prefs().boolForKey('hotword_activation') ? kIntroMessage : kIntroNoHotwordMessage;
  }

  Future<void> requestMicPermissionAndStartHotwordDetection() async {
    if (await Permission.microphone.isGranted) {
      if (Prefs().boolForKey('hotword_activation') == true) {
        HotwordDetector().start(hotwordHandler);
      }
    } else {
      dlog("Cannot start hotword detection, microphone permission refused");
    }
  }

  // Show alert dialog for when microphone permission is not available
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
    start();
  }

  void hotwordErrHandler(dynamic err) {
    dlog("Error starting hotword detection: ${err.toString()}");
  }

  /// Create session configuration
  Future<EmblaSessionConfig> configureSession() async {
    final String server = Prefs().stringForKey("ratatoskur_server") ?? kDefaultRatatoskurServer;
    final EmblaSessionConfig cfg = EmblaSessionConfig(server: server);

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
    cfg.onStartListening = handleStartListening;
    cfg.onSpeechTextReceived = handleTextReceived;
    cfg.onQueryAnswerReceived = handleQueryResponse;
    cfg.onStartAnswering = () {};
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
      AudioPlayer().playSound('rec_cancel');
      showMicPermissionErrorAlert(context);
      return;
    }

    // Check for internet connectivity
    if (await isConnectedToInternet() == false) {
      msg(kNoInternetMessage);
      AudioPlayer().playSound('conn', Prefs().stringForKey("voice_id")!);
      return;
    }

    HotwordDetector().stop();

    config = await configureSession();
    session = EmblaSession(config);
    try {
      session.start();

      // Clear text and set off animation timer
      setState(() {
        text = '';
        imageURL = null;
        audioSamples = populateSamples();
        animationTimer?.cancel();
        animationTimer = Timer.periodic(durationPerFrame, (Timer t) => ticker());
      });
    } catch (e) {
      dlog('Error starting session: ${e.toString()}');
      session.stop();
    }
  }

  // User cancelled ongoing session by pressing button
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
    }
  }

  void handleStartListening() {
    // Trigger redraw
    msg("Hlustandi...");
  }

  void handleTextReceived(String transcript, bool isFinal) {
    msg(transcript);
  }

  // Process response from query server
  void handleQueryResponse(dynamic resp) async {
    // Update text field with response
    String t = "${resp["q"]}\n\n${resp["answer"]}";
    if (resp['source'] != null && resp['source'] != '') {
      t = "$t (${resp['source']})";
    }
    msg(t, imgURL: resp['image']);

    // Open URL, if provided with query answer
    if (resp['open_url'] != null) {
      session.stop();
      dlog("Opening URL ${resp['open_url']}");
      launchUrl(Uri.parse(resp['open_url']), mode: LaunchMode.externalApplication);
    }
    // Javascript payload
    else if (resp['command'] != null) {
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
    });

    if (Prefs().boolForKey('hotword_activation') == true) {
      HotwordDetector().start(hotwordHandler);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Session button properties depending on whether session is active
    sessionContext = context;
    final bool active = session.isActive();
    const double prop = kRestingButtonPropSize;
    final double buttonSize = MediaQuery.of(context).size.width * prop;
    final String buttonLabel = active ? kRestingButtonLabel : kExpandedButtonLabel;

    // Hotword toggle button properties depending on whether hw detection is enabled
    final bool hwActive = Prefs().boolForKey('hotword_activation');
    final String hotwordIcon = hwActive ? 'mic' : 'mic-slash';
    final String hotwordLabel =
        hwActive ? kDisableHotwordDetectionLabel : kEnableHotwordDetectionLabel;

    // Present menu route
    void pushMenu() {
      session.stop();
      HotwordDetector().stop();
      Wakelock.disable();

      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => const MenuRoute(), // Push menu route
        ),
      ).then((val) {
        // Make sure we rebuild main route when menu route is popped in navigation
        // stack. This ensures that the state of the voice activation button is
        // updated to reflect potential changes in Settings and more.
        if (text == '') {
          msg(introMsg());
        }
        // Re-enable wakelock when returning to main route
        Wakelock.enable();
        // Re-enable hotword detection (if enabled)
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

    // Generate widget tree for the top scrollable text area
    Widget scrollableTextAreaWidget() {
      List<Widget> widgets = [
        FractionallySizedBox(widthFactor: 1.0, child: Text(text, style: sessionTextStyle))
      ];
      if (imageURL != null) {
        widgets.add(Image.network(imageURL!));
      }
      return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
              child: Column(
                children: widgets,
              )));
    }

    // Generate widget tree for the session button below the text area
    Widget sessionButtonWidget() {
      return Padding(
          padding: const EdgeInsets.only(bottom: 30, top: 30),
          child: Center(
              child: Semantics(
                  label: buttonLabel,
                  child: GestureDetector(
                      onTap: toggle,
                      child: SizedBox(
                        width: buttonSize,
                        height: buttonSize,
                        // Session button uses custom painter to draw the button
                        child: CustomPaint(painter: SessionButtonPainter(context, session))
                            .animate(target: session.isActive() ? 1 : 0)
                            .scaleXY(end: 1.20, duration: 100.ms),
                      )))));
    }

    return Scaffold(
      // Top nav bar
      appBar: AppBar(
          bottomOpacity: 0.0,
          elevation: 0.0,
          // Toggle hotword activation button
          leading: Semantics(
              label: hotwordLabel,
              child: IconButton(
                icon: ImageIcon(img4theme(hotwordIcon, context)),
                onPressed: toggleHotwordActivation,
              )),
          // Hamburger menu button
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
          Expanded(flex: 6, child: scrollableTextAreaWidget()),
          // Session button widget
          Expanded(flex: 8, child: sessionButtonWidget()),
        ],
      ),
    );
  }
}

// This is the drawing code for the session button
class SessionButtonPainter extends CustomPainter {
  late final EmblaSession session;
  late final BuildContext context;
  SessionButtonPainter(this.context, this.session);

  // Draw the three circles that make up the button
  void drawCircles(Canvas canvas, Size size) {
    final radius = min(size.width, size.height) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    final List<Color> circleColors = circleColors4Context(sessionContext);

    // First, outermost circle
    var paint = Paint()..color = circleColors[0];
    canvas.drawCircle(center, radius, paint);

    // Second, middle circle
    paint = Paint()..color = circleColors[1];
    canvas.drawCircle(center, radius / 1.25, paint);

    // Third, innermost circle
    paint = Paint()..color = circleColors[2];
    canvas.drawCircle(center, radius / 1.75, paint);
  }

  // Draw current logo animation frame
  void drawLogoFrame(Canvas canvas, Size size, int fnum) {
    if (animationFrames.isEmpty) {
      dlog('Animation frame drawing failed. No frames loaded.');
      return;
    }
    final ui.Image img = animationFrames[fnum];
    // Source image rect
    final Rect srcRect = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());

    // Destination rect centered in canvas
    final double sw = size.width.toDouble();
    final double sh = size.height.toDouble();
    const double prop = 2.4;
    final double w = sw / prop;
    final double h = sh / prop;
    final Rect dstRect = Rect.fromLTWH(
        (sw / 2) - (w / 2), // x
        (sh / 2) - (h / 2), // y
        w, // width
        h); // height
    canvas.drawImageRect(img, srcRect, dstRect, Paint());
  }

  // Draw audio waveform
  void drawWaveform(Canvas canvas, Size size) {
    // Generate square frame to contain waveform
    final double w = size.width / 2.0;
    final double xOffset = (size.width - w) / 2;
    final double yOffset = (size.height - w) / 2;
    final Rect frame = Rect.fromLTWH(xOffset, yOffset, w, w);

    final double margin = (size.width * kWaveformBarMarginRatio) / (kWaveformNumBars - 1);
    final double totalMarginWidth = (kWaveformNumBars * margin) - margin;

    final double barWidth = (frame.width - totalMarginWidth) / kWaveformNumBars;
    final double barHeight = frame.height / 2;
    final double centerY = (frame.height / 2);

    // Colors for the top and bottom waveform bars
    final topPaint = Paint()..color = topWaveformColor;
    final bottomPaint = Paint()..color = bottomWaveformColor;

    // Draw audio waveform bars based on audio sample levels
    for (int i = 0; i < audioSamples.length; i++) {
      // Clamp signal level
      final double level =
          min(max(kWaveformMinSampleLevel, audioSamples[i]), kWaveformMaxSampleLevel);

      // Draw top bar
      final Rect topRect = Rect.fromLTWH(
          i * (barWidth + margin) + (margin / 2) + xOffset, // x
          barHeight - (level * barHeight) + yOffset, // y
          barWidth, // width
          level * barHeight); // height
      canvas.drawRect(topRect, topPaint);

      // Draw circle at end of bar
      canvas.drawCircle(
          Offset(i * (barWidth + margin) + barWidth / 2 + (margin / 2) + xOffset,
              barHeight - (level * barHeight) + yOffset), // offset
          barWidth / 2, // radius
          topPaint);

      // Draw bottom bar
      final Rect bottomRect = Rect.fromLTWH(
          i * (barWidth + margin) + (margin / 2) + xOffset, // x
          centerY + yOffset, // y
          barWidth, // width
          level * barHeight); // height
      canvas.drawRect(bottomRect, bottomPaint);

      // Draw circle at end of bottom bar
      canvas.drawCircle(
          Offset(i * (barWidth + margin) + barWidth / 2 + (margin / 2) + xOffset,
              centerY + (level * barHeight) + yOffset), // offset
          barWidth / 2, // radius
          bottomPaint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // We always draw the circles
    drawCircles(canvas, size);

    // Draw waveform bars during microphone input
    if (session.state ==
            EmblaSessionState.listening /*||
        session.state == EmblaSessionState.starting*/
        ) {
      drawWaveform(canvas, size);
    }
    // Draw logo animation during answering phase
    else if (session.state == EmblaSessionState.answering) {
      drawLogoFrame(canvas, size, currFrame);
    }
    // Otherwise, draw non-animated Embla logo
    else {
      drawLogoFrame(canvas, size, kFullLogoFrame); // Always same frame
    }
  }

  @override
  bool shouldRepaint(SessionButtonPainter oldDelegate) {
    return true;
  }
}
