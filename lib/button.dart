/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020 Miðeind ehf.
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

import 'dart:math';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import './util.dart';
import './anim.dart' show animationFrames;
import './audio.dart' show playSound, stopSound;
import './connectivity.dart' show ConnectivityMonitor;

// Global state
const kRestingSessionState = 0; // No active session
const kListeningSessionState = 1; // Receiving microphone input
const kAnsweringSessionState = 2; // Communicating with server and playing back answer

var state = kRestingSessionState;

// Waveform configuration
const kWaveformNumBars = 15; // Number of waveform bars drawn
const kWaveformBarSpacing = 4.0; // Fixed spacing between bars. TODO: Fix this!
const kWaveformDefaultSampleLevel = 0.05; // Slightly above 0 looks better
const kWaveformMinSampleLevel = 0.025; // Hard limit on lowest level
const kWaveformMaxSampleLevel = 0.95; // Hard limit on highest level

List<double> audioSamples = populateSamples();

List<double> populateSamples() {
  return new List.filled(kWaveformNumBars, kWaveformDefaultSampleLevel, growable: true);
}

void addSample(double level) {
  while (audioSamples.length > kWaveformNumBars) {
    audioSamples.removeAt(0);
  }
  audioSamples.add(level);
}

// Logo animation
int currFrame = 0;
const kFullLogoFrame = 99;

class SessionWidget extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _SessionWidgetState();
}

class _SessionWidgetState extends State<SessionWidget> with TickerProviderStateMixin {
  Timer timer;

  @override
  Widget build(BuildContext context) {
    double prop = (state == kRestingSessionState) ? 0.6 : 0.75;
    double buttonSize = MediaQuery.of(context).size.width * prop;

    // Timer ticker to refresh button view
    void ticker() {
      setState(() {
        addSample(Random().nextDouble());
        currFrame += 1;
        if (currFrame > 99) {
          currFrame = 0;
        }
      });
    }

    // Start session
    void start() {
      // Check for internet connectivity
      if (!ConnectivityMonitor().connected) {
        playSound('conn');
        return;
      }
      playSound('rec_begin');
      setState(() {
        int msecPerFrame = (1000 ~/ 24); // Framerate
        timer = new Timer.periodic(Duration(milliseconds: msecPerFrame), (Timer t) => ticker());
        state = kListeningSessionState;
        audioSamples = populateSamples();
      });
    }

    // End session
    void stop() {
      setState(() {
        stopSound();
        timer.cancel();
        state = kRestingSessionState;
        currFrame = 0;
      });
    }

    // User cancelled ongoing session
    void cancel() {
      playSound('rec_cancel');
      stop();
    }

    // Button pressed
    void toggle() {
      if (state == kRestingSessionState) {
        start();
      } else {
        cancel();
      }
    }

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Text("Hello, world!"),
          Center(
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
                      )))),
        ],
      ),
    );
  }
}

// This is the drawing code for the session button
class SessionButtonPainter extends CustomPainter {
  void drawCircles(Canvas canvas, Size size) {
    // Outermost to innermost
    final circleColor1 = HexColor.fromHex("#f9f0f0");
    final circleColor2 = HexColor.fromHex("#f9e2e1");
    final circleColor3 = HexColor.fromHex("#f9dcdb");

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
    ui.Image img = animationFrames[fnum];
    // Source image rect
    Rect srcRect = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    // Destination rect centered in canvas
    double w = size.width.toDouble() / 2.4;
    double h = size.height.toDouble() / 2.4;
    Rect dstRect = Rect.fromLTWH(
        (size.width.toDouble() / 2) - (w / 2), // x
        (size.height.toDouble() / 2) - (h / 2), // y
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
    var topPaint = Paint()..color = HexColor.fromHex('#e83939');
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
    if (state == kRestingSessionState) {
      drawFrame(canvas, size, kFullLogoFrame); // Always same frame
    }
    // Draw waveform bars during microphone input
    else if (state == kListeningSessionState) {
      drawWaveform(canvas, size);
    }
    // Draw logo animation during query-answering phase
    else if (state == kAnsweringSessionState) {
      drawFrame(canvas, size, currFrame);
    }
  }

  @override
  bool shouldRepaint(SessionButtonPainter oldDelegate) {
    return true;
  }
}
