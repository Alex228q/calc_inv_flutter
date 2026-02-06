import 'package:flutter/material.dart';
import '../models/stock.dart';

class AdaptiveStocksGrid extends StatelessWidget {
  final List<Stock> stocks;

  const AdaptiveStocksGrid({Key? key, required this.stocks}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stocksWithSma = stocks.where((s) => s.sma200 != null).length;

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
                  color: stocksWithSma > 0
                      ? theme.colorScheme.primary
                      : Colors.grey,
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
                Row(
                  children: [
                    Chip(
                      backgroundColor: stocksWithSma > 0
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 14,
                            color: stocksWithSma > 0
                                ? Colors.green
                                : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'SMA: $stocksWithSma/${stocks.length}',
                            style: TextStyle(
                              fontSize: 11,
                              color: stocksWithSma > 0
                                  ? Colors.green
                                  : Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      backgroundColor: theme.colorScheme.primary.withOpacity(
                        0.1,
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
              ],
            ),

            const SizedBox(height: 16),

            // Адаптивная сетка
            LayoutBuilder(
              builder: (context, constraints) {
                final isWideScreen = constraints.maxWidth > 1000;

                if (isWideScreen) {
                  // Разделяем на две колонки
                  final middleIndex = (stocks.length / 2).ceil();
                  final firstColumn = stocks.sublist(0, middleIndex);
                  final secondColumn = stocks.sublist(middleIndex);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildColumn(theme, firstColumn, 0)),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildColumn(theme, secondColumn, middleIndex),
                      ),
                    ],
                  );
                } else {
                  return _buildColumn(theme, stocks, 0);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumn(
    ThemeData theme,
    List<Stock> columnStocks,
    int startIndex,
  ) {
    return Column(
      children: [
        // Заголовки таблицы
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Акция',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
              SizedBox(width: 16),
              SizedBox(
                width: 70,
                child: Text(
                  'Цена',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
              SizedBox(width: 16),
              SizedBox(
                width: 50,
                child: Text(
                  'Лот',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
              SizedBox(width: 16),
              SizedBox(
                width: 100,
                child: Text(
                  'SMA200',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Список акций
        ...columnStocks.asMap().entries.map((entry) {
          final index = entry.key + startIndex;
          final stock = entry.value;
          final isEven = index % 2 == 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isEven
                  ? theme.colorScheme.surfaceContainerHigh
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  // Иконка и тикер - ОБНОВЛЕНО ДЛЯ ИСПОЛЬЗОВАНИЯ ASSETS
                  Expanded(
                    child: Row(
                      children: [
                        // Логотип акции из assets
                        _buildStockLogo(stock.secId),
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
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
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

                  // Цена
                  SizedBox(
                    width: 70,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${stock.lastPrice.toStringAsFixed(2)} ₽',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (stock.sma200 != null)
                          Text(
                            'SMA: ${stock.sma200!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Информация о лоте
                  SizedBox(
                    width: 50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${stock.lotSize} шт.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Информация о SMA
                  SizedBox(
                    width: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (stock.deviationFromSma != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: stock.deviationFromSma! > 0
                                  ? Colors.red[50]
                                  : Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: stock.deviationFromSma! > 0
                                    ? Colors.red[200]!
                                    : Colors.green[200]!,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  stock.deviationFromSma! > 0
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  size: 12,
                                  color: stock.deviationFromSma! > 0
                                      ? Colors.red[700]
                                      : Colors.green[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${stock.deviationFromSma!.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: stock.deviationFromSma! > 0
                                        ? Colors.red[700]
                                        : Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_off,
                                  size: 12,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Нет данных',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  // ОБНОВЛЕННЫЙ МЕТОД ДЛЯ ОТОБРАЖЕНИЯ ЛОГОТИПОВ ИЗ ASSETS
  Widget _buildStockLogo(String ticker) {
    // Список доступных логотипов в assets
    final availableLogos = [
      'X5.png',
      'MDMG.png',
      'NVTK.png',
      'GMKN.png',
      'PLZL.png',
      'SBERP.png',
      'CHMF.png',
      'TATNP.png',
      'PHOR.png',
      'YDEX.png',
    ];

    final logoFileName = '$ticker.png';

    // Проверяем, есть ли логотип в списке доступных
    if (availableLogos.contains(logoFileName)) {
      return Container(
        width: 40, // Немного увеличим размер для логотипов
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          // Убираем градиентный фон, так как у логотипов может быть свой фон
          color: Colors.transparent,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/icons/$logoFileName',
            width: 40,
            height: 40,
            fit: BoxFit.contain, // Сохраняем пропорции логотипа
            errorBuilder: (context, error, stackTrace) {
              // Если файл не найден, возвращаем запасной вариант
              print('Не удалось загрузить логотип для $ticker: $error');
              return _buildFallbackLogo(ticker);
            },
          ),
        ),
      );
    } else {
      // Если тикер не в списке, используем запасной вариант
      return _buildFallbackLogo(ticker);
    }
  }

  // Запасной вариант с цветным градиентом (используется при ошибках)
  Widget _buildFallbackLogo(String ticker) {
    // Определяем индекс для цвета на основе тикера
    final tickerIndex = _getTickerIndex(ticker);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStockColor(tickerIndex).withOpacity(0.8),
            _getStockColor(tickerIndex).withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          ticker.substring(0, 1), // Первая буква тикера
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Получаем индекс тикера для определения цвета
  int _getTickerIndex(String ticker) {
    final tickers = [
      'X5',
      'MDMG',
      'NVTK',
      'GMKN',
      'PLZL',
      'SBERP',
      'CHMF',
      'TATNP',
      'PHOR',
      'YDEX',
    ];
    final index = tickers.indexOf(ticker);
    return index >= 0 ? index : 0;
  }

  Color _getStockColor(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
    ];
    return colors[index % colors.length];
  }
}
