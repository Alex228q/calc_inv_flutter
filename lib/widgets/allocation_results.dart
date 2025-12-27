import 'package:flutter/material.dart';
import '../models/stock_allocation.dart';

class AllocationResults extends StatelessWidget {
  final List<StockAllocation> allocations;
  final double amount;
  final double remaining;

  const AllocationResults({
    Key? key,
    required this.allocations,
    required this.amount,
    required this.remaining,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalCost = allocations.fold(
      0.0,
      (sum, allocation) => sum + allocation.totalCost,
    );
    final totalLotsToBuy = allocations.fold(
      0,
      (sum, allocation) => sum + allocation.lots,
    );
    final totalExistingCost = allocations.fold(
      0.0,
      (sum, allocation) => sum + allocation.existingCost,
    );

    final double targetPercentage = 100.0 / allocations.length;
    double deviationSum = 0;
    for (final allocation in allocations) {
      deviationSum += (allocation.percentage - targetPercentage).abs();
    }
    final double averageDeviation = deviationSum / allocations.length;

    final allocationsToShow = allocations
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
}
