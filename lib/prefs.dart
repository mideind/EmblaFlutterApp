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

// Prefs singleton object used globally by the app

import 'package:shared_preferences/shared_preferences.dart';

import './loc.dart';
import './common.dart';

class Prefs {
  Prefs._privateConstructor();
  static final Prefs _instance = Prefs._privateConstructor();
  static SharedPreferences _sp;
  factory Prefs() {
    return _instance;
  }

  Future<void> load() async {
    _sp = await SharedPreferences.getInstance();
  }

  bool boolForKey(String key) {
    return _sp.getBool(key) ?? false;
  }

  void setBoolForKey(String key, bool val) {
    dlog("Setting pref key '" + key + "' to bool '" + val.toString() + "'");
    _sp.setBool(key, val);
    if (key == 'share_location') {
      if (val == true) {
        LocationTracking().start();
      } else {
        LocationTracking().stop();
      }
    }
  }

  double floatForKey(String key) {
    return _sp.getDouble(key);
  }

  void setFloatForKey(String key, double val) {
    dlog("Setting pref key '" + key + "' to float '" + val.toString() + "'");
    _sp.setDouble(key, val);
  }

  String stringForKey(String key) {
    return _sp.getString(key);
  }

  void setStringForKey(String key, String val) {
    dlog("Setting pref key '" + key + "' to string '" + val + "'");
    _sp.setString(key, val);
  }

  String desc() {
    List list = _sp
        .getKeys()
        .map<String>((key) => key + ": " + _sp.get(key).toString())
        .toList(growable: false);
    return list.toString();
  }

  void clear() {
    _sp.clear();
  }

  void setDefaults() {
    Prefs().setBoolForKey('launched', true);
    Prefs().setBoolForKey('hotword_activation', true);
    Prefs().setBoolForKey('share_location', true);
    Prefs().setBoolForKey('privacy_mode', false);
    Prefs().setFloatForKey('voice_speed', 1.0);
    Prefs().setStringForKey('voice_id', 'Kona');
    Prefs().setStringForKey('query_server', kDefaultServer);
  }
}
