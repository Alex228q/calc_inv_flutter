import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/stock.dart';

class StockService {
  static const List<Map<String, String>> _stocksInfo = [
    {'ticker': 'X5', 'name': 'X5', 'lotSize': '1'},
    {'ticker': 'MDMG', 'name': 'Мать и дитя', 'lotSize': '1'},
    {'ticker': 'NVTK', 'name': 'Новатэк', 'lotSize': '1'},
    {'ticker': 'GMKN', 'name': 'Норникель', 'lotSize': '10'},
    {'ticker': 'PLZL', 'name': 'Полюс', 'lotSize': '1'},
    {'ticker': 'SBERP', 'name': 'Сбербанк', 'lotSize': '1'},
    {'ticker': 'CHMF', 'name': 'Северсталь', 'lotSize': '1'},
    {'ticker': 'TATNP', 'name': 'Татнефть', 'lotSize': '1'},
    {'ticker': 'PHOR', 'name': 'Фосагро', 'lotSize': '1'},
    {'ticker': 'YDEX', 'name': 'Yandex', 'lotSize': '1'},
  ];

  Future<List<Stock>> fetchStockPrices() async {
    final List<Stock> loadedStocks = [];

    // Используем параллельную загрузку для повышения производительности
    final List<Future<Stock?>> futures = [];

    for (var stockInfo in _stocksInfo) {
      final ticker = stockInfo['ticker']!;
      final lotSize = int.parse(stockInfo['lotSize']!);

      futures.add(_fetchStockWithSma(ticker, lotSize, stockInfo['name']!));
    }

    final results = await Future.wait(futures);

    for (var stock in results) {
      if (stock != null) {
        loadedStocks.add(stock);
      }
    }

    return loadedStocks;
  }

  Future<Stock?> _fetchStockWithSma(
    String ticker,
    int lotSize,
    String name,
  ) async {
    try {
      // Сначала получаем текущую цену
      final price = await _fetchStockPrice(ticker);
      if (price == null) return null;

      // Параллельно получаем SMA данные
      final smaFuture = _fetchSma200(ticker, price);

      // Ждем SMA или используем таймаут
      Map<String, double>? smaResult;
      try {
        smaResult = await smaFuture.timeout(const Duration(seconds: 10));
      } catch (e) {
        print('Таймаут при получении SMA для $ticker: $e');
      }

      double? sma200;
      double? deviationFromSma;

      if (smaResult != null) {
        sma200 = smaResult['sma200'];
        deviationFromSma = smaResult['deviation'];
      }

      return Stock(
        secId: ticker,
        shortName: name,
        lastPrice: price,
        lotSize: lotSize,
        sma200: sma200,
        deviationFromSma: deviationFromSma,
      );
    } catch (e) {
      print('Ошибка при загрузке данных для $ticker: $e');
      // В случае ошибки возвращаем stock без SMA данных
      final price = await _fetchStockPrice(ticker);
      if (price == null) return null;

      return Stock(
        secId: ticker,
        shortName: name,
        lastPrice: price,
        lotSize: lotSize,
        sma200: null,
        deviationFromSma: null,
      );
    }
  }

  Future<double?> _fetchStockPrice(String ticker) async {
    try {
      final priceUrl = Uri.parse(
        'https://iss.moex.com/iss/engines/stock/markets/shares/boards/TQBR/securities/$ticker.json?'
        'iss.meta=off&'
        'securities.columns=SECID,SECNAME,PREVPRICE&'
        'marketdata.columns=LAST',
      );

      final priceResponse = await http.get(priceUrl);

      if (priceResponse.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(priceResponse.body);
        print('Данные по цене для $ticker получены');

        double? currentPrice;

        // Пробуем получить из marketdata
        if (data['marketdata'] != null && data['marketdata']['data'] != null) {
          final marketData = data['marketdata']['data'];
          if (marketData.isNotEmpty && marketData[0].isNotEmpty) {
            final lastPrice = marketData[0][0];
            print('$ticker - LAST из marketdata: $lastPrice');
            currentPrice = double.tryParse(lastPrice?.toString() ?? '0');
          }
        }

        // Если не получили из marketdata, пробуем из securities
        if (currentPrice == null || currentPrice == 0) {
          if (data['securities'] != null &&
              data['securities']['data'] != null) {
            final securitiesData = data['securities']['data'];
            if (securitiesData.isNotEmpty && securitiesData[0].length > 2) {
              final prevPrice = securitiesData[0][2];
              print('$ticker - PREVPRICE из securities: $prevPrice');
              currentPrice = double.tryParse(prevPrice?.toString() ?? '0');
            }
          }
        }

        print('$ticker - итоговая цена: $currentPrice');
        return currentPrice ?? 0.0;
      } else {
        print(
          'Ошибка HTTP при получении цены $ticker: ${priceResponse.statusCode}',
        );
      }
    } catch (e) {
      print('Ошибка при получении цены для $ticker: $e');
    }

    return null;
  }

  Future<Map<String, double>?> _fetchSma200(
    String ticker,
    double currentPrice,
  ) async {
    try {
      print('Начинаем расчет SMA200 для $ticker...');

      final endDate = DateTime.now();
      final startDate = endDate.subtract(
        const Duration(days: 400),
      ); // Берем больше дней для надежности

      final url = Uri.parse(
        'https://iss.moex.com/iss/engines/stock/markets/shares/securities/$ticker/candles.json',
      );

      final params = {
        'interval': '24',
        'from': _formatDate(startDate),
        'till': _formatDate(endDate),
        'start': '0',
      };

      print(
        'Запрос SMA для $ticker: ${url.toString()}?${Uri(queryParameters: params).query}',
      );

      final response = await http.get(url.replace(queryParameters: params));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Отладка структуры данных
        print('$ticker - получены данные свечей');
        if (data.containsKey('candles')) {
          print('$ticker - есть ключ candles');
          if (data['candles'] != null && data['candles'].containsKey('data')) {
            print('$ticker - candles.data существует');
          }
        }

        if (data['candles'] != null && data['candles']['data'] != null) {
          final List<dynamic> candlesData = data['candles']['data'];
          final List<String> columns = List<String>.from(
            data['candles']['columns'],
          );

          print('$ticker - колонки: $columns');
          print('$ticker - количество свечей: ${candlesData.length}');

          if (candlesData.isEmpty) {
            print('$ticker - нет данных свечей');
            return null;
          }

          // Ищем индекс цены закрытия
          int closeIndex = columns.indexOf('close');
          if (closeIndex == -1) closeIndex = columns.indexOf('CLOSE');
          if (closeIndex == -1) closeIndex = 4; // По умолчанию 4-я колонка

          print('$ticker - индекс цены закрытия: $closeIndex');

          // Извлекаем цены закрытия
          final List<double> closes = [];
          for (var candle in candlesData) {
            if (candle is List && candle.length > closeIndex) {
              final closeValue = candle[closeIndex];
              if (closeValue != null) {
                final close = double.tryParse(closeValue.toString());
                if (close != null && close > 0) {
                  closes.add(close);
                }
              }
            }
          }

          print('$ticker - получено цен закрытия: ${closes.length}');

          if (closes.length < 200) {
            print(
              '$ticker - недостаточно данных для SMA200 (нужно 200, есть ${closes.length})',
            );
            return null;
          }

          // Рассчитываем SMA200 по последним 200 значениям
          double sum = 0;
          final startIndex = max(0, closes.length - 200);
          final endIndex = closes.length;

          for (int i = startIndex; i < endIndex; i++) {
            sum += closes[i];
          }

          final sma200 = sum / 200;
          final deviation = ((currentPrice - sma200) / sma200) * 100;

          print(
            '$ticker - SMA200: $sma200, Текущая цена: $currentPrice, Отклонение: ${deviation.toStringAsFixed(2)}%',
          );

          return {'sma200': sma200, 'deviation': deviation};
        } else {
          print('$ticker - нет структуры candles в ответе');
        }
      } else {
        print(
          '$ticker - ошибка HTTP при получении SMA: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('$ticker - ошибка при расчете SMA200: $e');
    }

    return null;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static List<Map<String, String>> get stocksInfo => _stocksInfo;
}
