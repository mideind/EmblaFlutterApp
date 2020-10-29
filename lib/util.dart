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

// Various utility functions

// String extensions
extension StringExtension on String {
  bool isPunctuationTerminated() {
    if (this.length == 0) {
      return false;
    }
    List<String> punc = ['.', '?', '!', '."', '.“', ".'"];
    for (String p in punc) {
      if (this.endsWith(p)) {
        return true;
      }
    }
    return false;
  }

  String sentenceCapitalized() {
    if (this.length == 0) {
      return this;
    }
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }

  String periodTerminated() {
    if (this.isPunctuationTerminated() == false) {
      return this + '.';
    }
    return this;
  }
}
