import 'package:flutter/material.dart';

/// Оценка бумаги по отклонению от SMA200.
class StockRating {
  const StockRating(this.label, this.color);

  final String label;
  final Color color;

  static const noData = StockRating('Нет данных', Colors.grey);

  static final StockRating _extremelyOver = StockRating(
    'Крайне переоценена',
    Colors.red.shade700,
  );

  /// (верхняя граница отклонения в %, рейтинг) — по возрастанию.
  static final List<(double, StockRating)> _bands = [
    (-15.0, StockRating('Крайне недооценена', Colors.green.shade900)),
    (-10.0, StockRating('Сильно недооценена', Colors.green.shade700)),
    (-5.0, StockRating('Умеренно недооценена', Colors.green.shade500)),
    (-2.0, StockRating('Слегка недооценена', Colors.green.shade300)),
    (2.0, const StockRating('Около справедливой', Colors.grey)),
    (5.0, StockRating('Слегка переоценена', Colors.orange.shade300)),
    (10.0, StockRating('Умеренно переоценена', Colors.orange.shade500)),
    (15.0, StockRating('Сильно переоценена', Colors.red.shade300)),
  ];

  static StockRating fromDeviation(double? deviation) {
    if (deviation == null) return noData;
    for (final (limit, rating) in _bands) {
      if (deviation < limit) return rating;
    }
    return _extremelyOver;
  }
}
