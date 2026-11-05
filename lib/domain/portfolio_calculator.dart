import '../models/stock.dart';
import '../models/stock_allocation.dart';

/// Чистая логика без Flutter и сети — легко покрывается unit-тестами.
abstract final class PortfolioCalculator {
  static const int _maxIterations = 100000;
  static const double _budgetTolerance = 0.01;

  /// Целевые доли в % (в сумме 100), в порядке [stocks].
  static List<double> normalizedTargets(List<Stock> stocks) {
    if (stocks.isEmpty) return const [];
    final totalWeight = stocks.fold<double>(
      0,
      (sum, s) => sum + s.targetWeight,
    );
    if (totalWeight <= 0) {
      return List.filled(stocks.length, 100 / stocks.length);
    }
    return [for (final s in stocks) s.targetWeight / totalWeight * 100];
  }

  static double portfolioValue(List<Stock> stocks, List<int> shares) {
    var total = 0.0;
    for (var i = 0; i < stocks.length; i++) {
      total += shares[i] * stocks[i].lastPrice;
    }
    return total;
  }

  /// Количество акций (кратное лоту), приводящее текущий портфель к целевым долям.
  static List<int> rebalancedShares({
    required List<Stock> stocks,
    required List<double> targets,
    required double portfolioValue,
  }) {
    return [
      for (var i = 0; i < stocks.length; i++)
        _sharesForTarget(stocks[i], targets[i] / 100 * portfolioValue),
    ];
  }

  static int _sharesForTarget(Stock stock, double targetValue) {
    final shares = (targetValue / stock.lastPrice).round();
    final lots = (shares / stock.lotSize).ceil();
    return lots * stock.lotSize;
  }

  /// Жадное распределение [amount]: каждый шаг покупаем лот той бумаги,
  /// у которой после покупки останется наибольший дефицит до целевой доли.
  static AllocationResult allocate({
    required List<Stock> stocks,
    required List<int> existingShares,
    required List<double> targets,
    required double amount,
  }) {
    final count = stocks.length;
    final lotCosts = [for (final s in stocks) s.lotCost];
    final existingCosts = [
      for (var i = 0; i < count; i++) existingShares[i] * stocks[i].lastPrice,
    ];
    final existingValue = existingCosts.fold<double>(0, (a, b) => a + b);

    final lots = List<int>.filled(count, 0);
    final values = List<double>.of(existingCosts);
    var spent = 0.0;

    for (var iter = 0; iter < _maxIterations && spent < amount; iter++) {
      var bestIndex = -1;
      var maxDeficit = double.negativeInfinity;

      for (var i = 0; i < count; i++) {
        if (spent + lotCosts[i] > amount + _budgetTolerance) continue;

        final futureTotal = existingValue + spent + lotCosts[i];
        final deficit =
            targets[i] / 100 * futureTotal - (values[i] + lotCosts[i]);
        if (deficit > maxDeficit) {
          maxDeficit = deficit;
          bestIndex = i;
        }
      }

      if (bestIndex == -1) break;
      lots[bestIndex]++;
      values[bestIndex] += lotCosts[bestIndex];
      spent += lotCosts[bestIndex];
    }

    final newTotal = existingValue + spent;
    final allocations = [
      for (var i = 0; i < count; i++)
        StockAllocation(
          stock: stocks[i],
          lots: lots[i],
          existingLots: existingShares[i] ~/ stocks[i].lotSize,
          purchaseCost: lots[i] * lotCosts[i],
          existingCost: existingCosts[i],
          existingPercentage: _share(existingCosts[i], existingValue),
          newPercentage: _share(values[i], newTotal),
        ),
    ];

    return AllocationResult(
      allocations: allocations,
      amount: amount,
      existingValue: existingValue,
      averageDeviation: _averageDeviation(allocations, targets),
    );
  }

  static double _share(double part, double total) =>
      total > 0 ? part / total * 100 : 0;

  static double _averageDeviation(
    List<StockAllocation> allocations,
    List<double> targets,
  ) {
    if (allocations.isEmpty) return 0;
    var sum = 0.0;
    for (var i = 0; i < allocations.length; i++) {
      sum += (allocations[i].newPercentage - targets[i]).abs();
    }
    return sum / allocations.length;
  }
}
