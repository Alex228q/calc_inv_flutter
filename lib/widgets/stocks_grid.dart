import 'package:flutter/material.dart';
import '../models/stock.dart';

class AdaptiveStocksGrid extends StatelessWidget {
  final List<Stock> stocks;

  const AdaptiveStocksGrid({Key? key, required this.stocks}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                Icon(Icons.trending_up, color: theme.colorScheme.primary),
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
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
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
                width: 80,
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
                width: 80,
                child: Text(
                  'Лот',
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
                  // Иконка и тикер
                  Expanded(
                    child: Row(
                      children: [
                        // Виджет для отображения логотипа или цветного фона
                        _buildLogoWidget(stock.secId, index),
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

                  // Цена
                  SizedBox(
                    width: 80,
                    child: Text(
                      '${stock.lastPrice.toStringAsFixed(2)} ₽',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Информация о лоте
                  SizedBox(
                    width: 80,
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
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  // Метод для построения виджета логотипа
  Widget _buildLogoWidget(String ticker, int index) {
    // Пытаемся загрузить изображение из assets
    try {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          // Добавляем белую подложку для логотипов с прозрачным фоном
          color: Colors.white,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/icons/$ticker.png', // Путь к файлу логотипа
            width: 32,
            height: 32,
            fit: BoxFit.contain, // Сохраняем пропорции логотипа
            errorBuilder: (context, error, stackTrace) {
              // Если файл не найден, возвращаем цветной контейнер
              return _buildFallbackLogo(ticker, index);
            },
          ),
        ),
      );
    } catch (e) {
      // В случае ошибки возвращаем цветной контейнер
      return _buildFallbackLogo(ticker, index);
    }
  }

  // Запасной вариант с цветным градиентом
  Widget _buildFallbackLogo(String ticker, int index) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStockColor(index).withOpacity(0.8),
            _getStockColor(index).withOpacity(0.4),
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
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
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
    ];
    return colors[index % colors.length];
  }
}
