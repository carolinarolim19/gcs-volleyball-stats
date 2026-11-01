import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:excel_community/excel_community.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

import '../models/match.dart';
import '../models/player.dart';
import '../models/match_event.dart';
import '../database/match_set_participation_repository.dart';

class MatchExcelExportService {
  static const String fileName =
      'GCS_Estatisticas_2026_2027.xlsx';

  CellStyle get efficacyStyle => CellStyle(
    bold: true,
    fontColorHex:
    ExcelColor.fromHexString('#1B5E20'),
    backgroundColorHex:
    ExcelColor.fromHexString('#E8F5E9'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  CellStyle get intermediateStyle => CellStyle(
    bold: true,
    fontColorHex:
    ExcelColor.fromHexString('#8A6D00'),
    backgroundColorHex:
    ExcelColor.fromHexString('#FFF8E1'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  CellStyle get errorStyle => CellStyle(
    bold: true,
    fontColorHex:
    ExcelColor.fromHexString('#B71C1C'),
    backgroundColorHex:
    ExcelColor.fromHexString('#FFEBEE'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  final MatchSetParticipationRepository
  _participationRepository =
  MatchSetParticipationRepository();

  static const String _webExcelKey = 'gcs_excel_2026_2027';

  Future<File> getExcelFile() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'O navegador não utiliza ficheiros locais.',
      );
    }

    final directory = await getApplicationDocumentsDirectory();

    return File('${directory.path}/$fileName');
  }

  Future<void> resetExcelFile() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_webExcelKey);
      return;
    }

    final file = await getExcelFile();

    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Excel> loadOrCreateExcel() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString(_webExcelKey);

      if (savedData != null) {
        return Excel.decodeBytes(base64Decode(savedData));
      }
    } else {
      final file = await getExcelFile();

      if (await file.exists()) {
        return Excel.decodeBytes(await file.readAsBytes());
      }
    }

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'RESUMO');

    return excel;
  }

  Future<Uint8List?> saveExcel(Excel excel) async {
    final bytes = excel.encode();

    if (bytes == null) return null;

    final data = Uint8List.fromList(bytes);

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_webExcelKey, base64Encode(data));
    } else {
      final file = await getExcelFile();

      await file.writeAsBytes(data, flush: true);
    }

    return data;
  }

  void downloadExcelWeb(Uint8List bytes) {
    final blob = html.Blob([
      bytes,
    ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  void prepareResumoSheet(Excel excel) {
    final sheet = excel['RESUMO'];

    sheet
        .cell(CellIndex.indexByString('A1'))
        .value =
        TextCellValue(
          'GCS - ESTATÍSTICAS 2026/2027',
        );

    sheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('F1'),
    );
    sheet.setRowHeight(0, 28);

    sheet
        .cell(CellIndex.indexByString('A1'))
        .cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.white,
      backgroundColorHex:
      ExcelColor.fromHexString('#2196F3'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headers = [
      'Jogo',
      'Data',
      'Adversário',
      'Competição',
      'Casa/Fora',
      'Resultado',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: i,
          rowIndex: 2,
        ),
      );

      cell.value = TextCellValue(headers[i]);

      cell.cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex:
        ExcelColor.fromHexString('#2196F3'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    sheet.setColumnWidth(0, 12); // Jogo
    sheet.setColumnWidth(1, 14); // Data
    sheet.setColumnWidth(2, 22); // Adversário
    sheet.setColumnWidth(3, 24); // Competição
    sheet.setColumnWidth(4, 14); // Casa/Fora
    sheet.setColumnWidth(5, 24); // Resultado
    sheet.setColumnWidth(51, 0);

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 51,
        rowIndex: 2,
      ),
    )
        .value = TextCellValue(
      '_MATCH_ID',
    );
  }

  void addMatchToResumo(
      Excel excel,
      Match match, {
        int? finalGcsSets,
        int? finalOpponentSets,
      }) {
    final sheet = excel['RESUMO'];

    final date = match.dateTime;

    final formattedDate =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';

    final result =
        'GCS ${finalGcsSets ?? match.gcsSets}-'
        '${finalOpponentSets ?? match.opponentSets} '
        '${match.opponent}';

    final existingRow = findMatchRowInResumo(
      excel: excel,
      matchId: match.id!,
    );

    final rowIndex =
        existingRow ?? sheet.maxRows;

    final values = [
      'Jogo ${rowIndex - 2}',
      formattedDate,
      match.opponent,
      match.competition,
      match.home ? 'Casa' : 'Fora',
      result,
    ];

    for (int i = 0; i < values.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: i,
          rowIndex: rowIndex,
        ),
      );

      cell.value = TextCellValue(values[i]);

      cell.cellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: rowIndex,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 5,
        rowIndex: rowIndex,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 51,
        rowIndex: rowIndex,
      ),
    )
        .value = IntCellValue(
      match.id!,
    );
  }

  String prepareMatchSheet(
      Excel excel,
      Match match, {
        int? finalGcsSets,
        int? finalOpponentSets,
      }) {
    final gameNumber = getGameNumber(
      excel: excel,
      matchId: match.id!,
    );

    final rawSheetName =
        'Jogo $gameNumber - ${match.opponent}';

    final cleanedSheetName = rawSheetName
        .replaceAll(
      RegExp(r'[:\\/?*\[\]]'),
      ' ',
    )
        .trim();

    final sheetName =
    cleanedSheetName.length > 31
        ? cleanedSheetName.substring(0, 31)
        : cleanedSheetName;

    final sheet = excel[sheetName];

    sheet
        .cell(CellIndex.indexByString('A1'))
        .value = TextCellValue(
      'GCS vs ${match.opponent}',
    );

    sheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('F1'),
    );
    sheet.setRowHeight(0, 28);

    sheet
        .cell(CellIndex.indexByString('A1'))
        .cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.white,
      backgroundColorHex:
      ExcelColor.fromHexString('#2196F3'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    sheet
        .cell(CellIndex.indexByString('A2'))
        .value = TextCellValue(
      'Competição: ${match.competition}',
    );

    final date = match.dateTime;

    final formattedDate =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';

    sheet
        .cell(CellIndex.indexByString('A3'))
        .value = TextCellValue(
      'Data: $formattedDate',
    );

    sheet
        .cell(CellIndex.indexByString('A4'))
        .value = TextCellValue(
      match.home ? 'Local: Casa' : 'Local: Fora',
    );

    sheet
        .cell(CellIndex.indexByString('A5'))
        .value = TextCellValue(
      'RESULTADO: GCS ${finalGcsSets ?? match.gcsSets}-'
          '${finalOpponentSets ?? match.opponentSets} '
          '${match.opponent}',
    );

    for (final cellName in ['A2', 'A3', 'A4', 'A5']) {
      sheet
          .cell(CellIndex.indexByString(cellName))
          .cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    for (int row = 2; row <= 5; row++) {
      sheet.merge(
        CellIndex.indexByString('A$row'),
        CellIndex.indexByString('F$row'),
      );
    }

    return sheetName;
  }

  int countEvents({
    required List<MatchEvent> events,
    required int playerId,
    required String action,
    required String result,
    int? setNumber,
  }) {
    return events.where((event) {
      final samePlayer =
          event.playerId == playerId;

      final sameAction =
          event.action == action;

      final sameResult =
          event.result == result;

      final sameSet =
          setNumber == null ||
              event.setNumber == setNumber;

      return samePlayer &&
          sameAction &&
          sameResult &&
          sameSet;
    }).length;
  }

  int countActionTotal({
    required List<MatchEvent> events,
    required int playerId,
    required String action,
    int? setNumber,
  }) {
    return events.where((event) {
      final samePlayer =
          event.playerId == playerId;

      final sameAction =
          event.action == action;

      final sameSet =
          setNumber == null ||
              event.setNumber == setNumber;

      return samePlayer &&
          sameAction &&
          sameSet;
    }).length;
  }



  String distributionZoneFromResult(String result) {
    final separatorIndex = result.indexOf(' | ');

    if (separatorIndex == -1) {
      return '';
    }

    final zoneText = result.substring(0, separatorIndex).trim();
    const prefix = 'Zona de ataque:';

    if (!zoneText.startsWith(prefix)) {
      return '';
    }

    final zone = zoneText.substring(prefix.length).trim();

    if (zone.toLowerCase().contains('pipe')) {
      if (RegExp(r'\b6\b').hasMatch(zone)) {
        return 'Pipe Zona 6';
      }

      if (RegExp(r'\b1\b').hasMatch(zone)) {
        return 'Pipe Zona 1';
      }

      return 'Pipe';
    }

    return zone;
  }


  List<String> distributionTypesFromResult(String result) {
    if (result.trim() == 'Erro') {
      return ['Erro'];
    }

    final separatorIndex = result.indexOf(' | ');

    if (separatorIndex == -1) {
      return [];
    }

    final typesText = result.substring(separatorIndex + 3).trim();
    const prefix = 'Tipo de distribuição:';

    if (!typesText.startsWith(prefix)) {
      return [];
    }

    final characteristics = typesText
        .substring(prefix.length)
        .split(',')
        .map((type) => type.trim())
        .where((type) => type.isNotEmpty)
        .toSet();

    if (characteristics.contains('Perfeita')) {
      return ['Perfeita'];
    }

    if (characteristics.contains('Erro')) {
      return ['Erro'];
    }

    const heights = ['Alta', 'Baixa'];
    const directions = ['Aberta', 'Interior'];
    const positions = ['Cima da Rede', 'Afastada da Rede'];

    final selected = <String>[];

    for (final group in [heights, directions, positions]) {
      final found = group.where(characteristics.contains).toList();

      if (found.length > 1) {
        selected.addAll(found);
      } else if (found.length == 1) {
        selected.add(found.first);
      }
    }

    return selected.isEmpty
        ? []
        : [selected.join(' + ')];
  }

  int countDistributionByZone({
    required List<MatchEvent> events,
    required int playerId,
    required String zone,
    int? setNumber,
  }) {
    return events.where((event) {
      return event.playerId == playerId &&
          event.action == 'Distribuição' &&
          distributionZoneFromResult(event.result) == zone &&
          (setNumber == null || event.setNumber == setNumber);
    }).length;
  }

  int countDistributionByType({
    required List<MatchEvent> events,
    required int playerId,
    required String type,
    int? setNumber,
  }) {
    return events.where((event) {
      return event.playerId == playerId &&
          event.action == 'Distribuição' &&
          distributionTypesFromResult(event.result).contains(type) &&
          (setNumber == null || event.setNumber == setNumber);
    }).length;
  }


  double? calculateRate(
      num numerator,
      num denominator,
      ) {
    if (denominator == 0) {
      return null;
    }

    return numerator / denominator;
  }

  Map<String, double?> calculateServiceMetrics({
    required List<MatchEvent> events,
    required int playerId,
    int? setNumber,
  }) {
    final ace = countEvents(
      events: events,
      playerId: playerId,
      action: 'Serviço',
      result: 'Ace',
      setNumber: setNumber,
    );

    final positivo = countEvents(
      events: events,
      playerId: playerId,
      action: 'Serviço',
      result: 'Positivo',
      setNumber: setNumber,
    );

    final fraco = countEvents(
      events: events,
      playerId: playerId,
      action: 'Serviço',
      result: 'Fraco',
      setNumber: setNumber,
    );

    final erro = countEvents(
      events: events,
      playerId: playerId,
      action: 'Serviço',
      result: 'Erro',
      setNumber: setNumber,
    );

    final total =
        ace + positivo + fraco + erro;

    return {
      'efficiency': calculateRate(
        ace,
        total,
      ),
      'successRate': calculateRate(
        (3 * ace) +
            (2 * positivo) +
            fraco,
        3 * total,
      ),
      'errorRate': calculateRate(
        erro,
        total,
      ),
    };
  }

  Map<String, double?> calculateReceptionMetrics({
    required List<MatchEvent> events,
    required int playerId,
    int? setNumber,
  }) {
    final bolaA = countEvents(
      events: events,
      playerId: playerId,
      action: 'Receção',
      result: 'Bola A',
      setNumber: setNumber,
    );

    final bolaB = countEvents(
      events: events,
      playerId: playerId,
      action: 'Receção',
      result: 'Bola B',
      setNumber: setNumber,
    );

    final bolaC = countEvents(
      events: events,
      playerId: playerId,
      action: 'Receção',
      result: 'Bola C',
      setNumber: setNumber,
    );

    final erro = countEvents(
      events: events,
      playerId: playerId,
      action: 'Receção',
      result: 'Erro',
      setNumber: setNumber,
    );

    final total =
        bolaA + bolaB + bolaC + erro;

    return {
      'efficiency': calculateRate(
        bolaA,
        total,
      ),
      'successRate': calculateRate(
        (3 * bolaA) +
            (2 * bolaB) +
            bolaC,
        3 * total,
      ),
      'errorRate': calculateRate(
        erro,
        total,
      ),
    };
  }

  Map<String, double?> calculateAttackMetrics({
    required List<MatchEvent> events,
    required int playerId,
    int? setNumber,
  }) {
    final ponto = countEvents(
      events: events,
      playerId: playerId,
      action: 'Ataque',
      result: 'Ponto',
      setNumber: setNumber,
    );

    final continuacao = countEvents(
      events: events,
      playerId: playerId,
      action: 'Ataque',
      result: 'Continuação',
      setNumber: setNumber,
    );

    final bloqueado = countEvents(
      events: events,
      playerId: playerId,
      action: 'Ataque',
      result: 'Blocado',
      setNumber: setNumber,
    );

    final passeManchete = countEvents(
      events: events,
      playerId: playerId,
      action: 'Ataque',
      result: 'Passe/Manchete',
      setNumber: setNumber,
    );

    final erro = countEvents(
      events: events,
      playerId: playerId,
      action: 'Ataque',
      result: 'Erro',
      setNumber: setNumber,
    );

    final total =
        ponto +
            continuacao +
            bloqueado +
            passeManchete +
            erro;

    return {
      'efficiency': calculateRate(
        ponto,
        total,
      ),
      'successRate': calculateRate(
        (3 * ponto) +
            (2 * continuacao) +
            passeManchete,
        3 * total,
      ),
      'errorRate': calculateRate(
        erro + bloqueado,
        total,
      ),
    };
  }

  Map<String, double?> calculateBlockMetrics({
    required List<MatchEvent> events,
    required int playerId,
    int? setNumber,
  }) {
    final ponto = countEvents(
      events: events,
      playerId: playerId,
      action: 'Bloco',
      result: 'Ponto',
      setNumber: setNumber,
    );

    final toque = countEvents(
      events: events,
      playerId: playerId,
      action: 'Bloco',
      result: 'Toque',
      setNumber: setNumber,
    );

    final erro = countEvents(
      events: events,
      playerId: playerId,
      action: 'Bloco',
      result: 'Erro',
      setNumber: setNumber,
    );

    final total =
        ponto + toque + erro;

    return {
      'efficiency': calculateRate(
        ponto,
        total,
      ),
      'successRate': calculateRate(
        (2 * ponto) + toque,
        2 * total,
      ),
      'errorRate': calculateRate(
        erro,
        total,
      ),
    };
  }

  Map<String, double?> calculateDefenseMetrics({
    required List<MatchEvent> events,
    required int playerId,
    int? setNumber,
  }) {
    final excelente = countEvents(
      events: events,
      playerId: playerId,
      action: 'Defesa',
      result: 'Excelente',
      setNumber: setNumber,
    );

    final positiva = countEvents(
      events: events,
      playerId: playerId,
      action: 'Defesa',
      result: 'Positiva',
      setNumber: setNumber,
    );

    final continuacao = countEvents(
      events: events,
      playerId: playerId,
      action: 'Defesa',
      result: 'Continuação',
      setNumber: setNumber,
    );

    final erro = countEvents(
      events: events,
      playerId: playerId,
      action: 'Defesa',
      result: 'Erro',
      setNumber: setNumber,
    );

    final total =
        excelente +
            positiva +
            continuacao +
            erro;

    return {
      'efficiency': calculateRate(
        excelente,
        total,
      ),
      'successRate': calculateRate(
        (3 * excelente) +
            (2 * positiva) +
            continuacao,
        3 * total,
      ),
      'errorRate': calculateRate(
        erro,
        total,
      ),
    };
  }

  String formatPercentage(
      double? value,
      ) {
    if (value == null) {
      return '-';
    }

    return '${(value * 100).toStringAsFixed(1)}%';
  }

  String preparePlayerSheet(
      Excel excel,
      Player player, {
        int totalSeasonGames = 1,
      }) {
    var sheetName = player.name
        .replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ')
        .trim();

    if (sheetName.length > 31) {
      sheetName = sheetName.substring(0, 31);
    }

    final sheet = excel[sheetName];

    if (sheet.maxRows == 0) {
      sheet
          .cell(CellIndex.indexByString('A1'))
          .value = TextCellValue('ATLETA');

      sheet
          .cell(CellIndex.indexByString('B1'))
          .value = TextCellValue(player.name);

      sheet.setColumnWidth(0, 18); // coluna A
      sheet.setColumnWidth(1, 24); // coluna B

      for (final cellName in ['A1', 'B1']) {
        sheet
            .cell(CellIndex.indexByString(cellName))
            .cellStyle = CellStyle(
          bold: true,
          fontColorHex: ExcelColor.white,
          backgroundColorHex:
          ExcelColor.fromHexString('#2196F3'),
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }
      sheet.setRowHeight(0, 26);

      sheet
          .cell(CellIndex.indexByString('B1'))
          .cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        fontColorHex: ExcelColor.white,
        backgroundColorHex:
        ExcelColor.fromHexString('#2196F3'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      sheet
          .cell(CellIndex.indexByString('A2'))
          .value = TextCellValue('NÚMERO');

      sheet
          .cell(CellIndex.indexByString('B2'))
          .value = TextCellValue(
        player.number.toString(),
      );

      sheet
          .cell(CellIndex.indexByString('A2'))
          .cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex:
        ExcelColor.fromHexString('#2196F3'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      sheet
          .cell(CellIndex.indexByString('B2'))
          .cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      // RESUMO DA ÉPOCA
      sheet
          .cell(CellIndex.indexByString('A4'))
          .value = TextCellValue(
        'RESUMO DA ÉPOCA',
      );

      sheet.merge(
        CellIndex.indexByString('A4'),
        CellIndex.indexByString('BB4'),
      );

      sheet
          .cell(CellIndex.indexByString('A4'))
          .cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex:
        ExcelColor.fromHexString('#2196F3'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final seasonHeaders = [
        'Adversário',
        'Local',
        'Sets',
        'Pontos jogados',
        'Pontos fora',

        'Serviço - Ace',
        'Serviço - Positivo',
        'Serviço - Fraco',
        'Serviço - Erro',
        'Serviço - Eficácia',
        'Serviço - Taxa de Acerto',
        'Serviço - Taxa de Erro',

        'Receção - Bola A',
        'Receção - Bola B',
        'Receção - Bola C',
        'Receção - Erro',
        'Receção - Eficácia',
        'Receção - Taxa de Acerto',
        'Receção - Taxa de Erro',

        'Ataque - Ponto',
        'Ataque - Continuação',
        'Ataque - Blocado',
        'Ataque - Passe/Manchete',
        'Ataque - Erro',
        'Ataque - Eficácia',
        'Ataque - Taxa de Acerto',
        'Ataque - Taxa de Erro',

        'Bloco - Ponto',
        'Bloco - Toque',
        'Bloco - Erro',
        'Bloco - Eficácia',
        'Bloco - Taxa de Acerto',
        'Bloco - Taxa de Erro',

        'Defesa - Excelente',
        'Defesa - Positiva',
        'Defesa - Continuação',
        'Defesa - Erro',
        'Defesa - Eficácia',
        'Defesa - Taxa de Acerto',
        'Defesa - Taxa de Erro',

        'Distribuição - Total',
        'Distribuição - Entrada',
        'Distribuição - Central',
        'Distribuição - Oposto',
        'Distribuição - Pipe Zona 6',
        'Distribuição - Pipe Zona 1',
        'Distribuição - Bola Perfeita',
        'Distribuição - Bola Interior',
        'Distribuição - Bola Aberta',
        'Distribuição - Bola Baixa',
        'Distribuição - Bola Alta',
        'Distribuição - Bola Cima da Rede',
        'Distribuição - Bola Afastada da Rede',
        'Distribuição - Bola Erro',
      ];

      for (int i = 0; i < seasonHeaders.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: i,
            rowIndex: 4,
          ),
        );

        cell.value = TextCellValue(
          seasonHeaders[i],
        );

        final header =
        seasonHeaders[i].toLowerCase();

        // Informação geral
        if (i <= 4) {
          cell.cellStyle = CellStyle(
            bold: true,
            fontColorHex: ExcelColor.white,
            backgroundColorHex:
            ExcelColor.fromHexString('#2196F3'),
            horizontalAlign:
            HorizontalAlign.Center,
            verticalAlign:
            VerticalAlign.Center,
          );
        }

        // VERDE
        else if (
        header.contains('eficácia') ||
            header.endsWith(' - ace') ||
            header == 'receção - bola a' ||
            header.endsWith(' - ponto') ||
            header.endsWith(' - bola perfeita') ||
            header.endsWith(' - excelente')) {
          cell.cellStyle = efficacyStyle;
        }

        // VERMELHO
        else if (
        header.contains('erro') ||
            header.endsWith(' - blocado')) {
          cell.cellStyle = errorStyle;
        }

        // AMARELO
        else if (
        header.contains('taxa de acerto') ||
            header.endsWith(' - positivo') ||
            header.endsWith(' - fraco') ||
            header.endsWith(' - bola b') ||
            header.endsWith(' - bola c') ||
            header.endsWith(' - continuação') ||
            header.endsWith(' - passe/manchete') ||
            header.endsWith(' - toque') ||
            header.endsWith(' - positiva')) {
          cell.cellStyle = intermediateStyle;
        }

        // AZUL — cabeçalhos de distribuição, exceto erro
        else if (
        header.startsWith('distribuição') &&
            !header.contains('erro')) {
          cell.cellStyle = CellStyle(
            bold: true,
            fontColorHex: ExcelColor.white,
            backgroundColorHex:
            ExcelColor.fromHexString('#2196F3'),
            horizontalAlign: HorizontalAlign.Center,
            verticalAlign: VerticalAlign.Center,
          );
        }
      }

      final thinBorder = Border(
        borderStyle: BorderStyle.Thin,
      );

      for (int columnIndex = 0;
      columnIndex < seasonHeaders.length;
      columnIndex++) {

        // Cabeçalho
        final headerCell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: columnIndex,
            rowIndex: 4,
          ),
        );

        headerCell.cellStyle =
            (headerCell.cellStyle ?? CellStyle()).copyWith(
              leftBorderVal: thinBorder,
              rightBorderVal: thinBorder,
              topBorderVal: thinBorder,
              bottomBorderVal: thinBorder,
            );

        // Valores
        final valueCell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: columnIndex,
            rowIndex: 5,
          ),
        );

        valueCell.cellStyle =
            (valueCell.cellStyle ?? CellStyle()).copyWith(
              leftBorderVal: thinBorder,
              rightBorderVal: thinBorder,
              topBorderVal: thinBorder,
              bottomBorderVal: thinBorder,
            );
      }

      for (int i = 0; i < seasonHeaders.length; i++) {
        double width =
            seasonHeaders[i].length.toDouble() + 4;

        // Mantemos A e B mais largas porque também
        // são usadas no resto da folha da atleta
        if (i == 0) {
          width = 14; // Jogo
        } else if (i == 1) {
          width = 24; // Adversário
        } else if (i == 2) {
          width = 10; // Sets
        } else if (i == 3) {
          width = 18; // Pontos jogados
        } else if (i == 4) {
          width = 16; // Pontos fora
        }

        if (width > 30) {
          width = 30;
        }

        sheet.setColumnWidth(
          i,
          width,
        );
      }

      // Reserva espaço para:
      // JOGO 1
      // JOGO 2
      // ...
      // TOTAL
      for (int rowIndex = 5;
      rowIndex <= 5 + totalSeasonGames;
      rowIndex++) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 51,
            rowIndex: rowIndex,
          ),
        )
            .value = TextCellValue(
          '_SEASON_SUMMARY_RESERVED',
        );
      }
    }
    sheet.setColumnWidth(51, 0);
    return sheetName;
  }

  int addMatchHeaderToPlayerSheet({
    required Excel excel,
    required String sheetName,
    required Match match,
    required int gameNumber,
    int? finalGcsSets,
    int? finalOpponentSets,
  }) {
    final sheet = excel[sheetName];

    final existingStartRow =
    findMatchStartRowInPlayerSheet(
      excel: excel,
      sheetName: sheetName,
      matchId: match.id!,
    );

    final startRow =
        existingStartRow ?? sheet.maxRows + 1;

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 51,
        rowIndex: startRow,
      ),
    )
        .value = IntCellValue(
      match.id!,
    );

    final date = match.dateTime;

    final formattedDate =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
    )
        .value = TextCellValue(
      'JOGO $gameNumber',
    );

    sheet.merge(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow,
      ),
    );
    sheet.setRowHeight(startRow, 24);

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex:
      ExcelColor.fromHexString('#2196F3'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow + 1,
      ),
    )
        .value = TextCellValue(
      'ADVERSÁRIO',
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow + 1,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex:
      ExcelColor.fromHexString('#2196F3'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow + 1,
      ),
    )
        .value = TextCellValue(
      match.opponent,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow + 2,
      ),
    )
        .value = TextCellValue(
      'COMPETIÇÃO',
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow + 2,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex:
      ExcelColor.fromHexString('#2196F3'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow + 2,
      ),
    )
        .value = TextCellValue(
      match.competition,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow + 3,
      ),
    )
        .value = TextCellValue(
      'DATA',
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow + 3,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex:
      ExcelColor.fromHexString('#2196F3'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow + 3,
      ),
    )
        .value = TextCellValue(
      formattedDate,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow + 4,
      ),
    )
        .value = TextCellValue(
      'RESULTADO',
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow + 4,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex:
      ExcelColor.fromHexString('#2196F3'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow + 4,
      ),
    )
        .value = TextCellValue(
        'GCS ${finalGcsSets ?? match.gcsSets}-'
            '${finalOpponentSets ?? match.opponentSets} '
            '${match.opponent}'
    );

    for (int offset = 1; offset <= 4; offset++) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: startRow + offset,
        ),
      )
          .cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex:
        ExcelColor.fromHexString('#2196F3'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: 1,
          rowIndex: startRow + offset,
        ),
      )
          .cellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow + 4,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    return startRow + 6;
  }

  Future<int> addSetParticipationToPlayerSheet({
    required Excel excel,
    required String sheetName,
    required int startRow,
    required int matchId,
    required int setNumber,
    required int playerId,
  }) async {
    final sheet = excel[sheetName];

    final setStats =
    await _participationRepository
        .getSetParticipationStats(
      matchId: matchId,
      setNumber: setNumber,
    );

    final playerStats = setStats[playerId];

    final inGame = playerStats != null;

    final pointsPlayed =
        playerStats?['pointsPlayed'] ?? 0;

    final pointsOut =
        playerStats?['pointsOut'] ?? 0;

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
    )
        .value = TextCellValue(
      'SET $setNumber',
    );

    sheet.merge(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow,
      ),
    );
    sheet.setRowHeight(startRow, 22);

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex:
      ExcelColor.fromHexString('#2196F3'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow + 1,
      ),
    )
        .value = TextCellValue(
      'Em jogo',
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow + 1,
      ),
    )
        .value = TextCellValue(
      inGame ? 'Sim' : 'Não',
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow + 2,
      ),
    )
        .value = TextCellValue(
      'Pontos jogados',
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow + 2,
      ),
    )
        .value = IntCellValue(
      pointsPlayed,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow + 3,
      ),
    )
        .value = TextCellValue(
      'Pontos fora',
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow + 3,
      ),
    )
        .value = IntCellValue(
      pointsOut,
    );

    for (int offset = 1; offset <= 3; offset++) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: startRow + offset,
        ),
      )
          .cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex:
        ExcelColor.fromHexString('#2196F3'),
        verticalAlign: VerticalAlign.Center,
      );

      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: 1,
          rowIndex: startRow + offset,
        ),
      )
          .cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    return startRow + 5;
  }

  int addServiceStatsToPlayerSheet({
    required Excel excel,
    required String sheetName,
    required int startRow,
    required List<MatchEvent> events,
    required int playerId,
    required int? setNumber,
  }) {
    final sheet = excel[sheetName];

    final ace = countEvents(
      events: events,
      playerId: playerId,
      action: 'Serviço',
      result: 'Ace',
      setNumber: setNumber,
    );

    final positivo = countEvents(
      events: events,
      playerId: playerId,
      action: 'Serviço',
      result: 'Positivo',
      setNumber: setNumber,
    );

    final fraco = countEvents(
      events: events,
      playerId: playerId,
      action: 'Serviço',
      result: 'Fraco',
      setNumber: setNumber,
    );

    final erro = countEvents(
      events: events,
      playerId: playerId,
      action: 'Serviço',
      result: 'Erro',
      setNumber: setNumber,
    );

    final metrics = calculateServiceMetrics(
      events: events,
      playerId: playerId,
      setNumber: setNumber,
    );

    final rows = [
      ['SERVIÇO', ''],
      ['Ace', ace],
      ['Positivo', positivo],
      ['Fraco', fraco],
      ['Erro', erro],
      [
        'Eficácia',
        formatPercentage(
          metrics['efficiency'],
        ),
      ],
      [
        'Taxa de Acerto',
        formatPercentage(
          metrics['successRate'],
        ),
      ],
      [
        'Taxa de Erro',
        formatPercentage(
          metrics['errorRate'],
        ),
      ],
    ];

    sheet.merge(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow,
      ),
    );
    sheet.setRowHeight(startRow, 22);

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex:
      ExcelColor.fromHexString('#2196F3'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    for (int i = 0; i < rows.length; i++) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: startRow + i,
        ),
      )
          .value = TextCellValue(
        rows[i][0].toString(),
      );

      final value = rows[i][1];

      if (value is int) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: startRow + i,
          ),
        )
            .value = IntCellValue(value);
      } else if (value.toString().isNotEmpty) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: startRow + i,
          ),
        )
            .value = TextCellValue(
          value.toString(),
        );
      }
      final label =
      rows[i][0].toString().toLowerCase();

      CellStyle? rowStyle;

      if (label == 'ace' ||
          label == 'eficácia') {
        rowStyle = efficacyStyle;
      }

      if (label == 'positivo' ||
          label == 'fraco' ||
          label == 'taxa de acerto') {
        rowStyle = intermediateStyle;
      }

      if (label == 'erro' ||
          label == 'taxa de erro') {
        rowStyle = errorStyle;
      }

      if (rowStyle != null) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: startRow + i,
          ),
        )
            .cellStyle = rowStyle;

        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: startRow + i,
          ),
        )
            .cellStyle = rowStyle;
      }
    }

    return startRow + rows.length + 1;
  }

  int addReceptionStatsToPlayerSheet({
    required Excel excel,
    required String sheetName,
    required int startRow,
    required List<MatchEvent> events,
    required int playerId,
    required int? setNumber,
  }) {
    final sheet = excel[sheetName];

    final bolaA = countEvents(
      events: events,
      playerId: playerId,
      action: 'Receção',
      result: 'Bola A',
      setNumber: setNumber,
    );

    final bolaB = countEvents(
      events: events,
      playerId: playerId,
      action: 'Receção',
      result: 'Bola B',
      setNumber: setNumber,
    );

    final bolaC = countEvents(
      events: events,
      playerId: playerId,
      action: 'Receção',
      result: 'Bola C',
      setNumber: setNumber,
    );

    final erro = countEvents(
      events: events,
      playerId: playerId,
      action: 'Receção',
      result: 'Erro',
      setNumber: setNumber,
    );

    final metrics = calculateReceptionMetrics(
      events: events,
      playerId: playerId,
      setNumber: setNumber,
    );

    final rows = [
      ['RECEÇÃO', ''],
      ['Bola A', bolaA],
      ['Bola B', bolaB],
      ['Bola C', bolaC],
      ['Erro', erro],
      [
        'Eficácia',
        formatPercentage(
          metrics['efficiency'],
        ),
      ],
      [
        'Taxa de Acerto',
        formatPercentage(
          metrics['successRate'],
        ),
      ],
      [
        'Taxa de Erro',
        formatPercentage(
          metrics['errorRate'],
        ),
      ],
    ];

    sheet.merge(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow,
      ),
    );
    sheet.setRowHeight(startRow, 22);

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex:
      ExcelColor.fromHexString('#2196F3'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    for (int i = 0; i < rows.length; i++) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: startRow + i,
        ),
      )
          .value = TextCellValue(
        rows[i][0].toString(),
      );

      final value = rows[i][1];

      if (value is int) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: startRow + i,
          ),
        )
            .value = IntCellValue(value);
      } else if (value.toString().isNotEmpty) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: startRow + i,
          ),
        )
            .value = TextCellValue(
          value.toString(),
        );
      }
      final label =
      rows[i][0].toString().toLowerCase();

      CellStyle? rowStyle;

      if (label == 'bola a' ||
          label == 'eficácia') {
        rowStyle = efficacyStyle;
      }

      if (label == 'bola b' ||
          label == 'bola c' ||
          label == 'taxa de acerto') {
        rowStyle = intermediateStyle;
      }

      if (label == 'erro' ||
          label == 'taxa de erro') {
        rowStyle = errorStyle;
      }

      if (rowStyle != null) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: startRow + i,
          ),
        )
            .cellStyle = rowStyle;

        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: startRow + i,
          ),
        )
            .cellStyle = rowStyle;
      }
    }

    return startRow + rows.length + 1;
  }

  int addAttackStatsToPlayerSheet({
    required Excel excel,
    required String sheetName,
    required int startRow,
    required List<MatchEvent> events,
    required int playerId,
    required int? setNumber,
  }) {
    final sheet = excel[sheetName];

    final ponto = countEvents(
      events: events,
      playerId: playerId,
      action: 'Ataque',
      result: 'Ponto',
      setNumber: setNumber,
    );

    final continuacao = countEvents(
      events: events,
      playerId: playerId,
      action: 'Ataque',
      result: 'Continuação',
      setNumber: setNumber,
    );

    final bloqueado = countEvents(
      events: events,
      playerId: playerId,
      action: 'Ataque',
      result: 'Blocado',
      setNumber: setNumber,
    );

    final passeManchete = countEvents(
      events: events,
      playerId: playerId,
      action: 'Ataque',
      result: 'Passe/Manchete',
      setNumber: setNumber,
    );

    final erro = countEvents(
      events: events,
      playerId: playerId,
      action: 'Ataque',
      result: 'Erro',
      setNumber: setNumber,
    );

    final metrics = calculateAttackMetrics(
      events: events,
      playerId: playerId,
      setNumber: setNumber,
    );

    final rows = [
      ['ATAQUE', ''],
      ['Ponto', ponto],
      ['Continuação', continuacao],
      ['Blocado', bloqueado],
      ['Passe/Manchete', passeManchete],
      ['Erro', erro],
      [
        'Eficácia',
        formatPercentage(
          metrics['efficiency'],
        ),
      ],
      [
        'Taxa de Acerto',
        formatPercentage(
          metrics['successRate'],
        ),
      ],
      [
        'Taxa de Erro',
        formatPercentage(
          metrics['errorRate'],
        ),
      ],
    ];

    sheet.merge(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow,
      ),
    );
    sheet.setRowHeight(startRow, 22);

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex:
      ExcelColor.fromHexString('#2196F3'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    for (int i = 0; i < rows.length; i++) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: startRow + i,
        ),
      )
          .value = TextCellValue(
        rows[i][0].toString(),
      );

      final value = rows[i][1];

      if (value is int) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: startRow + i,
          ),
        )
            .value = IntCellValue(value);
      } else if (value.toString().isNotEmpty) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: startRow + i,
          ),
        )
            .value = TextCellValue(
          value.toString(),
        );
      }
      final label =
      rows[i][0].toString().toLowerCase();

      CellStyle? rowStyle;

      if (label == 'ponto' ||
          label == 'eficácia') {
        rowStyle = efficacyStyle;
      }

      if (label == 'continuação' ||
          label == 'passe/manchete' ||
          label == 'taxa de acerto') {
        rowStyle = intermediateStyle;
      }

      if (label == 'blocado' ||
          label == 'erro' ||
          label == 'taxa de erro') {
        rowStyle = errorStyle;
      }

      if (rowStyle != null) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: startRow + i,
          ),
        )
            .cellStyle = rowStyle;

        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: startRow + i,
          ),
        )
            .cellStyle = rowStyle;
      }
    }

    return startRow + rows.length + 1;
  }

  int addBlockStatsToPlayerSheet({
    required Excel excel,
    required String sheetName,
    required int startRow,
    required List<MatchEvent> events,
    required int playerId,
    required int? setNumber,
  }) {
    final sheet = excel[sheetName];

    final ponto = countEvents(
      events: events,
      playerId: playerId,
      action: 'Bloco',
      result: 'Ponto',
      setNumber: setNumber,
    );

    final toque = countEvents(
      events: events,
      playerId: playerId,
      action: 'Bloco',
      result: 'Toque',
      setNumber: setNumber,
    );

    final erro = countEvents(
      events: events,
      playerId: playerId,
      action: 'Bloco',
      result: 'Erro',
      setNumber: setNumber,
    );

    final metrics = calculateBlockMetrics(
      events: events,
      playerId: playerId,
      setNumber: setNumber,
    );

    final rows = [
      ['BLOCO', ''],
      ['Ponto', ponto],
      ['Toque', toque],
      ['Erro', erro],
      [
        'Eficácia',
        formatPercentage(
          metrics['efficiency'],
        ),
      ],
      [
        'Taxa de Acerto',
        formatPercentage(
          metrics['successRate'],
        ),
      ],
      [
        'Taxa de Erro',
        formatPercentage(
          metrics['errorRate'],
        ),
      ],
    ];

    sheet.merge(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow,
      ),
    );
    sheet.setRowHeight(startRow, 22);

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex:
      ExcelColor.fromHexString('#2196F3'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    for (int i = 0; i < rows.length; i++) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: startRow + i,
        ),
      )
          .value = TextCellValue(
        rows[i][0].toString(),
      );

      final value = rows[i][1];

      if (value is int) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: startRow + i,
          ),
        )
            .value = IntCellValue(value);
      } else if (value.toString().isNotEmpty) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: startRow + i,
          ),
        )
            .value = TextCellValue(
          value.toString(),
        );
      }
      final label =
      rows[i][0].toString().toLowerCase();

      CellStyle? rowStyle;

      if (label == 'ponto' ||
          label == 'eficácia') {
        rowStyle = efficacyStyle;
      }

      if (label == 'toque' ||
          label == 'taxa de acerto') {
        rowStyle = intermediateStyle;
      }

      if (label == 'erro' ||
          label == 'taxa de erro') {
        rowStyle = errorStyle;
      }

      if (rowStyle != null) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: startRow + i,
          ),
        )
            .cellStyle = rowStyle;

        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: startRow + i,
          ),
        )
            .cellStyle = rowStyle;
      }
    }

    return startRow + rows.length + 1;
  }

  int addDefenseStatsToPlayerSheet({
    required Excel excel,
    required String sheetName,
    required int startRow,
    required List<MatchEvent> events,
    required int playerId,
    required int? setNumber,
  }) {
    final sheet = excel[sheetName];

    final excelente = countEvents(
      events: events,
      playerId: playerId,
      action: 'Defesa',
      result: 'Excelente',
      setNumber: setNumber,
    );

    final positiva = countEvents(
      events: events,
      playerId: playerId,
      action: 'Defesa',
      result: 'Positiva',
      setNumber: setNumber,
    );

    final continuacao = countEvents(
      events: events,
      playerId: playerId,
      action: 'Defesa',
      result: 'Continuação',
      setNumber: setNumber,
    );

    final erro = countEvents(
      events: events,
      playerId: playerId,
      action: 'Defesa',
      result: 'Erro',
      setNumber: setNumber,
    );

    final metrics = calculateDefenseMetrics(
      events: events,
      playerId: playerId,
      setNumber: setNumber,
    );

    final rows = [
      ['DEFESA', ''],
      ['Excelente', excelente],
      ['Positiva', positiva],
      ['Continuação', continuacao],
      ['Erro', erro],
      [
        'Eficácia',
        formatPercentage(
          metrics['efficiency'],
        ),
      ],
      [
        'Taxa de Acerto',
        formatPercentage(
          metrics['successRate'],
        ),
      ],
      [
        'Taxa de Erro',
        formatPercentage(
          metrics['errorRate'],
        ),
      ],
    ];

    sheet.merge(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow,
      ),
    );
    sheet.setRowHeight(startRow, 22);

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex:
      ExcelColor.fromHexString('#2196F3'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    for (int i = 0; i < rows.length; i++) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: startRow + i,
        ),
      )
          .value = TextCellValue(
        rows[i][0].toString(),
      );

      final value = rows[i][1];

      if (value is int) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: startRow + i,
          ),
        )
            .value = IntCellValue(value);
      } else if (value.toString().isNotEmpty) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: startRow + i,
          ),
        )
            .value = TextCellValue(
          value.toString(),
        );
      }
      final label =
      rows[i][0].toString().toLowerCase();

      CellStyle? rowStyle;

      if (label == 'excelente' ||
          label == 'eficácia') {
        rowStyle = efficacyStyle;
      }

      if (label == 'positiva' ||
          label == 'continuação' ||
          label == 'taxa de acerto') {
        rowStyle = intermediateStyle;
      }

      if (label == 'erro' ||
          label == 'taxa de erro') {
        rowStyle = errorStyle;
      }

      if (rowStyle != null) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: startRow + i,
          ),
        )
            .cellStyle = rowStyle;

        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: startRow + i,
          ),
        )
            .cellStyle = rowStyle;
      }
    }

    return startRow + rows.length + 1;
  }


  int addDistributionStatsToPlayerSheet({
    required Excel excel,
    required String sheetName,
    required int startRow,
    required List<MatchEvent> events,
    required int playerId,
    required int? setNumber,
  }) {
    final sheet = excel[sheetName];

    final rows = <List<Object>>[
      [
        'Total de distribuições',
        countActionTotal(
          events: events,
          playerId: playerId,
          action: 'Distribuição',
          setNumber: setNumber,
        ),
      ],
      [
        'Zona: Entrada',
        countDistributionByZone(
          events: events,
          playerId: playerId,
          zone: 'Entrada',
          setNumber: setNumber,
        ),
      ],
      [
        'Zona: Central',
        countDistributionByZone(
          events: events,
          playerId: playerId,
          zone: 'Central',
          setNumber: setNumber,
        ),
      ],
      [
        'Zona: Oposto',
        countDistributionByZone(
          events: events,
          playerId: playerId,
          zone: 'Oposto',
          setNumber: setNumber,
        ),
      ],
      [
        'Zona: Pipe Zona 6',
        countDistributionByZone(
          events: events,
          playerId: playerId,
          zone: 'Pipe Zona 6',
          setNumber: setNumber,
        ),
      ],
      [
        'Zona: Pipe Zona 1',
        countDistributionByZone(
          events: events,
          playerId: playerId,
          zone: 'Pipe Zona 1',
          setNumber: setNumber,
        ),
      ],
      [
        'Tipo: Perfeita',
        countDistributionByType(
          events: events,
          playerId: playerId,
          type: 'Perfeita',
          setNumber: setNumber,
        ),
      ],
      [
        'Tipo: Interior',
        countDistributionByType(
          events: events,
          playerId: playerId,
          type: 'Interior',
          setNumber: setNumber,
        ),
      ],
      [
        'Tipo: Aberta',
        countDistributionByType(
          events: events,
          playerId: playerId,
          type: 'Aberta',
          setNumber: setNumber,
        ),
      ],
      [
        'Tipo: Baixa',
        countDistributionByType(
          events: events,
          playerId: playerId,
          type: 'Baixa',
          setNumber: setNumber,
        ),
      ],
      [
        'Tipo: Alta',
        countDistributionByType(
          events: events,
          playerId: playerId,
          type: 'Alta',
          setNumber: setNumber,
        ),
      ],
      [
        'Tipo: Cima da Rede',
        countDistributionByType(
          events: events,
          playerId: playerId,
          type: 'Cima da Rede',
          setNumber: setNumber,
        ),
      ],
      [
        'Tipo: Afastada da Rede',
        countDistributionByType(
          events: events,
          playerId: playerId,
          type: 'Afastada da Rede',
          setNumber: setNumber,
        ),
      ],
      [
        'Tipo: Erro',
        countDistributionByType(
          events: events,
          playerId: playerId,
          type: 'Erro',
          setNumber: setNumber,
        ),
      ],
    ];

    sheet.merge(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow,
      ),
    );

    sheet.setRowHeight(startRow, 22);

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
    )
        .value = TextCellValue('DISTRIBUIÇÃO');

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex:
      ExcelColor.fromHexString('#2196F3'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    for (int i = 0; i < rows.length; i++) {
      final rowIndex = startRow + i + 1;
      final label = rows[i][0].toString();
      final value = rows[i][1] as int;

      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: rowIndex,
        ),
      )
          .value = TextCellValue(label);

      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: 1,
          rowIndex: rowIndex,
        ),
      )
          .value = IntCellValue(value);

      CellStyle? rowStyle;

      if (label == 'Tipo: Perfeita') {
        rowStyle = efficacyStyle;
      } else if (label == 'Tipo: Erro') {
        rowStyle = errorStyle;
      } else if (label.startsWith('Tipo:')) {
        rowStyle = intermediateStyle;
      }

      if (rowStyle != null) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
            .cellStyle = rowStyle;

        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: rowIndex,
          ),
        )
            .cellStyle = rowStyle;
      }
    }

    return startRow + rows.length + 1;
  }

  Future<int> addSetToPlayerSheet({
    required Excel excel,
    required String sheetName,
    required int startRow,
    required int matchId,
    required int setNumber,
    required int playerId,
    required List<MatchEvent> events,
  }) async {
    var nextRow =
    await addSetParticipationToPlayerSheet(
      excel: excel,
      sheetName: sheetName,
      startRow: startRow,
      matchId: matchId,
      setNumber: setNumber,
      playerId: playerId,
    );

    nextRow = addServiceStatsToPlayerSheet(
      excel: excel,
      sheetName: sheetName,
      startRow: nextRow,
      events: events,
      playerId: playerId,
      setNumber: setNumber,
    );

    nextRow = addReceptionStatsToPlayerSheet(
      excel: excel,
      sheetName: sheetName,
      startRow: nextRow,
      events: events,
      playerId: playerId,
      setNumber: setNumber,
    );

    nextRow = addAttackStatsToPlayerSheet(
      excel: excel,
      sheetName: sheetName,
      startRow: nextRow,
      events: events,
      playerId: playerId,
      setNumber: setNumber,
    );

    nextRow = addBlockStatsToPlayerSheet(
      excel: excel,
      sheetName: sheetName,
      startRow: nextRow,
      events: events,
      playerId: playerId,
      setNumber: setNumber,
    );

    nextRow = addDefenseStatsToPlayerSheet(
      excel: excel,
      sheetName: sheetName,
      startRow: nextRow,
      events: events,
      playerId: playerId,
      setNumber: setNumber,
    );


    nextRow = addDistributionStatsToPlayerSheet(
      excel: excel,
      sheetName: sheetName,
      startRow: nextRow,
      events: events,
      playerId: playerId,
      setNumber: setNumber,
    );

    return nextRow;
  }

  Future<int> addMatchTotalToPlayerSheet({
    required Excel excel,
    required String sheetName,
    required int startRow,
    required int matchId,
    required int playerId,
    required List<MatchEvent> events,
  }) async {
    final sheet = excel[sheetName];

    final participationStats =
    await _participationRepository
        .getMatchParticipationStats(
      matchId: matchId,
    );

    final playerParticipation =
    participationStats[playerId];

    final pointsPlayed =
        playerParticipation?['pointsPlayed'] ?? 0;

    final pointsOut =
        playerParticipation?['pointsOut'] ?? 0;

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
    )
        .value = TextCellValue(
      'TOTAL DO JOGO',
    );

    sheet.merge(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow,
      ),
    );
    sheet.setRowHeight(startRow, 24);

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex:
      ExcelColor.fromHexString('#2196F3'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow + 1,
      ),
    )
        .value = TextCellValue(
      'Pontos jogados',
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow + 1,
      ),
    )
        .value = IntCellValue(
      pointsPlayed,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: startRow + 2,
      ),
    )
        .value = TextCellValue(
      'Pontos fora',
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: startRow + 2,
      ),
    )
        .value = IntCellValue(
      pointsOut,
    );

    for (int offset = 1; offset <= 2; offset++) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: startRow + offset,
        ),
      )
          .cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex:
        ExcelColor.fromHexString('#2196F3'),
        verticalAlign: VerticalAlign.Center,
      );

      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: 1,
          rowIndex: startRow + offset,
        ),
      )
          .cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    var nextRow = startRow + 4;

    nextRow = addServiceStatsToPlayerSheet(
      excel: excel,
      sheetName: sheetName,
      startRow: nextRow,
      events: events,
      playerId: playerId,
      setNumber: null,
    );

    nextRow = addReceptionStatsToPlayerSheet(
      excel: excel,
      sheetName: sheetName,
      startRow: nextRow,
      events: events,
      playerId: playerId,
      setNumber: null,
    );

    nextRow = addAttackStatsToPlayerSheet(
      excel: excel,
      sheetName: sheetName,
      startRow: nextRow,
      events: events,
      playerId: playerId,
      setNumber: null,
    );

    nextRow = addBlockStatsToPlayerSheet(
      excel: excel,
      sheetName: sheetName,
      startRow: nextRow,
      events: events,
      playerId: playerId,
      setNumber: null,
    );

    nextRow = addDefenseStatsToPlayerSheet(
      excel: excel,
      sheetName: sheetName,
      startRow: nextRow,
      events: events,
      playerId: playerId,
      setNumber: null,
    );


    nextRow = addDistributionStatsToPlayerSheet(
      excel: excel,
      sheetName: sheetName,
      startRow: nextRow,
      events: events,
      playerId: playerId,
      setNumber: null,
    );

    return nextRow;
  }

  int getPlayedSetCount(
      Match match,
      ) {
    return match.gcsSets +
        match.opponentSets;
  }

  Future<void> addMatchToSeasonSummary({
    required Excel excel,
    required String sheetName,
    required Match match,
    required int gameNumber,
    required int totalSeasonGames,
    required int playerId,
    required List<MatchEvent> events,
    required int playedSetCount,
  }) async {
    final sheet = excel[sheetName];

    // JOGO 1 = linha 6 do Excel (index 5)
    final gameRow = 4 + gameNumber;

    // Depois de todos os jogos fica a linha TOTAL
    final totalRow = 5 + totalSeasonGames;

    int setsPlayed = 0;

    for (
    int setNumber = 1;
    setNumber <= playedSetCount;
    setNumber++
    ) {
      final setParticipation =
      await _participationRepository
          .getSetParticipationStats(
        matchId: match.id!,
        setNumber: setNumber,
      );

      if (setParticipation[playerId] != null) {
        setsPlayed++;
      }
    }

    final matchParticipation =
    await _participationRepository
        .getMatchParticipationStats(
      matchId: match.id!,
    );

    final playerParticipation =
    matchParticipation[playerId];

    final pointsPlayed =
        playerParticipation?['pointsPlayed'] ?? 0;

    final pointsOut =
        playerParticipation?['pointsOut'] ?? 0;

    int eventCount(
        String action,
        String result,
        ) {
      return countEvents(
        events: events,
        playerId: playerId,
        action: action,
        result: result,
      );
    }

    // SERVIÇO
    final serviceAce =
    eventCount('Serviço', 'Ace');

    final servicePositive =
    eventCount('Serviço', 'Positivo');

    final serviceWeak =
    eventCount('Serviço', 'Fraco');

    final serviceError =
    eventCount('Serviço', 'Erro');

    // RECEÇÃO
    final receptionA =
    eventCount('Receção', 'Bola A');

    final receptionB =
    eventCount('Receção', 'Bola B');

    final receptionC =
    eventCount('Receção', 'Bola C');

    final receptionError =
    eventCount('Receção', 'Erro');

    // ATAQUE
    final attackPoint =
    eventCount('Ataque', 'Ponto');

    final attackContinuation =
    eventCount('Ataque', 'Continuação');

    final attackBlocked =
    eventCount('Ataque', 'Blocado');

    final attackPass =
    eventCount('Ataque', 'Passe/Manchete');

    final attackError =
    eventCount('Ataque', 'Erro');

    // BLOCO
    final blockPoint =
    eventCount('Bloco', 'Ponto');

    final blockTouch =
    eventCount('Bloco', 'Toque');

    final blockError =
    eventCount('Bloco', 'Erro');

    // DEFESA
    final defenseExcellent =
    eventCount('Defesa', 'Excelente');

    final defensePositive =
    eventCount('Defesa', 'Positiva');

    final defenseContinuation =
    eventCount('Defesa', 'Continuação');

    final defenseError =
    eventCount('Defesa', 'Erro');

    // DISTRIBUIÇÃO
    final distributionTotal = countActionTotal(
      events: events,
      playerId: playerId,
      action: 'Distribuição',
    );

    final distributionEntry = countDistributionByZone(
      events: events,
      playerId: playerId,
      zone: 'Entrada',
    );

    final distributionCentral = countDistributionByZone(
      events: events,
      playerId: playerId,
      zone: 'Central',
    );

    final distributionOpposite = countDistributionByZone(
      events: events,
      playerId: playerId,
      zone: 'Oposto',
    );

    final distributionPipe6 = countDistributionByZone(
      events: events,
      playerId: playerId,
      zone: 'Pipe Zona 6',
    );

    final distributionPipe1 = countDistributionByZone(
      events: events,
      playerId: playerId,
      zone: 'Pipe Zona 1',
    );

    final distributionPerfect = countDistributionByType(
      events: events,
      playerId: playerId,
      type: 'Perfeita',
    );

    final distributionInterior = countDistributionByType(
      events: events,
      playerId: playerId,
      type: 'Interior',
    );

    final distributionOpen = countDistributionByType(
      events: events,
      playerId: playerId,
      type: 'Aberta',
    );

    final distributionLow = countDistributionByType(
      events: events,
      playerId: playerId,
      type: 'Baixa',
    );

    final distributionHigh = countDistributionByType(
      events: events,
      playerId: playerId,
      type: 'Alta',
    );

    final distributionNet = countDistributionByType(
      events: events,
      playerId: playerId,
      type: 'Cima da Rede',
    );

    final distributionFar = countDistributionByType(
      events: events,
      playerId: playerId,
      type: 'Afastada da Rede',
    );

    final distributionError = countDistributionByType(
      events: events,
      playerId: playerId,
      type: 'Erro',
    );

    void writeInt(
        int row,
        int column,
        int value,
        ) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: column,
          rowIndex: row,
        ),
      )
          .value = IntCellValue(value);
    }

    void writeText(
        int row,
        int column,
        String value,
        ) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: column,
          rowIndex: row,
        ),
      )
          .value = TextCellValue(value);
    }

    void writePercentage(
        int row,
        int column,
        double? value,
        ) {
      writeText(
        row,
        column,
        formatPercentage(value),
      );
    }

    // =====================================================
    // LINHA DO JOGO
    // =====================================================

    writeText(
      gameRow,
      0,
      match.opponent,
    );

    writeText(
      gameRow,
      1,
      match.home ? 'Casa' : 'Fora',
    );

    writeInt(gameRow, 2, setsPlayed);
    writeInt(gameRow, 3, pointsPlayed);
    writeInt(gameRow, 4, pointsOut);

    // Serviço
    writeInt(gameRow, 5, serviceAce);
    writeInt(gameRow, 6, servicePositive);
    writeInt(gameRow, 7, serviceWeak);
    writeInt(gameRow, 8, serviceError);

    final serviceTotal =
        serviceAce +
            servicePositive +
            serviceWeak +
            serviceError;

    writePercentage(
      gameRow,
      9,
      calculateRate(
        serviceAce,
        serviceTotal,
      ),
    );

    writePercentage(
      gameRow,
      10,
      calculateRate(
        (3 * serviceAce) +
            (2 * servicePositive) +
            serviceWeak,
        3 * serviceTotal,
      ),
    );

    writePercentage(
      gameRow,
      11,
      calculateRate(
        serviceError,
        serviceTotal,
      ),
    );

    // Receção
    writeInt(gameRow, 12, receptionA);
    writeInt(gameRow, 13, receptionB);
    writeInt(gameRow, 14, receptionC);
    writeInt(gameRow, 15, receptionError);

    final receptionTotal =
        receptionA +
            receptionB +
            receptionC +
            receptionError;

    writePercentage(
      gameRow,
      16,
      calculateRate(
        receptionA,
        receptionTotal,
      ),
    );

    writePercentage(
      gameRow,
      17,
      calculateRate(
        (3 * receptionA) +
            (2 * receptionB) +
            receptionC,
        3 * receptionTotal,
      ),
    );

    writePercentage(
      gameRow,
      18,
      calculateRate(
        receptionError,
        receptionTotal,
      ),
    );

    // Ataque
    writeInt(gameRow, 19, attackPoint);
    writeInt(gameRow, 20, attackContinuation);
    writeInt(gameRow, 21, attackBlocked);
    writeInt(gameRow, 22, attackPass);
    writeInt(gameRow, 23, attackError);

    final attackTotal =
        attackPoint +
            attackContinuation +
            attackBlocked +
            attackPass +
            attackError;

    writePercentage(
      gameRow,
      24,
      calculateRate(
        attackPoint,
        attackTotal,
      ),
    );

    writePercentage(
      gameRow,
      25,
      calculateRate(
        (3 * attackPoint) +
            (2 * attackContinuation) +
            attackPass,
        3 * attackTotal,
      ),
    );

    writePercentage(
      gameRow,
      26,
      calculateRate(
        attackError + attackBlocked,
        attackTotal,
      ),
    );

    // Bloco
    writeInt(gameRow, 27, blockPoint);
    writeInt(gameRow, 28, blockTouch);
    writeInt(gameRow, 29, blockError);

    final blockTotal =
        blockPoint +
            blockTouch +
            blockError;

    writePercentage(
      gameRow,
      30,
      calculateRate(
        blockPoint,
        blockTotal,
      ),
    );

    writePercentage(
      gameRow,
      31,
      calculateRate(
        (2 * blockPoint) + blockTouch,
        2 * blockTotal,
      ),
    );

    writePercentage(
      gameRow,
      32,
      calculateRate(
        blockError,
        blockTotal,
      ),
    );

    // Defesa
    writeInt(gameRow, 33, defenseExcellent);
    writeInt(gameRow, 34, defensePositive);
    writeInt(gameRow, 35, defenseContinuation);
    writeInt(gameRow, 36, defenseError);

    final defenseTotal =
        defenseExcellent +
            defensePositive +
            defenseContinuation +
            defenseError;

    writePercentage(
      gameRow,
      37,
      calculateRate(
        defenseExcellent,
        defenseTotal,
      ),
    );

    writePercentage(
      gameRow,
      38,
      calculateRate(
        (3 * defenseExcellent) +
            (2 * defensePositive) +
            defenseContinuation,
        3 * defenseTotal,
      ),
    );

    writePercentage(
      gameRow,
      39,
      calculateRate(
        defenseError,
        defenseTotal,
      ),
    );

    // Distribuição
    writeInt(gameRow, 40, distributionTotal);

    writeInt(gameRow, 41, distributionEntry);
    writeInt(gameRow, 42, distributionCentral);
    writeInt(gameRow, 43, distributionOpposite);
    writeInt(gameRow, 44, distributionPipe6);
    writeInt(gameRow, 45, distributionPipe1);

    writeInt(gameRow, 46, distributionPerfect);
    writeInt(gameRow, 47, distributionInterior);
    writeInt(gameRow, 48, distributionOpen);
    writeInt(gameRow, 49, distributionLow);
    writeInt(gameRow, 50, distributionHigh);
    writeInt(gameRow, 51, distributionNet);
    writeInt(gameRow, 52, distributionFar);
    writeInt(gameRow, 53, distributionError);

    // =====================================================
    // TOTAL DA ÉPOCA
    // =====================================================

    int currentTotal(int column) {
      final value = sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: column,
          rowIndex: totalRow,
        ),
      )
          .value;

      if (value is IntCellValue) {
        return value.value;
      }

      return 0;
    }

    writeText(
      totalRow,
      0,
      'TOTAL',
    );

    writeText(
      totalRow,
      1,
      '',
    );

    final totalsToAdd = <int, int>{
      2: setsPlayed,
      3: pointsPlayed,
      4: pointsOut,

      5: serviceAce,
      6: servicePositive,
      7: serviceWeak,
      8: serviceError,

      12: receptionA,
      13: receptionB,
      14: receptionC,
      15: receptionError,

      19: attackPoint,
      20: attackContinuation,
      21: attackBlocked,
      22: attackPass,
      23: attackError,

      27: blockPoint,
      28: blockTouch,
      29: blockError,

      33: defenseExcellent,
      34: defensePositive,
      35: defenseContinuation,
      36: defenseError,

      40: distributionTotal,
      41: distributionEntry,
      42: distributionCentral,
      43: distributionOpposite,
      44: distributionPipe6,
      45: distributionPipe1,
      46: distributionPerfect,
      47: distributionInterior,
      48: distributionOpen,
      49: distributionLow,
      50: distributionHigh,
      51: distributionNet,
      52: distributionFar,
      53: distributionError,
    };

    for (final entry in totalsToAdd.entries) {
      writeInt(
        totalRow,
        entry.key,
        currentTotal(entry.key) +
            entry.value,
      );
    }

    // Serviço TOTAL
    final totalServiceAce =
    currentTotal(5);

    final totalServicePositive =
    currentTotal(6);

    final totalServiceWeak =
    currentTotal(7);

    final totalServiceError =
    currentTotal(8);

    final totalServiceActions =
        totalServiceAce +
            totalServicePositive +
            totalServiceWeak +
            totalServiceError;

    writePercentage(
      totalRow,
      9,
      calculateRate(
        totalServiceAce,
        totalServiceActions,
      ),
    );

    writePercentage(
      totalRow,
      10,
      calculateRate(
        (3 * totalServiceAce) +
            (2 * totalServicePositive) +
            totalServiceWeak,
        3 * totalServiceActions,
      ),
    );

    writePercentage(
      totalRow,
      11,
      calculateRate(
        totalServiceError,
        totalServiceActions,
      ),
    );

    // Receção TOTAL
    final totalReceptionA =
    currentTotal(12);

    final totalReceptionB =
    currentTotal(13);

    final totalReceptionC =
    currentTotal(14);

    final totalReceptionError =
    currentTotal(15);

    final totalReceptionActions =
        totalReceptionA +
            totalReceptionB +
            totalReceptionC +
            totalReceptionError;

    writePercentage(
      totalRow,
      16,
      calculateRate(
        totalReceptionA,
        totalReceptionActions,
      ),
    );

    writePercentage(
      totalRow,
      17,
      calculateRate(
        (3 * totalReceptionA) +
            (2 * totalReceptionB) +
            totalReceptionC,
        3 * totalReceptionActions,
      ),
    );

    writePercentage(
      totalRow,
      18,
      calculateRate(
        totalReceptionError,
        totalReceptionActions,
      ),
    );

    // Ataque TOTAL
    final totalAttackPoint =
    currentTotal(19);

    final totalAttackContinuation =
    currentTotal(20);

    final totalAttackBlocked =
    currentTotal(21);

    final totalAttackPass =
    currentTotal(22);

    final totalAttackError =
    currentTotal(23);

    final totalAttackActions =
        totalAttackPoint +
            totalAttackContinuation +
            totalAttackBlocked +
            totalAttackPass +
            totalAttackError;

    writePercentage(
      totalRow,
      24,
      calculateRate(
        totalAttackPoint,
        totalAttackActions,
      ),
    );

    writePercentage(
      totalRow,
      25,
      calculateRate(
        (3 * totalAttackPoint) +
            (2 * totalAttackContinuation) +
            totalAttackPass,
        3 * totalAttackActions,
      ),
    );

    writePercentage(
      totalRow,
      26,
      calculateRate(
        totalAttackError +
            totalAttackBlocked,
        totalAttackActions,
      ),
    );

    // Bloco TOTAL
    final totalBlockPoint =
    currentTotal(27);

    final totalBlockTouch =
    currentTotal(28);

    final totalBlockError =
    currentTotal(29);

    final totalBlockActions =
        totalBlockPoint +
            totalBlockTouch +
            totalBlockError;

    writePercentage(
      totalRow,
      30,
      calculateRate(
        totalBlockPoint,
        totalBlockActions,
      ),
    );

    writePercentage(
      totalRow,
      31,
      calculateRate(
        (2 * totalBlockPoint) +
            totalBlockTouch,
        2 * totalBlockActions,
      ),
    );

    writePercentage(
      totalRow,
      32,
      calculateRate(
        totalBlockError,
        totalBlockActions,
      ),
    );

    // Defesa TOTAL
    final totalDefenseExcellent =
    currentTotal(33);

    final totalDefensePositive =
    currentTotal(34);

    final totalDefenseContinuation =
    currentTotal(35);

    final totalDefenseError =
    currentTotal(36);

    final totalDefenseActions =
        totalDefenseExcellent +
            totalDefensePositive +
            totalDefenseContinuation +
            totalDefenseError;

    writePercentage(
      totalRow,
      37,
      calculateRate(
        totalDefenseExcellent,
        totalDefenseActions,
      ),
    );

    writePercentage(
      totalRow,
      38,
      calculateRate(
        (3 * totalDefenseExcellent) +
            (2 * totalDefensePositive) +
            totalDefenseContinuation,
        3 * totalDefenseActions,
      ),
    );

    writePercentage(
      totalRow,
      39,
      calculateRate(
        totalDefenseError,
        totalDefenseActions,
      ),
    );

    // =====================================================
    // ESTILO
    // =====================================================

    const greenColumns = [
      5, 9,
      12, 16,
      19, 24,
      27, 30,
      33, 37,
    ];

    const yellowColumns = [
      6, 7, 10,
      13, 14, 17,
      20, 22, 25,
      28, 31,
      34, 35, 38,
    ];

    const redColumns = [
      8, 11,
      15, 18,
      21, 23, 26,
      29, 32,
      36, 39, 53
    ];

    final thinBorder = Border(
      borderStyle: BorderStyle.Thin,
    );

    for (final row in [
      gameRow,
      totalRow,
    ]) {
      for (
      int column = 0;
      column <= 53;
      column++
      ) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: column,
            rowIndex: row,
          ),
        );

        CellStyle style;

        if (greenColumns.contains(column)) {
          style = efficacyStyle;
        } else if (
        yellowColumns.contains(column)) {
          style = intermediateStyle;
        } else if (
        redColumns.contains(column)) {
          style = errorStyle;
        } else {
          style = CellStyle(
            bold:
            row == totalRow ||
                column == 0,
            horizontalAlign:
            HorizontalAlign.Center,
            verticalAlign:
            VerticalAlign.Center,
          );
        }

        cell.cellStyle = style.copyWith(
          leftBorderVal: thinBorder,
          rightBorderVal: thinBorder,
          topBorderVal: thinBorder,
          bottomBorderVal: thinBorder,
        );
      }
    }
  }

  Future<void> addMatchToPlayerSheet({
    required Excel excel,
    required Player player,
    required Match match,
    required int gameNumber,
    required List<MatchEvent> events,
    required int finalGcsSets,
    required int finalOpponentSets,
    int totalSeasonGames = 1,
  }) async {
    final playerId = player.id;

    if (playerId == null) {
      return;
    }

    final sheetName = preparePlayerSheet(
      excel,
      player,
      totalSeasonGames: totalSeasonGames,
    );

    var nextRow = addMatchHeaderToPlayerSheet(
      excel: excel,
      sheetName: sheetName,
      match: match,
      gameNumber: gameNumber,
      finalGcsSets: finalGcsSets,
      finalOpponentSets: finalOpponentSets,
    );

    final playedSetCount =
        finalGcsSets + finalOpponentSets;

    await addMatchToSeasonSummary(
      excel: excel,
      sheetName: sheetName,
      match: match,
      gameNumber: gameNumber,
      totalSeasonGames: totalSeasonGames,
      playerId: playerId,
      events: events,
      playedSetCount: playedSetCount,
    );

    for (
    int setNumber = 1;
    setNumber <= playedSetCount;
    setNumber++
    ) {
      nextRow = await addSetToPlayerSheet(
        excel: excel,
        sheetName: sheetName,
        startRow: nextRow,
        matchId: match.id!,
        setNumber: setNumber,
        playerId: playerId,
        events: events,
      );
    }

    await addMatchTotalToPlayerSheet(
      excel: excel,
      sheetName: sheetName,
      startRow: nextRow,
      matchId: match.id!,
      playerId: playerId,
      events: events,
    );
  }

  void prepareMatchPlayersTable({
    required Excel excel,
    required String sheetName,
  }) {
    final sheet = excel[sheetName];

    sheet.frozenColumns = 2;

    final headers = [
      'Nº',
      'Atleta',
      'Em jogo',
      'Pontos jogados',
      'Pontos fora',

      'Serviço - Ace',
      'Serviço - Positivo',
      'Serviço - Fraco',
      'Serviço - Erro',
      'Serviço - Eficácia',
      'Serviço - Taxa de Acerto',
      'Serviço - Taxa de Erro',

      'Receção - Bola A',
      'Receção - Bola B',
      'Receção - Bola C',
      'Receção - Erro',
      'Receção - Eficácia',
      'Receção - Taxa de Acerto',
      'Receção - Taxa de Erro',

      'Ataque - Ponto',
      'Ataque - Continuação',
      'Ataque - Blocado',
      'Ataque - Passe/Manchete',
      'Ataque - Erro',
      'Ataque - Eficácia',
      'Ataque - Taxa de Acerto',
      'Ataque - Taxa de Erro',

      'Bloco - Ponto',
      'Bloco - Toque',
      'Bloco - Erro',
      'Bloco - Eficácia',
      'Bloco - Taxa de Acerto',
      'Bloco - Taxa de Erro',

      'Defesa - Excelente',
      'Defesa - Positiva',
      'Defesa - Continuação',
      'Defesa - Erro',
      'Defesa - Eficácia',
      'Defesa - Taxa de Acerto',
      'Defesa - Taxa de Erro',

      'Distribuição - Total',
      'Distribuição - Entrada',
      'Distribuição - Central',
      'Distribuição - Oposto',
      'Distribuição - Pipe Zona 6',
      'Distribuição - Pipe Zona 1',
      'Distribuição - Bola Perfeita',
      'Distribuição - Bola Interior',
      'Distribuição - Bola Aberta',
      'Distribuição - Bola Baixa',
      'Distribuição - Bola Alta',
      'Distribuição - Bola Cima da Rede',
      'Distribuição - Bola Afastada da Rede',
      'Distribuição - Bola Erro',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: i,
          rowIndex: 6,
        ),
      );

      for (int i = 0; i <= 4; i++) {
        sheet
            .cell(
          CellIndex.indexByColumnRow(
            columnIndex: i,
            rowIndex: 6,
          ),
        )
            .cellStyle = CellStyle(
          bold: true,
          fontColorHex: ExcelColor.white,
          backgroundColorHex:
          ExcelColor.fromHexString('#2196F3'),
          horizontalAlign:
          i == 1
              ? HorizontalAlign.Left
              : HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }

      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: 1,
          rowIndex: 6,
        ),
      )
          .cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex:
        ExcelColor.fromHexString('#2196F3'),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      cell.value = TextCellValue(headers[i]);

      cell.cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex:
        ExcelColor.fromHexString('#2196F3'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      if (headers[i].toLowerCase().contains('eficácia')) {
        cell.cellStyle = efficacyStyle;
      }

      if (headers[i].toLowerCase().contains('erro')) {
        cell.cellStyle = errorStyle;
      }

      if (headers[i].toLowerCase().contains('taxa de acerto')) {
        cell.cellStyle = intermediateStyle;
      }

      if (headers[i].toLowerCase().endsWith(' - ace')) {
        cell.cellStyle = efficacyStyle;
      }

      if (headers[i].toLowerCase() == 'receção - bola a') {
        cell.cellStyle = efficacyStyle;
      }

      if (headers[i].toLowerCase().endsWith(' - ponto')) {
        cell.cellStyle = efficacyStyle;
      }

      if (headers[i].toLowerCase().endsWith(' - excelente')) {
        cell.cellStyle = efficacyStyle;
      }

      if (headers[i].toLowerCase().endsWith(' - positivo')) {
        cell.cellStyle = intermediateStyle;
      }

      if (headers[i].toLowerCase().endsWith(' - fraco')) {
        cell.cellStyle = intermediateStyle;
      }

      if (headers[i].toLowerCase().endsWith(' - bola b')) {
        cell.cellStyle = intermediateStyle;
      }

      if (headers[i].toLowerCase().endsWith(' - bola c')) {
        cell.cellStyle = intermediateStyle;
      }

      if (headers[i].toLowerCase().endsWith(' - continuação')) {
        cell.cellStyle = intermediateStyle;
      }

      if (headers[i].toLowerCase().endsWith(' - passe/manchete')) {
        cell.cellStyle = intermediateStyle;
      }

      if (headers[i].toLowerCase().endsWith(' - toque')) {
        cell.cellStyle = intermediateStyle;
      }

      if (headers[i].toLowerCase().endsWith(' - positiva')) {
        cell.cellStyle = intermediateStyle;
      }

      if (headers[i].toLowerCase().endsWith(' - blocado')) {
        cell.cellStyle = errorStyle;
      }

      if (headers[i].toLowerCase().endsWith(' - bola perfeita')) {
        cell.cellStyle = efficacyStyle;
      }
    }

    sheet.setRowHeight(6, 30);

    for (int i = 0; i < headers.length; i++) {
      double width = headers[i].length.toDouble() + 4;

      if (i == 0) {
        width = 8; // Nº
      } else if (i == 1) {
        width = 22; // Atleta
      } else if (i == 2) {
        width = 12; // Em jogo
      } else if (i == 3) {
        width = 18; // Pontos jogados
      } else if (i == 4) {
        width = 16; // Pontos fora
      }

      if (width > 30) {
        width = 30;
      }

      sheet.setColumnWidth(i, width);
    }

  }

  Future<void> addPlayerParticipationToMatchTable({
    required Excel excel,
    required String sheetName,
    required int rowIndex,
    required int matchId,
    required Player player,
  }) async {
    final playerId = player.id;

    if (playerId == null) {
      return;
    }

    final sheet = excel[sheetName];

    final participationStats =
    await _participationRepository
        .getMatchParticipationStats(
      matchId: matchId,
    );

    final playerStats =
    participationStats[playerId];

    final inGame = playerStats != null;

    final pointsPlayed =
        playerStats?['pointsPlayed'] ?? 0;

    final pointsOut =
        playerStats?['pointsOut'] ?? 0;

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: rowIndex,
      ),
    )
        .value = TextCellValue(
      player.number.toString(),
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: rowIndex,
      ),
    )
        .value = TextCellValue(
      player.name,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 2,
        rowIndex: rowIndex,
      ),
    )
        .value = TextCellValue(
      inGame ? 'Sim' : 'Não',
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 3,
        rowIndex: rowIndex,
      ),
    )
        .value = IntCellValue(
      pointsPlayed,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 4,
        rowIndex: rowIndex,
      ),
    )
        .value = IntCellValue(
      pointsOut,
    );
  }

  void addPlayerServiceToMatchTable({
    required Excel excel,
    required String sheetName,
    required int rowIndex,
    required List<MatchEvent> events,
    required int playerId,
  }) {
    final sheet = excel[sheetName];

    final ace = countEvents(
      events: events,
      playerId: playerId,
      action: 'Serviço',
      result: 'Ace',
    );

    final positivo = countEvents(
      events: events,
      playerId: playerId,
      action: 'Serviço',
      result: 'Positivo',
    );

    final fraco = countEvents(
      events: events,
      playerId: playerId,
      action: 'Serviço',
      result: 'Fraco',
    );

    final erro = countEvents(
      events: events,
      playerId: playerId,
      action: 'Serviço',
      result: 'Erro',
    );

    final metrics = calculateServiceMetrics(
      events: events,
      playerId: playerId,
    );

    final values = [
      ace,
      positivo,
      fraco,
      erro,
      formatPercentage(
        metrics['efficiency'],
      ),
      formatPercentage(
        metrics['successRate'],
      ),
      formatPercentage(
        metrics['errorRate'],
      ),
    ];

    for (int i = 0; i < values.length; i++) {
      final value = values[i];

      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: 5 + i,
          rowIndex: rowIndex,
        ),
      );

      if (value is int) {
        cell.value = IntCellValue(value);
      } else {
        cell.value = TextCellValue(
          value.toString(),
        );
      }
    }
  }

  void addPlayerReceptionToMatchTable({
    required Excel excel,
    required String sheetName,
    required int rowIndex,
    required List<MatchEvent> events,
    required int playerId,
  }) {
    final sheet = excel[sheetName];

    final bolaA = countEvents(
      events: events,
      playerId: playerId,
      action: 'Receção',
      result: 'Bola A',
    );

    final bolaB = countEvents(
      events: events,
      playerId: playerId,
      action: 'Receção',
      result: 'Bola B',
    );

    final bolaC = countEvents(
      events: events,
      playerId: playerId,
      action: 'Receção',
      result: 'Bola C',
    );

    final erro = countEvents(
      events: events,
      playerId: playerId,
      action: 'Receção',
      result: 'Erro',
    );

    final metrics = calculateReceptionMetrics(
      events: events,
      playerId: playerId,
    );

    final values = [
      bolaA,
      bolaB,
      bolaC,
      erro,
      formatPercentage(
        metrics['efficiency'],
      ),
      formatPercentage(
        metrics['successRate'],
      ),
      formatPercentage(
        metrics['errorRate'],
      ),
    ];

    for (int i = 0; i < values.length; i++) {
      final value = values[i];

      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: 12 + i,
          rowIndex: rowIndex,
        ),
      );

      if (value is int) {
        cell.value = IntCellValue(value);
      } else {
        cell.value = TextCellValue(
          value.toString(),
        );
      }
    }
  }

  void addPlayerAttackToMatchTable({
    required Excel excel,
    required String sheetName,
    required int rowIndex,
    required List<MatchEvent> events,
    required int playerId,
  }) {
    final sheet = excel[sheetName];

    final ponto = countEvents(
      events: events,
      playerId: playerId,
      action: 'Ataque',
      result: 'Ponto',
    );

    final continuacao = countEvents(
      events: events,
      playerId: playerId,
      action: 'Ataque',
      result: 'Continuação',
    );

    final bloqueado = countEvents(
      events: events,
      playerId: playerId,
      action: 'Ataque',
      result: 'Blocado',
    );

    final passeManchete = countEvents(
      events: events,
      playerId: playerId,
      action: 'Ataque',
      result: 'Passe/Manchete',
    );

    final erro = countEvents(
      events: events,
      playerId: playerId,
      action: 'Ataque',
      result: 'Erro',
    );

    final metrics = calculateAttackMetrics(
      events: events,
      playerId: playerId,
    );

    final values = [
      ponto,
      continuacao,
      bloqueado,
      passeManchete,
      erro,
      formatPercentage(
        metrics['efficiency'],
      ),
      formatPercentage(
        metrics['successRate'],
      ),
      formatPercentage(
        metrics['errorRate'],
      ),
    ];

    for (int i = 0; i < values.length; i++) {
      final value = values[i];

      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: 19 + i,
          rowIndex: rowIndex,
        ),
      );

      if (value is int) {
        cell.value = IntCellValue(value);
      } else {
        cell.value = TextCellValue(
          value.toString(),
        );
      }
    }
  }

  void addPlayerBlockToMatchTable({
    required Excel excel,
    required String sheetName,
    required int rowIndex,
    required List<MatchEvent> events,
    required int playerId,
  }) {
    final sheet = excel[sheetName];

    final ponto = countEvents(
      events: events,
      playerId: playerId,
      action: 'Bloco',
      result: 'Ponto',
    );

    final toque = countEvents(
      events: events,
      playerId: playerId,
      action: 'Bloco',
      result: 'Toque',
    );

    final erro = countEvents(
      events: events,
      playerId: playerId,
      action: 'Bloco',
      result: 'Erro',
    );

    final metrics = calculateBlockMetrics(
      events: events,
      playerId: playerId,
    );

    final values = [
      ponto,
      toque,
      erro,
      formatPercentage(
        metrics['efficiency'],
      ),
      formatPercentage(
        metrics['successRate'],
      ),
      formatPercentage(
        metrics['errorRate'],
      ),
    ];

    for (int i = 0; i < values.length; i++) {
      final value = values[i];

      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: 27 + i,
          rowIndex: rowIndex,
        ),
      );

      if (value is int) {
        cell.value = IntCellValue(value);
      } else {
        cell.value = TextCellValue(
          value.toString(),
        );
      }
    }
  }

  void addPlayerDefenseToMatchTable({
    required Excel excel,
    required String sheetName,
    required int rowIndex,
    required List<MatchEvent> events,
    required int playerId,
  }) {
    final sheet = excel[sheetName];

    final excelente = countEvents(
      events: events,
      playerId: playerId,
      action: 'Defesa',
      result: 'Excelente',
    );

    final positiva = countEvents(
      events: events,
      playerId: playerId,
      action: 'Defesa',
      result: 'Positiva',
    );

    final continuacao = countEvents(
      events: events,
      playerId: playerId,
      action: 'Defesa',
      result: 'Continuação',
    );

    final erro = countEvents(
      events: events,
      playerId: playerId,
      action: 'Defesa',
      result: 'Erro',
    );

    final metrics = calculateDefenseMetrics(
      events: events,
      playerId: playerId,
    );

    final values = [
      excelente,
      positiva,
      continuacao,
      erro,
      formatPercentage(
        metrics['efficiency'],
      ),
      formatPercentage(
        metrics['successRate'],
      ),
      formatPercentage(
        metrics['errorRate'],
      ),
    ];

    for (int i = 0; i < values.length; i++) {
      final value = values[i];

      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: 33 + i,
          rowIndex: rowIndex,
        ),
      );

      if (value is int) {
        cell.value = IntCellValue(value);
      } else {
        cell.value = TextCellValue(
          value.toString(),
        );
      }
    }
  }


  void addPlayerDistributionToMatchTable({
    required Excel excel,
    required String sheetName,
    required int rowIndex,
    required List<MatchEvent> events,
    required int playerId,
  }) {
    final sheet = excel[sheetName];

    final values = [
      countActionTotal(
        events: events,
        playerId: playerId,
        action: 'Distribuição',
      ),
      countDistributionByZone(
        events: events,
        playerId: playerId,
        zone: 'Entrada',
      ),
      countDistributionByZone(
        events: events,
        playerId: playerId,
        zone: 'Central',
      ),
      countDistributionByZone(
        events: events,
        playerId: playerId,
        zone: 'Oposto',
      ),
      countDistributionByZone(
        events: events,
        playerId: playerId,
        zone: 'Pipe Zona 6',
      ),
      countDistributionByZone(
        events: events,
        playerId: playerId,
        zone: 'Pipe Zona 1',
      ),
      countDistributionByType(
        events: events,
        playerId: playerId,
        type: 'Perfeita',
      ),
      countDistributionByType(
        events: events,
        playerId: playerId,
        type: 'Interior',
      ),
      countDistributionByType(
        events: events,
        playerId: playerId,
        type: 'Aberta',
      ),
      countDistributionByType(
        events: events,
        playerId: playerId,
        type: 'Baixa',
      ),
      countDistributionByType(
        events: events,
        playerId: playerId,
        type: 'Alta',
      ),
      countDistributionByType(
        events: events,
        playerId: playerId,
        type: 'Cima da Rede',
      ),
      countDistributionByType(
        events: events,
        playerId: playerId,
        type: 'Afastada da Rede',
      ),
      countDistributionByType(
        events: events,
        playerId: playerId,
        type: 'Erro',
      ),
    ];

    for (int i = 0; i < values.length; i++) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: 40 + i,
          rowIndex: rowIndex,
        ),
      )
          .value = IntCellValue(values[i]);
    }
  }

  Future<void> addPlayerToMatchTable({
    required Excel excel,
    required String sheetName,
    required int rowIndex,
    required int matchId,
    required Player player,
    required List<MatchEvent> events,
  }) async {
    final playerId = player.id;

    if (playerId == null) {
      return;
    }

    await addPlayerParticipationToMatchTable(
      excel: excel,
      sheetName: sheetName,
      rowIndex: rowIndex,
      matchId: matchId,
      player: player,
    );

    addPlayerServiceToMatchTable(
      excel: excel,
      sheetName: sheetName,
      rowIndex: rowIndex,
      events: events,
      playerId: playerId,
    );

    addPlayerReceptionToMatchTable(
      excel: excel,
      sheetName: sheetName,
      rowIndex: rowIndex,
      events: events,
      playerId: playerId,
    );

    addPlayerAttackToMatchTable(
      excel: excel,
      sheetName: sheetName,
      rowIndex: rowIndex,
      events: events,
      playerId: playerId,
    );

    addPlayerBlockToMatchTable(
      excel: excel,
      sheetName: sheetName,
      rowIndex: rowIndex,
      events: events,
      playerId: playerId,
    );

    addPlayerDefenseToMatchTable(
      excel: excel,
      sheetName: sheetName,
      rowIndex: rowIndex,
      events: events,
      playerId: playerId,
    );

    addPlayerDistributionToMatchTable(
      excel: excel,
      sheetName: sheetName,
      rowIndex: rowIndex,
      events: events,
      playerId: playerId,
    );

    final sheet = excel[sheetName];

    for (int columnIndex = 0;
    columnIndex < 54;
    columnIndex++) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
      )
          .cellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    final greenColumns = [
      5, 9,        // Serviço
      12, 16,      // Receção
      19, 24,      // Ataque
      27, 30,      // Bloco
      33, 37,      // Defesa
    ];

    final yellowColumns = [
      6, 7, 10,    // Serviço
      13, 14, 17,  // Receção
      20, 22, 25,  // Ataque
      28, 31,      // Bloco
      34, 35, 38,  // Defesa
    ];

    final redColumns = [
      8, 11,       // Serviço
      15, 18,      // Receção
      21, 23, 26,  // Ataque
      29, 32,      // Bloco
      36, 39,      // Defesa
    ];

    for (final columnIndex in greenColumns) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
      )
          .cellStyle = efficacyStyle;
    }

    for (final columnIndex in yellowColumns) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
      )
          .cellStyle = intermediateStyle;
    }

    for (final columnIndex in redColumns) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
      )
          .cellStyle = errorStyle;
    }

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: rowIndex,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: rowIndex,
      ),
    )
        .cellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final thinBorder = Border(
      borderStyle: BorderStyle.Thin,
    );

    for (int columnIndex = 0;
    columnIndex < 54;
    columnIndex++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
      );

      cell.cellStyle =
          (cell.cellStyle ?? CellStyle()).copyWith(
            leftBorderVal: thinBorder,
            rightBorderVal: thinBorder,
            topBorderVal: thinBorder,
            bottomBorderVal: thinBorder,
          );
    }
  }

  Future<void> addPlayersToMatchTable({
    required Excel excel,
    required String sheetName,
    required int matchId,
    required List<Player> players,
    required List<MatchEvent> events,
  }) async {
    final sheet = excel[sheetName];

    const firstPlayerRow = 7;
    var rowIndex = firstPlayerRow;

    for (final player in players) {
      await addPlayerToMatchTable(
        excel: excel,
        sheetName: sheetName,
        rowIndex: rowIndex,
        matchId: matchId,
        player: player,
        events: events,
      );

      rowIndex++;
    }

    if (players.isEmpty) {
      return;
    }

    // A primeira linha depois das atletas
    // será a linha TOTAL.
    final totalRow = rowIndex;

    int readInt(
        int row,
        int column,
        ) {
      final value = sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: column,
          rowIndex: row,
        ),
      )
          .value;

      if (value is IntCellValue) {
        return value.value;
      }

      return 0;
    }

    int sumColumn(int column) {
      int total = 0;

      for (
      int row = firstPlayerRow;
      row < totalRow;
      row++
      ) {
        total += readInt(
          row,
          column,
        );
      }

      return total;
    }

    void writeInt(
        int column,
        int value,
        ) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: column,
          rowIndex: totalRow,
        ),
      )
          .value = IntCellValue(value);
    }

    void writeText(
        int column,
        String value,
        ) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: column,
          rowIndex: totalRow,
        ),
      )
          .value = TextCellValue(value);
    }

    void writePercentage(
        int column,
        double? value,
        ) {
      writeText(
        column,
        formatPercentage(value),
      );
    }

    // ==========================================
    // IDENTIFICAÇÃO / PARTICIPAÇÃO
    // ==========================================

    writeText(1, 'TOTAL');

    writeInt(
      3,
      sumColumn(3),
    );

    writeInt(
      4,
      sumColumn(4),
    );

    // ==========================================
    // SERVIÇO
    // ==========================================

    final serviceAce =
    sumColumn(5);

    final servicePositive =
    sumColumn(6);

    final serviceWeak =
    sumColumn(7);

    final serviceError =
    sumColumn(8);

    final serviceTotal =
        serviceAce +
            servicePositive +
            serviceWeak +
            serviceError;

    writeInt(5, serviceAce);
    writeInt(6, servicePositive);
    writeInt(7, serviceWeak);
    writeInt(8, serviceError);

    writePercentage(
      9,
      calculateRate(
        serviceAce,
        serviceTotal,
      ),
    );

    writePercentage(
      10,
      calculateRate(
        (3 * serviceAce) +
            (2 * servicePositive) +
            serviceWeak,
        3 * serviceTotal,
      ),
    );

    writePercentage(
      11,
      calculateRate(
        serviceError,
        serviceTotal,
      ),
    );

    // ==========================================
    // RECEÇÃO
    // ==========================================

    final receptionA =
    sumColumn(12);

    final receptionB =
    sumColumn(13);

    final receptionC =
    sumColumn(14);

    final receptionError =
    sumColumn(15);

    final receptionTotal =
        receptionA +
            receptionB +
            receptionC +
            receptionError;

    writeInt(12, receptionA);
    writeInt(13, receptionB);
    writeInt(14, receptionC);
    writeInt(15, receptionError);

    writePercentage(
      16,
      calculateRate(
        receptionA,
        receptionTotal,
      ),
    );

    writePercentage(
      17,
      calculateRate(
        (3 * receptionA) +
            (2 * receptionB) +
            receptionC,
        3 * receptionTotal,
      ),
    );

    writePercentage(
      18,
      calculateRate(
        receptionError,
        receptionTotal,
      ),
    );

    // ==========================================
    // ATAQUE
    // ==========================================

    final attackPoint =
    sumColumn(19);

    final attackContinuation =
    sumColumn(20);

    final attackBlocked =
    sumColumn(21);

    final attackPass =
    sumColumn(22);

    final attackError =
    sumColumn(23);

    final attackTotal =
        attackPoint +
            attackContinuation +
            attackBlocked +
            attackPass +
            attackError;

    writeInt(19, attackPoint);
    writeInt(20, attackContinuation);
    writeInt(21, attackBlocked);
    writeInt(22, attackPass);
    writeInt(23, attackError);

    writePercentage(
      24,
      calculateRate(
        attackPoint,
        attackTotal,
      ),
    );

    writePercentage(
      25,
      calculateRate(
        (3 * attackPoint) +
            (2 * attackContinuation) +
            attackPass,
        3 * attackTotal,
      ),
    );

    writePercentage(
      26,
      calculateRate(
        attackError +
            attackBlocked,
        attackTotal,
      ),
    );

    // ==========================================
    // BLOCO
    // ==========================================

    final blockPoint =
    sumColumn(27);

    final blockTouch =
    sumColumn(28);

    final blockError =
    sumColumn(29);

    final blockTotal =
        blockPoint +
            blockTouch +
            blockError;

    writeInt(27, blockPoint);
    writeInt(28, blockTouch);
    writeInt(29, blockError);

    writePercentage(
      30,
      calculateRate(
        blockPoint,
        blockTotal,
      ),
    );

    writePercentage(
      31,
      calculateRate(
        (2 * blockPoint) +
            blockTouch,
        2 * blockTotal,
      ),
    );

    writePercentage(
      32,
      calculateRate(
        blockError,
        blockTotal,
      ),
    );

    // ==========================================
    // DEFESA
    // ==========================================

    final defenseExcellent =
    sumColumn(33);

    final defensePositive =
    sumColumn(34);

    final defenseContinuation =
    sumColumn(35);

    final defenseError =
    sumColumn(36);

    final defenseTotal =
        defenseExcellent +
            defensePositive +
            defenseContinuation +
            defenseError;

    writeInt(33, defenseExcellent);
    writeInt(34, defensePositive);
    writeInt(35, defenseContinuation);
    writeInt(36, defenseError);

    writePercentage(
      37,
      calculateRate(
        defenseExcellent,
        defenseTotal,
      ),
    );

    writePercentage(
      38,
      calculateRate(
        (3 * defenseExcellent) +
            (2 * defensePositive) +
            defenseContinuation,
        3 * defenseTotal,
      ),
    );

    writePercentage(
      39,
      calculateRate(
        defenseError,
        defenseTotal,
      ),
    );

    // ==========================================
    // DISTRIBUIÇÃO
    // ==========================================

    for (int column = 40; column < 54; column++) {
      writeInt(
        column,
        sumColumn(column),
      );
    }

    // ==========================================
    // ESTILO DA LINHA TOTAL
    // ==========================================

    const greenColumns = [
      5, 9,
      12, 16,
      19, 24,
      27, 30,
      33, 37,
    ];

    const yellowColumns = [
      6, 7, 10,
      13, 14, 17,
      20, 22, 25,
      28, 31,
      34, 35, 38,
    ];

    const redColumns = [
      8, 11,
      15, 18,
      21, 23, 26,
      29, 32,
      36, 39, 53
    ];

    final thinBorder = Border(
      borderStyle: BorderStyle.Thin,
    );

    for (
    int column = 0;
    column < 54;
    column++
    ) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: column,
          rowIndex: totalRow,
        ),
      );

      CellStyle style;

      if (greenColumns.contains(column)) {
        style = efficacyStyle;
      } else if (
      yellowColumns.contains(column)) {
        style = intermediateStyle;
      } else if (
      redColumns.contains(column)) {
        style = errorStyle;
      } else {
        style = CellStyle(
          bold: true,
          horizontalAlign:
          column == 1
              ? HorizontalAlign.Left
              : HorizontalAlign.Center,
          verticalAlign:
          VerticalAlign.Center,
        );
      }

      cell.cellStyle = style.copyWith(
        leftBorderVal: thinBorder,
        rightBorderVal: thinBorder,
        topBorderVal: thinBorder,
        bottomBorderVal: thinBorder,
      );
    }
  }



  void prepareDistributionAnalysisSheet(Excel excel) {
    const sheetName = 'Análise de Distribuição';

    if (excel.sheets.containsKey(sheetName)) {
      excel.delete(sheetName);
    }

    final sheet = excel[sheetName];

    sheet.cell(CellIndex.indexByString('A1')).value =
        TextCellValue('ANÁLISE DE DISTRIBUIÇÃO');

    sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.fromHexString('#1565C0'),
    );

    sheet.cell(CellIndex.indexByString('A2')).value =
        TextCellValue(
          'Resumo da época, análise individual por jogo e relação entre '
              'distribuição e qualidade da receção/defesa.',
        );

    sheet.setColumnWidth(0, 24);
    sheet.setColumnWidth(1, 12);
    sheet.setColumnWidth(2, 24);
    sheet.setColumnWidth(3, 20);
    sheet.setColumnWidth(4, 18);
    sheet.setColumnWidth(5, 22);
    sheet.setColumnWidth(6, 25);
    sheet.setColumnWidth(7, 16);
    sheet.setColumnWidth(8, 18);
    sheet.setColumnWidth(9, 30);
    sheet.setColumnWidth(10, 20);
    sheet.setColumnWidth(11, 28);
    sheet.setColumnWidth(12, 16);
    sheet.setColumnWidth(13, 0);

    sheet.setRowHeight(0, 30);
    sheet.setRowHeight(1, 30);
  }


  String distributionRallyQuality({
    required MatchEvent distributionEvent,
    required List<MatchEvent> events,
  }) {
    final rallyId = distributionEvent.rallyId;

    if (rallyId == null || distributionEvent.id == null) {
      return 'Sem receção/defesa associada';
    }

    final relatedEvents = events
        .where((event) =>
    event.matchId == distributionEvent.matchId &&
        event.setNumber == distributionEvent.setNumber &&
        event.rallyId == rallyId &&
        event.id != null)
        .toList()
      ..sort((a, b) => a.id!.compareTo(b.id!));

    final distributionIndex = relatedEvents.indexWhere(
          (event) => event.id == distributionEvent.id,
    );

    if (distributionIndex == -1) {
      return 'Sem receção/defesa associada';
    }

    // 1. Confirmar que existe um ataque depois da distribuição.
    var hasAttackAfter = false;

    for (var i = distributionIndex + 1;
    i < relatedEvents.length;
    i++) {
      final event = relatedEvents[i];

      if (event.action == 'Ataque') {
        hasAttackAfter = true;
        break;
      }

      if (event.action == 'Receção' || event.action == 'Defesa') {
        break;
      }
    }

    if (!hasAttackAfter) {
      return 'Sem receção/defesa associada';
    }

    // 2. Procurar a receção ou defesa anterior à distribuição.
    for (var i = distributionIndex - 1; i >= 0; i--) {
      final event = relatedEvents[i];

      if (event.action == 'Ataque') {
        break;
      }

      if (event.action == 'Receção' || event.action == 'Defesa') {
        return '${event.action}: ${event.result}';
      }
    }

    return 'Sem receção/defesa associada';
  }


  void clearDistributionRowsForMatch({
    required Excel excel,
    required int matchId,
  }) {
    const sheetName = 'Análise de Distribuição';

    if (!excel.sheets.containsKey(sheetName)) {
      return;
    }

    final sheet = excel[sheetName];

    for (var rowIndex = 4; rowIndex < sheet.maxRows; rowIndex++) {

      final observationCell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: 13,
          rowIndex: rowIndex,
        ),
      );

      final observation = observationCell.value;

      if (observation is IntCellValue &&
          observation.value == matchId) {
        for (var column = 0; column < 14; column++) {
          sheet
              .cell(
            CellIndex.indexByColumnRow(
              columnIndex: column,
              rowIndex: rowIndex,
            ),
          )
              .value = TextCellValue('');
        }
      }
    }
  }


  void addDistributionEventRows({
    required Excel excel,
    required String scope,
    required String matchLabel,
    int? matchId,
    required List<Player> players,
    required List<MatchEvent> events,
  }) {
    const sheetName = 'Análise de Distribuição';

    const zones = [
      'Entrada',
      'Central',
      'Oposto',
      'Pipe Zona 6',
      'Pipe Zona 1',
    ];

    final sheet = excel[sheetName];
    var rowIndex = sheet.maxRows < 3 ? 3 : sheet.maxRows;

    void writeCell(int column, int row, CellValue value) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: column,
          rowIndex: row,
        ),
      )
          .value = value;
    }

    void writeTitle(String title) {
      writeCell(0, rowIndex, TextCellValue(title));

      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: rowIndex,
        ),
      )
          .cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        fontColorHex: ExcelColor.fromHexString('#1565C0'),
      );

      rowIndex++;
    }

    void writeHeaders(List<String> headers) {
      for (var column = 0; column < headers.length; column++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: column,
            rowIndex: rowIndex,
          ),
        );

        cell.value = TextCellValue(headers[column]);
        cell.cellStyle = CellStyle(
          bold: true,
          fontColorHex: ExcelColor.white,
          backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          textWrapping: TextWrapping.WrapText,
        );
      }

      sheet.setRowHeight(rowIndex, 36);
      rowIndex++;
    }

    final setterIds = players
        .where((player) {
      String normalize(String? position) {
        return (position ?? '')
            .trim()
            .toLowerCase()
            .replaceAll('í', 'i');
      }

      final primary = normalize(player.primaryPosition);
      final secondary = normalize(player.secondaryPosition);

      return primary == 'distribuidor' ||
          secondary == 'distribuidor' ||
          primary == 'libero' ||
          secondary == 'libero';
    })
        .map((player) => player.id)
        .whereType<int>()
        .toSet();

    final distributionEvents = events
        .where((event) =>
    event.action == 'Distribuição' &&
        setterIds.contains(event.playerId) &&
        (matchId == null || event.matchId == matchId))
        .toList();

    final playerIds = distributionEvents
        .map((event) => event.playerId)
        .toSet()
        .toList()
      ..sort();

    final isSeason = scope == 'Época';

    writeTitle(
      isSeason
          ? '1.º QUADRO — TOTAL DA ÉPOCA'
          : 'JOGO — $matchLabel',
    );

    // QUADRO 1: totais por passadora e zona
    writeHeaders([
      'Jogo',
      'Set',
      'Passadora',
      'Zona de ataque',
      'N.º distribuições',
      '% do total da passadora',
      'Tipo de distribuição',
      'N.º por tipo',
      '% dentro da zona',
      'Qualidade da receção/defesa',
      'N.º de ocorrências',
      '% das distribuições associadas',
    ]);

    final playerNames = <int, String>{};

    for (final playerId in playerIds) {
      final matchingPlayers =
      players.where((player) => player.id == playerId);

      playerNames[playerId] = matchingPlayers.isEmpty
          ? 'Jogadora $playerId'
          : matchingPlayers.first.name;
    }

    // RESUMO POR PASSADORA/LÍBERO E ZONA DE ATAQUE

    for (final playerId in playerIds) {
      final playerEvents = distributionEvents
          .where((event) => event.playerId == playerId)
          .toList();

      final setNumbers = isSeason
          ? <int>[-1]
          : (playerEvents
          .map((event) => event.setNumber)
          .toSet()
          .toList()
        ..sort());

      for (final setNumber in setNumbers) {
        final setEvents = isSeason
            ? playerEvents
            : playerEvents
            .where((event) => event.setNumber == setNumber)
            .toList();

        final totalPlayerDistributions = setEvents.length;

        for (final zone in zones) {
          final zoneTotal = setEvents
              .where(
                (event) =>
            distributionZoneFromResult(event.result) == zone,
          )
              .length;

          if (zoneTotal == 0) continue;

          final values = <CellValue>[
            TextCellValue(isSeason ? 'Época' : matchLabel),
            isSeason
                ? TextCellValue('Época')
                : IntCellValue(setNumber),
            TextCellValue(playerNames[playerId]!),
            TextCellValue(zone),
            IntCellValue(zoneTotal),
            TextCellValue(
              totalPlayerDistributions == 0
                  ? '—'
                  : '${(zoneTotal / totalPlayerDistributions * 100)
                  .toStringAsFixed(1)}%',
            ),
          ];

          for (var column = 0; column < values.length; column++) {
            writeCell(column, rowIndex, values[column]);
          }

          if (!isSeason && matchId != null) {
            writeCell(13, rowIndex, IntCellValue(matchId));
          }

          rowIndex++;
        }
      }
    }

// Espaço entre o resumo e o detalhe.
    rowIndex += 2;

// QUADRO 2: análise por qualidade da receção/defesa
    writeTitle(
      isSeason
          ? '2.º QUADRO — DISTRIBUIÇÃO POR QUALIDADE DA RECEÇÃO/DEFESA'
          : 'ANÁLISE — $matchLabel',
    );

    writeHeaders([
      'Jogo',
      'Passadora',
      'Qualidade da receção/defesa',
      'Zona de ataque',
      'N.º de distribuições',
      'Tipo de distribuição',
      'N.º por tipo',
      '% dentro da zona',
    ]);

    for (final playerId in playerIds) {
      final playerEvents = distributionEvents
          .where((event) => event.playerId == playerId)
          .toList();

      final groupedCounts = <String, int>{};
      final groupedTypeCounts = <String, int>{};

      for (final event in playerEvents) {
        final zone = distributionZoneFromResult(event.result);
        if (zone.isEmpty) continue;

        final quality = distributionRallyQuality(
          distributionEvent: event,
          events: events,
        );

        final qualityLabel =
        quality.startsWith('Sem receção/defesa') ||
            quality.startsWith('Sem rallyId')
            ? 'Sem associação'
            : quality;

        final groupKey = '$qualityLabel\u0000$zone';
        groupedCounts[groupKey] =
            (groupedCounts[groupKey] ?? 0) + 1;

        final eventTypes =
        distributionTypesFromResult(event.result).toSet();

        for (final type in eventTypes) {
          final typeKey = '$groupKey\u0000$type';
          groupedTypeCounts[typeKey] =
              (groupedTypeCounts[typeKey] ?? 0) + 1;
        }
      }

      for (final entry in groupedCounts.entries) {
        final parts = entry.key.split('\u0000');
        final quality = parts[0];
        final zone = parts[1];
        final zoneTotal = entry.value;

        final typeEntries = groupedTypeCounts.entries
            .where((item) =>
            item.key.startsWith('${entry.key}\u0000'))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        if (typeEntries.isEmpty) {
          final values = <CellValue>[
            TextCellValue(isSeason ? 'Época' : matchLabel),
            TextCellValue(playerNames[playerId]!),
            TextCellValue(quality),
            TextCellValue(zone),
            IntCellValue(zoneTotal),
            TextCellValue('Sem tipo registado'),
            IntCellValue(0),
            TextCellValue('—'),
          ];

          for (var column = 0; column < values.length; column++) {
            writeCell(column, rowIndex, values[column]);
          }

          if (!isSeason && matchId != null) {
            writeCell(13, rowIndex, IntCellValue(matchId));
          }

          rowIndex++;
          continue;
        }

        for (final typeEntry in typeEntries) {
          final type = typeEntry.key
              .split('\u0000')
              .last;
          final typeTotal = typeEntry.value;

          final values = <CellValue>[
            TextCellValue(isSeason ? 'Época' : matchLabel),
            TextCellValue(playerNames[playerId]!),
            TextCellValue(quality),
            TextCellValue(zone),
            IntCellValue(zoneTotal),
            TextCellValue(type),
            IntCellValue(typeTotal),
            TextCellValue(
              zoneTotal == 0
                  ? '—'
                  : '${(typeTotal / zoneTotal * 100).toStringAsFixed(1)}%',
            ),
          ];

          for (var column = 0; column < values.length; column++) {
            writeCell(column, rowIndex, values[column]);
          }

          if (!isSeason && matchId != null) {
            writeCell(13, rowIndex, IntCellValue(matchId));
          }

          rowIndex++;
        }
      }
    }

// Espaço entre o resumo e os quadros seguintes.
    rowIndex += 2;
  }

  Future<Uint8List> exportMatch({
    required Match match,
    required List<Player> players,
    required List<MatchEvent> events,
    required int finalGcsSets,
    required int finalOpponentSets,
    bool includePlayerSheets = true,
  }) async {
    final matchId = match.id;

    if (matchId == null) {
      throw Exception(
        'Não é possível exportar um jogo sem ID.',
      );
    }

    final excel = await loadOrCreateExcel();

    prepareResumoSheet(excel);

    if (!excel.sheets.containsKey('Análise de Distribuição')) {
      prepareDistributionAnalysisSheet(excel);
    }

    addMatchToResumo(
      excel,
      match,
      finalGcsSets: finalGcsSets,
      finalOpponentSets: finalOpponentSets,
    );

    final gameNumber = getGameNumber(
      excel: excel,
      matchId: matchId,
    );

    final matchSheetName =
    prepareMatchSheet(
      excel,
      match,
      finalGcsSets: finalGcsSets,
      finalOpponentSets: finalOpponentSets,
    );

    prepareMatchPlayersTable(
      excel: excel,
      sheetName: matchSheetName,
    );

    await addPlayersToMatchTable(
      excel: excel,
      sheetName: matchSheetName,
      matchId: matchId,
      players: players,
      events: events,
    );

    if (includePlayerSheets) {
      for (final player in players) {
        await addMatchToPlayerSheet(
          excel: excel,
          player: player,
          match: match,
          gameNumber: gameNumber,
          events: events,
          finalGcsSets: finalGcsSets,
          finalOpponentSets: finalOpponentSets,
        );
      }
    }

    clearDistributionRowsForMatch(
      excel: excel,
      matchId: matchId,
    );

    addDistributionEventRows(
      excel: excel,
      scope: 'Jogo',
      matchLabel: match.opponent,
      matchId: matchId,
      players: players,
      events: events,
    );

    final bytes = await saveExcel(excel);

    if (bytes == null) {
      throw Exception('Não foi possível gerar o ficheiro Excel.');
    }

    return bytes;
  }

  Future<void> exportPlayerSheetsForMatch({
    required Match match,
    required List<Player> players,
    required List<MatchEvent> events,
    required int finalGcsSets,
    required int finalOpponentSets,
  }) async {
    final matchId = match.id;

    if (matchId == null) {
      return;
    }

    final excel = await loadOrCreateExcel();

    final gameNumber = getGameNumber(
      excel: excel,
      matchId: matchId,
    );

    for (final player in players) {
      await addMatchToPlayerSheet(
        excel: excel,
        player: player,
        match: match,
        gameNumber: gameNumber,
        events: events,
        finalGcsSets: finalGcsSets,
        finalOpponentSets: finalOpponentSets,
      );
    }

    await saveExcel(excel);
  }

  int? findMatchRowInResumo({
    required Excel excel,
    required int matchId,
  }) {
    final sheet = excel['RESUMO'];

    for (int rowIndex = 3;
    rowIndex < sheet.maxRows;
    rowIndex++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: 51,
          rowIndex: rowIndex,
        ),
      );

      final value = cell.value;

      if (value is IntCellValue &&
          value.value == matchId) {
        return rowIndex;
      }
    }

    return null;
  }

  int getGameNumber({
    required Excel excel,
    required int matchId,
  }) {
    final existingRow = findMatchRowInResumo(
      excel: excel,
      matchId: matchId,
    );

    if (existingRow != null) {
      return existingRow - 2;
    }

    final resumoSheet = excel['RESUMO'];

    return resumoSheet.maxRows - 2;
  }

  int? findMatchStartRowInPlayerSheet({
    required Excel excel,
    required String sheetName,
    required int matchId,
  }) {
    final sheet = excel[sheetName];

    for (
    int rowIndex = 0;
    rowIndex < sheet.maxRows;
    rowIndex++
    ) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: 51,
          rowIndex: rowIndex,
        ),
      );

      final value = cell.value;

      if (value is IntCellValue &&
          value.value == matchId) {
        return rowIndex;
      }
    }

    return null;
  }

  Future<Uint8List> exportAllMatches({
    required List<Match> matches,
    required Map<int, List<Player>> playersByMatch,
    required Map<int, List<MatchEvent>> eventsByMatch,
  }) async {
    await resetExcelFile();

    final excel = await loadOrCreateExcel();

    prepareResumoSheet(excel);
    prepareDistributionAnalysisSheet(excel);

    // PRIMEIRO:
    // RESUMO + todas as folhas dos jogos

    // 1.º: preparar o resumo e as folhas de cada jogo
    for (final match in matches) {
      final matchId = match.id;

      if (matchId == null) {
        continue;
      }

      final players = playersByMatch[matchId] ?? [];
      final events = eventsByMatch[matchId] ?? [];

      addMatchToResumo(
        excel,
        match,
        finalGcsSets: match.gcsSets,
        finalOpponentSets: match.opponentSets,
      );

      final matchSheetName = prepareMatchSheet(
        excel,
        match,
        finalGcsSets: match.gcsSets,
        finalOpponentSets: match.opponentSets,
      );

      prepareMatchPlayersTable(
        excel: excel,
        sheetName: matchSheetName,
      );

      await addPlayersToMatchTable(
        excel: excel,
        sheetName: matchSheetName,
        matchId: matchId,
        players: players,
        events: events,
      );
    }

    // 2.º: acumular os dados de todos os jogos da época
    final allEvents = eventsByMatch.values
        .expand((matchEvents) => matchEvents)
        .toList();

    final allPlayers = playersByMatch.values
        .expand((matchPlayers) => matchPlayers)
        .toList();

    addDistributionEventRows(
      excel: excel,
      scope: 'Época',
      matchLabel: 'Acumulado da época',
      players: allPlayers,
      events: allEvents,
    );

    // 3.º: acrescentar os jogos do mais recente para o mais antigo
    final distributionMatches = [...matches]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    for (final match in distributionMatches) {
      final matchId = match.id;

      if (matchId == null) {
        continue;
      }

      addDistributionEventRows(
        excel: excel,
        scope: 'Jogo',
        matchLabel: match.opponent,
        matchId: matchId,
        players: playersByMatch[matchId] ?? [],
        events: eventsByMatch[matchId] ?? [],
      );
    }


    // DEPOIS:
    // todas as folhas das jogadoras
    for (final match in matches.reversed) {
      final matchId = match.id;

      if (matchId == null) {
        continue;
      }

      final players =
          playersByMatch[matchId] ?? [];

      final events =
          eventsByMatch[matchId] ?? [];

      final gameNumber = getGameNumber(
        excel: excel,
        matchId: matchId,
      );

      for (final player in players) {
        await addMatchToPlayerSheet(
          excel: excel,
          player: player,
          match: match,
          gameNumber: gameNumber,
          events: events,
          finalGcsSets: match.gcsSets,
          finalOpponentSets:
          match.opponentSets,
          totalSeasonGames: matches.length,
        );
      }
    }

    // GRAVA SÓ UMA VEZ
    final bytes = await saveExcel(excel);

    if (bytes == null) {
      throw Exception('Não foi possível gerar o ficheiro Excel.');
    }

    return bytes;
  }
}
