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

// Global state
const kRestingSessionState = 0;
const kListeningSessionState = 1;
const kAnsweringSessionState = 2;

var state = kRestingSessionState;

// Waveform configuration
const kWaveformNumBars = 15;
const kWaveformBarSpacing = 4.0;
const kWaveformDefaultSampleLevel = 0.05; // A hard lower limit above 0 looks better
const kWaveformDefaultVariation = 0.025; // Variation range for bars when reset
const kWaveformMinSampleLevel = 0.025; // Hard limit on lowest level
const kWaveformMaxSampleLevel = 0.95; // Hard limit on highest level

final List audioSamples = <double>[
  0.025,
  0.5,
  0.3,
  0.2,
  1.0,
  0.7,
  0.025,
  0.5,
  0.3,
  0.2,
  1.0,
  0.7,
  0.025,
  0.5,
  0.3
];

// Logo animation
int currFrame = 0;
const kRestFrame = 99;

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

    void updateAnim() {
      setState(() {
        audioSamples.removeAt(0);
        audioSamples.add(Random().nextDouble());
        currFrame += 1;
        if (currFrame > 99) {
          currFrame = 0;
        }
      });
    }

    void stop() {
      setState(() {
        stopSound();
        timer.cancel();
        state = kRestingSessionState;
        currFrame = 0;
      });
    }

    void cancel() {
      stop();
      playSound('rec_cancel');
    }

    void start() {
      setState(() {
        playSound('rec_begin');
        timer = new Timer.periodic(Duration(milliseconds: (1000 ~/ 24)), (Timer t) => updateAnim());
        state = kListeningSessionState;
      });
    }

    void toggle() {
      if (state == kRestingSessionState) {
        start();
      } else {
        cancel();
      }
    }

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
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

/* This is the drawing code for the session button. */
class SessionButtonPainter extends CustomPainter {
  // Outermost to innermost
  final circleColor1 = HexColor.fromHex("#F9F0F0");
  final circleColor2 = HexColor.fromHex("#F9E2E1");
  final circleColor3 = HexColor.fromHex("#F9DCDB");

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
    ui.Image img = animationFrames[fnum];
    // Source image rect
    Rect srcRect = const Offset(0, 0) & Size(img.width.toDouble(), img.height.toDouble());
    // Destination rect centered in canvas
    double w = size.width.toDouble() / 2.5;
    double h = size.height.toDouble() / 2.5;
    Rect dstRect =
        Offset((size.width.toDouble() / 2) - (w / 2), (size.height.toDouble() / 2) - (h / 2)) &
            Size(w, h);
    canvas.drawImageRect(img, srcRect, dstRect, Paint());
  }

  void drawWaveform(Canvas canvas, Size size) {
    // Generate square frame to contain waveform
    double w = size.width / 1.95;
    double xOffset = (size.width - w) / 2;
    double yOffset = (size.height - w) / 2;
    Rect frame = Rect.fromLTWH(xOffset, yOffset, w, w);

    double margin = kWaveformBarSpacing;
    double totalMarginWidth = kWaveformNumBars * margin;

    double barWidth = (frame.width - totalMarginWidth) / kWaveformNumBars;
    double barHeight = frame.height / 2;
    double centerY = (frame.height / 2);

    var topPaint = Paint()..color = HexColor.fromHex('#e83939');
    var bottomPaint = Paint()..color = HexColor.fromHex('#f2918f');

    for (int i = 0; i < audioSamples.length; i++) {
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
    drawCircles(canvas, size);

    // Draw non-animated Embla logo
    if (state == kRestingSessionState) {
      drawFrame(canvas, size, kRestFrame);
    }
    // Draw waveform bars during microphone input
    else if (state == kListeningSessionState) {
      drawWaveform(canvas, size);
    }
    // Draw logo animation during query-answering phase
    else if (state == kListeningSessionState) {
      drawFrame(canvas, size, currFrame);
    }
  }

  @override
  bool shouldRepaint(SessionButtonPainter oldDelegate) {
    return true;
  }
}
