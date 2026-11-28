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
  StockConfig(ticker: 'X5', name: 'Икс 5', targetWeight: 10),
  StockConfig(ticker: 'LKOH', name: 'Лукойл', targetWeight: 12),
  StockConfig(ticker: 'MDMG', name: 'Мать и дитя', targetWeight: 7),
  StockConfig(ticker: 'MOEX', name: 'Мосбиржа', lotSize: 10, targetWeight: 8),

  StockConfig(ticker: 'NVTK', name: 'Новатэк', targetWeight: 10),

  StockConfig(ticker: 'PLZL', name: 'Полюс', targetWeight: 9),

  StockConfig(ticker: 'SBERP', name: 'Сбербанк', targetWeight: 13),

  StockConfig(ticker: 'T', name: 'Т-Технологии', targetWeight: 11),
  StockConfig(ticker: 'PHOR', name: 'Фосагро', targetWeight: 9),

  StockConfig(ticker: 'YDEX', name: 'Yandex', targetWeight: 11),
];
