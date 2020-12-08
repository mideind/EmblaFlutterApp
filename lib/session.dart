/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020 Miðeind ehf. <mideind@mideind.is>
 * Author: Sveinbjorn Thordarson
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
import 'dart:ui' as ui;
import 'dart:math' show Random, min, max, pow;
import 'dart:typed_data';

import 'package:dart_numerics/dart_numerics.dart' show log10;
import 'package:flutter/material.dart';
import 'package:google_speech/google_speech.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sound_stream/sound_stream.dart';

import './anim.dart' show animationFrames;
import './audio.dart' show playSound, stopSound, playURL;
//import './connectivity.dart' show ConnectivityMonitor;
import './prefs.dart' show Prefs;
import './query.dart' show QueryService;
import './theme.dart';
import './util.dart';
import './common.dart';

// String constants
const kIntroMessage = 'Segðu „Hæ, Embla“ eða smelltu á hnappinn til þess að tala við Emblu.';
const kIntroNoHotwordMessage = 'Smelltu á hnappinn til þess að tala við Emblu.';

// Global session state enum
enum SessionState {
  resting, // No active session
  listening, // Receiving microphone input
  answering, // Communicating with server and playing back answer
}

SessionState state = SessionState.resting;

// Speech recognition config
RecognitionConfig speechRecognitionConfig = RecognitionConfig(
    encoding: AudioEncoding.LINEAR16,
    model: RecognitionModel.command_and_search,
    enableAutomaticPunctuation: true,
    sampleRateHertz: 16000,
    languageCode: 'is-IS');

// Waveform configuration
const int kWaveformNumBars = 15; // Number of waveform bars drawn
const double kWaveformBarSpacing = 4.0; // Fixed spacing between bars. TODO: Fix this!
const double kWaveformDefaultSampleLevel = 0.05; // Slightly above 0 looks better
const double kWaveformMinSampleLevel = 0.025; // Hard limit on lowest level
const double kWaveformMaxSampleLevel = 0.95; // Hard limit on highest level

// Session button size (proportional to width/height)
const kRestingButtonProp = 0.62;
const kExpandedButtonProp = 0.77;

List<double> audioSamples = populateSamples();

List<double> populateSamples() {
  return new List.filled(kWaveformNumBars, kWaveformDefaultSampleLevel, growable: true);
}

void addSample(double level) {
  while (audioSamples.length >= kWaveformNumBars) {
    audioSamples.removeAt(0);
  }
  audioSamples.add(level);
}

String introMsg() {
  return Prefs().boolForKey('hotword_activation') ? kIntroMessage : kIntroNoHotwordMessage;
}

// Logo animation
int currFrame = 0;
const kFullLogoFrame = 99;

class SessionWidget extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _SessionWidgetState();
}

class _SessionWidgetState extends State<SessionWidget> with TickerProviderStateMixin {
  Timer animationTimer;
  final RecorderStream _recorder = RecorderStream();
  String text = introMsg();
  StreamSubscription<List<int>> _audioStreamSubscription;
  BehaviorSubject<List<int>> _audioStream;
  double lastSignal = 0;

  @override
  void initState() {
    super.initState();
    _recorder.initialize(sampleRate: 16000);
  }

  double _normalizedPowerLevelFromDecibels(double decibels) {
    if (decibels < -60.0 || decibels == 0.0) {
      return 0.0;
    }
    double exp = 0.05;
    return pow(
        (pow(10.0, exp * decibels) - pow(10.0, exp * -60.0)) *
            (1.0 / (1.0 - pow(10.0, exp * -60.0))),
        1.0 / 2.0);
  }

  double doubleInRange(double start, double end) {
    return Random().nextDouble() * (end - start) + start;
  }

  void addSignalForAudioBuffer(Int16List samples) {
    int max = 0;
    for (var i = 0; i < samples.length; i++) {
      max = (samples[i] > max) ? samples[i] : max;
    }
    //print(total / samples.length);

    double ampl = max / 32767.0;
    print(ampl);
    double decibels = 20.0 * log10(ampl);
    print(decibels);
    //addSample(lastSignal);

    lastSignal = ampl;

    lastSignal = _normalizedPowerLevelFromDecibels(decibels);
    // print(lastSignal);

    // addSample(lastSignal);
    // double rand = doubleInRange(-0.05, 0.05);
    // addSample(lastSignal + rand);
  }

  void startSpeechRecognition() async {
    dlog("Starting speech recognition");
    _audioStream = BehaviorSubject<List<int>>();
    _audioStreamSubscription = _recorder.audioStream.listen((data) {
      _audioStream.add(data);

      ByteBuffer bytes = data.buffer;
      Int16List samples = bytes.asInt16List();
      print("Num samples: " + samples.length.toString());

      // Int16List first = samples.sublist(0, (samples.length ~/ 2));
      // Int16List second = samples.sublist(first.length, samples.length);

      // addSignalForAudioBuffer(first);
      // addSignalForAudioBuffer(second);

      addSignalForAudioBuffer(samples);
    });

    await _recorder.start();

    final serviceAccount = ServiceAccount.fromString(await readGoogleServiceAccount());
    final speechToText = SpeechToText.viaServiceAccount(serviceAccount);
    final Stream responseStream = speechToText.streamingRecognize(
        StreamingRecognitionConfig(config: speechRecognitionConfig, interimResults: true),
        _audioStream);

    responseStream.listen((data) {
      setState(() {
        text = data.results.map((e) => e.alternatives.first.transcript).join('');
        dlog("RESULTS--------------");
        dlog(data.results.toString());
        if (data.results.length < 1) {
          return;
        }
        text = text.sentenceCapitalized();
        var first = data.results[0];
        if (first.isFinal) {
          dlog("Final result received, stopping recording");
          stopSpeechRecognition();
          handleFinal(first);
        }
      });
    }, onDone: () {
      dlog("Stream done");
      stopSpeechRecognition();
    });
  }

  void stopSpeechRecognition() async {
    dlog("Stopping speech recognition");
    await _recorder.stop();
    await _audioStreamSubscription?.cancel();
    await _audioStream?.close();
  }

  // Animation timer ticker to refresh button view
  void ticker() {
    setState(() {
      if (state == SessionState.listening) {
        addSample(lastSignal);
        double rand = doubleInRange(-0.05, 0.05);
        addSample(lastSignal + rand);
      } else if (state == SessionState.answering) {
        currFrame += 1;
        if (currFrame >= animationFrames.length) {
          currFrame = 0; // Reset animation
        }
      }
    });
  }

  Future<void> handleFinal(var finalResult) async {
    state = SessionState.answering;
    String res = finalResult.alternatives.first.transcript;
    QueryService.sendQuery([res], (Map resp) async {
      if (state != SessionState.answering) {
        dlog('Received query answer after session terminated: ' + resp.toString());
        return;
      }

      if (resp["valid"] == true && resp["error"] == null) {
        dlog("Received valid response to query");
        setState(() {
          text = resp["answer"];
        });
        await playURL(resp['audio'], (err) {
          if (err) {
            dlog('Error during audio playback');
            playSound('err');
          } else {
            dlog("Playback finished");
          }
          stop();
          state = SessionState.resting;
        });
      } else {
        setState(() {
          text = 'Það veit ég ekki.';
          playSound('dunno', (err) {
            dlog("Playback finished");
            stop();
            state = SessionState.resting;
          });
        });
      }
    });
  }

  // Start session
  void start() {
    if (state != SessionState.resting) {
      dlog('Session start called during pre-existing session!');
      return;
    }
    // Check for internet connectivity
    // if (!ConnectivityMonitor().connected) {
    //   playSound('conn');
    //   return;
    // }
    playSound('rec_begin');

    setState(() {
      text = '';
      int msecPerFrame = (1000 ~/ 24); // Framerate
      animationTimer =
          new Timer.periodic(Duration(milliseconds: msecPerFrame), (Timer t) => ticker());
      state = SessionState.listening;
      audioSamples = populateSamples();
    });

    startSpeechRecognition();
  }

  // End session
  void stop() {
    stopSpeechRecognition();

    setState(() {
      stopSound();
      animationTimer.cancel();
      state = SessionState.resting;
      currFrame = 0;
    });
  }

  // User cancelled ongoing session
  void cancel() {
    stop();
    playSound('rec_cancel');
    text = introMsg();
  }

  // Button pressed
  void toggle() {
    if (state == SessionState.resting) {
      start();
    } else {
      cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    double prop = (state == SessionState.resting) ? kRestingButtonProp : kExpandedButtonProp;
    double buttonSize = MediaQuery.of(context).size.width * prop;

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Expanded(
              flex: 6,
              child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Padding(
                      padding: EdgeInsets.only(left: 20, right: 20),
                      child: FractionallySizedBox(
                          widthFactor: 1.0, child: Text(text, style: sessionTextStyle))))),
          Expanded(
              flex: 6,
              child: Padding(
                  padding: EdgeInsets.only(bottom: 20, top: 20),
                  child: Center(
                      child: GestureDetector(
                          onTap: toggle,
                          child: AnimatedSize(
                              curve: Curves.linear,
                              duration: Duration(milliseconds: 1),
                              vsync: this,
                              alignment: Alignment.center,
                              child: new SizedBox(
                                width: buttonSize,
                                height: buttonSize,
                                child: CustomPaint(painter: SessionButtonPainter()),
                              )))))),
        ],
      ),
    );
  }
}

// This is the drawing code for the session button
class SessionButtonPainter extends CustomPainter {
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

  void drawFrame(Canvas canvas, Size size, int fnum) {
    if (animationFrames.length == 0) {
      dlog("Animation frame loading fail. No frames loaded.");
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

  void drawWaveform(Canvas canvas, Size size) {
    // Generate square frame to contain waveform
    double w = size.width / 2.0;
    double xOffset = (size.width - w) / 2;
    double yOffset = (size.height - w) / 2;
    Rect frame = Rect.fromLTWH(xOffset, yOffset, w, w);

    double margin = kWaveformBarSpacing;
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
  void paint(Canvas canvas, Size size) async {
    // We always draw the circles
    drawCircles(canvas, size);

    // Draw non-animated Embla logo
    if (state == SessionState.resting) {
      drawFrame(canvas, size, kFullLogoFrame); // Always same frame
    }
    // Draw waveform bars during microphone input
    else if (state == SessionState.listening) {
      drawWaveform(canvas, size);
    }
    // Draw logo animation during query-answering phase
    else if (state == SessionState.answering) {
      drawFrame(canvas, size, currFrame);
    }
  }

  @override
  bool shouldRepaint(SessionButtonPainter oldDelegate) {
    return true;
  }
}
