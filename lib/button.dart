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

final List<double> audioSamples = populateSamples();

List<double> populateSamples() {
  return new List.filled(kWaveformNumBars, kWaveformDefaultSampleLevel, growable: true);
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
        audioSamples = populateSamples();
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

    if (state == kRestingSessionState) {
      // Draw non-animated Embla logo
      drawFrame(canvas, size, kFullLogoFrame); // Always same frame
    } else if (state == kListeningSessionState) {
      // Draw waveform bars during microphone input
      drawWaveform(canvas, size);
    } else if (state == kListeningSessionState) {
      // Draw logo animation during query-answering phase
      drawFrame(canvas, size, currFrame);
    }
  }

  @override
  bool shouldRepaint(SessionButtonPainter oldDelegate) {
    return true;
  }
}
