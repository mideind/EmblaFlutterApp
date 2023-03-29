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

/// Session button implementation.

import 'dart:math' show min, max;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:embla_core/embla_core.dart';

import './common.dart';
import './theme.dart';
import './animations.dart' show animationFrames;

// Waveform configuration
const int kWaveformNumBars = 12; // Number of waveform bars drawn
const double kWaveformBarMarginRatio = 0.22; // Spacing between bars as proportion of width
const double kWaveformDefaultSampleLevel = 0.05; // Slightly above 0 looks better
const double kWaveformMinSampleLevel = 0.025; // Hard limit on lowest level
const double kWaveformMaxSampleLevel = 0.95; // Hard limit on highest level

// Logo animation status
const kFullLogoFrame = 99;
int currFrame = kFullLogoFrame;

// Session button size (proportional to width/height)
const kRestingButtonPropSize = 0.58;

// Expanded size (proportional to original size)
const kExpandedButtonPropSize = 1.20;

// Animation durations
const Duration kButtonZoomAnimationDuration = Duration(milliseconds: 100);

// Session button accessibility labels
const kRestingButtonLabel = 'Tala við Emblu';
const kExpandedButtonLabel = 'Hætta að tala við Emblu';

/// Singleton class for storing waveform samples.
class Waveform {
  List<double> samples = [];

  // Constructor, only called once, when singleton is instantiated
  static final Waveform _instance = Waveform._constructor();
  Waveform._constructor() {
    setDefaultSamples();
  }

  factory Waveform() {
    return _instance;
  }

  void setDefaultSamples() {
    samples = List.filled(kWaveformNumBars, kWaveformDefaultSampleLevel, growable: true);
  }

  void addSample(double level) {
    while (samples.length >= kWaveformNumBars) {
      samples.removeAt(0);
    }
    samples.add(level < kWaveformDefaultSampleLevel ? kWaveformDefaultSampleLevel : level);
  }
}

/// Widget for the session button
class SessionButtonWidget extends StatelessWidget {
  late final BuildContext context;
  late final EmblaSession session;
  late final void Function() onTap;

  SessionButtonWidget(this.context, this.session, this.onTap, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool active = session.isActive();
    final double buttonSize = MediaQuery.of(context).size.width * kRestingButtonPropSize;
    final String buttonLabel = active ? kRestingButtonLabel : kExpandedButtonLabel;

    return Padding(
        padding: const EdgeInsets.only(bottom: 30, top: 30),
        child: Center(
            child: Semantics(
                label: buttonLabel,
                child: GestureDetector(
                    onTap: onTap,
                    child: SizedBox(
                      width: buttonSize,
                      height: buttonSize,
                      // Uses custom painter to draw the button
                      child: CustomPaint(painter: SessionButtonPainter(context, session))
                          .animate(target: active ? 1 : 0)
                          .scaleXY(
                              end: kExpandedButtonPropSize, duration: kButtonZoomAnimationDuration),
                    )))));
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

    final List<Color> circleColors = circleColors4Context(context);

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
    var audioSamples = Waveform().samples;
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
    for (int i = 0; i < Waveform().samples.length; i++) {
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
