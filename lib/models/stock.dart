class Stock {
  const Stock({
    required this.secId,
    required this.shortName,
    required this.lastPrice,
    required this.lotSize,
    required this.targetWeight,
    this.sma200,
    this.deviationFromSma,
  });

  final String secId;
  final String shortName;
  final double lastPrice;
  final int lotSize;

  /// Сырой вес из каталога (до нормализации в проценты).
  final double targetWeight;

  final double? sma200;

  /// Отклонение цены от SMA200 в процентах.
  final double? deviationFromSma;

  double get lotCost => lastPrice * lotSize;

  @override
  String toString() =>
      'Stock($secId, price: $lastPrice, lot: $lotSize, sma200: $sma200, dev: $deviationFromSma)';
}
