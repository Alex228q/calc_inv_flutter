import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
      title: 'Равномерное распределение',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
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
    {'ticker': 'LKOH', 'name': 'Лукойл', 'lotSize': '1'},
    {'ticker': 'MDMG', 'name': 'Мать и дитя', 'lotSize': '1'},
    {'ticker': 'MOEX', 'name': 'Московская Биржа', 'lotSize': '10'},
    {'ticker': 'NVTK', 'name': 'Новатэк', 'lotSize': '1'},
    {'ticker': 'GMKN', 'name': 'Норникель', 'lotSize': '10'},
    {'ticker': 'OZON', 'name': 'OZON', 'lotSize': '1'},
    {'ticker': 'PLZL', 'name': 'Полюс', 'lotSize': '1'},
    {'ticker': 'SBERP', 'name': 'Сбербанк', 'lotSize': '1'},
    {'ticker': 'CHMF', 'name': 'Северсталь', 'lotSize': '1'},
    {'ticker': 'PHOR', 'name': 'Фосагро', 'lotSize': '1'},
    {'ticker': 'YDEX', 'name': 'Yandex', 'lotSize': '1'},
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
      _existingSharesControllers.add(TextEditingController(text: '0'));
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

        // Получаем текущую цену
        final price = await _fetchStockPrice(ticker);

        if (price != null) {
          loadedStocks.add(
            Stock(
              secId: ticker,
              shortName: stockInfo['name']!,
              lastPrice: price,
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

        return currentPrice ?? 0.0;
      }
    } catch (e) {
      // В случае ошибки возвращаем null
    }

    return null;
  }

  // Рассчитываем равные целевые доли
  List<double> _calculateEqualPercentages() {
    final int stockCount = _stocks.length;
    final double equalPercentage = 100.0 / stockCount;
    return List.filled(stockCount, equalPercentage);
  }

  // Ребалансировка портфеля
  void _rebalancePortfolio() {
    if (_stocks.isEmpty) {
      _showSnackBar('Нет данных об акциях для ребалансировки', Colors.red);
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
      _showSnackBar('Введите имеющиеся акции для ребалансировки', Colors.red);
      return;
    }

    // Рассчитываем целевые доли (равные)
    final List<double> targetPercentages = _calculateEqualPercentages();

    // Рассчитываем целевые стоимости для каждой акции
    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final double targetValue =
          (targetPercentages[i] / 100) * currentPortfolioValue;

      // Рассчитываем целевое количество акций
      int targetShares = (targetValue / stock.lastPrice).round();
      targetShares = targetShares < 0 ? 0 : targetShares;

      // Обновляем поле ввода
      _existingSharesControllers[i].text = targetShares.toString();
    }

    setState(() {
      _showAllocation = false;
    });

    _showSnackBar('Портфель ребалансирован на равные доли', Colors.green);
  }

  // Основной расчет распределения
  void _calculateAllocation() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnackBar('Введите корректную сумму для расчета', Colors.red);
      return;
    }

    if (_stocks.isEmpty) {
      _showSnackBar('Нет данных об акциях для расчета', Colors.red);
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

    // Рассчитываем целевые доли (равные)
    final List<double> targetPercentages = _calculateEqualPercentages();

    // Рассчитываем целевые суммы для каждой акции
    final List<double> targetAmounts = [];
    for (int i = 0; i < _stocks.length; i++) {
      final double targetAmount =
          (targetPercentages[i] / 100) * totalPortfolioValue;
      targetAmounts.add(targetAmount);
    }

    // Инициализация allocations
    _allocations = [];
    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final double existingCost = existingCosts[i];
      final double existingPercentage = currentPortfolioValue > 0
          ? (existingCost / currentPortfolioValue * 100)
          : 0;

      _allocations.add(
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

    // Покупаем акции, наиболее отстающие от целевой доли
    bool changed = true;
    int iterations = 0;
    const int maxIterations = 10000; // Увеличим лимит для большей точности

    while (remainingAmount > 0 && changed && iterations < maxIterations) {
      changed = false;

      // Находим акции, которые наиболее отстают от целевой доли
      final List<Map<String, dynamic>> underweightStocks = [];

      for (int i = 0; i < _allocations.length; i++) {
        final allocation = _allocations[i];
        final stock = _stocks[i];
        final double sharePrice = sharePrices[i];
        final double targetAmount = targetAmounts[i];

        // Текущая общая стоимость (имеющиеся + купленные)
        final double currentTotalAmount =
            allocation.existingCost + allocation.totalCost;

        // Отклонение от целевой суммы (отрицательное = недобор)
        final double deviationFromTarget = targetAmount - currentTotalAmount;

        // Можем ли купить хотя бы 1 лот?
        final double lotCost = sharePrice * stock.lotSize;
        if (deviationFromTarget > 0 && lotCost <= remainingAmount) {
          underweightStocks.add({
            'index': i,
            'allocation': allocation,
            'lotCost': lotCost,
            'deviation': deviationFromTarget,
          });
        }
      }

      // Сортируем по величине недобора (самые отстающие сначала)
      underweightStocks.sort(
        (a, b) => b['deviation'].compareTo(a['deviation']),
      );

      // Покупаем у самой отстающей акции
      if (underweightStocks.isNotEmpty) {
        final stockInfo = underweightStocks.first;
        final int index = stockInfo['index'];
        final allocation = stockInfo['allocation'];
        final double lotCost = stockInfo['lotCost'];

        // Покупаем 1 лот
        _allocations[index] = StockAllocation(
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

    setState(() {
      _showAllocation = true;
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
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
      final double cost = existingShares * stock.lastPrice;
      existingCosts.add(cost);
      currentPortfolioValue += cost;
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 450) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Уже имеющиеся акции (в штуках):',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
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
                  );
                } else {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Уже имеющиеся акции (в штуках):',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
                  );
                }
              },
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
              spacing: 16.0,
              runSpacing: 16.0,
              children: List.generate(_stocks.length, (index) {
                final stock = _stocks[index];
                final existingShares =
                    int.tryParse(_existingSharesControllers[index].text) ?? 0;
                final double cost = existingShares * stock.lastPrice;
                final double percentage = currentPortfolioValue > 0
                    ? (cost / currentPortfolioValue * 100)
                    : 0;

                return SizedBox(
                  width: 154,
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

                      // Отображение стоимости и процента
                      if (existingShares > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
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
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: percentage / 100,
                                      backgroundColor: Colors.grey[200],
                                      color: _getExistingPercentageColor(
                                        percentage,
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
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

    // Рассчитываем насколько равномерно распределены средства
    final double targetPercentage = 100.0 / _allocations.length;
    double deviationSum = 0;
    for (final allocation in _allocations) {
      deviationSum += (allocation.percentage - targetPercentage).abs();
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
                color: averageDeviation < 5 ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 16),

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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 800) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10.0,
                                horizontal: 8.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            allocation.stock.shortName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
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
                                      Text(
                                        'Купить: ${allocation.lots} лотов',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.green,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Стоимость: ${allocation.totalCost.toStringAsFixed(2)} ₽',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Было: ${allocation.existingPercentage.toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
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
                                    ],
                                  ),
                                ],
                              ),
                            );
                          } else {
                            return Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Стоимость: ${allocation.totalCost.toStringAsFixed(2)} ₽',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            'Было: ${allocation.existingPercentage.toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(width: 50),
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
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }
                        },
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
          spacing: 16.0,
          runSpacing: 16.0,
          children: List.generate(_stocks.length, (index) {
            final stock = _stocks[index];

            return SizedBox(
              width: 170,
              child: Card(
                margin: const EdgeInsets.all(0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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

                      // Цена
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${stock.lastPrice.toStringAsFixed(2)} ₽',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Лот: ${stock.lotSize} шт',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
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
        title: const Text('Равномерное распределение'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchStockPrices,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _stocks.isEmpty
            ? const Center(
                child: Text(
                  'Нет данных для отображения',
                  style: TextStyle(fontSize: 16),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 18),
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

                    // Поля для ввода имеющихся акций
                    _buildExistingSharesInputs(),

                    // Результаты распределения
                    _buildAllocationResults(),

                    // Список акций в сетке
                    _buildStocksGrid(),
                  ],
                ),
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
