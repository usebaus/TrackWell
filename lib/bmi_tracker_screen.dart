import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'profile_provider.dart';
import 'weight_provider.dart';

class BmiTrackerScreen extends StatelessWidget {
  const BmiTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final wp = context.watch<WeightProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('BMI Trend'),
      ),
      body: profile.heightCm == null
          ? _NoHeightPrompt()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BmiGaugeCard(profile: profile),
                  const SizedBox(height: 20),
                  _BmiTrendChart(wp: wp, heightCm: profile.heightCm!),
                  const SizedBox(height: 20),
                  _BmiInsightCard(wp: wp, heightCm: profile.heightCm!),
                  const SizedBox(height: 20),
                  _BmiScaleCard(),
                ],
              ),
            ),
    );
  }
}

class _NoHeightPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.height, size: 64, color: AppTheme.primary),
            const SizedBox(height: 16),
            const Text('Add your height in Settings to track BMI over time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textMuted)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              child: const Text('Go to Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BmiGaugeCard extends StatelessWidget {
  const _BmiGaugeCard({required this.profile});
  final ProfileProvider profile;

  @override
  Widget build(BuildContext context) {
    final bmi = profile.bmi;
    final cat = profile.bmiCategory;
    if (bmi == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cat.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: cat.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(bmi.toStringAsFixed(1),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                        color: cat.color)),
                Text('BMI',
                    style:
                        TextStyle(fontSize: 12, color: cat.color)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(cat.label,
                      style: TextStyle(
                          color: cat.color,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
                const SizedBox(height: 8),
                Text(cat.message,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BmiTrendChart extends StatelessWidget {
  const _BmiTrendChart(
      {required this.wp, required this.heightCm});
  final WeightProvider wp;
  final int heightCm;

  double _toBmi(double kg) {
    final h = heightCm / 100.0;
    return kg / (h * h);
  }

  @override
  Widget build(BuildContext context) {
    final entries = wp.allEntries.reversed.toList();
    if (entries.length < 2) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Text(
          'Log weight entries to see your BMI trend.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    final spots = entries.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), _toBmi(e.value.weightKg));
    }).toList();

    final bmiVals = spots.map((s) => s.y).toList();
    final minY = (bmiVals.reduce((a, b) => a < b ? a : b) - 1).clamp(10, 40).toDouble();
    final maxY = (bmiVals.reduce((a, b) => a > b ? a : b) + 1).clamp(15, 45).toDouble();

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 4),
            child: Text('BMI Over Time',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.textPrimary)),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: AppTheme.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: (entries.length / 4).ceilToDouble(),
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= entries.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('MMM').format(entries[idx].timestamp),
                            style: const TextStyle(
                                fontSize: 9,
                                color: AppTheme.textMuted),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                        y: 18.5,
                        color: Colors.blue.withOpacity(0.5),
                        strokeWidth: 1,
                        dashArray: [4, 4]),
                    HorizontalLine(
                        y: 25.0,
                        color: Colors.orange.withOpacity(0.5),
                        strokeWidth: 1,
                        dashArray: [4, 4]),
                    HorizontalLine(
                        y: 30.0,
                        color: Colors.red.withOpacity(0.5),
                        strokeWidth: 1,
                        dashArray: [4, 4]),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppTheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withOpacity(0.15),
                          AppTheme.primary.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            ),
          ),
        ],
      ),
    );
  }
}

class _BmiInsightCard extends StatelessWidget {
  const _BmiInsightCard({required this.wp, required this.heightCm});
  final WeightProvider wp;
  final int heightCm;

  double _toBmi(double kg) {
    final h = heightCm / 100.0;
    return kg / (h * h);
  }

  @override
  Widget build(BuildContext context) {
    final entries = wp.allEntries;
    if (entries.length < 2) return const SizedBox.shrink();

    final latestBmi = _toBmi(entries.first.weightKg);
    final oldestBmi = _toBmi(entries.last.weightKg);
    final change = latestBmi - oldestBmi;
    final direction = change < 0 ? 'decreased' : 'increased';
    final weeks = entries.first.timestamp
        .difference(entries.last.timestamp)
        .inDays / 7.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: change < 0
              ? [const Color(0xFF2DC88A), const Color(0xFF1A9E6A)]
              : [const Color(0xFFDA7101), const Color(0xFFB85E00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text('BMI Insight',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your BMI has $direction by ${change.abs().toStringAsFixed(2)} '
            'over ${weeks.toStringAsFixed(0)} weeks.',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            'From ${oldestBmi.toStringAsFixed(1)} → ${latestBmi.toStringAsFixed(1)}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _BmiScaleCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const ranges = [
      ('< 18.5', 'Underweight', Color(0xFF006494)),
      ('18.5–24.9', 'Normal', Color(0xFF437a22)),
      ('25–29.9', 'Overweight', Color(0xFFda7101)),
      ('≥ 30', 'Obese', Color(0xFFa12c7b)),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BMI Scale',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          ...ranges.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: r.$3,
                            borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 10),
                    Text(r.$1,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    Text(r.$2,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}