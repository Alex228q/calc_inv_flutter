import 'dart:convert';
import 'package:http/http.dart' as http;

class MoexException implements Exception {
  MoexException(this.message);
  final String message;

  @override
  String toString() => 'MoexException: $message';
}

/// Тонкий клиент MOEX ISS: только HTTP и разбор JSON, без бизнес-логики.
class MoexApiClient {
  MoexApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const _host = 'iss.moex.com';
  static const _timeout = Duration(seconds: 10);

  final http.Client _client;

  /// Последняя цена (LAST), а если торгов нет — цена предыдущего дня.
  /// null, если цену получить не удалось.
  Future<double?> fetchLastPrice(String ticker) async {
    final data = await _getJson(
      '/iss/engines/stock/markets/shares/boards/TQBR/securities/$ticker.json',
      {
        'iss.meta': 'off',
        'securities.columns': 'SECID,SECNAME,PREVPRICE',
        'marketdata.columns': 'LAST',
      },
    );

    final last = _firstRowCell(data['marketdata'], column: 0);
    if (last != null && last > 0) return last;

    final previous = _firstRowCell(data['securities'], column: 2);
    return (previous != null && previous > 0) ? previous : null;
  }

  /// Дневные цены закрытия за последние [days] календарных дней.
  Future<List<double>> fetchDailyCloses(String ticker, {int days = 400}) async {
    final till = DateTime.now();
    final from = till.subtract(Duration(days: days));

    final data = await _getJson(
      '/iss/engines/stock/markets/shares/securities/$ticker/candles.json',
      {
        'interval': '24',
        'from': _formatDate(from),
        'till': _formatDate(till),
        'start': '0',
      },
    );

    final candles = data['candles'];
    if (candles is! Map<String, dynamic>) return const [];

    final columns = List<String>.from(candles['columns'] as List);
    final closeIndex = columns.indexWhere((c) => c.toLowerCase() == 'close');
    if (closeIndex == -1) {
      throw MoexException('В свечах $ticker нет колонки close');
    }

    final rows = candles['data'] as List? ?? const [];
    final closes = <double>[];
    for (final row in rows) {
      if (row is! List || row.length <= closeIndex) continue;
      final close = double.tryParse('${row[closeIndex]}');
      if (close != null && close > 0) closes.add(close);
    }
    return closes;
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, String> query,
  ) async {
    final response = await _client
        .get(Uri.https(_host, path, query))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw MoexException('HTTP ${response.statusCode} для $path');
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  double? _firstRowCell(Object? section, {required int column}) {
    if (section is! Map<String, dynamic>) return null;
    final rows = section['data'];
    if (rows is! List || rows.isEmpty) return null;
    final row = rows.first;
    if (row is! List || row.length <= column) return null;
    return double.tryParse('${row[column]}');
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void dispose() => _client.close();
}
