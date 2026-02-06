
class Stock {
  final String secId;
  final double lastPrice;
  final String shortName;
  final int lotSize;
  final double? sma200; // Добавляем SMA200
  final double? deviationFromSma; // Отклонение от SMA в процентах

  Stock({
    required this.secId,
    required this.lastPrice,
    required this.shortName,
    required this.lotSize,
    this.sma200,
    this.deviationFromSma,
  });

  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      secId: json['SECID'] ?? json['secId'],
      shortName: json['SECNAME'] ?? json['shortName'],
      lastPrice:
          double.tryParse(
            json['PREVPRICE']?.toString() ??
                json['lastPrice']?.toString() ??
                '0',
          ) ??
          0.0,
      lotSize: int.tryParse(json['lotSize']?.toString() ?? '1') ?? 1,
      sma200: json['sma200'] != null
          ? double.tryParse(json['sma200'].toString())
          : null,
      deviationFromSma: json['deviationFromSma'] != null
          ? double.tryParse(json['deviationFromSma'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'secId': secId,
      'lastPrice': lastPrice,
      'shortName': shortName,
      'lotSize': lotSize,
      'sma200': sma200,
      'deviationFromSma': deviationFromSma,
    };
  }

  Stock copyWith({
    String? secId,
    double? lastPrice,
    String? shortName,
    int? lotSize,
    double? sma200,
    double? deviationFromSma,
  }) {
    return Stock(
      secId: secId ?? this.secId,
      lastPrice: lastPrice ?? this.lastPrice,
      shortName: shortName ?? this.shortName,
      lotSize: lotSize ?? this.lotSize,
      sma200: sma200 ?? this.sma200,
      deviationFromSma: deviationFromSma ?? this.deviationFromSma,
    );
  }

  @override
  String toString() {
    return 'Stock{secId: $secId, lastPrice: $lastPrice, shortName: $shortName, lotSize: $lotSize, sma200: $sma200, deviationFromSma: $deviationFromSma}';
  }
}
