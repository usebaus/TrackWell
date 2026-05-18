import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'weight_provider.dart';

class WeightTrackerScreen extends StatefulWidget {
  const WeightTrackerScreen({super.key});

  @override
  State<WeightTrackerScreen> createState() => _WeightTrackerScreenState();
}

class _WeightTrackerScreenState extends State<WeightTrackerScreen>
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
      context.read<WeightProvider>().seedDemoDataIfEmpty();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WeightProvider>();
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Weight History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddDialog(context, wp),
          ),
        ],
      ),
      body: wp.loading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatsRow(wp: wp),
                    const SizedBox(height: 20),
                    _InsightCard(wp: wp),
                    const SizedBox(height: 20),
                    _RangeSelector(wp: wp),
                    const SizedBox(height: 12),
                    _WeightChart(wp: wp),
                    const SizedBox(height: 24),
                    _HistoryList(wp: wp),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WeightProvider wp,
      {WeightEntry? editing}) async {
    final ctrl = TextEditingController(
        text: editing != null
            ? editing.weightKg.toStringAsFixed(1)
            : wp.latestWeightKg?.toStringAsFixed(1) ?? '');
    final noteCtrl =
        TextEditingController(text: editing?.note ?? '');
    DateTime selectedDate = editing?.timestamp ?? DateTime.now();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
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
              Text(
                editing == null ? 'Log Weight' : 'Edit Entry',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  hintText: 'e.g. 72.5',
                  suffixText: 'kg',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. After workout',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined,
                    color: AppTheme.primary),
                title: Text(
                  DateFormat('dd MMM yyyy').format(selectedDate),
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setS(() => selectedDate = picked);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final kg = double.tryParse(ctrl.text.trim());
                    if (kg == null || kg <= 0) return;
                    if (editing == null) {
                      await wp.addEntry(kg,
                          note: noteCtrl.text.trim().isEmpty
                              ? null
                              : noteCtrl.text.trim());
                    } else {
                      await wp.updateEntry(
                        editing.id,
                        kg,
                        selectedDate,
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(editing == null ? 'Save Entry' : 'Update'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    ctrl.dispose();
    noteCtrl.dispose();
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.wp});
  final WeightProvider wp;

  @override
  Widget build(BuildContext context) {
    final current = wp.latestWeightKg;
    final change = wp.rangeChange;
    final weekly = wp.weeklyChange;
    return Row(
      children: [
        _StatChip(
          label: 'Current',
          value: current != null
              ? '${current.toStringAsFixed(1)} kg'
              : '—',
          icon: Icons.monitor_weight_outlined,
          color: AppTheme.primary,
        ),
        const SizedBox(width: 10),
        _StatChip(
          label: 'Change',
          value: change != null
              ? '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg'
              : '—',
          icon: change != null && change < 0
              ? Icons.trending_down
              : Icons.trending_up,
          color: change != null && change < 0
              ? Colors.green
              : Colors.orange,
        ),
        const SizedBox(width: 10),
        _StatChip(
          label: 'Weekly',
          value: weekly != null
              ? '${weekly > 0 ? '+' : ''}${weekly.toStringAsFixed(2)} kg'
              : '—',
          icon: Icons.show_chart,
          color: AppTheme.primary,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

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
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ── Insight Card ──────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.wp});
  final WeightProvider wp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2DC88A), Color(0xFF1A9E6A)],
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
              Icon(Icons.insights, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Insights',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(wp.insightText,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
          if (wp.weeklyInsightText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(wp.weeklyInsightText,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

// ── Range Selector ────────────────────────────────────────────────────────────

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.wp});
  final WeightProvider wp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: WeightRange.values.map((r) {
        final selected = wp.selectedRange == r;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => wp.setRange(r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      selected ? AppTheme.primary : AppTheme.border,
                ),
              ),
              child: Text(
                r.label,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Weight Chart ──────────────────────────────────────────────────────────────

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.wp});
  final WeightProvider wp;

  @override
  Widget build(BuildContext context) {
    final entries = wp.filteredEntries.reversed.toList();
    if (entries.length < 2) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Text(
          'Log at least 2 entries to see the graph.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    final spots = entries.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.weightKg);
    }).toList();

    final minY = entries.map((e) => e.weightKg).reduce((a, b) => a < b ? a : b) - 1;
    final maxY = entries.map((e) => e.weightKg).reduce((a, b) => a > b ? a : b) + 1;

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppTheme.border,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(0),
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textMuted),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (entries.length / 4).ceilToDouble(),
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  final date = entries[idx].timestamp;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat('d MMM').format(date),
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textMuted),
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
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppTheme.primary,
              barWidth: 3,
              dotData: FlDotData(
                show: entries.length < 20,
                getDotPainter: (spot, _, __, ___) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: AppTheme.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.20),
                    AppTheme.primary.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final entry = entries[s.x.toInt()];
                return LineTooltipItem(
                  '${entry.weightKg.toStringAsFixed(1)} kg\n${DateFormat('d MMM').format(entry.timestamp)}',
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
          ),
        ),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      ),
    );
  }
}

// ── History List ──────────────────────────────────────────────────────────────

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.wp});
  final WeightProvider wp;

  @override
  Widget build(BuildContext context) {
    final entries = wp.filteredEntries;
    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No entries yet. Tap + to add your first.',
              style: TextStyle(color: AppTheme.textMuted)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('History',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        ...entries.map((entry) => _EntryTile(
              entry: entry,
              onEdit: () => _showEditSheet(context, entry),
              onDelete: () => _confirmDelete(context, entry),
            )),
      ],
    );
  }

  void _showEditSheet(BuildContext context, WeightEntry entry) {
    context
        .findAncestorStateOfType<_WeightTrackerScreenState>()
        ?._showAddDialog(
          context,
          context.read<WeightProvider>(),
          editing: entry,
        );
  }

  Future<void> _confirmDelete(
      BuildContext context, WeightEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(
            '${entry.weightKg.toStringAsFixed(1)} kg on '
            '${DateFormat('d MMM yyyy').format(entry.timestamp)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<WeightProvider>().deleteEntry(entry.id);
    }
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });
  final WeightEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              entry.weightKg.toStringAsFixed(1),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppTheme.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, d MMM yyyy')
                      .format(entry.timestamp),
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: AppTheme.textPrimary),
                ),
                if (entry.note != null)
                  Text(entry.note!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: AppTheme.textMuted)),
          IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Colors.red)),
        ],
      ),
    );
  }
}