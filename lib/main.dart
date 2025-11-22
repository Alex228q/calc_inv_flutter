import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class Stock {
  final String secId;
  final double lastPrice;
  final String shortName;
  final double? sma200;
  final int lotSize;

  Stock({
    required this.secId,
    required this.lastPrice,
    required this.shortName,
    this.sma200,
    required this.lotSize,
  });

  @override
  String toString() {
    return 'Stock{secId: $secId, lastPrice: $lastPrice, shortName: $shortName, sma200: $sma200, lotSize: $lotSize}';
  }
}

class StockAllocation {
  final Stock stock;
  int lots;
  int existingLots;
  double totalCost;
  double percentage;
  double existingCost;
  double existingPercentage;

  StockAllocation({
    required this.stock,
    required this.lots,
    required this.existingLots,
    required this.totalCost,
    required this.percentage,
    required this.existingCost,
    required this.existingPercentage,
  });
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Цены акций со SMA200',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const StockPriceScreen(),
    );
  }
}

class StockPriceScreen extends StatefulWidget {
  const StockPriceScreen({super.key});

  @override
  State<StockPriceScreen> createState() => _StockPriceScreenState();
}

class _StockPriceScreenState extends State<StockPriceScreen> {
  final List<Map<String, String>> _stocksInfo = [
    {'ticker': 'X5', 'name': 'X5', 'lotSize': '1'},
    {'ticker': 'MDMG', 'name': 'Мать и дитя', 'lotSize': '1'},
    {'ticker': 'NVTK', 'name': 'НОВАТЭК', 'lotSize': '1'},
    {'ticker': 'OZON', 'name': 'OZON', 'lotSize': '1'},
    {'ticker': 'PLZL', 'name': 'Полюс', 'lotSize': '1'},
    {'ticker': 'SBERP', 'name': 'Сбербанк', 'lotSize': '1'},
    {'ticker': 'T', 'name': 'Т-Технологии', 'lotSize': '1'},
    {'ticker': 'CHMF', 'name': 'Северсталь', 'lotSize': '1'},
    {'ticker': 'TATNP', 'name': 'Татнефть', 'lotSize': '1'},
    {'ticker': 'PHOR', 'name': 'ФосАгро', 'lotSize': '1'},
    {'ticker': 'YDEX', 'name': 'ЯНДЕКС', 'lotSize': '1'},
    {'ticker': 'GMKN', 'name': 'Норникель', 'lotSize': '10'},
  ];

  List<Stock> _stocks = [];
  bool _isLoading = true;
  String _error = '';
  final TextEditingController _amountController = TextEditingController();
  final List<TextEditingController> _existingSharesControllers = [];
  List<StockAllocation> _allocations = [];
  bool _showAllocation = false;

  @override
  void initState() {
    super.initState();
    // Инициализируем контроллеры для существующих акций (штук)
    for (int i = 0; i < _stocksInfo.length; i++) {
      _existingSharesControllers.add(TextEditingController(text: ''));
    }
    _fetchStockPrices();
  }

  Future<void> _fetchStockPrices() async {
    setState(() {
      _isLoading = true;
      _error = '';
      _showAllocation = false;
    });

    try {
      final List<Stock> loadedStocks = [];

      for (var stockInfo in _stocksInfo) {
        final ticker = stockInfo['ticker']!;
        final lotSize = int.parse(stockInfo['lotSize']!);

        // Получаем текущую цену и SMA200
        final stockData = await _fetchStockData(ticker);

        if (stockData['price'] != null) {
          loadedStocks.add(
            Stock(
              secId: ticker,
              shortName: stockInfo['name']!,
              lastPrice: stockData['price']!,
              sma200: stockData['sma200'],
              lotSize: lotSize,
            ),
          );
        }
      }

      setState(() {
        _stocks = loadedStocks;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _error = 'Ошибка загрузки: $error';
      });
    }
  }

  Future<Map<String, double?>> _fetchStockData(String ticker) async {
    try {
      // Получаем текущую цену
      final priceUrl = Uri.parse(
        'https://iss.moex.com/iss/engines/stock/markets/shares/boards/TQBR/securities/$ticker.json?'
        'iss.meta=off&'
        'securities.columns=SECID,SECNAME,PREVPRICE&'
        'marketdata.columns=LAST',
      );

      final priceResponse = await http.get(priceUrl);

      if (priceResponse.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(priceResponse.body);

        double? currentPrice;

        // Пытаемся получить цену из marketdata (LAST)
        if (data['marketdata'] != null && data['marketdata']['data'] != null) {
          final marketData = data['marketdata']['data'];
          if (marketData.isNotEmpty && marketData[0].isNotEmpty) {
            currentPrice = double.tryParse(marketData[0][0]?.toString() ?? '0');
          }
        }

        // Если не получили из marketdata, используем PREVPRICE из securities
        if (currentPrice == null || currentPrice == 0) {
          if (data['securities'] != null &&
              data['securities']['data'] != null) {
            final securitiesData = data['securities']['data'];
            if (securitiesData.isNotEmpty && securitiesData[0].length > 2) {
              currentPrice = double.tryParse(
                securitiesData[0][2]?.toString() ?? '0',
              );
            }
          }
        }

        // Получаем SMA200
        final sma200 = await _fetchSMA200(ticker);

        return {'price': currentPrice ?? 0.0, 'sma200': sma200};
      }
    } catch (e) {}

    return {'price': null, 'sma200': null};
  }

  Future<double?> _fetchSMA200(String ticker) async {
    try {
      // Рассчитываем дату начала (примерно 200 торговых дней назад)
      final now = DateTime.now();
      final startDate = DateTime(
        now.year - 1,
        now.month,
        now.day,
      ); // Берем данные за год

      final formattedStartDate = DateFormat('yyyy-MM-dd').format(startDate);
      final formattedEndDate = DateFormat('yyyy-MM-dd').format(now);

      final requestUrl = Uri.parse(
        'https://iss.moex.com/iss/engines/stock/markets/shares/boards/TQBR/securities/$ticker/candles.json?'
        'iss.meta=off&'
        'from=$formattedStartDate&'
        'till=$formattedEndDate&'
        'interval=24&' // Дневные данные
        'candles.columns=close,volume',
      );

      final response = await http.get(requestUrl);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final candles = data['candles'];

        if (candles != null && candles['data'] != null) {
          final List<dynamic> candleData = candles['data'];

          if (candleData.isNotEmpty) {
            // Берем только свечи с объемом (исключаем не торговые дни)
            final List<double> validCloses = [];

            for (var candle in candleData) {
              if (candle.length >= 2) {
                final closePrice = candle[0]; // close price
                final volume = candle[1]; // volume

                // Проверяем что объем > 0 (торговый день)
                if (volume != null && volume > 0) {
                  final price = double.tryParse(closePrice.toString());
                  if (price != null && price > 0) {
                    validCloses.add(price);
                  }
                }
              }
            }

            // Берем последние 200 торговых дней
            final int count = validCloses.length > 200
                ? 200
                : validCloses.length;
            if (count >= 50) {
              // Минимум 50 дней для хоть какой-то статистики
              double sum = 0;
              final startIndex = validCloses.length - count;

              for (int i = startIndex; i < validCloses.length; i++) {
                sum += validCloses[i];
              }

              final sma200 = sum / count;

              return sma200;
            } else {}
          }
        }
      } else {}
    } catch (e) {}
    return null;
  }

  // Новый метод для расчета целевых процентов с учетом SMA200
  List<double> _calculateTargetPercentages() {
    final int stockCount = _stocks.length;
    final double basePercentage = 100.0 / stockCount;
    final double maxDeviation = 2.0; // Максимальное отклонение ±2%

    List<double> deviations = [];
    List<double> targetPercentages = [];

    // Рассчитываем отклонения от SMA200 для каждой акции
    for (final stock in _stocks) {
      if (stock.sma200 != null && stock.sma200! > 0) {
        final double deviationFromSMA =
            ((stock.lastPrice - stock.sma200!) / stock.sma200!) * 100;
        deviations.add(deviationFromSMA);
      } else {
        // Если SMA200 недоступна, используем нейтральное значение
        deviations.add(0.0);
      }
    }

    // Нормализуем отклонения в диапазоне [-maxDeviation, +maxDeviation]
    if (deviations.isNotEmpty) {
      double minDeviation = deviations.reduce((a, b) => a < b ? a : b);
      double maxDeviationValue = deviations.reduce((a, b) => a > b ? a : b);
      double range = maxDeviationValue - minDeviation;

      if (range > 0) {
        for (int i = 0; i < deviations.length; i++) {
          // Нормализуем от -maxDeviation до +maxDeviation
          double normalized =
              ((deviations[i] - minDeviation) / range) * (2 * maxDeviation) -
              maxDeviation;

          // Инвертируем: чем ниже цена относительно SMA200, тем выше вес
          double adjustedDeviation = -normalized;

          targetPercentages.add(basePercentage + adjustedDeviation);
        }
      } else {
        // Если все отклонения одинаковы, используем равные доли
        for (int i = 0; i < deviations.length; i++) {
          targetPercentages.add(basePercentage);
        }
      }

      // Нормализуем проценты, чтобы сумма была 100%
      double sum = targetPercentages.reduce((a, b) => a + b);
      for (int i = 0; i < targetPercentages.length; i++) {
        targetPercentages[i] = (targetPercentages[i] / sum) * 100;
      }
    } else {
      // Резервный вариант: равные доли
      for (int i = 0; i < stockCount; i++) {
        targetPercentages.add(basePercentage);
      }
    }

    return targetPercentages;
  }

  // НОВЫЙ МЕТОД: Ребалансировка портфеля
  void _rebalancePortfolio() {
    if (_stocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет данных об акциях для ребалансировки'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Рассчитываем текущую стоимость портфеля
    double currentPortfolioValue = 0;
    final List<double> currentValues = [];

    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final existingShares =
          int.tryParse(_existingSharesControllers[i].text) ?? 0;
      final double value = existingShares * stock.lastPrice;
      currentValues.add(value);
      currentPortfolioValue += value;
    }

    if (currentPortfolioValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите имеющиеся акции для ребалансировки'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Рассчитываем целевые доли
    final List<double> targetPercentages = _calculateTargetPercentages();

    // Рассчитываем целевые стоимости для каждой акции
    final List<double> targetValues = [];
    for (int i = 0; i < _stocks.length; i++) {
      final double targetValue =
          (targetPercentages[i] / 100) * currentPortfolioValue;
      targetValues.add(targetValue);
    }

    // Рассчитываем целевое количество акций для каждой позиции
    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final double targetValue = targetValues[i];

      // Рассчитываем целевое количество акций
      int targetShares = (targetValue / stock.lastPrice).round();

      // Округляем до целого количества акций
      targetShares = targetShares < 0 ? 0 : targetShares;

      // Обновляем поле ввода
      _existingSharesControllers[i].text = targetShares.toString();
    }

    setState(() {
      _showAllocation = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Портфель ребалансирован согласно целевым долям'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _calculateAllocation() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите корректную сумму для расчета'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_stocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет данных об акциях для расчета'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Собираем информацию о существующих акциях
    final List<int> existingShares = [];
    for (int i = 0; i < _stocks.length; i++) {
      final shares = int.tryParse(_existingSharesControllers[i].text) ?? 0;
      existingShares.add(shares);
    }

    // Рассчитываем текущую стоимость портфеля
    double currentPortfolioValue = 0;
    final List<double> sharePrices = [];
    final List<double> existingCosts = [];

    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final double sharePrice = stock.lastPrice;
      final double cost = existingShares[i] * sharePrice;

      sharePrices.add(sharePrice);
      existingCosts.add(cost);
      currentPortfolioValue += cost;
    }

    final double totalPortfolioValue = currentPortfolioValue + amount;

    // Рассчитываем целевые доли с учетом SMA200
    final List<double> targetPercentages = _calculateTargetPercentages();

    // Рассчитываем целевые суммы для каждой акции
    final List<double> targetAmounts = [];
    for (int i = 0; i < _stocks.length; i++) {
      final double targetAmount =
          (targetPercentages[i] / 100) * totalPortfolioValue;
      targetAmounts.add(targetAmount);
    }

    // Инициализация allocations
    List<StockAllocation> allocations = [];
    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final double existingCost = existingCosts[i];
      final double existingPercentage = currentPortfolioValue > 0
          ? (existingCost / currentPortfolioValue * 100)
          : 0;

      allocations.add(
        StockAllocation(
          stock: stock,
          lots: 0,
          existingLots: (existingShares[i] / stock.lotSize).floor(),
          totalCost: 0,
          percentage: existingPercentage,
          existingCost: existingCost,
          existingPercentage: existingPercentage,
        ),
      );
    }

    double remainingAmount = amount;

    // ПРИОРИТЕТНОЕ РАСПРЕДЕЛЕНИЕ: покупаем самые недооцененные акции относительно целевых долей
    bool changed = true;
    int iterations = 0;
    int maxIterations = 1000;

    while (remainingAmount > 0 && changed && iterations < maxIterations) {
      changed = false;

      // Находим акции, которые наиболее отстают от целевой доли
      final List<Map<String, dynamic>> underweightStocks = [];

      for (int i = 0; i < allocations.length; i++) {
        final allocation = allocations[i];
        final stock = _stocks[i];
        final double sharePrice = sharePrices[i];
        final double targetAmount = targetAmounts[i];

        // Текущая общая стоимость (имеющиеся + купленные)
        final double currentTotalAmount =
            allocation.existingCost + allocation.totalCost;

        // Отклонение от целевой суммы (отрицательное = недобор)
        final double deviationFromTarget = targetAmount - currentTotalAmount;

        // Можем ли купить хотя бы 1 акцию?
        if (deviationFromTarget > 0 && sharePrice <= remainingAmount) {
          underweightStocks.add({
            'index': i,
            'allocation': allocation,
            'sharePrice': sharePrice,
            'deviation': deviationFromTarget,
            'lotSize': stock.lotSize,
          });
        }
      }

      // Сортируем по величине недобора (самые недооцененные сначала)
      underweightStocks.sort(
        (a, b) => b['deviation'].compareTo(a['deviation']),
      );

      // Покупаем у самой недооцененной акции
      if (underweightStocks.isNotEmpty) {
        final stockInfo = underweightStocks.first;
        final int index = stockInfo['index'];
        final allocation = stockInfo['allocation'];
        final double sharePrice = stockInfo['sharePrice'];
        final int lotSize = stockInfo['lotSize'];

        // Рассчитываем, сколько акций нужно для приближения к целевой доле
        final double neededAmount = stockInfo['deviation'];
        int sharesToBuy = (neededAmount / sharePrice)
            .ceil(); // Округляем вверх для быстрого достижения цели

        // Ограничиваем количеством, которое можем купить на оставшиеся средства
        final int maxAffordableShares = (remainingAmount / sharePrice).floor();
        sharesToBuy = sharesToBuy > maxAffordableShares
            ? maxAffordableShares
            : sharesToBuy;

        // Покупаем целыми лотами
        final int lotsToBuy = (sharesToBuy / lotSize).floor();
        final int actualSharesToBuy = lotsToBuy * lotSize;

        if (actualSharesToBuy > 0) {
          final double cost = actualSharesToBuy * sharePrice;
          final double newTotalCost = allocation.totalCost + cost;
          final double newTotalAmount = allocation.existingCost + newTotalCost;
          final double newPercentage =
              newTotalAmount / totalPortfolioValue * 100;

          allocations[index] = StockAllocation(
            stock: allocation.stock,
            lots: allocation.lots + lotsToBuy,
            existingLots: allocation.existingLots,
            totalCost: newTotalCost,
            percentage: newPercentage,
            existingCost: allocation.existingCost,
            existingPercentage: allocation.existingPercentage,
          );

          remainingAmount -= cost;
          changed = true;
        }
      }

      iterations++;
    }

    // ЕСЛИ ВСЕ ЕЩЕ ОСТАЛИСЬ СРЕДСТВА - покупаем самые недооцененные по 1 лоту
    if (remainingAmount > 0) {
      changed = true;
      iterations = 0;

      while (remainingAmount > 0 && changed && iterations < maxIterations) {
        changed = false;

        final List<Map<String, dynamic>> affordableStocks = [];

        for (int i = 0; i < allocations.length; i++) {
          final allocation = allocations[i];
          final stock = _stocks[i];
          final double sharePrice = sharePrices[i];
          final double lotCost = sharePrice * stock.lotSize;
          final double targetAmount = targetAmounts[i];
          final double currentTotalAmount =
              allocation.existingCost + allocation.totalCost;
          final double deviationFromTarget = targetAmount - currentTotalAmount;

          // Покупаем если есть недобор и можем купить лот
          if (deviationFromTarget > 0 && lotCost <= remainingAmount) {
            affordableStocks.add({
              'index': i,
              'allocation': allocation,
              'lotCost': lotCost,
              'deviation': deviationFromTarget,
            });
          }
        }

        // Сортируем по недобору (самые недооцененные сначала)
        affordableStocks.sort(
          (a, b) => b['deviation'].compareTo(a['deviation']),
        );

        if (affordableStocks.isNotEmpty) {
          final stockInfo = affordableStocks.first;
          final int index = stockInfo['index'];
          final allocation = stockInfo['allocation'];
          final double lotCost = stockInfo['lotCost'];

          allocations[index] = StockAllocation(
            stock: allocation.stock,
            lots: allocation.lots + 1,
            existingLots: allocation.existingLots,
            totalCost: allocation.totalCost + lotCost,
            percentage:
                (allocation.existingCost + allocation.totalCost + lotCost) /
                totalPortfolioValue *
                100,
            existingCost: allocation.existingCost,
            existingPercentage: allocation.existingPercentage,
          );

          remainingAmount -= lotCost;
          changed = true;
        }

        iterations++;
      }
    }

    setState(() {
      _allocations = allocations;
      _showAllocation = true;
    });
  }

  Widget _buildTargetPercentages() {
    if (_stocks.isEmpty) return const SizedBox();

    final targetPercentages = _calculateTargetPercentages();

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ExpansionTile(
        title: const Text(
          'Целевые доли с учетом SMA200:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ..._stocks.asMap().entries.map((entry) {
                  final index = entry.key;
                  final stock = entry.value;
                  final targetPercentage = targetPercentages[index];
                  final basePercentage = 100.0 / _stocks.length;
                  final difference = targetPercentage - basePercentage;

                  Color getColor(double value) {
                    if (value > 0) return Colors.green;
                    if (value < 0) return Colors.red;
                    return Colors.grey;
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                stock.shortName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${targetPercentage.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${difference >= 0 ? '+' : ''}${difference.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          color: getColor(difference),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Подчеркивание после каждой строки
                      Divider(color: Colors.grey[300], height: 1, thickness: 1),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPriceComparison(double currentPrice, double? sma200) {
    if (sma200 == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${currentPrice.toStringAsFixed(2)} ₽',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const Text(
            'SMA200: расчёт...',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      );
    }

    final difference = currentPrice - sma200;
    final percent = (difference / sma200 * 100);
    final color = difference >= 0 ? Colors.green : Colors.red;
    final icon = difference >= 0 ? Icons.arrow_upward : Icons.arrow_downward;
    final iconSize = 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Текущая цена
        Row(
          children: [
            Icon(icon, size: iconSize, color: color),
            const SizedBox(width: 4),
            Text(
              '${currentPrice.toStringAsFixed(2)} ₽',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        // SMA200
        Text(
          'SMA200: ${sma200.toStringAsFixed(2)} ₽',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),

        const SizedBox(height: 4),

        // Процентное изменение
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${difference >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExistingSharesInputs() {
    if (_stocks.isEmpty) return const SizedBox();

    // Рассчитываем текущую стоимость портфеля для отображения процентов
    double currentPortfolioValue = 0;
    final List<double> existingCosts = [];

    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final existingShares =
          int.tryParse(_existingSharesControllers[i].text) ?? 0;
      final int lotSize = stock.lotSize;
      final int lots = (existingShares / lotSize).floor();
      final double lotPrice = stock.lastPrice * stock.lotSize;
      final double cost = lots * lotPrice;
      existingCosts.add(cost);
      currentPortfolioValue += cost;
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Уже имеющиеся акции (в штуках):',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _rebalancePortfolio,
                  icon: const Icon(Icons.autorenew, size: 20),
                  label: const Text('Ребалансировка'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (currentPortfolioValue > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Текущая стоимость портфеля: ${currentPortfolioValue.toStringAsFixed(2)} ₽',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Сетка с Wrap
            Wrap(
              spacing: 16.0, // горизонтальное расстояние
              runSpacing: 16.0, // вертикальное расстояние
              children: List.generate(_stocks.length, (index) {
                final stock = _stocks[index];
                final existingShares =
                    int.tryParse(_existingSharesControllers[index].text) ?? 0;
                final int lotSize = stock.lotSize;
                final int lots = (existingShares / lotSize).floor();
                final double lotPrice = stock.lastPrice * stock.lotSize;
                final double cost = lots * lotPrice;
                final double percentage = currentPortfolioValue > 0
                    ? (cost / currentPortfolioValue * 100)
                    : 0;

                return SizedBox(
                  width: 250, // фиксированная ширина 250 пикселей
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _existingSharesControllers[index],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: stock.shortName,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),

                      // Отображение стоимости и процента (если есть акции)
                      if (existingShares > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${cost.toStringAsFixed(2)} ₽',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '$lots лотов',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 6.0,
                                ),
                                decoration: BoxDecoration(
                                  color: _getExistingPercentageColor(
                                    percentage,
                                  ),
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                                child: Text(
                                  '${percentage.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationResults() {
    if (!_showAllocation || _allocations.isEmpty) {
      return const SizedBox();
    }

    final totalCost = _allocations.fold(
      0.0,
      (sum, allocation) => sum + allocation.totalCost,
    );
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final remaining = amount - totalCost;
    final totalLotsToBuy = _allocations.fold(
      0,
      (sum, allocation) => sum + allocation.lots,
    );

    final totalExistingCost = _allocations.fold(
      0.0,
      (sum, allocation) => sum + allocation.existingCost,
    );

    // Рассчитываем стандартное отклонение для оценки равномерности
    final double averagePercentage = 100.0 / _allocations.length;
    double deviationSum = 0;
    for (final allocation in _allocations) {
      deviationSum += (allocation.percentage - averagePercentage).abs();
    }
    final double averageDeviation = deviationSum / _allocations.length;

    // Фильтруем allocations, оставляя только те акции, которые нужно докупить
    final allocationsToShow = _allocations
        .where((allocation) => allocation.lots > 0)
        .toList();

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Результаты распределения:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Среднее отклонение от равных долей: ${averageDeviation.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                color: averageDeviation < 10 ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 16),

            // Показываем только акции, которые нужно докупить
            if (allocationsToShow.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Не нужно докупать акции - портфель уже сбалансирован',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...allocationsToShow.map(
                (allocation) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    children: [
                      // Показываем только информацию о покупке
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  allocation.stock.shortName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 18,
                                  ),
                                ),
                                if (allocation.existingLots > 0)
                                  Text(
                                    'Имеется: ${allocation.existingLots} лотов',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Купить: ${allocation.lots} лотов',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Стоимость: ${allocation.totalCost.toStringAsFixed(2)} ₽',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                // ИЗМЕНЕНИЕ ЗДЕСЬ: показываем старые и новые проценты
                                Row(
                                  children: [
                                    Text(
                                      'Было: ${allocation.existingPercentage.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    SizedBox(width: 50),
                                    Text(
                                      'Станет: ${allocation.percentage.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.purple,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Текущий портфель:'),
                Text(
                  '${totalExistingCost.toStringAsFixed(2)} ₽',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Всего купить лотов:'),
                Text(
                  '$totalLotsToBuy',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Общая стоимость покупки:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${totalCost.toStringAsFixed(2)} ₽',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Остаток:'),
                Text(
                  '${remaining.toStringAsFixed(2)} ₽',
                  style: TextStyle(
                    color: remaining > 0 ? Colors.orange : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (remaining > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Недостаточно средств для покупки дополнительных лотов',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getExistingPercentageColor(double percentage) {
    final average = 100.0 / _stocks.length;
    final deviation = (percentage - average).abs();
    if (deviation < 5) return Colors.green;
    if (deviation < 15) return Colors.orange;
    return Colors.red;
  }

  Widget _buildStocksGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Текущие цены акций:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),

        Wrap(
          spacing: 16.0, // горизонтальное расстояние
          runSpacing: 16.0, // вертикальное расстояние
          children: List.generate(_stocks.length, (index) {
            final stock = _stocks[index];

            return SizedBox(
              width: 250, // фиксированная ширина 250 пикселей
              child: Card(
                margin: const EdgeInsets.all(0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок с тикером и названием
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue[50],
                            radius: 16,
                            child: Text(
                              stock.secId.substring(0, 1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stock.shortName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  stock.secId,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Информация о лоте
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Лот: ${stock.lotSize} шт',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Цена и SMA200
                      _buildCompactPriceComparison(
                        stock.lastPrice,
                        stock.sma200,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Акции'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchStockPrices,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stocks.isEmpty
          ? const Center(
              child: Text(
                'Нет данных для отображения',
                style: TextStyle(fontSize: 16),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  if (_error.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      color: Colors.orange[100],
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Поле ввода суммы и кнопка расчета
                  Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Сумма для инвестирования (₽)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : _calculateAllocation,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Рассчитать распределение',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Целевые доли (новый виджет)
                  _buildTargetPercentages(),

                  // Поля для ввода имеющихся акций (штук)
                  _buildExistingSharesInputs(),

                  // Результаты распределения
                  _buildAllocationResults(),

                  // Список акций в сетке
                  _buildStocksGrid(),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    for (var controller in _existingSharesControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
