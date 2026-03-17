import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../models/stock_allocation.dart';
import '../services/stock_service.dart';
import '../widgets/existing_shares_input.dart';
import '../widgets/allocation_results.dart';
import '../widgets/stocks_grid.dart';

class StockPriceScreen extends StatefulWidget {
  const StockPriceScreen({super.key});

  @override
  State<StockPriceScreen> createState() => _StockPriceScreenState();
}

class _StockPriceScreenState extends State<StockPriceScreen> {
  final StockService _stockService = StockService();
  List<Stock> _stocks = [];
  bool _isLoading = true;
  String _error = '';
  final TextEditingController _amountController = TextEditingController();
  final List<TextEditingController> _existingSharesControllers = [];
  List<StockAllocation> _allocations = [];
  bool _showAllocation = false;
  bool _isLoadingSma = false;
  int _stocksWithSma = 0;

  // Кэшируем целевые проценты
  List<double>? _cachedTargetPercentages;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < StockService.stocksInfo.length; i++) {
      _existingSharesControllers.add(TextEditingController(text: ''));
    }
    _fetchStockPrices();
  }

  Future<void> _fetchStockPrices() async {
    setState(() {
      _isLoading = true;
      _isLoadingSma = true;
      _error = '';
      _showAllocation = false;
      _stocksWithSma = 0;
      _cachedTargetPercentages = null;
    });

    try {
      final loadedStocks = await _stockService.fetchStockPrices();

      // Считаем сколько акций имеют SMA данные
      final smaCount = loadedStocks
          .where((stock) => stock.sma200 != null)
          .length;

      setState(() {
        _stocks = loadedStocks;
        _isLoading = false;
        _isLoadingSma = false;
        _stocksWithSma = smaCount;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _isLoadingSma = false;
        _error = 'Ошибка загрузки: $error';
      });
    }
  }

  List<double> _calculateTargetPercentages() {
    // Защита от пустого списка
    if (_stocks.isEmpty) {
      return [];
    }

    // Если уже вычисляли, возвращаем кэшированное значение
    if (_cachedTargetPercentages != null) {
      return _cachedTargetPercentages!;
    }

    final int stockCount = _stocks.length;
    const double minP = 8.5;
    const double maxP = 16.5;
    final double basePercentage = 100.0 / stockCount;

    print('\n=== РАСЧЕТ ЦЕЛЕВЫХ ДОЛЕЙ (КОРРЕКТИРОВКА ±4%) ===');

    // Шаг 1: Анализируем отклонения от SMA
    List<Map<String, dynamic>> stockAnalysis = [];

    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      double deviation = stock.deviationFromSma ?? 0;

      // Рассчитываем корректировку на основе отклонения
      double adjustment = 0;
      String rating;

      if (deviation < -15) {
        adjustment = 3.5;
        rating = "Крайне недооценена";
      } else if (deviation < -10) {
        adjustment = 3.0;
        rating = "Сильно недооценена";
      } else if (deviation < -5) {
        adjustment = 2.0;
        rating = "Умеренно недооценена";
      } else if (deviation < -2) {
        adjustment = 1.0;
        rating = "Слегка недооценена";
      } else if (deviation < 2) {
        adjustment = 0.0;
        rating = "Около справедливой";
      } else if (deviation < 5) {
        adjustment = -1.0;
        rating = "Слегка переоценена";
      } else if (deviation < 10) {
        adjustment = -2.0;
        rating = "Умеренно переоценена";
      } else if (deviation < 15) {
        adjustment = -3.0;
        rating = "Сильно переоценена";
      } else {
        adjustment = -3.5;
        rating = "Крайне переоценена";
      }

      // Ограничиваем корректировку коридором ±4%
      adjustment = adjustment.clamp(-4.0, 4.0);

      double target = basePercentage + adjustment;

      // Финальное ограничение диапазоном
      target = target.clamp(minP, maxP);

      stockAnalysis.add({
        'index': i,
        'stock': stock,
        'deviation': deviation,
        'rating': rating,
        'adjustment': adjustment,
        'target': target,
      });

      print(
        '${stock.shortName}: отклонение ${deviation.toStringAsFixed(1)}% - $rating',
      );
      print(
        '  → корректировка: ${adjustment.toStringAsFixed(1)}%, целевая доля: ${target.toStringAsFixed(1)}%',
      );
    }

    // Шаг 2: Применяем корректировки
    List<double> weights = stockAnalysis
        .map((a) => a['target'] as double)
        .toList();

    // Шаг 3: Проверяем сумму до нормализации
    double sum = weights.fold(0.0, (a, b) => a + b);
    print('\nСумма до нормализации: ${sum.toStringAsFixed(4)}%');
    print('Нужно добавить: ${(100 - sum).toStringAsFixed(4)}%');

    // Шаг 4: Нормализация до 100% с минимальными изменениями
    List<double> normalized = _normalizeWithProportions(weights, minP, maxP);

    // Шаг 5: Финальная проверка
    print('\n=== ИТОГОВЫЕ ЦЕЛЕВЫЕ ДОЛИ ===');
    for (int i = 0; i < stockCount; i++) {
      print('${_stocks[i].shortName}: ${normalized[i].toStringAsFixed(1)}%');
    }
    double finalSum = normalized.fold(0.0, (a, b) => a + b);
    print('СУММА: ${finalSum.toStringAsFixed(1)}%');
    print('=============================\n');

    // Кэшируем результат
    _cachedTargetPercentages = normalized;

    return normalized;
  }

  List<double> _normalizeWithProportions(
    List<double> weights,
    double minP,
    double maxP,
  ) {
    final int count = weights.length;
    double sum = weights.fold(0.0, (a, b) => a + b);

    print('\n--- НОРМАЛИЗАЦИЯ (МИНИМАЛЬНЫЕ ИЗМЕНЕНИЯ) ---');
    print('Сумма до нормализации: ${sum.toStringAsFixed(4)}%');
    print('Нужно добавить: ${(100 - sum).toStringAsFixed(4)}%');

    // Защита от деления на ноль
    if (sum.abs() < 0.0001) {
      return List.filled(count, 100.0 / count);
    }

    // Если сумма уже близка к 100, возвращаем с округлением
    if ((sum - 100.0).abs() < 0.01) {
      return weights.map((w) => double.parse(w.toStringAsFixed(1))).toList();
    }

    // Масштабируем пропорционально (минимальные изменения)
    double factor = 100.0 / sum;
    List<double> normalized = weights.map((w) => w * factor).toList();

    print('Коэффициент масштабирования: ${factor.toStringAsFixed(4)}');
    for (int i = 0; i < count; i++) {
      print(
        '${_stocks[i].shortName}: ${weights[i].toStringAsFixed(2)}% → ${normalized[i].toStringAsFixed(2)}%',
      );
    }

    // Проверяем границы и корректируем с минимальными изменениями
    bool hasViolations = true;
    int iterations = 0;
    const maxIterations = 50;

    while (hasViolations && iterations < maxIterations) {
      hasViolations = false;

      for (int i = 0; i < count; i++) {
        if (normalized[i] < minP - 0.01) {
          hasViolations = true;
          double excess = minP - normalized[i];
          normalized[i] = minP;
          print(
            '  ${_stocks[i].shortName}: подняли до мин ${minP}% (избыток ${excess.toStringAsFixed(2)}%)',
          );
          _redistributeExcessMinimal(normalized, i, excess, maxP, minP, maxP);
        } else if (normalized[i] > maxP + 0.01) {
          hasViolations = true;
          double excess = normalized[i] - maxP;
          normalized[i] = maxP;
          print(
            '  ${_stocks[i].shortName}: опустили до макс ${maxP}% (избыток ${excess.toStringAsFixed(2)}%)',
          );
          _redistributeExcessMinimal(normalized, i, excess, minP, minP, maxP);
        }
      }

      iterations++;
    }

    // Финальная корректировка до 100%
    sum = normalized.fold(0.0, (a, b) => a + b);
    double diff = 100.0 - sum;

    if (diff.abs() > 0.01) {
      print('\nФинальная корректировка: нужно ${diff.toStringAsFixed(3)}%');

      // Распределяем разницу пропорционально текущим весам
      for (int i = 0; i < count; i++) {
        double proportion = normalized[i] / sum;
        double adjustment = diff * proportion;
        normalized[i] += adjustment;
        print(
          '  ${_stocks[i].shortName}: +${adjustment.toStringAsFixed(3)}% → ${normalized[i].toStringAsFixed(3)}%',
        );
      }

      // Проверяем границы после финальной корректировки
      for (int i = 0; i < count; i++) {
        if (normalized[i] < minP) normalized[i] = minP;
        if (normalized[i] > maxP) normalized[i] = maxP;
      }
    }

    // Округляем до 1 знака для отображения
    List<double> result = normalized
        .map((w) => double.parse(w.toStringAsFixed(1)))
        .toList();

    // Проверяем сумму после округления
    double roundedSum = result.fold(0.0, (a, b) => a + b);
    if ((roundedSum - 100.0).abs() > 0.1) {
      // Корректируем последний элемент
      double lastAdjustment = 100.0 - roundedSum;
      result[count - 1] = double.parse(
        (result[count - 1] + lastAdjustment).toStringAsFixed(1),
      );
    }

    print('\n--- ИТОГ ПОСЛЕ НОРМАЛИЗАЦИИ ---');
    for (int i = 0; i < count; i++) {
      print('${_stocks[i].shortName}: ${result[i].toStringAsFixed(1)}%');
    }
    print('Сумма: ${result.fold(0.0, (a, b) => a + b).toStringAsFixed(1)}%');

    return result;
  }

  void _redistributeExcessMinimal(
    List<double> values,
    int excludeIndex,
    double excess,
    double bound,
    double minP,
    double maxP,
  ) {
    final int count = values.length;
    double totalAvailable = 0;
    List<int> availableIndices = [];

    // Собираем индексы, которые могут принять избыток
    for (int i = 0; i < count; i++) {
      if (i != excludeIndex) {
        if (bound == maxP) {
          // Нужно добавить вес (при выходе за minP)
          if (values[i] < bound) {
            totalAvailable += (bound - values[i]);
            availableIndices.add(i);
          }
        } else {
          // Нужно убавить вес (при выходе за maxP)
          if (values[i] > bound) {
            totalAvailable += (values[i] - bound);
            availableIndices.add(i);
          }
        }
      }
    }

    if (totalAvailable <= 0.0001 || availableIndices.isEmpty) {
      print('    Нет доступного пространства для перераспределения');
      return;
    }

    // Распределяем избыток пропорционально доступному пространству
    double remainingExcess = excess;
    for (int index in availableIndices) {
      if (remainingExcess.abs() <= 0.0001) break;

      double available = bound == maxP
          ? bound - values[index]
          : values[index] - bound;

      double proportion = available / totalAvailable;
      double adjustment = remainingExcess * proportion;

      double oldValue = values[index];

      if (bound == maxP) {
        values[index] = (values[index] + adjustment).clamp(minP, maxP);
      } else {
        values[index] = (values[index] - adjustment).clamp(minP, maxP);
      }

      double actualAdjustment = values[index] - oldValue;
      remainingExcess -= actualAdjustment;

      print(
        '    ${_stocks[index].shortName}: ${oldValue.toStringAsFixed(2)}% → ${values[index].toStringAsFixed(2)}% (корр: ${actualAdjustment.toStringAsFixed(2)}%)',
      );
    }
  }

  void _rebalancePortfolio() {
    if (_stocks.isEmpty) {
      _showSnackBar('Нет данных об акциях для ребалансировки', Colors.red);
      return;
    }

    double currentPortfolioValue = 0;
    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final existingShares =
          int.tryParse(_existingSharesControllers[i].text) ?? 0;
      currentPortfolioValue += existingShares * stock.lastPrice;
    }

    if (currentPortfolioValue <= 0) {
      _showSnackBar('Введите имеющиеся акции для ребалансировки', Colors.red);
      return;
    }

    _cachedTargetPercentages = null;
    final List<double> targetPercentages = _calculateTargetPercentages();

    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final double targetValue =
          (targetPercentages[i] / 100) * currentPortfolioValue;
      int targetShares = (targetValue / stock.lastPrice).round();
      targetShares = targetShares < 0 ? 0 : targetShares;
      _existingSharesControllers[i].text = targetShares.toString();
    }

    setState(() {
      _showAllocation = false;
      _cachedTargetPercentages = null;
    });

    _showSnackBar('Портфель ребалансирован', Colors.green);
  }

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

    final List<int> existingShares = [];
    for (int i = 0; i < _stocks.length; i++) {
      final shares = int.tryParse(_existingSharesControllers[i].text) ?? 0;
      existingShares.add(shares);
    }

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

    _cachedTargetPercentages = null;
    final List<double> targetPercentages = _calculateTargetPercentages();

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

    _allocateWithImprovedAlgorithm(
      amount,
      sharePrices,
      targetPercentages,
      currentPortfolioValue,
      totalPortfolioValue,
      existingCosts,
    );

    setState(() {
      _showAllocation = true;
    });
  }

  void _allocateWithImprovedAlgorithm(
    double amount,
    List<double> sharePrices,
    List<double> targetPercentages,
    double currentPortfolioValue,
    double totalPortfolioValue,
    List<double> existingCosts,
  ) {
    final List<double> targetAmounts = [];
    for (int i = 0; i < _stocks.length; i++) {
      final double targetAmount =
          (targetPercentages[i] / 100) * totalPortfolioValue;
      targetAmounts.add(targetAmount);
    }

    final List<Map<String, dynamic>> stockData = [];
    double totalToSpend = 0;

    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final double sharePrice = sharePrices[i];
      final double lotCost = sharePrice * stock.lotSize;
      final double targetAmount = targetAmounts[i];
      final double existingCost = existingCosts[i];

      final double neededAmount = targetAmount - existingCost;

      int lotsToBuy = 0;
      if (neededAmount > 0) {
        lotsToBuy = (neededAmount / lotCost).floor();
        lotsToBuy = lotsToBuy < 0 ? 0 : lotsToBuy;
      } else {
        lotsToBuy = 0;
      }

      double buyCost = lotsToBuy * lotCost;

      stockData.add({
        'index': i,
        'stock': stock,
        'sharePrice': sharePrice,
        'lotCost': lotCost,
        'targetAmount': targetAmount,
        'existingCost': existingCost,
        'neededAmount': neededAmount,
        'lotsToBuy': lotsToBuy,
        'buyCost': buyCost,
        'totalCostAfterBuy': existingCost + buyCost,
        'deviationAfterBuy': targetAmount - (existingCost + buyCost),
      });

      totalToSpend += buyCost;
    }

    double remainingAmount = amount;

    if (totalToSpend > amount) {
      _reducePurchasesToFitBudget(stockData, amount);
      totalToSpend = stockData.fold(0.0, (sum, data) => sum + data['buyCost']);
    }

    remainingAmount = amount - totalToSpend;

    if (remainingAmount > 0) {
      _distributeRemainingBudget(stockData, remainingAmount, targetAmounts);
    }

    for (var data in stockData) {
      final int index = data['index'];
      final int lotsToBuy = data['lotsToBuy'];
      final double buyCost = data['buyCost'];
      final double totalCost = data['existingCost'] + buyCost;
      final double percentage = (totalCost / totalPortfolioValue) * 100;

      _allocations[index] = StockAllocation(
        stock: _allocations[index].stock,
        lots: lotsToBuy,
        existingLots: _allocations[index].existingLots,
        totalCost: buyCost,
        percentage: percentage,
        existingCost: data['existingCost'],
        existingPercentage:
            (data['existingCost'] / currentPortfolioValue * 100),
      );
    }
  }

  void _reducePurchasesToFitBudget(
    List<Map<String, dynamic>> stockData,
    double availableBudget,
  ) {
    stockData.sort((a, b) {
      final double devA = a['deviationAfterBuy'];
      final double devB = b['deviationAfterBuy'];
      return devA.compareTo(devB);
    });

    double totalSpent = stockData.fold(
      0.0,
      (sum, data) => sum + data['buyCost'],
    );

    while (totalSpent > availableBudget && totalSpent > 0) {
      bool reduced = false;

      for (var data in stockData) {
        if (data['lotsToBuy'] > 0) {
          data['lotsToBuy'] = data['lotsToBuy'] - 1;
          data['buyCost'] = data['lotsToBuy'] * data['lotCost'];
          data['totalCostAfterBuy'] = data['existingCost'] + data['buyCost'];
          data['deviationAfterBuy'] =
              data['targetAmount'] - data['totalCostAfterBuy'];

          totalSpent = stockData.fold(0.0, (sum, d) => sum + d['buyCost']);
          reduced = true;

          if (totalSpent <= availableBudget) {
            break;
          }
        }
      }

      if (!reduced) {
        break;
      }
    }
  }

  void _distributeRemainingBudget(
    List<Map<String, dynamic>> stockData,
    double remainingAmount,
    List<double> targetAmounts,
  ) {
    List<Map<String, dynamic>> underInvestedStocks = [];

    for (var data in stockData) {
      double deviation = data['deviationAfterBuy'];
      if (deviation > 0) {
        underInvestedStocks.add(data);
      }
    }

    bool distributed = true;
    while (remainingAmount > 0 &&
        distributed &&
        underInvestedStocks.isNotEmpty) {
      distributed = false;

      underInvestedStocks.sort(
        (a, b) => b['deviationAfterBuy'].compareTo(a['deviationAfterBuy']),
      );

      final List<Map<String, dynamic>> stocksToProcess = List.from(
        underInvestedStocks,
      );

      for (var data in stocksToProcess) {
        double lotCost = data['lotCost'];
        double deviation = data['deviationAfterBuy'];

        if (lotCost <= remainingAmount && deviation >= lotCost * 0.5) {
          data['lotsToBuy'] = data['lotsToBuy'] + 1;
          data['buyCost'] = data['lotsToBuy'] * data['lotCost'];
          data['totalCostAfterBuy'] = data['existingCost'] + data['buyCost'];
          data['deviationAfterBuy'] =
              data['targetAmount'] - data['totalCostAfterBuy'];

          remainingAmount -= lotCost;
          distributed = true;

          if (data['deviationAfterBuy'] <= 0) {
            underInvestedStocks.remove(data);
          }

          if (remainingAmount <= 0) break;
        }
      }

      if (!distributed) {
        break;
      }
    }

    if (remainingAmount > 0) {
      _distributeEvenlyAllStocks(stockData, remainingAmount);
    }
  }

  void _distributeEvenlyAllStocks(
    List<Map<String, dynamic>> stockData,
    double remainingAmount,
  ) {
    List<Map<String, dynamic>> availableStocks = [];

    for (var data in stockData) {
      double lotCost = data['lotCost'];
      if (lotCost <= remainingAmount) {
        availableStocks.add(data);
      }
    }

    bool distributed = true;
    while (remainingAmount > 0 && distributed && availableStocks.isNotEmpty) {
      distributed = false;

      availableStocks.sort((a, b) => a['lotsToBuy'].compareTo(b['lotsToBuy']));

      final List<Map<String, dynamic>> stocksToProcess = List.from(
        availableStocks,
      );

      for (var data in stocksToProcess) {
        double lotCost = data['lotCost'];

        if (lotCost <= remainingAmount) {
          data['lotsToBuy'] = data['lotsToBuy'] + 1;
          data['buyCost'] = data['lotsToBuy'] * data['lotCost'];
          data['totalCostAfterBuy'] = data['existingCost'] + data['buyCost'];

          remainingAmount -= lotCost;
          distributed = true;

          if (lotCost > remainingAmount) {
            availableStocks.remove(data);
          }

          if (remainingAmount <= 0) break;
        } else {
          availableStocks.remove(data);
        }
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  void _onShareChanged(int index) {
    setState(() {
      _cachedTargetPercentages = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Получаем текущие целевые проценты
    final List<double> currentTargets = _calculateTargetPercentages();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Покупка акций (SMA)'),
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

                    if (_isLoadingSma)
                      Card(
                        margin: const EdgeInsets.all(8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Загрузка данных SMA200...',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

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

                    ExistingSharesInput(
                      stocks: _stocks,
                      controllers: _existingSharesControllers,
                      onRebalance: _rebalancePortfolio,
                      onChanged: _onShareChanged,
                      targetPercentages: currentTargets,
                    ),

                    if (_showAllocation)
                      AllocationResults(
                        allocations: _allocations,
                        amount: double.tryParse(_amountController.text) ?? 0,
                        remaining:
                            (double.tryParse(_amountController.text) ?? 0) -
                            _allocations.fold(
                              0.0,
                              (sum, allocation) => sum + allocation.totalCost,
                            ),
                        useSmaAdjustment: true,
                        targetPercentages: currentTargets,
                      ),

                    AdaptiveStocksGrid(stocks: _stocks),
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
