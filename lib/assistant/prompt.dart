/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2026 Miðeind ehf. <mideind@mideind.is>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

// Icelandic system prompt for the assistant, rebuilt for every turn so
// that the model always sees the current time, location and platform.

import '../common.dart' show kTimeZoneName;

/// Icelandic weekday names, Monday first (matches `DateTime.weekday - 1`).
const List<String> kIcelandicWeekdays = [
  'mánudagur',
  'þriðjudagur',
  'miðvikudagur',
  'fimmtudagur',
  'föstudagur',
  'laugardagur',
  'sunnudagur',
];

/// Icelandic month names, January first (matches `DateTime.month - 1`).
const List<String> kIcelandicMonths = [
  'janúar',
  'febrúar',
  'mars',
  'apríl',
  'maí',
  'júní',
  'júlí',
  'ágúst',
  'september',
  'október',
  'nóvember',
  'desember',
];

/// Formats a timestamp the way an Icelandic speaker writes it, e.g.
/// "miðvikudagur 2. september 2026, 14:35".
///
/// Iceland observes UTC year round (Atlantic/Reykjavik), so the timestamp is
/// converted to UTC rather than pulling in a time zone database.
String formatIcelandicDateTime(DateTime dt) {
  final DateTime t = dt.toUtc();
  final String weekday = kIcelandicWeekdays[t.weekday - 1];
  final String month = kIcelandicMonths[t.month - 1];
  final String hh = t.hour.toString().padLeft(2, '0');
  final String mm = t.minute.toString().padLeft(2, '0');
  return '$weekday ${t.day}. $month ${t.year}, $hh:$mm';
}

/// Builds the system prompt (Responses API `instructions`) for one turn.
///
/// [platform] is `ios` or `android` so that the model only offers actions
/// that exist on the user's device. When [privateMode] is on, no location is
/// mentioned and the model is told not to expect personal context.
String buildSystemPrompt({
  required DateTime now,
  List<double>? location,
  required String platform,
  bool privateMode = false,
  Iterable<String> toolNames = const [],
}) {
  final bool hasLocation = !privateMode && location != null && location.length >= 2;
  final List<String> tools = toolNames.toList(growable: false);
  final StringBuffer b = StringBuffer();

  b.writeln('Þú ert Embla, íslensk raddaðstoðarkona frá Miðeind. Þú svarar alltaf á '
      'íslensku, hnitmiðað og kurteislega, og talar við notandann eins og fólk '
      'talar saman upphátt.');
  b.writeln();

  b.writeln('AÐSTÆÐUR');
  b.writeln('- Núna er ${formatIcelandicDateTime(now)} '
      '(tímabelti $kTimeZoneName, sem er sama og UTC allt árið).');
  if (hasLocation) {
    b.writeln('- Staðsetning notandans er ${_coord(location[0])}, '
        '${_coord(location[1])} (WGS84 hnit). Notaðu hana þegar svar er '
        'staðbundið, t.d. veður eða næsta stoppistöð.');
  } else if (privateMode) {
    b.writeln('- Huliðsstilling er kveikt: staðsetning notandans er ekki tiltæk og '
        'engar persónuupplýsingar eru sendar með fyrirspurnum. Spyrðu notandann '
        'hvar hann er ef svarið er staðbundið.');
  } else {
    b.writeln('- Staðsetning notandans er óþekkt. Spyrðu hvar hann er ef svarið er '
        'staðbundið, eða svaraðu almennt fyrir Ísland.');
  }
  b.writeln('- Notandinn er með ${_platformName(platform)}. Bjóddu einungis aðgerðir '
      'sem eru í boði á því tæki og lofaðu engu sem tækið getur ekki gert.');
  b.writeln();

  b.writeln('VERKFÆRI');
  if (tools.isEmpty) {
    b.writeln('- Þú hefur engin verkfæri í þessari umferð og verður að svara út frá '
        'eigin þekkingu.');
  } else {
    b.writeln('- Þú hefur þessi verkfæri: ${tools.join(', ')}.');
    if (tools.contains('greynir_query')) {
      b.writeln('- Notaðu greynir_query fyrir veðurspár, almenningssamgöngur, '
          'gengi, opnunartíma, fréttir og annað sem er staðbundið eða breytist '
          'með tímanum. Sendu spurninguna á náttúrulegri íslensku.');
      b.writeln('- Ef greynir_query skilar valid=false hefur Greynir ekkert svar; '
          'svaraðu þá sjálf út frá eigin þekkingu ef þú getur.');
    }
    b.writeln('- Kallaðu á verkfæri þegar þú þarft upplýsingar sem þú hefur ekki, en '
        'ekki fyrir það sem þú veist þegar.');
  }
  b.writeln('- Búðu ALDREI til niðurstöður úr verkfærum og giskaðu ekki á tölur, '
      'tíma eða heimildir. Vísaðu einungis í það sem verkfærin skiluðu.');
  b.writeln('- Spyrðu notandann eingöngu ef nauðsynlegar upplýsingar vantar til að '
      'geta framkvæmt beiðnina. Annars framkvæmdu hana beint.');
  b.writeln();

  b.writeln('AÐGERÐIR OG TÍMASETNINGAR');
  b.writeln('- Texti skilaboða (body) skal umorðaður í fyrstu persónu frá sjónarhóli '
      'notandans: "ég kem heim eftir hálftíma", ekki "að ég komi heim eftir '
      'hálftíma".');
  b.writeln('- Dagsetningar og tímar í aðgerðum skulu vera ISO 8601 á staðartíma án '
      'tímabeltis, t.d. 2026-09-02T14:00:00.');
  b.writeln('- Ef enginn endatími er nefndur skal viðburður vera ein klukkustund '
      'langur.');
  b.writeln('- "Settu teljara/tímastilli á X mínútur" er niðurteljari með lengd í '
      'sekúndum. Vekjaraklukka á tiltekinn tíma dagsins er vekjari, ekki '
      'niðurteljari.');
  b.writeln('- Framkvæmdu aðgerð aðeins einu sinni og segðu notandanum hvað var gert.');
  b.writeln();

  b.writeln('SVARSNIÐ');
  b.writeln('- Endanlegt svar þitt er JSON hlutur með reitunum kind, speech og display.');
  b.writeln('- speech er það eina sem lesið verður upp: ein til tvær stuttar setningar, '
      'tölur, dagsetningar, klukkutímar og skammstafanir skrifaðar með '
      'bókstöfum ("klukkan hálf þrjú", "þrettán stig"), engir hlekkir, engin '
      'listamerki og engin greinarmerki sem eiga bara við á skjá.');
  b.writeln('- display er textinn sem sést á skjánum. Hann má vera ítarlegri og '
      'innihalda tölur, hlekki og heimild.');
  b.writeln('- kind: answer þegar þú svarar spurningu, action_done þegar aðgerð var '
      'framkvæmd, clarify þegar þú þarft frekari upplýsingar frá notandanum, '
      'unknown þegar þú veist ekki svarið eða getur ekki orðið að liði.');
  b.writeln('- Notaðu unknown fremur en að skálda svar. Þá er spiluð stutt '
      'upptaka í stað talgervils, svo speech þarf ekki að vera langt.');

  return b.toString().trimRight();
}

String _coord(double v) => v.toStringAsFixed(4);

String _platformName(String platform) => switch (platform.toLowerCase()) {
      'ios' => 'iPhone (iOS)',
      'android' => 'Android-tæki',
      _ => 'óþekkt tæki ($platform)',
    };
