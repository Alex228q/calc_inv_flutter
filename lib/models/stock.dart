class Stock {
  final String secId;
  final double lastPrice;
  final String shortName;
  final int lotSize;

  Stock({
    required this.secId,
    required this.lastPrice,
    required this.shortName,
    required this.lotSize,
  });

  @override
  String toString() {
    return 'Stock{secId: $secId, lastPrice: $lastPrice, shortName: $shortName, lotSize: $lotSize}';
  }
}
