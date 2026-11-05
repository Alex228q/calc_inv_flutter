import 'package:flutter/material.dart';
import '../core/formatters.dart';
import '../models/stock.dart';
import 'stock_logo.dart';

class AdaptiveStocksGrid extends StatelessWidget {
  const AdaptiveStocksGrid({super.key, required this.stocks});

  static const double _twoColumnBreakpoint = 1000;

  final List<Stock> stocks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSma = stocks.any((s) => s.sma200 != null);

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: hasSma ? theme.colorScheme.primary : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Акции в портфеле',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Chip(
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  label: Text(
                    '${stocks.length} шт.',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth <= _twoColumnBreakpoint) {
                  return _StocksColumn(stocks: stocks);
                }
                final middle = (stocks.length / 2).ceil();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _StocksColumn(stocks: stocks.sublist(0, middle)),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _StocksColumn(
                        stocks: stocks.sublist(middle),
                        startIndex: middle,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

const double _priceWidth = 70;
const double _lotWidth = 60;
const _headerStyle = TextStyle(
  fontWeight: FontWeight.w600,
  fontSize: 12,
  color: Colors.grey,
);

class _StocksColumn extends StatelessWidget {
  const _StocksColumn({required this.stocks, this.startIndex = 0});

  final List<Stock> stocks;

  /// Глобальный индекс первой строки — для сквозной «зебры».
  final int startIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Expanded(child: Text('Акция', style: _headerStyle)),
              SizedBox(width: 16),
              SizedBox(
                width: _priceWidth,
                child: Text('Цена', style: _headerStyle),
              ),
              SizedBox(width: 16),
              SizedBox(
                width: _lotWidth,
                child: Text('Лот', style: _headerStyle),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < stocks.length; i++)
          _StockRow(stock: stocks[i], isStriped: (startIndex + i).isEven),
      ],
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.stock, required this.isStriped});

  final Stock stock;
  final bool isStriped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isStriped
            ? theme.colorScheme.surfaceContainerHigh
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                StockLogo(ticker: stock.secId),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stock.secId,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stock.shortName,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: _priceWidth,
            child: Text(
              formatRub(stock.lastPrice),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: _lotWidth,
            child: Text(
              '${stock.lotSize} шт.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
