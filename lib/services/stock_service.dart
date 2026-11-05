import 'package:flutter/foundation.dart';
import '../core/indicators.dart';
import '../data/stock_catalog.dart';
import '../models/stock.dart';
import 'moex_api_client.dart';

/// Собирает [Stock] из каталога + данных MOEX (цена и SMA200).
class StockService {
  StockService({MoexApiClient? api, List<StockConfig> catalog = stockCatalog})
    : _api = api ?? MoexApiClient(),
      _catalog = catalog;

  static const _smaPeriod = 200;

  final MoexApiClient _api;
  final List<StockConfig> _catalog;

  /// Порядок результата соответствует каталогу; бумаги без цены пропускаются.
  Future<List<Stock>> fetchStocks() async {
    final results = await Future.wait(_catalog.map(_loadStock));
    return results.whereType<Stock>().toList();
  }

  Future<Stock?> _loadStock(StockConfig config) async {
    final ticker = config.ticker;
    try {
      // Цена и свечи грузятся параллельно.
      final priceFuture = _api.fetchLastPrice(ticker);
      final closesFuture = _loadCloses(ticker);

      final price = await priceFuture;
      final closes = await closesFuture;
      if (price == null) {
        debugPrint('$ticker: цена недоступна, бумага пропущена');
        return null;
      }

      final sma = closes == null
          ? null
          : simpleMovingAverage(closes, _smaPeriod);
      return Stock(
        secId: ticker,
        shortName: config.name,
        lastPrice: price,
        lotSize: config.lotSize,
        targetWeight: config.targetWeight,
        sma200: sma,
        deviationFromSma: sma == null ? null : (price - sma) / sma * 100,
      );
    } catch (e) {
      debugPrint('$ticker: ошибка загрузки цены: $e');
      return null;
    }
  }

  /// Ошибка свечей не должна ронять загрузку цены — вернём null.
  Future<List<double>?> _loadCloses(String ticker) async {
    try {
      return await _api.fetchDailyCloses(ticker);
    } catch (e) {
      debugPrint('$ticker: ошибка загрузки свечей: $e');
      return null;
    }
  }

  void dispose() => _api.dispose();
}
