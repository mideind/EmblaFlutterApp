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

// Minimal RIFF/WAVE container for the raw PCM the microphone gives us.
//
// `AudioRecorder` (embla_core) hands out headerless 16-bit little-endian
// PCM chunks. Batch ASR endpoints want a file, so we prepend the canonical
// 44-byte header. Only linear PCM (format tag 1) is produced.

import 'dart:typed_data';

/// Size of the canonical RIFF/WAVE header for linear PCM.
const int kWavHeaderSize = 44;

/// Bit depth of the PCM data produced by `AudioRecorder`.
const int kWavBitsPerSample = 16;

/// Wraps raw little-endian 16-bit PCM in a WAV container.
///
/// [pcm] is copied, so the caller may reuse its buffer afterwards.
Uint8List wavFromPcm16(Uint8List pcm, {int sampleRate = 16000, int channels = 1}) {
  final int dataSize = pcm.lengthInBytes;
  final int blockAlign = channels * kWavBitsPerSample ~/ 8;
  final int byteRate = sampleRate * blockAlign;

  final Uint8List out = Uint8List(kWavHeaderSize + dataSize);
  final ByteData h = ByteData.view(out.buffer);

  void ascii(int offset, String tag) {
    for (int i = 0; i < tag.length; i++) {
      h.setUint8(offset + i, tag.codeUnitAt(i));
    }
  }

  // RIFF chunk descriptor
  ascii(0, 'RIFF');
  h.setUint32(4, kWavHeaderSize - 8 + dataSize, Endian.little); // 36 + dataSize
  ascii(8, 'WAVE');
  // "fmt " sub-chunk
  ascii(12, 'fmt ');
  h.setUint32(16, 16, Endian.little); // PCM fmt chunk length
  h.setUint16(20, 1, Endian.little); // 1 = linear PCM, uncompressed
  h.setUint16(22, channels, Endian.little);
  h.setUint32(24, sampleRate, Endian.little);
  h.setUint32(28, byteRate, Endian.little);
  h.setUint16(32, blockAlign, Endian.little);
  h.setUint16(34, kWavBitsPerSample, Endian.little);
  // "data" sub-chunk
  ascii(36, 'data');
  h.setUint32(40, dataSize, Endian.little);

  out.setRange(kWavHeaderSize, kWavHeaderSize + dataSize, pcm);
  return out;
}
