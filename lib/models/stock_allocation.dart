import 'stock.dart';

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
