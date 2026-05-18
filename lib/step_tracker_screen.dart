import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'step_provider.dart';

class StepTrackerScreen extends StatefulWidget {
  const StepTrackerScreen({super.key});

  @override
  State<StepTrackerScreen> createState() => _StepTrackerScreenState();
}

class _StepTrackerScreenState extends State<StepTrackerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StepProvider>().seedDemoDataIfEmpty();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StepProvider>();
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Step Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showLogDialog(context, sp),
          ),
        ],
      ),
      body: sp.loading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TodayRing(sp: sp),
                    const SizedBox(height: 20),
                    _StepStatsRow(sp: sp),
                    const SizedBox(height: 20),
                    _InsightCard(sp: sp),
                    const SizedBox(height: 20),
                    const Text('Last 7 Days',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    _StepBarChart(sp: sp, days: 7),
                    const SizedBox(height: 20),
                    const Text('Last 30 Days',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    _StepBarChart(sp: sp, days: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _showLogDialog(
      BuildContext context, StepProvider sp) async {
    final ctrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Log Steps',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Steps today',
                hintText: 'e.g. 8000',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final steps = int.tryParse(ctrl.text.trim());
                  if (steps == null || steps < 0) return;
                  await sp.logSteps(steps);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }
}

class _TodayRing extends StatelessWidget {
  const _TodayRing({required this.sp});
  final StepProvider sp;

  @override
  Widget build(BuildContext context) {
    final steps = sp.todaySteps;
    final goal = sp.dailyGoal;
    final progress = (steps / goal).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  backgroundColor: AppTheme.primaryLight,
                  color: progress >= 1.0
                      ? Colors.green
                      : AppTheme.primary,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      steps >= 1000
                          ? '${(steps / 1000).toStringAsFixed(1)}k'
                          : '$steps',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppTheme.textPrimary),
                    ),
                    const Text('steps',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  '$steps / $goal steps',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  progress >= 1.0
                      ? 'Goal reached! 🎉'
                      : '${(goal - steps)} steps to goal',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: progress >= 1.0
                          ? Colors.green
                          : AppTheme.textMuted),
                ),
                const SizedBox(height: 6),
                if (sp.currentStreak > 0)
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text('${sp.currentStreak} day streak',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.orange,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepStatsRow extends StatelessWidget {
  const _StepStatsRow({required this.sp});
  final StepProvider sp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatBox(
            label: '7-Day Avg',
            value: sp.weeklyAverage.toInt().toString(),
            sub: 'steps/day',
            icon: Icons.show_chart),
        const SizedBox(width: 10),
        _StatBox(
            label: '30-Day Avg',
            value: sp.monthlyAverage.toInt().toString(),
            sub: 'steps/day',
            icon: Icons.bar_chart),
        const SizedBox(width: 10),
        _StatBox(
            label: 'Best Day',
            value: sp.highestStepDay >= 1000
                ? '${(sp.highestStepDay / 1000).toStringAsFixed(1)}k'
                : sp.highestStepDay.toString(),
            sub: sp.highestStepDate.isEmpty
                ? '—'
                : DateFormat('d MMM')
                    .format(DateTime.parse(sp.highestStepDate)),
            icon: Icons.emoji_events_outlined),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
  });
  final String label;
  final String value;
  final String sub;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimary)),
            Text(sub,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textMuted),
                textAlign: TextAlign.center),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.sp});
  final StepProvider sp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B67F8), Color(0xFF3D52D5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_walk, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sp.insightText,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBarChart extends StatelessWidget {
  const _StepBarChart({required this.sp, required this.days});
  final StepProvider sp;
  final int days;

  @override
  Widget build(BuildContext context) {
    final entries = sp.entriesForDays(days);
    final maxSteps =
        entries.map((e) => e.steps).reduce((a, b) => a > b ? a : b);
    final maxY = (maxSteps + 1000).toDouble();

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppTheme.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (days / 6).ceilToDouble(),
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  try {
                    final d = DateTime.parse(entries[idx].date);
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(DateFormat('d').format(d),
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMuted)),
                    );
                  } catch (_) {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text(
                  v >= 1000
                      ? '${(v / 1000).toStringAsFixed(0)}k'
                      : v.toStringAsFixed(0),
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textMuted),
                ),
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: entries.asMap().entries.map((e) {
            final steps = e.value.steps;
            final reachedGoal = steps >= sp.dailyGoal;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: steps.toDouble(),
                  color: reachedGoal ? Colors.green : AppTheme.primary,
                  width: days <= 7 ? 20 : 8,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) {
                final entry = entries[group.x];
                return BarTooltipItem(
                  '${entry.steps} steps\n${entry.date}',
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
        ),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      ),
    );
  }
}