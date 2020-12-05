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

// Singleton wrapper class for speech recognition

import 'package:flutter/services.dart' show rootBundle;
import 'package:google_speech/google_speech.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sound_stream/sound_stream.dart';

import './common.dart';

// Speech recognition config
RecognitionConfig speechRecognitionConfig = RecognitionConfig(
    encoding: AudioEncoding.LINEAR16,
    model: RecognitionModel.command_and_search,
    enableAutomaticPunctuation: true,
    sampleRateHertz: 16000,
    languageCode: 'is-IS');

class SpeechRecognizer {
  SpeechRecognizer._privateConstructor();
  static final SpeechRecognizer _instance = SpeechRecognizer._privateConstructor();
  factory SpeechRecognizer() {
    return _instance;
  }
}
