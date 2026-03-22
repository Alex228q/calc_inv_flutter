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

  List<double>? _cachedTargetPercentages;
  Set<int>? _cachedExcludedIndices;

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
      _cachedExcludedIndices = null;
    });

    try {
      final loadedStocks = await _stockService.fetchStockPrices();
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

  /// УЛУЧШЕННЫЙ АЛГОРИТМ РАСЧЕТА ЦЕЛЕЙ
  /// Учитывает исключенные акции и перераспределяет их доли
  List<double> _calculateTargetPercentages() {
    if (_stocks.isEmpty) return [];
    if (_cachedTargetPercentages != null && _cachedExcludedIndices != null) {
      return _cachedTargetPercentages!;
    }

    final int stockCount = _stocks.length;
    const double overvaluationThreshold = 10.0;

    print(
      '\n=== РАСЧЕТ ЦЕЛЕВЫХ ДОЛЕЙ (ПЛАВНАЯ КОРРЕКТИРОВКА + ПЕРЕРАСПРЕДЕЛЕНИЕ) ===',
    );

    // Параметры алгоритма
    const double maxAdjustment = 3.0;
    const double deviationCap = 20.0;

    List<double> rawWeights = [];
    Set<int> excludedIndices = {};

    // 1. Проход 1: Определяем базовые веса и исключения
    List<double> baseWeights = [];
    double activeWeightSum = 0.0;

    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      double deviation = stock.deviationFromSma ?? 0;

      // Проверка на переоцененность
      if (deviation >= overvaluationThreshold) {
        baseWeights.add(0.0); // Временно 0
        excludedIndices.add(i);
        print('${stock.shortName}: ПЕРЕОЦЕНЕНА -> ИСКЛЮЧЕНА');
        continue;
      }

      double adjustment = 0;
      if (deviation != 0) {
        double normalizedDev = (deviation / deviationCap).clamp(-1.0, 1.0);
        adjustment = -normalizedDev * maxAdjustment;
      }

      // Базовый вес + коррекция SMA
      double weight = (100.0 / stockCount) + adjustment;

      // Защита от отрицательных весов
      weight = weight.clamp(0.1, 100.0);

      baseWeights.add(weight);
      activeWeightSum += weight;
    }

    // 2. Нормализация с учетом исключенных
    // Сумма весов "активных" акций должна стать 100%
    if (activeWeightSum > 0) {
      for (int i = 0; i < baseWeights.length; i++) {
        if (!excludedIndices.contains(i)) {
          // Пропорционально увеличиваем веса оставшихся акций
          rawWeights.add((baseWeights[i] / activeWeightSum) * 100.0);
        } else {
          rawWeights.add(0.0);
        }
      }
    } else {
      // Если все исключены (маловерноятно), возвращаем нули
      return List.filled(stockCount, 0.0);
    }

    // 3. Финальная нормализация до 100% (для устранения ошибок округления)
    List<double> normalized = _normalizeToSum(rawWeights, 100.0);

    _cachedTargetPercentages = normalized;
    _cachedExcludedIndices = excludedIndices;

    print('Исключено акций: ${excludedIndices.length}');
    print('Итоговые доли:');
    for (int i = 0; i < _stocks.length; i++) {
      print('${_stocks[i].shortName}: ${normalized[i].toStringAsFixed(2)}%');
    }

    return normalized;
  }

  List<double> _normalizeToSum(List<double> weights, double targetSum) {
    final int count = weights.length;
    double currentSum = weights.fold(0.0, (a, b) => a + b);
    if (currentSum.abs() < 0.0001) return List.filled(count, 0.0);

    double factor = targetSum / currentSum;
    List<double> normalized = weights.map((w) => w * factor).toList();

    List<double> result = normalized
        .map((w) => double.parse(w.toStringAsFixed(1)))
        .toList();
    double roundedSum = result.fold(0.0, (a, b) => a + b);
    double diff = targetSum - roundedSum;

    if (diff.abs() > 0.001) {
      var indices = List.generate(count, (i) => i);
      indices.sort((a, b) {
        double fracA = normalized[a] - result[a];
        double fracB = normalized[b] - result[b];
        return (diff > 0 ? fracB - fracA : fracA - fracB).toInt();
      });

      int idx = 0;
      while (diff.abs() > 0.001 && idx < count) {
        int i = indices[idx];
        double change = diff > 0 ? 0.1 : -0.1;
        if (result[i] + change >= 0) {
          result[i] += change;
          diff -= change;
        }
        idx++;
      }
    }
    return result;
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
    _cachedExcludedIndices = null;
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
      _cachedExcludedIndices = null;
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
      existingShares.add(int.tryParse(_existingSharesControllers[i].text) ?? 0);
    }

    double currentPortfolioValue = 0;
    final List<double> sharePrices = [];
    final List<double> existingCosts = [];

    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final double cost = existingShares[i] * stock.lastPrice;
      sharePrices.add(stock.lastPrice);
      existingCosts.add(cost);
      currentPortfolioValue += cost;
    }

    final double totalPortfolioValue = currentPortfolioValue + amount;
    _cachedTargetPercentages = null;
    _cachedExcludedIndices = null;
    final List<double> targetPercentages = _calculateTargetPercentages();
    final excludedIndices = _cachedExcludedIndices ?? {};

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

    // ИСПОЛЬЗУЕМ НОВЫЙ ИТЕРАТИВНЫЙ АЛГОРИТМ
    _allocateIteratively(
      amount,
      sharePrices,
      targetPercentages,
      currentPortfolioValue,
      totalPortfolioValue,
      existingCosts,
      excludedIndices,
    );

    setState(() {
      _showAllocation = true;
    });
  }

  /// НОВЫЙ АЛГОРИТМ: Итеративное распределение
  /// Покупает лот за лотом, выбирая актив с наибольшим дефицитом до цели
  void _allocateIteratively(
    double amountToSpend,
    List<double> sharePrices,
    List<double> targetPercentages,
    double currentPortfolioValue,
    double totalPortfolioValue,
    List<double> existingCosts,
    Set<int> excludedIndices,
  ) {
    List<int> lotsToBuy = List.filled(_stocks.length, 0);
    List<double> currentValues = List.from(
      existingCosts,
    ); // Текущая стоимость каждого актива

    double spent = 0.0;

    // Предварительный расчет стоимости одного лота
    List<double> lotCosts = [];
    for (int i = 0; i < _stocks.length; i++) {
      lotCosts.add(sharePrices[i] * _stocks[i].lotSize);
    }

    int safetyCounter = 0;
    const int maxIterations = 10000; // Защита от бесконечного цикла

    while (spent < amountToSpend && safetyCounter < maxIterations) {
      safetyCounter++;

      int bestIndex = -1;
      double maxDeficit = -double.infinity;

      // Ищем актив, которому больше всего "не хватает" до цели с учетом текущего бюджета
      for (int i = 0; i < _stocks.length; i++) {
        // Пропускаем исключенные (переоцененные)
        if (excludedIndices.contains(i)) continue;

        double lotCost = lotCosts[i];

        // Если лот дороже оставшихся денег, пропускаем
        if (spent + lotCost > amountToSpend + 0.01) continue;

        // Считаем дефицит:
        // Целевая стоимость - (Текущая стоимость + стоимость одного лота)
        // Нам нужно найти тот актив, покупка которого даст наибольший вклад в выравнивание портфеля.
        // Точнее: мы выбираем актив, у которого разница между (Целью) и (Текущим + Лот) самая большая (наибольший недобор).

        double targetValue =
            (targetPercentages[i] / 100) *
            (currentPortfolioValue + spent + lotCost);

        // Более простой и надежный эвристический подход:
        // D = (Target% * TotalPortfolio) - CurrentCost.
        // Мы хотим купить тот лот, который максимально уменьшит D.
        // Но поскольку TotalPortfolio растет, пересчитываем D динамически.

        // Текущий прогнозируемый дефицит, если мы купим этот лот
        double futureTotalPortfolio = currentPortfolioValue + spent + lotCost;
        double futureTarget =
            (targetPercentages[i] / 100) * futureTotalPortfolio;
        double futureCurrent = currentValues[i] + lotCost;

        double deficit = futureTarget - futureCurrent;

        // Если дефицит положительный, значит нам все еще нужно докупать этот актив.
        // Мы выбираем актив с самым большим дефицитом.

        // Нюанс: Если у актива дефицит отрицательный (мы уже перебрали), мы его не покупаем в приоритете.
        // Но если у всех дефицит отрицательный (идеальный портфель), мы можем докупить того, у кого он "наименее отрицательный".

        if (deficit > maxDeficit) {
          maxDeficit = deficit;
          bestIndex = i;
        }
      }

      // Если не нашли подходящий лот (либо все куплено, либо не хватает денег)
      if (bestIndex == -1) break;

      // Совершаем покупку
      double buyLotCost = lotCosts[bestIndex];
      lotsToBuy[bestIndex]++;
      currentValues[bestIndex] += buyLotCost;
      spent += buyLotCost;
    }

    print('Аллокация завершена. Потрачено: $spent из $amountToSpend');

    // Сохранение результатов
    for (int i = 0; i < _stocks.length; i++) {
      final double buyCost = lotsToBuy[i] * lotCosts[i];
      final double totalCost = existingCosts[i] + buyCost;

      _allocations[i] = StockAllocation(
        stock: _allocations[i].stock,
        lots: lotsToBuy[i],
        existingLots: _allocations[i].existingLots,
        totalCost: buyCost,
        percentage: (totalCost / (currentPortfolioValue + spent)) * 100,
        existingCost: existingCosts[i],
        existingPercentage: (existingCosts[i] / currentPortfolioValue * 100),
      );
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
      _cachedExcludedIndices = null;
    });
  }

  @override
  Widget build(BuildContext context) {
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
            ? const Center(child: Text('Нет данных для отображения'))
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
                      const Card(
                        margin: EdgeInsets.all(8.0),
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text('Загрузка данных SMA200...'),
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
                              (sum, a) => sum + a.totalCost,
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
