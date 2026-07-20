import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/stock.dart';

class StockService {
  static const List<Map<String, dynamic>> _stocksInfo = [
    {"ticker": "X5", "name": "Икс 5", "lotSize": "1", "targetPercentage": 10.0},
    {
      "ticker": "MDMG",
      "name": "Мать и дитя",
      "lotSize": "1",
      "targetPercentage": 10.0,
    },
    {
      "ticker": "MOEX",
      "name": "Мосбиржа",
      "lotSize": "10",
      "targetPercentage": 10.0,
    },
    {
      "ticker": "NVTK",
      "name": "Новатэк",
      "lotSize": "1",
      "targetPercentage": 10.0,
    },
    {
      "ticker": "OZON",
      "name": "OZON",
      "lotSize": "1",
      "targetPercentage": 10.0,
    },
    {
      "ticker": "PLZL",
      "name": "Полюс",
      "lotSize": "1",
      "targetPercentage": 10.0,
    },
    {
      "ticker": "SBERP",
      "name": "Сбербанк",
      "lotSize": "1",
      "targetPercentage": 10.0,
    },
    {
      "ticker": "TATNP",
      "name": "Татнефть",
      "lotSize": "1",
      "targetPercentage": 10.0,
    },
    {
      "ticker": "PHOR",
      "name": "Фосагро",
      "lotSize": "1",
      "targetPercentage": 10.0,
    },
    {
      "ticker": "YDEX",
      "name": "Yandex",
      "lotSize": "1",
      "targetPercentage": 10.0,
    },
  ];

  // Метод для получения целевых процентов
  static List<double> getTargetPercentages() {
    double sum = 0;
    for (var stock in _stocksInfo) {
      sum += (stock['targetPercentage'] as double);
    }

    // Нормализуем, чтобы сумма была 100%
    List<double> percentages = [];
    for (var stock in _stocksInfo) {
      double normalized = (stock['targetPercentage'] as double) / sum * 100;
      percentages.add(double.parse(normalized.toStringAsFixed(2)));
    }

    return percentages;
  }

  Future<List<Stock>> fetchStockPrices() async {
    final List<Stock> loadedStocks = [];

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
      final price = await _fetchStockPrice(ticker);
      if (price == null) return null;

      final smaFuture = _fetchSma200(ticker, price);

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
        'http://iss.moex.com/iss/engines/stock/markets/shares/boards/TQBR/securities/$ticker.json?'
        'iss.meta=off&'
        'securities.columns=SECID,SECNAME,PREVPRICE&'
        'marketdata.columns=LAST',
      );

      final priceResponse = await http.get(priceUrl);

      if (priceResponse.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(priceResponse.body);
        print('Данные по цене для $ticker получены');

        double? currentPrice;

        if (data['marketdata'] != null && data['marketdata']['data'] != null) {
          final marketData = data['marketdata']['data'];
          if (marketData.isNotEmpty && marketData[0].isNotEmpty) {
            final lastPrice = marketData[0][0];
            print('$ticker - LAST из marketdata: $lastPrice');
            currentPrice = double.tryParse(lastPrice?.toString() ?? '0');
          }
        }

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
      final startDate = endDate.subtract(const Duration(days: 400));

      final url = Uri.parse(
        'http://iss.moex.com/iss/engines/stock/markets/shares/securities/$ticker/candles.json',
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

        if (data['candles'] != null && data['candles']['data'] != null) {
          final List<dynamic> candlesData = data['candles']['data'];
          final List<String> columns = List<String>.from(
            data['candles']['columns'],
          );

          print('$ticker - количество свечей: ${candlesData.length}');

          if (candlesData.isEmpty) {
            print('$ticker - нет данных свечей');
            return null;
          }

          int closeIndex = columns.indexOf('close');
          if (closeIndex == -1) closeIndex = columns.indexOf('CLOSE');
          if (closeIndex == -1) closeIndex = 4;

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

  static List<Map<String, dynamic>> get stocksInfo => _stocksInfo;
}
