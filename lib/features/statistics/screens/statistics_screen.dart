import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/genres.dart';
import '../../../core/utils.dart';
import '../../../models/book.dart';
import '../../../providers/library_provider.dart';
import '../../../widgets/common_widgets.dart';
import 'history_screen.dart';

/// Síntesis de la actividad lectora (RF-07).
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final books = library.books;
    final average = library.averageRating;
    final perMonth = library.completedPerMonth();
    final topGenres = library.topGenres();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        actions: [
          IconButton(
            tooltip: 'Historial de lectura',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
        ],
      ),
      body: books.isEmpty
          ? const EmptyState(
              icon: Icons.bar_chart,
              title: 'Todavía no hay datos',
              message:
                  'Cuando registres libros y avances, aquí verás tu trayectoria lectora.',
            )
          // H-01: en pantallas anchas el contenido se limita a un ancho
          // máximo y las tarjetas de resumen tienen altura fija, para que no
          // se agranden al ensanchar la ventana.
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        mainAxisExtent: 100,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      children: [
                        _StatCard(label: 'Libros', value: '${books.length}', icon: Icons.library_books),
                        _StatCard(
                          label: 'Terminados',
                          value: '${library.countByStatus(ReadingStatus.completed)}',
                          icon: Icons.check_circle_outline,
                        ),
                        _StatCard(
                          label: 'En lectura',
                          value: '${library.countByStatus(ReadingStatus.reading)}',
                          icon: Icons.auto_stories,
                        ),
                        _StatCard(label: 'Páginas leídas', value: '${library.pagesRead}', icon: Icons.description_outlined),
                        _StatCard(
                          label: 'Págs. este mes',
                          value: '${library.pagesInMonth(DateTime.now())}',
                          icon: Icons.trending_up,
                        ),
                        _StatCard(
                          label: 'Valoración media',
                          value: average == null ? '—' : average.toStringAsFixed(1),
                          icon: Icons.star_outline,
                        ),
                      ],
                    ),
                    const SectionHeader(title: 'Libros por estado'),
                    _StatusChart(library: library),
                    const SectionHeader(title: 'Libros terminados por mes'),
                    _MonthlyChart(data: perMonth),
                    if (topGenres.isNotEmpty) ...[
                      const SectionHeader(title: 'Tus géneros más leídos'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              for (final entry in topGenres)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Icon(Genres.iconOf(entry.key), size: 18, color: AppColors.secondary),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 130,
                                        child: Text(Genres.labelOf(entry.key), overflow: TextOverflow.ellipsis),
                                      ),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: entry.value / topGenres.first.value,
                                            minHeight: 8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('${entry.value}'),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SectionHeader(title: 'Tus sugerencias'),
                    _SuggestionMetricsCard(library: library),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HistoryScreen()),
                      ),
                      icon: const Icon(Icons.history),
                      label: const Text('Ver historial completo'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Ancho máximo del contenido de Estadísticas (H-01).
const double _maxContentWidth = 760;

/// Resumen de cómo el usuario ha respondido a las sugerencias de Descubrir:
/// mostradas, agregadas a la biblioteca y descartadas (métrica de
/// aceptación de OE3).
class _SuggestionMetricsCard extends StatelessWidget {
  const _SuggestionMetricsCard({required this.library});

  final LibraryProvider library;

  @override
  Widget build(BuildContext context) {
    final rate = library.acceptanceRate;
    Widget metric(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                metric('Mostradas', '${library.suggestionsShown}'),
                metric('Agregadas', '${library.suggestionsAccepted}'),
                metric('Descartadas', '${library.suggestionsDismissed}'),
                metric(
                  'Aceptación',
                  rate == null ? '—' : '${(rate * 100).toStringAsFixed(0)} %',
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Porcentaje de sugerencias que agregaste a tu biblioteca '
              'respecto de las que viste en Descubrir e Inicio.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.secondary),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChart extends StatelessWidget {
  const _StatusChart({required this.library});

  final LibraryProvider library;

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final status in ReadingStatus.values) status: library.countByStatus(status),
    };
    final sections = [
      for (final entry in counts.entries)
        if (entry.value > 0)
          PieChartSectionData(
            value: entry.value.toDouble(),
            color: entry.key.color,
            title: '${entry.value}',
            radius: 48,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 180,
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    sections: sections,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final status in ReadingStatus.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: status.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${status.pluralLabel} (${counts[status]})'),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.data});

  final List<MapEntry<DateTime, int>> data;

  @override
  Widget build(BuildContext context) {
    final maxValue = data.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxValue < 3 ? 3 : maxValue + 1).toDouble(),
              barTouchData: BarTouchData(enabled: false),
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) {
                        return const SizedBox.shrink();
                      }
                      final entry = data[index];
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${monthShort(entry.key.month)}\n${entry.value}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < data.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: data[i].value.toDouble(),
                        color: AppColors.primaryDark,
                        width: 18,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
