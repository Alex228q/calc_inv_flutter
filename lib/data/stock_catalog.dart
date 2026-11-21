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
    targetWeight: 4,
  ),
  StockConfig(ticker: 'RAGR', name: 'Русагро', targetWeight: 4),
  StockConfig(ticker: 'DOMRF', name: 'ДОМ.РФ', targetWeight: 4),
  StockConfig(ticker: 'IRAO', name: 'Интер РАО', lotSize: 100, targetWeight: 4),
  StockConfig(ticker: 'X5', name: 'Икс 5', targetWeight: 4),
  StockConfig(ticker: 'LKOH', name: 'Лукойл', targetWeight: 4),
  StockConfig(ticker: 'MDMG', name: 'Мать и дитя', targetWeight: 4),

  StockConfig(
    ticker: 'MOEX',
    name: 'Московская Биржа',
    lotSize: 10,
    targetWeight: 4,
  ),
  StockConfig(ticker: 'MTSS', name: 'МТС', lotSize: 10, targetWeight: 4),
  StockConfig(ticker: 'NVTK', name: 'Новатэк', targetWeight: 4),
  StockConfig(ticker: 'GMKN', name: 'Норникель', lotSize: 10, targetWeight: 4),
  StockConfig(ticker: 'OZON', name: 'OZON', targetWeight: 4),

  StockConfig(ticker: 'PLZL', name: 'Полюс', targetWeight: 4),
  StockConfig(ticker: 'ROSN', name: 'Роснефть', targetWeight: 4),
  StockConfig(ticker: 'LSNGP', name: 'Ленэнерго', lotSize: 10, targetWeight: 4),

  StockConfig(ticker: 'SBERP', name: 'Сбербанк', targetWeight: 4),
  StockConfig(ticker: 'CHMF', name: 'Северсталь', targetWeight: 4),
  StockConfig(ticker: 'FLOT', name: 'Совкомфлот', lotSize: 10, targetWeight: 4),

  StockConfig(
    ticker: 'SNGSP',
    name: 'Сургутнефтегаз',
    lotSize: 10,
    targetWeight: 4,
  ),
  StockConfig(ticker: 'T', name: 'Т-Технологии', targetWeight: 4),
  StockConfig(ticker: 'TATNP', name: 'Татнефть', targetWeight: 4),
  StockConfig(ticker: 'TRNFP', name: 'Транснефть', targetWeight: 4),
  StockConfig(ticker: 'PHOR', name: 'ФосАгро', targetWeight: 4),
  StockConfig(ticker: 'HEAD', name: 'HeadHanter', targetWeight: 4),

  StockConfig(ticker: 'YDEX', name: 'Yandex', targetWeight: 4),
];
