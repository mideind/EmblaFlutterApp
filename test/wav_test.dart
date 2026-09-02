/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2026 Miðeind ehf. <mideind@mideind.is>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

// Tests for the RIFF/WAVE header builder.

import 'dart:convert' show ascii;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:embla/asr/wav.dart';

String tag(Uint8List wav, int offset) => ascii.decode(wav.sublist(offset, offset + 4));

void main() {
  final Uint8List pcm = Uint8List.fromList(List<int>.generate(320, (int i) => i % 256));

  group('wavFromPcm16', () {
    test('has a 44-byte header followed by the payload', () {
      final Uint8List wav = wavFromPcm16(pcm);
      expect(kWavHeaderSize, 44);
      expect(wav.lengthInBytes, 44 + pcm.lengthInBytes);
      expect(wav.sublist(44), pcm);
    });

    test('writes the RIFF chunk descriptor', () {
      final Uint8List wav = wavFromPcm16(pcm);
      final ByteData h = ByteData.sublistView(wav);
      expect(tag(wav, 0), 'RIFF');
      expect(h.getUint32(4, Endian.little), 36 + pcm.lengthInBytes);
      expect(tag(wav, 8), 'WAVE');
    });

    test('writes a 16-byte linear PCM fmt chunk', () {
      final Uint8List wav = wavFromPcm16(pcm);
      final ByteData h = ByteData.sublistView(wav);
      expect(tag(wav, 12), 'fmt ');
      expect(h.getUint32(16, Endian.little), 16); // fmt chunk size
      expect(h.getUint16(20, Endian.little), 1); // audio format: PCM
      expect(h.getUint16(34, Endian.little), 16); // bits per sample
    });

    test('defaults to 16 kHz mono', () {
      final Uint8List wav = wavFromPcm16(pcm);
      final ByteData h = ByteData.sublistView(wav);
      expect(h.getUint16(22, Endian.little), 1); // channels
      expect(h.getUint32(24, Endian.little), 16000); // sample rate
      expect(h.getUint32(28, Endian.little), 32000); // byte rate
      expect(h.getUint16(32, Endian.little), 2); // block align
    });

    test('derives byte rate and block align from rate and channels', () {
      final Uint8List wav = wavFromPcm16(pcm, sampleRate: 8000, channels: 2);
      final ByteData h = ByteData.sublistView(wav);
      expect(h.getUint16(22, Endian.little), 2); // channels
      expect(h.getUint32(24, Endian.little), 8000); // sample rate
      expect(h.getUint32(28, Endian.little), 8000 * 2 * 2); // byte rate
      expect(h.getUint16(32, Endian.little), 4); // block align
    });

    test('writes the data chunk size', () {
      final Uint8List wav = wavFromPcm16(pcm);
      final ByteData h = ByteData.sublistView(wav);
      expect(tag(wav, 36), 'data');
      expect(h.getUint32(40, Endian.little), pcm.lengthInBytes);
    });

    test('handles empty audio', () {
      final Uint8List wav = wavFromPcm16(Uint8List(0));
      final ByteData h = ByteData.sublistView(wav);
      expect(wav.lengthInBytes, 44);
      expect(h.getUint32(4, Endian.little), 36);
      expect(h.getUint32(40, Endian.little), 0);
    });
  });
}
