import 'package:flutter/material.dart';
import '../core/formatters.dart';
import '../models/stock_allocation.dart';

/// Строка результата по бумаге. Один набор частей, две раскладки.
/// Слева чекбокс, чтобы отметить, что действие выполнено.
class AllocationRow extends StatefulWidget {
  const AllocationRow({super.key, required this.allocation});

  static const double _wideBreakpoint = 800;

  final StockAllocation allocation;

  @override
  State<AllocationRow> createState() => _AllocationRowState();
}

class _AllocationRowState extends State<AllocationRow> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: _done,
                onChanged: (value) => setState(() => _done = value ?? false),
              ),
              Expanded(
                child: Opacity(
                  opacity: _done ? 0.45 : 1,
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < AllocationRow._wideBreakpoint
                        ? _NarrowLayout(allocation: widget.allocation)
                        : _WideLayout(allocation: widget.allocation),
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.allocation});

  final StockAllocation allocation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NameBlock(allocation: allocation),
              _BuyLabel(lots: allocation.lots, fontSize: 16),
            ],
          ),
          const SizedBox(height: 12),
          _CostLabel(cost: allocation.purchaseCost),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BeforeLabel(percentage: allocation.existingPercentage),
              _AfterLabel(percentage: allocation.newPercentage),
            ],
          ),
        ],
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.allocation});

  final StockAllocation allocation;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 2, child: _NameBlock(allocation: allocation)),
        Expanded(
          flex: 1,
          child: _BuyLabel(lots: allocation.lots, fontSize: 18),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _CostLabel(cost: allocation.purchaseCost),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _BeforeLabel(percentage: allocation.existingPercentage),
                  const SizedBox(width: 40),
                  _AfterLabel(percentage: allocation.newPercentage),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NameBlock extends StatelessWidget {
  const _NameBlock({required this.allocation});

  final StockAllocation allocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          allocation.stock.shortName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        if (allocation.existingLots > 0)
          Text(
            'Имеется: ${allocation.existingLots} лотов',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
      ],
    );
  }
}

class _BuyLabel extends StatelessWidget {
  const _BuyLabel({required this.lots, required this.fontSize});

  final int lots;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Купить: $lots лотов',
      style: TextStyle(
        fontSize: fontSize,
        color: Colors.green,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _CostLabel extends StatelessWidget {
  const _CostLabel({required this.cost});

  final double cost;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Стоимость: ${formatRub(cost)}',
      style: const TextStyle(
        fontSize: 16,
        color: Colors.blue,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _BeforeLabel extends StatelessWidget {
  const _BeforeLabel({required this.percentage});

  final double percentage;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Было: ${formatPercent(percentage)}',
      style: const TextStyle(fontSize: 14, color: Colors.grey),
    );
  }
}

class _AfterLabel extends StatelessWidget {
  const _AfterLabel({required this.percentage});

  final double percentage;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Станет: ${formatPercent(percentage)}',
      style: const TextStyle(
        fontSize: 14,
        color: Colors.purple,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
