/// Статическое описание бумаги в портфеле.
class StockConfig {
  const StockConfig({
    required this.ticker,
    required this.name,
    required this.targetWeight,
    this.lotSize = 1,
  });

  final String ticker;
  final String name;
  final int lotSize;

  /// Относительный вес. Доли нормализуются в [PortfolioCalculator.normalizedTargets].
  final double targetWeight;
}

const List<StockConfig> stockCatalog = [
  StockConfig(ticker: 'X5', name: 'Икс 5', targetWeight: 12.5),
  StockConfig(ticker: 'LKOH', name: 'Лукойл', targetWeight: 12.5),

  StockConfig(ticker: 'NVTK', name: 'Новатэк', targetWeight: 12.5),

  StockConfig(ticker: 'OZON', name: 'OZON', targetWeight: 12.5),

  StockConfig(ticker: 'PLZL', name: 'Полюс', targetWeight: 12.5),

  StockConfig(ticker: 'SBERP', name: 'Сбербанк', targetWeight: 12.5),

  StockConfig(ticker: 'T', name: 'Т-Технологии', targetWeight: 12.5),

  StockConfig(ticker: 'YDEX', name: 'Yandex', targetWeight: 12.5),
];
