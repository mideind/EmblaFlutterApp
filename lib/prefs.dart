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

// Prefs singleton

import 'package:shared_preferences/shared_preferences.dart';
import './common.dart';

// Singleton class
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
    _sp.setBool(key, val);
  }

  String stringForKey(String key) {
    return _sp.getString(key);
  }

  void setStringForKey(String key, String val) {
    _sp.setString(key, val);
  }

  String desc() {
    List list = _sp
        .getKeys()
        .map<String>((key) => key + ": " + _sp.get(key).toString())
        .toList(growable: false);
    return "Shared Preferences: " + list.toString();
  }

  void clear() {
    _sp.clear();
  }

  void setDefaults() {
    Prefs().setBoolForKey('launched', true);
    Prefs().setBoolForKey('voice_activation', true);
    Prefs().setBoolForKey('share_location', true);
    Prefs().setBoolForKey('privacy_mode', false);
    Prefs().setBoolForKey('voice_id', false);
    Prefs().setStringForKey('voice_speed', '1.0');
    Prefs().setStringForKey('query_server', DEFAULT_SERVER);
  }
}
