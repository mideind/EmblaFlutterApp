/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020-2026 Miðeind ehf. <mideind@mideind.is>
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

// Main session view

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;
import 'package:wakelock_plus/wakelock_plus.dart' show WakelockPlus;
import 'package:flutter_fgbg/flutter_fgbg.dart' show FGBGEvents, FGBGType;
import 'package:permission_handler/permission_handler.dart';
import 'package:open_settings/open_settings.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';

// Only the audio bits of embla_core are used here: UI sounds for the
// situations the assistant session never gets to see (offline, no mic),
// the microphone signal strength for the waveform, and the streaming ASR
// token prefetch.
import 'package:embla_core/embla_core.dart' show AudioPlayer, AudioRecorder;

import './animations.dart';
import './assistant/assistant_session.dart';
import './assistant/pipeline_factory.dart' show buildAssistantSessionConfig;
import './common.dart';
import './hotword.dart' show HotwordDetector;
import './menu.dart' show MenuRoute;
import './prefs.dart' show Prefs;
import './theme.dart';
import './button.dart';
import './transcript_widget.dart' show TranscriptView, TextInputBar;
import './util.dart';

// UI String constants
const kIntroMessage = 'Segðu „Hæ, Embla“ eða smelltu á hnappinn til þess að tala við Emblu.';
const kIntroNoHotwordMessage = 'Smelltu á hnappinn til þess að tala við Emblu.';
const kServerErrorMessage = 'Villa kom upp í samskiptum við netþjón.';
const kNoInternetMessage = 'Ekki næst samband við netið.';
const kNoMicPermissionMessage = 'Emblu vantar heimild til að nota hljóðnema.';

// Hotword detection button accessibility labels
const kDisableHotwordDetectionLabel = 'Slökkva á raddvirkjun';
const kEnableHotwordDetectionLabel = 'Kveikja á raddvirkjun';

// Style of the status line above the text input bar
const kStatusTextStyle = TextStyle(fontSize: defaultFontSize * 0.8, fontStyle: FontStyle.italic);

// Animation framerate
const int msecPerFrame = (1000 ~/ 24);
const Duration durationPerFrame = Duration(milliseconds: msecPerFrame);

BuildContext? sessionContext;

// Main widget for session view
class SessionRoute extends StatefulWidget {
  const SessionRoute({super.key});

  @override
  State<StatefulWidget> createState() => SessionRouteState();
}

class SessionRouteState extends State<SessionRoute> with SingleTickerProviderStateMixin {
  AssistantSession? session;
  AssistantSessionConfig? config;
  Timer? animationTimer;

  // Status or error line shown above the text input bar
  String statusText = '';
  // Live (interim) transcript while the user is speaking
  String? partialText;

  late StreamSubscription<FGBGType> appStateSubscription;
  StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;
  bool inBackground = false;
  bool inMenu = false;

  // Owned by the route so that 24 fps rebuilds don't lose the typed text
  final TextEditingController textController = TextEditingController();
  final ScrollController transcriptScrollController = ScrollController();

  @protected
  @mustCallSuper
  @override
  void initState() {
    super.initState();

    // This is needed to make animations work when hot reloading during development
    Animate.restartOnHotReload = (kDebugMode == true);

    // Start observing app state (foreground, background)
    appStateSubscription = FGBGEvents.stream.listen((event) async {
      if (event == FGBGType.foreground) {
        dlog("App went into foreground");
        inBackground = false;
        await requestMicPermissionAndStartHotwordDetection();
      } else {
        // App went into background - FGBGType.background
        dlog("App went into background");
        inBackground = true;
        if (session?.isActive() == true) {
          await session!.cancel();
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
    connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> events) async {
      final ConnectivityResult event = events.last;
      dlog("Connectivity changed: $event");
      if (event == ConnectivityResult.none && session?.isActive() == true) {
        await session!.cancel();
        playOfflineSound();
        msg(kNoInternetMessage);
      }
    });

    requestMicPermissionAndStartHotwordDetection();
  }

  @protected
  @mustCallSuper
  @override
  void dispose() {
    appStateSubscription.cancel();
    connectivitySubscription?.cancel();
    animationTimer?.cancel();
    textController.dispose();
    transcriptScrollController.dispose();
    super.dispose();
  }

  // Intro message varies depending on whether hotword detection is enabled
  String introMsg() {
    return Prefs().boolForKey('hotword_activation') ? kIntroMessage : kIntroNoHotwordMessage;
  }

  // Start hotword detection after gaining microphone permission
  Future<void> requestMicPermissionAndStartHotwordDetection() async {
    final bool isGranted = await Permission.microphone.isGranted;
    if (isGranted == false) {
      dlog("Cannot start hotword detection, microphone permission refused");
      playNoMic();
      if (sessionContext != null) {
        showMicPermissionErrorAlert(sessionContext!);
      }
      return;
    }
    await resumeHotwordIfAppropriate();
  }

  /// Resume hotword detection, if it is enabled and nothing else
  /// is using the microphone.
  Future<void> resumeHotwordIfAppropriate() async {
    if (Prefs().boolForKey('hotword_activation') != true) {
      return;
    }
    if (inBackground || inMenu) {
      return;
    }
    if (session?.isActive() == true) {
      return;
    }
    await HotwordDetector().start(hotwordHandler);
  }

  // Show alert dialog explaining that microphone permission has not been granted
  void showMicPermissionErrorAlert(BuildContext context) async {
    playNoMic();
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

  void playNoMic() {
    AudioPlayer().playNoMic(
        voiceID: Prefs().stringForKey("voice_id") ?? kDefaultVoiceID,
        voiceSpeed: Prefs().doubleForKey("voice_speed") ?? kDefaultVoiceSpeed);
  }

  void playOfflineSound() {
    AudioPlayer().playSound('conn', Prefs().stringForKey("voice_id") ?? kDefaultVoiceID, null,
        Prefs().doubleForKey("voice_speed") ?? kDefaultVoiceSpeed);
  }

  Future<bool> isConnectedToInternet() async {
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.none) == false;
  }

  // Set the status line above the text input bar
  void msg(String s) {
    if (mounted == false) {
      return;
    }
    setState(() {
      statusText = s.sentenceCapitalized();
    });
  }

  /// Hotword detection handling
  void hotwordHandler() {
    dlog("Hotword detected");
    start();
  }

  /// Attach our handlers to a freshly built session configuration
  void setSessionHandlers(AssistantSessionConfig cfg) {
    cfg.onStateChanged = handleStateChanged;
    cfg.onPartialTranscript = handlePartialTranscript;
    cfg.onFinalTranscript = handleFinalTranscript;
    cfg.onReply = handleReply;
    cfg.onToolActivity = handleToolActivity;
    cfg.onOpenURL = handleOpenURL;
    cfg.onDone = handleDone;
    cfg.onError = handleError;
  }

  /// Create a new session, with handlers attached, from current settings
  Future<bool> prepareSession() async {
    try {
      final AssistantSessionConfig cfg = await buildAssistantSessionConfig();
      if (mounted == false) {
        return false;
      }
      setSessionHandlers(cfg);
      config = cfg;
      session = AssistantSession(cfg);
      return true;
    } catch (e) {
      dlog('Error creating session: $e');
      handleError(e.toString());
      return false;
    }
  }

  // Clear the transcript status lines and set off the animation timer
  void startTicker() {
    if (mounted == false) {
      return;
    }
    setState(() {
      statusText = '';
      partialText = null;
      Waveform().setDefaultSamples();
      animationTimer?.cancel();
      animationTimer = Timer.periodic(durationPerFrame, (Timer t) => ticker());
    });
  }

  /// Start a voice session
  Future<void> start() async {
    if (session?.isActive() == true) {
      dlog('Session start called during active pre-existing session!');
      return;
    }

    // Make sure we have microphone permission
    if (await Permission.microphone.isGranted == false) {
      playNoMic();
      if (mounted && sessionContext != null) {
        showMicPermissionErrorAlert(sessionContext!);
      }
      return;
    }

    // Check for internet connectivity
    if (await isConnectedToInternet() == false) {
      playOfflineSound();
      msg(kNoInternetMessage);
      return;
    }

    // OK, the conditions are right, let's start the session.
    await HotwordDetector().stop();
    if (await prepareSession() == false) {
      return;
    }
    startTicker();

    try {
      await session!.startVoice();
    } catch (e) {
      dlog('Error starting session: $e');
      handleError(e.toString());
    }
  }

  /// Submit a typed command instead of speaking it
  Future<void> submitTyped(String text) async {
    if (text.trim().isEmpty) {
      return;
    }
    if (session?.isActive() == true) {
      dlog('Text submitted during active pre-existing session!');
      return;
    }

    // Check for internet connectivity
    if (await isConnectedToInternet() == false) {
      playOfflineSound();
      msg(kNoInternetMessage);
      return;
    }

    await HotwordDetector().stop();
    if (await prepareSession() == false) {
      return;
    }
    startTicker();

    try {
      await session!.submitText(text);
    } catch (e) {
      dlog('Error submitting text: $e');
      handleError(e.toString());
    }
  }

  // User cancelled ongoing session by pressing the button
  Future<void> cancel() async {
    dlog('User initiated cancellation of session');
    await session?.cancel();
    msg('');
  }

  // Session button pressed
  void toggle() async {
    if (session?.isActive() != true) {
      await start();
      return;
    }
    if (session!.state == AssistantState.listening && config?.asr.needsManualStop == true) {
      // Batch ASR engines need to be told when the user is done speaking
      await session!.finishListening();
      return;
    }
    await cancel();
  }

  /// Start a new conversation, clearing the transcript
  void newConversation() {
    dlog('Starting new conversation');
    Conversation.shared.reset();
    if (mounted == false) {
      return;
    }
    setState(() {
      statusText = '';
      partialText = null;
    });
  }

  // Ticker to animate session button
  void ticker() {
    if (mounted == false) {
      return;
    }
    final AssistantState? state = session?.state;
    if (state == null) {
      return;
    }
    if (state.showsWaveform) {
      setState(() {
        Waveform().addSample(AudioRecorder().signalStrength());
      });
    } else if (state.showsAnimation) {
      setState(() {
        currFrame += 1;
        if (currFrame >= animationFrames.length) {
          currFrame = 0; // Reset animation to first frame
        }
      });
    }
  }

  /// Assistant session handlers ///

  // Session moved to a new stage. Triggers a redraw of the session button.
  void handleStateChanged(AssistantState state) {
    dlog("Session state: $state");
    if (mounted == false) {
      return;
    }
    setState(() {});
  }

  // Interim ASR transcript, shown live above the text input bar
  void handlePartialTranscript(String partial) {
    if (mounted == false) {
      return;
    }
    setState(() {
      partialText = partial;
    });
  }

  // Final ASR transcript. The session adds it to the conversation and
  // plays the confirmation sound, so we only clear the live line.
  void handleFinalTranscript(String finalText) {
    if (mounted == false) {
      return;
    }
    setState(() {
      partialText = null;
    });
  }

  // The assistant's reply has been added to the conversation. The transcript
  // view listens to the conversation itself, we only scroll it into view.
  void handleReply(Turn reply) {
    if (mounted == false) {
      return;
    }
    scrollTranscriptToBottom();
  }

  // A tool started running. It is already shown in the transcript.
  void handleToolActivity(String label) {
    dlog("Tool activity: $label");
    if (mounted == false) {
      return;
    }
    scrollTranscriptToBottom();
  }

  // A tool asked us to open a URL
  void handleOpenURL(Uri url) {
    dlog("Opening URL $url");
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void scrollTranscriptToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted == false || transcriptScrollController.hasClients == false) {
        return;
      }
      transcriptScrollController.jumpTo(transcriptScrollController.position.maxScrollExtent);
    });
  }

  // Session error handler
  void handleError(String errMsg) async {
    final String errStr = kDebugMode ? errMsg : kServerErrorMessage;
    animationTimer?.cancel();
    if (mounted) {
      setState(() {
        partialText = null;
        currFrame = kFullLogoAnimationFrame;
        statusText = errStr.sentenceCapitalized();
      });
    }
    await resumeHotwordIfAppropriate();
  }

  // Session completion handler
  void handleDone() async {
    animationTimer?.cancel();
    if (mounted) {
      setState(() {
        partialText = null;
        currFrame = kFullLogoAnimationFrame;
      });
    }
    await resumeHotwordIfAppropriate();
  }

  /// The line shown above the text input bar: live transcript, if any,
  /// otherwise a status or error message.
  String? statusLine() {
    if (partialText != null && partialText!.trim().isNotEmpty) {
      return partialText!.sentenceCapitalized();
    }
    return statusText.isEmpty ? null : statusText;
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
      if (session?.isActive() == true) {
        await session!.cancel();
      }
      if (HotwordDetector().isActive()) {
        await HotwordDetector().stop();
      }
      await WakelockPlus.disable();
      if (!context.mounted) return;
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
        if (mounted) {
          setState(() {});
        }
        // Re-enable wakelock when returning to main route
        await WakelockPlus.enable();
        // Resume hotword detection (if enabled)
        await resumeHotwordIfAppropriate();
      });
    }

    // Handle tap on microphone icon to toggle hotword activation
    void toggleHotwordActivation() async {
      setState(() {
        final bool on = Prefs().boolForKey('hotword_activation');
        Prefs().setBoolForKey('hotword_activation', !on);
      });
      if (Prefs().boolForKey('hotword_activation')) {
        if (session?.isActive() != true) {
          await HotwordDetector().start(hotwordHandler);
        }
      } else {
        await HotwordDetector().stop();
      }
    }

    final String? status = statusLine();
    final bool sessionActive = session?.isActive() == true;

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
          // Conversation transcript
          Expanded(
              flex: 6,
              child: TranscriptView(
                  conversation: Conversation.shared,
                  emptyMessage: introMsg(),
                  scrollController: transcriptScrollController,
                  onNewConversation: newConversation)),
          // Status line (live transcript, offline or error message)
          if (status != null)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                child: SizedBox(
                    width: double.infinity, child: Text(status, style: kStatusTextStyle))),
          // Typed text input
          TextInputBar(
              controller: textController,
              enabled: sessionActive == false,
              onSubmit: submitTyped,
              onNewConversation: newConversation),
          // Session button widget
          Expanded(flex: 8, child: SessionButtonWidget(context, session, toggle)),
        ],
      ),
    );
  }
}
