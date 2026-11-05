import 'stock.dart';

/// Результат по одной бумаге.
class StockAllocation {
  const StockAllocation({
    required this.stock,
    required this.lots,
    required this.existingLots,
    required this.purchaseCost,
    required this.existingCost,
    required this.existingPercentage,
    required this.newPercentage,
  });

  final Stock stock;

  /// Сколько лотов докупить.
  final int lots;
  final int existingLots;

  /// Стоимость докупки.
  final double purchaseCost;
  final double existingCost;

  /// Доля в портфеле до / после докупки, %.
  final double existingPercentage;
  final double newPercentage;
}

/// Итог всего расчёта: все итоговые суммы считаются здесь, а не в виджетах.
class AllocationResult {
  const AllocationResult({
    required this.allocations,
    required this.amount,
    required this.existingValue,
    required this.averageDeviation,
  });

  final List<StockAllocation> allocations;

  /// Сумма пополнения, для которой считали.
  final double amount;
  final double existingValue;

  /// Среднее |доля после − целевая доля|, п.п.
  final double averageDeviation;

  List<StockAllocation> get purchases =>
      allocations.where((a) => a.lots > 0).toList();

  double get spent => allocations.fold(0.0, (sum, a) => sum + a.purchaseCost);

  int get totalLots => allocations.fold(0, (sum, a) => sum + a.lots);

  double get remaining => amount - spent;
}
