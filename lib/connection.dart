// @dart=2.9
// ^ Removes checks for null safety
import 'package:flutter/material.dart';

class Connection {
  final String name;
  String brand;
  final Icon icon;
  Image logo;
  final String webview;

  Connection.card({this.name, this.brand, this.icon, this.webview});
  Connection.list({this.name, this.icon, this.logo, this.webview});
}
