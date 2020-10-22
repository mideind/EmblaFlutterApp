import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static bool boolForKey(String key) {
    SharedPreferences p = await SharedPreferences.getInstance();
    return p.getBool(key);
  }

  static setBoolForKey(String key, bool val) async {
    SharedPreferences p = await SharedPreferences.getInstance();
    p.setBool(key, val);
  }

  static String stringForKey(String key) {
    SharedPreferences p = await SharedPreferences.getInstance();
    return p.getString(key);
  }

  static setStringForKey(String key, String val) async {
    SharedPreferences p = await SharedPreferences.getInstance();
    p.setString(key, val);
  }
}
