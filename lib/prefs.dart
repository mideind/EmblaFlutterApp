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

/// Prefs singleton object that contains all user settings
/// used globally by the app.

import 'package:shared_preferences/shared_preferences.dart';

import './common.dart';
import './loc.dart' show LocationTracker;

class Prefs {
  static final Prefs _instance = Prefs._constructor();
  static SharedPreferences? _sp;

  // Singleton pattern
  Prefs._constructor();
  factory Prefs() {
    return _instance;
  }

  Future<void> load() async {
    dlog("Loading prefs...");
    _sp = await SharedPreferences.getInstance();
  }

  // Boolean values
  bool boolForKey(String key) {
    return _sp?.getBool(key) ?? false;
  }

  void setBoolForKey(String key, bool val) {
    dlog("Setting pref key '$key' to bool '$val'");
    _sp?.setBool(key, val);
    // TODO: This is hacky and should be solved in some other way.
    // Can we subscribe to changes?
    if (key == 'share_location') {
      if (val == true) {
        LocationTracker().start();
      } else {
        LocationTracker().stop();
      }
    }
  }

  // Double values
  double? doubleForKey(String key) {
    return _sp?.getDouble(key);
  }

  void setDoubleForKey(String key, double val) {
    dlog("Setting pref key '$key' to double '$val'");
    _sp?.setDouble(key, val);
  }

  // String values
  String? stringForKey(String key) {
    return _sp?.getString(key);
  }

  void setStringForKey(String key, String val) {
    dlog("Setting pref key '$key' to string '$val'");
    _sp?.setString(key, val);
  }

  /// Set default starting values for prefs.
  void setDefaults() {
    dlog('Setting prefs to default values');
    setBoolForKey('launched', true);
    setBoolForKey('hotword_activation', true);
    setBoolForKey('share_location', true);
    setBoolForKey('privacy_mode', false);
    setDoubleForKey('voice_speed', kDefaultVoiceSpeed);
    setStringForKey('voice_id', kDefaultVoiceID);
    setStringForKey('query_server', kDefaultQueryServer);
    setStringForKey('ratatoskur_server', kDefaultRatatoskurServer);
    setStringForKey('asr_engine', kDefaultASREngine);
  }

  /// Generate a human-readable string representation
  /// of all key/value pairs in global Prefs object.
  @override
  String toString() {
    final List<dynamic> list = _sp!
        .getKeys()
        .map<String>((key) => "$key: ${_sp?.get(key).toString()}")
        .toList(growable: false);
    return list.toString();
  }
}
