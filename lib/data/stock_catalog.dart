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
  StockConfig(
    ticker: 'BSPB',
    name: 'Банк Санкт-Петербург',
    lotSize: 10,
    targetWeight: 5,
  ),
  StockConfig(ticker: 'IRAO', name: 'Интер РАО', lotSize: 100, targetWeight: 5),
  StockConfig(ticker: 'X5', name: 'Икс 5', targetWeight: 5),
  StockConfig(ticker: 'LKOH', name: 'Лукойл', targetWeight: 5),
  StockConfig(ticker: 'MDMG', name: 'Мать и дитя', targetWeight: 5),

  StockConfig(
    ticker: 'MOEX',
    name: 'Московская Биржа',
    lotSize: 10,
    targetWeight: 5,
  ),
  StockConfig(ticker: 'NVTK', name: 'Новатэк', targetWeight: 5),
  StockConfig(ticker: 'GMKN', name: 'Норникель', lotSize: 10, targetWeight: 5),
  StockConfig(ticker: 'OZON', name: 'OZON', targetWeight: 5),

  StockConfig(ticker: 'PLZL', name: 'Полюс', targetWeight: 5),
  StockConfig(ticker: 'ROSN', name: 'Роснефть', targetWeight: 5),
  StockConfig(ticker: 'LSNGP', name: 'Ленэнерго', lotSize: 10, targetWeight: 5),

  StockConfig(ticker: 'SBERP', name: 'Сбербанк', targetWeight: 5),
  StockConfig(ticker: 'CHMF', name: 'Северсталь', targetWeight: 5),
  StockConfig(ticker: 'FLOT', name: 'Совкомфлот', lotSize: 10, targetWeight: 5),

  StockConfig(ticker: 'T', name: 'Т-Технологии', targetWeight: 5),
  StockConfig(ticker: 'TATNP', name: 'Татнефть', targetWeight: 5),
  StockConfig(ticker: 'PHOR', name: 'ФосАгро', targetWeight: 5),
  StockConfig(ticker: 'HEAD', name: 'Хэдхантер', targetWeight: 5),

  StockConfig(ticker: 'YDEX', name: 'Yandex', targetWeight: 5),
];
