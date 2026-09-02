/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020-2026 Miðeind ehf. <mideind@mideind.is>
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

// ASR provider selection route. Subroute of SettingsRoute.

import 'package:flutter/material.dart';

import './common.dart';
import './provider_selection.dart' show ProviderSelectionRoute;

/// Speech recognition provider selection, i.e. streaming ASR via
/// Ratatoskur vs. batch ASR via Hreimur.
class ASRSelectionRoute extends StatelessWidget {
  const ASRSelectionRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderSelectionRoute(
      title: 'Talgreining',
      prefKey: 'asr_provider',
      options: kASRProviders,
    );
  }
}
