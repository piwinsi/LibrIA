import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../models/book.dart';
import '../../../providers/library_provider.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final books = context.watch<LibraryProvider>().books;
    final read = books
        .where((b) => b.status == ReadingStatus.completed)
        .length;
    final reading = books
        .where((b) => b.status == ReadingStatus.reading)
        .length;
    final pending = books
        .where((b) => b.status == ReadingStatus.pending)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (books.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Todavía no hay libros registrados.'),
              ),
            )
          else
            _StatusChart(read: read, reading: reading, pending: pending),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.4,
            children: [
              _StatCard(label: 'Leídos', value: read, color: AppColors.success),
              _StatCard(
                label: 'En progreso',
                value: reading,
                color: AppColors.secondary,
              ),
              _StatCard(
                label: 'Pendientes',
                value: pending,
                color: AppColors.textSecondary,
              ),
              _StatCard(label: 'Total', value: books.length, color: AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChart extends StatelessWidget {
  const _StatusChart({
    required this.read,
    required this.reading,
    required this.pending,
  });

  final int read;
  final int reading;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      if (read > 0)
                        PieChartSectionData(
                          value: read.toDouble(),
                          color: AppColors.success,
                          title: '$read',
                          radius: 50,
                        ),
                      if (reading > 0)
                        PieChartSectionData(
                          value: reading.toDouble(),
                          color: AppColors.secondary,
                          title: '$reading',
                          radius: 50,
                        ),
                      if (pending > 0)
                        PieChartSectionData(
                          value: pending.toDouble(),
                          color: AppColors.textSecondary,
                          title: '$pending',
                          radius: 50,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendItem(color: AppColors.success, label: 'Leídos'),
                  _LegendItem(color: AppColors.secondary, label: 'En progreso'),
                  _LegendItem(color: AppColors.textSecondary, label: 'Pendientes'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }
}
