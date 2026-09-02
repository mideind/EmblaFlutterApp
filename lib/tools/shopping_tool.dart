/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2026 Miðeind ehf. <mideind@mideind.is>
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

// Adds items to the user's shopping list (a Reminders list on iOS).

import '../common.dart' show kDefaultShoppingList;
import '../prefs.dart' show Prefs;
import 'device_actions_channel.dart';
import 'tool.dart';
import 'tool_args.dart';

class AddShoppingTool extends Tool {
  final DeviceActions actions;

  /// Read at call time so the setting can change between turns.
  final String Function() listName;

  AddShoppingTool({required this.actions, String Function()? listName})
      : listName = listName ??
            (() => Prefs().stringForKey('shopping_list') ?? kDefaultShoppingList);

  @override
  String get name => 'add_shopping';

  @override
  String get description =>
      'Bætir hlutum á innkaupalistann. Notaðu þetta þegar notandinn vill setja '
      'eitthvað á innkaupalistann, t.d. „settu mjólk og egg á innkaupalistann“.';

  @override
  String? get activityLabel => 'Bæti á innkaupalistann…';

  @override
  Map<String, dynamic> get parameters => strictObjectSchema(<String, Map<String, dynamic>>{
        'items': stringArrayProperty(
            'Hlutirnir sem á að bæta við, hver hlutur í nefnifalli '
            '(t.d. egg, tómatar). Einn hlutur per stak.'),
      });

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final List<String> items = stringList(args['items']);
    if (items.isEmpty) {
      return ToolResult.failure('Vantar hluti til að bæta á listann (items).');
    }
    final String list = listName();
    try {
      final int count = await actions.addShopping(items: items, list: list);
      return ToolResult.success(<String, dynamic>{
        'count': count,
        'list': list,
        'items': items,
      });
    } on DeviceActionsException catch (e) {
      return ToolResult.failure(e.message);
    }
  }
}
