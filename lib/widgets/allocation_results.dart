import 'package:flutter/material.dart';
import '../models/stock_allocation.dart';

class AllocationResults extends StatelessWidget {
  final List<StockAllocation> allocations;
  final double amount;
  final double remaining;
  final bool useSmaAdjustment;
  final List<double> targetPercentages;

  const AllocationResults({
    Key? key,
    required this.allocations,
    required this.amount,
    required this.remaining,
    this.useSmaAdjustment = false,
    required this.targetPercentages,
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

    double deviationSum = 0;
    for (int i = 0; i < allocations.length; i++) {
      final allocation = allocations[i];
      deviationSum += (allocation.percentage - targetPercentages[i]).abs();
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Результаты распределения:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (useSmaAdjustment)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.trending_up, size: 14, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          'SMA200',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Среднее отклонение от целевых долей: ${averageDeviation.toStringAsFixed(1)}%',
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
                          final stock = allocation.stock;
                          final targetPercentage =
                              targetPercentages[allocations.indexOf(
                                allocation,
                              )];
                          final basePercentage = 100.0 / allocations.length;
                          final smaAdjustment =
                              targetPercentage - basePercentage;

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
                                            stock.shortName,
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
                                          // Информация о SMA
                                          if (useSmaAdjustment &&
                                              stock.deviationFromSma != null)
                                            Text(
                                              'SMA200: ${stock.deviationFromSma!.toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    stock.deviationFromSma! > 0
                                                    ? Colors.red[700]
                                                    : Colors.green[700],
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
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Было: ${allocation.existingPercentage.toStringAsFixed(1)}%',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              if (useSmaAdjustment &&
                                                  smaAdjustment.abs() > 0.1)
                                                Text(
                                                  'Корр.: ${smaAdjustment > 0 ? '+' : ''}${smaAdjustment.toStringAsFixed(1)}%',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: smaAdjustment > 0
                                                        ? Colors.green[700]
                                                        : Colors.red[700],
                                                  ),
                                                ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Станет: ${allocation.percentage.toStringAsFixed(1)}%',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.purple,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                'Цель: ${targetPercentage.toStringAsFixed(1)}%',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
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
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stock.shortName,
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
                                      // Информация о SMA
                                      if (useSmaAdjustment &&
                                          stock.deviationFromSma != null)
                                        Text(
                                          'Отклонение от SMA200: ${stock.deviationFromSma!.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: stock.deviationFromSma! > 0
                                                ? Colors.red[700]
                                                : Colors.green[700],
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
                                  flex: 2,
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
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Было: ${allocation.existingPercentage.toStringAsFixed(1)}%',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 40),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
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
