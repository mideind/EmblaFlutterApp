/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2021 Miðeind ehf. <mideind@mideind.is>
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
import 'dart:math' show min, max;
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show launch;
import 'package:wakelock/wakelock.dart' show Wakelock;
import 'package:google_speech/generated/google/cloud/speech/v1/cloud_speech.pbenum.dart'
    show StreamingRecognizeResponse_SpeechEventType;
import './animations.dart' show animationFrames;
import './audio.dart' show AudioPlayer;
import './common.dart';
import './hotword.dart' show HotwordDetector;
import './menu.dart' show MenuRoute;
import './prefs.dart' show Prefs;
import './query.dart' show QueryService;
import './speech2text.dart' show SpeechRecognizer;
import './theme.dart';
import './util.dart';

// UI String constants
const kIntroMessage = 'Segðu „Hæ, Embla“ eða smelltu á hnappinn til þess að tala við Emblu.';
const kIntroNoHotwordMessage = 'Smelltu á hnappinn til þess að tala við Emblu.';
const kDunnoMessage = 'Það veit ég ekki.';
const kServerErrorMessage = 'Villa kom upp í samskiptum við netþjón.';
const kNoInternetMessage = 'Ekki næst samband við netið.';

// Global session state enum
enum SessionState {
  resting, // Session not active
  listening, // Receiving microphone input
  answering, // Communicating with server or playing back answer
}
// Current state
SessionState state = SessionState.resting;

// Waveform configuration
const int kWaveformNumBars = 12; // Number of waveform bars drawn
const double kWaveformBarMarginRatio = 0.22; // Spacing between waveform bars as proportion of width
const double kWaveformDefaultSampleLevel = 0.05; // Slightly above 0 looks better
const double kWaveformMinSampleLevel = 0.025; // Hard limit on lowest level
const double kWaveformMaxSampleLevel = 0.95; // Hard limit on highest level

// Animation framerate
const int msecPerFrame = (1000 ~/ 24);
// Logo animation status
const kFullLogoFrame = 99;
int currFrame = kFullLogoFrame;

// Session button size (proportional to width/height)
const kRestingButtonPropSize = 0.58;
const kExpandedButtonPropSize = 0.74;

// Samples (0.0-1.0) used for waveform animation
List<double> audioSamples = populateSamples();

List<double> populateSamples() {
  return new List.filled(kWaveformNumBars, kWaveformDefaultSampleLevel, growable: true);
}

void addSample(double level) {
  while (audioSamples.length >= kWaveformNumBars) {
    audioSamples.removeAt(0);
  }
  audioSamples.add(level < kWaveformDefaultSampleLevel ? kWaveformDefaultSampleLevel : level);
}

String introMsg() {
  return Prefs().boolForKey('hotword_activation') ? kIntroMessage : kIntroNoHotwordMessage;
}

// Main widget for session view
class SessionRoute extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => SessionRouteState();
}

class SessionRouteState extends State<SessionRoute> with TickerProviderStateMixin {
  Timer animationTimer;
  String text = introMsg();

  @override
  void initState() {
    super.initState();
    if (Prefs().boolForKey('hotword_activation') == true) {
      // HotwordDetector().purge();
      HotwordDetector().start(hotwordHandler, hotwordErrHandler);
    }
  }

  Future<bool> isConnectedToInternet() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return (connectivityResult != ConnectivityResult.none);
  }

  void hotwordHandler() {
    start();
  }

  void hotwordErrHandler(dynamic err) {
    dlog("Error starting hotword detection: $err");
  }

  void startSpeechRecognition() {
    List<String> transcripts = [];

    SpeechRecognizer().start(
        // Data handler
        (data) {
      if (state != SessionState.listening) {
        dlog('Received speech recognition results after session was terminated.');
        return;
      }

      // End of utterance event handling
      if (data.hasSpeechEventType()) {
        if (data.speechEventType ==
            StreamingRecognizeResponse_SpeechEventType.END_OF_SINGLE_UTTERANCE) {
          dlog('Received END_OF_SINGLE_UTTERANCE speech event.');
          stopSpeechRecognition();
        }
      }

      // Bail on empty result list
      if (data == null || data.results.length < 1) {
        dlog('Empty result from speech recognition');
        return;
      }

      setState(() {
        text = data.results.map((e) => e.alternatives.first.transcript).join('');
        dlog('RESULTS--------------');
        dlog(data.results);
        text = text.sentenceCapitalized();
        var first = data.results[0];
        if (first.isFinal) {
          dlog('Final result received');
          stopSpeechRecognition();
          for (var a in first.alternatives) {
            transcripts.add(a.transcript.toString());
          }
        }
      });
    },
        // Completion handler
        () {
      dlog('Stream done');
      stopSpeechRecognition();
      dlog('Transcripts: ' + transcripts.toString());
      if (transcripts.length != 0) {
        AudioPlayer().playSound('rec_confirm');
        answerQuery(transcripts);
      } else {
        dlog('Stream ended without answer');
        AudioPlayer().playSound('rec_cancel');
        setState(() {
          text = introMsg();
        });
        stop();
      }
    },
        // Error handler
        (var err) {
      dlog("Streaming recognition error: $err");
      setState(() {
        text = kServerErrorMessage;
      });
      stop();
      AudioPlayer().playSound('err');
    });
  }

  void stopSpeechRecognition() {
    SpeechRecognizer().stop();
  }

  // Ticker to animate session button
  void ticker() {
    setState(() {
      if (state == SessionState.listening) {
        addSample(SpeechRecognizer().lastSignal);
      } else if (state == SessionState.answering) {
        currFrame += 1;
        if (currFrame >= animationFrames.length) {
          currFrame = 0; // Reset animation
        }
      }
    });
  }

  void answerQuery(List<String> alternatives) {
    dlog("Answering query: " + alternatives.toString());
    // Transition to answering state
    state = SessionState.answering;
    currFrame = kFullLogoFrame;

    // Send text to query server
    QueryService.sendQuery(alternatives, handleQueryResponse);
  }

  // Process response from query server
  void handleQueryResponse(Map resp) async {
    if (state != SessionState.answering) {
      dlog("Received query answer after session terminated: ${resp.toString()}");
      return;
    }

    // Received valid response to query
    if (resp != null &&
        resp['valid'] == true &&
        resp['error'] == null &&
        resp['answer'] != null &&
        resp['audio'] != null) {
      dlog('Received valid response to query');
      // Update text
      setState(() {
        text = "${resp["q"]}\n\n${resp["answer"]}".periodTerminated();
        if (resp["source"] != null) {
          text = "$text (${resp['source']})";
        }
      });
      // Play audio answer and then terminate session
      await AudioPlayer().playURL(resp['audio'], (bool err) {
        if (err == true) {
          dlog('Error during audio playback');
          AudioPlayer().playSound('err');
          setState(() {
            text = kServerErrorMessage;
          });
        } else {
          dlog('Playback finished');
        }
        stop();
      });
      // Open URL, if provided in query answer
      if (resp['open_url'] != null) {
        launch(resp['open_url']);
      }
    }
    // Don't know
    else if (resp['error'] != null) {
      setState(() {
        text = kDunnoMessage;
      });
      AudioPlayer().playSound('dunno', () {
        dlog('Playback finished');
        stop();
      });
    }
    // Error in server response
    else {
      stop();
      setState(() {
        text = kServerErrorMessage;
      });
      AudioPlayer().playSound('err');
    }
  }

  // Start session
  void start() async {
    if (state != SessionState.resting) {
      dlog('Session start called during pre-existing session!');
      return;
    }
    dlog('Starting session');

    if (await SpeechRecognizer().canRecognizeSpeech() == false) {
      AudioPlayer().playSound('rec_cancel');
      showRecognitionErrorAlert(context);
      return;
    }

    // Check for internet connectivity
    if (await isConnectedToInternet() == false) {
      text = kNoInternetMessage;
      AudioPlayer().playSound('conn');
      return;
    }

    HotwordDetector().stop();

    AudioPlayer().playSound('rec_begin');

    // Set off animation timer
    setState(() {
      state = SessionState.listening;
      text = '';
      audioSamples = populateSamples();
      animationTimer?.cancel();
      animationTimer =
          new Timer.periodic(Duration(milliseconds: msecPerFrame), (Timer t) => ticker());
    });

    // Start recognizing speech from microphone input
    try {
      // await Future.delayed(Duration(milliseconds: 350), () {
      startSpeechRecognition();
      // });
    } catch (e) {
      stop();
      AudioPlayer().playSound('conn');
    }
  }

  // End session, reset state
  void stop() {
    if (state == SessionState.resting) {
      return;
    }
    dlog('Stopping session');
    stopSpeechRecognition();
    AudioPlayer().stop();
    animationTimer?.cancel();

    setState(() {
      state = SessionState.resting;
      currFrame = kFullLogoFrame;
    });

    if (Prefs().boolForKey('hotword_activation') == true) {
      HotwordDetector().start(hotwordHandler, hotwordErrHandler);
    }
  }

  // User cancelled ongoing session by pressing button
  void cancel() {
    dlog('User initiated cancellation of session');
    stop();
    AudioPlayer().playSound('rec_cancel');
    setState(() {
      text = introMsg();
    });
  }

  // Button pressed
  void toggle() async {
    if (state == SessionState.resting) {
      start();
    }
    // We are in an active session state
    else {
      cancel();
    }
  }

  void showRecognitionErrorAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: new Text('Villa í talgreiningu'),
          content: new Text(
              'Ekki tókst að hefja talgreiningu. Emblu vantar heimild til að nota hljóðnema.'),
          actions: <Widget>[
            new TextButton(
              child: new Text('Allt í lagi'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Session button size depends on whether session is active
    double prop =
        (state == SessionState.resting) ? kRestingButtonPropSize : kExpandedButtonPropSize;
    double buttonSize = MediaQuery.of(context).size.width * prop;
    String hotwordIcon = Prefs().boolForKey('hotword_activation') ? 'mic.png' : 'mic-slash.png';

    // Present menu route
    void pushMenu() {
      stop(); // Terminate any ongoing session
      Wakelock.disable();
      HotwordDetector().stop();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MenuRoute(), // Push menu route
        ),
      ).then((val) {
        // Make sure we rebuild main route when menu route is popped in navigation
        // stack. This ensures that the state of the voice activation button is
        // updated to reflect potential changes in Settings and more.
        if (text == '') {
          setState(() {
            text = introMsg();
          });
        }
        // Re-enable wake lock when returning to main route
        Wakelock.enable();
        // Re-enable hotword detection (if enabled)
        if (Prefs().boolForKey('hotword_activation') == true) {
          HotwordDetector().start(hotwordHandler, hotwordErrHandler);
        }
      });
    }

    // Enable/disable hotword activation
    void toggleHotwordActivation() {
      var p = Prefs();
      p.setBoolForKey('hotword_activation', !p.boolForKey('hotword_activation'));
      if (state == SessionState.resting) {
        setState(() {
          text = introMsg();
        });
      }
      if (p.boolForKey('hotword_activation') == true) {
        HotwordDetector().start(hotwordHandler, hotwordErrHandler);
      } else {
        HotwordDetector().stop();
      }
    }

    return Scaffold(
      // Top nav bar
      appBar: AppBar(
          backgroundColor: bgColor,
          bottomOpacity: 0.0,
          elevation: 0.0,
          // Toggle hotword activation button
          leading: IconButton(
            icon: ImageIcon(AssetImage('assets/images/' + hotwordIcon)),
            onPressed: toggleHotwordActivation,
          ),
          // Hamburger menu button
          actions: <Widget>[
            IconButton(icon: ImageIcon(AssetImage('assets/images/menu.png')), onPressed: pushMenu)
          ]),
      // Main view contents
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          // Session text widget
          Expanded(
              flex: 6,
              child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Padding(
                      padding: EdgeInsets.only(left: 20, right: 20, top: 10),
                      child: FractionallySizedBox(
                          widthFactor: 1.0, child: Text(text, style: sessionTextStyle))))),
          // Session button widget
          Expanded(
              flex: 6,
              child: Padding(
                  padding: EdgeInsets.only(bottom: 20, top: 20),
                  child: Center(
                      child: GestureDetector(
                          onTap: toggle,
                          child: new SizedBox(
                            width: buttonSize,
                            height: buttonSize,
                            child: CustomPaint(painter: SessionButtonPainter()),
                          ))))),
        ],
      ),
    );
  }
}

// This is the drawing code for the session button
class SessionButtonPainter extends CustomPainter {
  // Draw the three circles that make up the button
  void drawCircles(Canvas canvas, Size size) {
    final radius = min(size.width, size.height) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    // First, outermost, circle
    var paint = Paint()..color = circleColor1;
    canvas.drawCircle(center, radius, paint);

    // Second circle
    paint = Paint()..color = circleColor2;
    canvas.drawCircle(center, radius / 1.25, paint);

    // Third, innermost, circle
    paint = Paint()..color = circleColor3;
    canvas.drawCircle(center, radius / 1.75, paint);
  }

  // Draw current logo animation frame
  void drawFrame(Canvas canvas, Size size, int fnum) {
    if (animationFrames.length == 0) {
      dlog('Animation frame drawing failed. No frames loaded.');
    }
    ui.Image img = animationFrames[fnum];
    // Source image rect
    Rect srcRect = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());

    // Destination rect centered in canvas
    double sw = size.width.toDouble();
    double sh = size.height.toDouble();
    double prop = 2.4;
    double w = sw / prop;
    double h = sh / prop;
    Rect dstRect = Rect.fromLTWH(
        (sw / 2) - (w / 2), // x
        (sh / 2) - (h / 2), // y
        w, // width
        h); // height
    canvas.drawImageRect(img, srcRect, dstRect, Paint());
  }

  // Draw audio waveform
  void drawWaveform(Canvas canvas, Size size) {
    // Generate square frame to contain waveform
    double w = size.width / 2.0;
    double xOffset = (size.width - w) / 2;
    double yOffset = (size.height - w) / 2;
    Rect frame = Rect.fromLTWH(xOffset, yOffset, w, w);

    double margin = (size.width * kWaveformBarMarginRatio) / (kWaveformNumBars - 1);
    double totalMarginWidth = (kWaveformNumBars * margin) - margin;

    double barWidth = (frame.width - totalMarginWidth) / kWaveformNumBars;
    double barHeight = frame.height / 2;
    double centerY = (frame.height / 2);

    // Colors for the top and bottom waveform bars
    var topPaint = Paint()..color = mainColor;
    var bottomPaint = Paint()..color = HexColor.fromHex('#f2918f');

    // Draw audio waveform bars based on audio sample levels
    for (int i = 0; i < audioSamples.length; i++) {
      // Clamp signal level
      double level = min(max(kWaveformMinSampleLevel, audioSamples[i]), kWaveformMaxSampleLevel);

      // Draw top bar
      Rect topRect = new Rect.fromLTWH(
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
      Rect bottomRect = new Rect.fromLTWH(
          i * (barWidth + margin) + (margin / 2) + xOffset, // x
          centerY + yOffset, // y
          barWidth, // width
          level * barHeight); // height
      canvas.drawRect(bottomRect, bottomPaint);

      // Draw circle at end of bar
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
    if (state == SessionState.listening) {
      drawWaveform(canvas, size);
    }
    // Draw logo animation during answering phase
    else if (state == SessionState.answering) {
      drawFrame(canvas, size, currFrame);
    }
    // Otherwise, draw non-animated Embla logo
    else {
      drawFrame(canvas, size, kFullLogoFrame); // Always same frame
    }
  }

  @override
  bool shouldRepaint(SessionButtonPainter oldDelegate) {
    return true;
  }
}
