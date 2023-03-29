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

/// Session button widget

/// // Waveform configuration
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

class Waveform {
  static List<double> samples = [];

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

class SessionButton {}
