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

// Prefs singleton object that contains all user
// settings variables used globally by the app.

import 'package:shared_preferences/shared_preferences.dart';

import './common.dart';
import './loc.dart' show LocationTracker;

class Prefs {
  Prefs._privateConstructor();
  static final Prefs _instance = Prefs._privateConstructor();
  static SharedPreferences? _sp;

  // Singleton pattern
  factory Prefs() {
    return _instance;
  }

  Future<void> load() async {
    dlog("Loading prefs...");
    _sp = await SharedPreferences.getInstance();
  }

  bool boolForKey(String key) {
    return _sp?.getBool(key) ?? false;
  }

  void setBoolForKey(String key, bool val) {
    dlog("Setting pref key '$key' to bool '${val.toString()}'");
    _sp?.setBool(key, val);
    // TODO: This is hacky and should be solved in some other way. Can we subscribe to changes?
    if (key == 'share_location') {
      if (val == true) {
        LocationTracker().start();
      } else {
        LocationTracker().stop();
      }
    }
  }

  double? doubleForKey(String key) {
    return _sp?.getDouble(key);
  }

  void setDoubleForKey(String key, double val) {
    dlog("Setting pref key '$key' to float '${val.toString()}'");
    _sp?.setDouble(key, val);
  }

  String? stringForKey(String key) {
    return _sp?.getString(key);
  }

  void setStringForKey(String key, String val) {
    dlog("Setting pref key '$key' to string '$val'");
    _sp?.setString(key, val);
  }

  void clear() {
    dlog("Clearing prefs");
    _sp?.clear();
  }

  /// Set default starting values for prefs
  void setDefaults() {
    dlog('Setting prefs to default values');
    Prefs().setBoolForKey('launched', true);
    Prefs().setBoolForKey('hotword_activation', true);
    Prefs().setBoolForKey('share_location', true);
    Prefs().setBoolForKey('privacy_mode', false);
    Prefs().setDoubleForKey('voice_speed', 1.0);
    Prefs().setStringForKey('voice_id', kDefaultVoice);
    Prefs().setStringForKey('query_server', kDefaultQueryServer);
  }

  /// Generate a human-readable string representation of
  /// all key/value pairs in global Prefs object
  String description() {
    List<dynamic> list = _sp!
        .getKeys()
        .map<String>((key) => "$key: ${_sp?.get(key).toString()}")
        .toList(growable: false);
    return list.toString();
  }
}
