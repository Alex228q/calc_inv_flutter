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
  StockConfig(ticker: 'IRAO', name: 'Интер РАО', lotSize: 100, targetWeight: 5),
  StockConfig(ticker: 'X5', name: 'Икс 5', targetWeight: 8),
  StockConfig(ticker: 'LKOH', name: 'Лукойл', targetWeight: 7),
  StockConfig(
    ticker: 'MOEX',
    name: 'Московская Биржа',
    lotSize: 10,
    targetWeight: 7,
  ),
  StockConfig(ticker: 'NVTK', name: 'Новатэк', targetWeight: 7),
  StockConfig(ticker: 'OZON', name: 'OZON', targetWeight: 5),
  StockConfig(ticker: 'PLZL', name: 'Полюс', targetWeight: 8),
  StockConfig(ticker: 'LSNGP', name: 'Ленэнерго', lotSize: 10, targetWeight: 5),
  StockConfig(ticker: 'SBERP', name: 'Сбербанк', targetWeight: 10),
  StockConfig(ticker: 'T', name: 'Т-Технологии', targetWeight: 8),
  StockConfig(ticker: 'TATNP', name: 'Татнефть', targetWeight: 7),
  StockConfig(ticker: 'PHOR', name: 'ФосАгро', targetWeight: 8),
  StockConfig(ticker: 'HEAD', name: 'Хэдхантер', targetWeight: 5),
  StockConfig(ticker: 'YDEX', name: 'Yandex', targetWeight: 10),
];
