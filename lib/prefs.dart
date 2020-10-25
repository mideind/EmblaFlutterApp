import 'package:shared_preferences/shared_preferences.dart';

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

  void dump() async {
    List list = _sp
        .getKeys()
        .map<String>((key) => key + ": " + _sp.get(key).toString())
        .toList(growable: false);
    print("Shared Preferences: " + list.toString());
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
    Prefs().setStringForKey('query_server', 'https://greynir.is');
  }
}
