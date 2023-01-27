/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2023 Miðeind ehf. <mideind@mideind.is>
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

import 'package:flutter/material.dart';

class Connection {
  final String name;
  String brand = "";
  final Icon icon;
  Image? logo;
  String webview;

  Connection.card(
      {required this.name, required this.brand, required this.icon, required this.webview});
  Connection.list(
      {required this.name, required this.icon, required this.logo, required this.webview});
}
