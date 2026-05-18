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

  DateTime _selectedDate = DateTime.now();
  final DateFormat _displayFormat = DateFormat('d MMM yyyy');

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  String get _selectedDateKey =>
      '${_selectedDate.year}-'
      '${_selectedDate.month.toString().padLeft(2, '0')}-'
      '${_selectedDate.day.toString().padLeft(2, '0')}';

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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _goToToday() => setState(() => _selectedDate = DateTime.now());
  void _goToPrevDay() =>
      setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
  void _goToNextDay() {
    final next = _selectedDate.add(const Duration(days: 1));
    if (!next.isAfter(DateTime.now())) setState(() => _selectedDate = next);
  }

  // ── Log / Edit dialog ──────────────────────────────────────────────────────
  Future<void> _showLogDialog(StepProvider sp, {String? prefillDate, int? prefillSteps}) async {
    final targetDate = prefillDate != null
        ? DateTime.parse(prefillDate)
        : _selectedDate;
    final isEditingToday = prefillDate == null;
    final ctrl = TextEditingController(
        text: prefillSteps != null && prefillSteps > 0 ? prefillSteps.toString() : '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_walk,
                      color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prefillSteps != null ? 'Edit Steps' : 'Log Steps',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary),
                      ),
                      Text(
                        isEditingToday
                            ? (_isToday ? 'Today' : _displayFormat.format(_selectedDate))
                            : _displayFormat.format(targetDate),
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Step count',
                hintText: 'e.g. 8000',
                suffixIcon: ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => ctrl.clear(),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            // Quick presets
            Wrap(
              spacing: 8,
              children: [3000, 5000, 8000, 10000, 12000].map((v) {
                return ActionChip(
                  label: Text('${v ~/ 1000}k'),
                  onPressed: () => ctrl.text = v.toString(),
                  backgroundColor: AppTheme.primaryLight,
                  labelStyle: const TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.w500),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final steps = int.tryParse(ctrl.text.trim());
                  if (steps == null || steps < 0) return;
                  final dateKey = prefillDate ??
                      '${_selectedDate.year}-'
                      '${_selectedDate.month.toString().padLeft(2, '0')}-'
                      '${_selectedDate.day.toString().padLeft(2, '0')}';
                  await sp.logSteps(steps, date: DateTime.parse(dateKey));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(prefillSteps != null ? 'Update Steps' : 'Save Steps'),
              ),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  // ── Delete confirm dialog ──────────────────────────────────────────────────
  Future<void> _confirmDelete(StepProvider sp, String dateKey, int steps) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Entry',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        content: Text(
          'Delete $steps steps on $dateKey?',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await sp.deleteStepsForDate(dateKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry deleted'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // ── Full history bottom sheet ──────────────────────────────────────────────
  void _showHistory(StepProvider sp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Step History',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppTheme.textPrimary)),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showLogDialog(sp);
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const Divider(),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: sp.allEntries.length,
                itemBuilder: (context, index) {
                  final entry = sp.allEntries[index];
                  final progress = (entry.steps / sp.dailyGoal).clamp(0.0, 1.0);
                  final reached = entry.steps >= sp.dailyGoal;
                  DateTime? parsedDate;
                  try { parsedDate = DateTime.parse(entry.date); } catch (_) {}

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: reached
                              ? Colors.green.withOpacity(0.4)
                              : AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: reached
                                    ? Colors.green.withOpacity(0.1)
                                    : AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.directions_walk,
                                  color: reached ? Colors.green : AppTheme.primary,
                                  size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    parsedDate != null
                                        ? DateFormat('EEE, d MMM yyyy').format(parsedDate)
                                        : entry.date,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppTheme.textPrimary),
                                  ),
                                  Text(
                                    '${entry.steps.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} steps'
                                    '${reached ? '  ✅' : ''}',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: reached ? Colors.green : AppTheme.textMuted,
                                        fontWeight: reached ? FontWeight.w500 : FontWeight.normal),
                                  ),
                                ],
                              ),
                            ),
                            // Edit button
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  color: AppTheme.primary, size: 20),
                              tooltip: 'Edit',
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showLogDialog(sp,
                                    prefillDate: entry.date,
                                    prefillSteps: entry.steps);
                              },
                            ),
                            // Delete button
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red, size: 20),
                              tooltip: 'Delete',
                              onPressed: () {
                                Navigator.pop(ctx);
                                _confirmDelete(sp, entry.date, entry.steps);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: AppTheme.primaryLight,
                            color: reached ? Colors.green : AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${(progress * 100).toInt()}% of goal',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textMuted)),
                            Text(
                              reached
                                  ? 'Goal reached!'
                                  : '${(sp.dailyGoal - entry.steps)} to go',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: reached ? Colors.green : AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StepProvider>();
    final isToday = _isToday;
    final selectedSteps = sp.stepsForDate(_selectedDateKey);
    final hasEntry = selectedSteps > 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Step Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
            onPressed: sp.loading ? null : () => _showHistory(sp),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Log Steps',
            onPressed: sp.loading ? null : () => _showLogDialog(sp),
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
                    // ── Date navigator ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _goToPrevDay,
                            tooltip: 'Previous day',
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _pickDate,
                              child: Column(
                                children: [
                                  Text(
                                    isToday
                                        ? 'Today'
                                        : _displayFormat.format(_selectedDate),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: AppTheme.textPrimary),
                                  ),
                                  if (!isToday)
                                    const Text('tap to change date',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.textMuted)),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: isToday ? null : _goToNextDay,
                            color: isToday ? AppTheme.border : null,
                            tooltip: 'Next day',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Selected date ring card ──
                    _DateRingCard(
                      steps: selectedSteps,
                      goal: sp.dailyGoal,
                      label: isToday ? 'Today' : _displayFormat.format(_selectedDate),
                      streak: isToday ? sp.currentStreak : 0,
                      hasEntry: hasEntry,
                      onLog: () => _showLogDialog(sp),
                      onEdit: hasEntry
                          ? () => _showLogDialog(sp,
                              prefillDate: _selectedDateKey,
                              prefillSteps: selectedSteps)
                          : null,
                      onDelete: hasEntry
                          ? () => _confirmDelete(sp, _selectedDateKey, selectedSteps)
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // ── Stats row ──
                    _StepStatsRow(sp: sp),
                    const SizedBox(height: 20),

                    // ── Insight ──
                    _InsightCard(sp: sp),
                    const SizedBox(height: 20),

                    // ── Charts ──
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
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Date Ring Card ────────────────────────────────────────────────────────────

class _DateRingCard extends StatelessWidget {
  const _DateRingCard({
    required this.steps,
    required this.goal,
    required this.label,
    required this.streak,
    required this.hasEntry,
    required this.onLog,
    this.onEdit,
    this.onDelete,
  });

  final int steps;
  final int goal;
  final String label;
  final int streak;
  final bool hasEntry;
  final VoidCallback onLog;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = (steps / goal).clamp(0.0, 1.0);
    final reached = progress >= 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: reached ? Colors.green.withOpacity(0.5) : AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Ring
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
                      color: reached ? Colors.green : AppTheme.primary,
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
                                fontSize: 11, color: AppTheme.textMuted)),
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
                    Text(label,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text('$steps / $goal steps',
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(
                      reached
                          ? 'Goal reached! 🎉'
                          : hasEntry
                              ? '${goal - steps} steps to goal'
                              : 'No entry yet',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: reached
                              ? Colors.green
                              : AppTheme.textMuted),
                    ),
                    if (streak > 0) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.local_fire_department,
                            color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text('$streak day streak',
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // ── Action buttons ──
          const SizedBox(height: 16),
          Row(
            children: [
              if (!hasEntry)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onLog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Log Steps'),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10)),
                  ),
                )
              else ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 16,
                        color: Colors.red),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

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
                : DateFormat('d MMM').format(DateTime.parse(sp.highestStepDate)),
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
  final String label, value, sub;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
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
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                textAlign: TextAlign.center),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ── Insight Card ──────────────────────────────────────────────────────────────

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
      child: Row(children: [
        const Icon(Icons.directions_walk, color: Colors.white, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(sp.insightText,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

// ── Bar Chart ─────────────────────────────────────────────────────────────────

class _StepBarChart extends StatelessWidget {
  const _StepBarChart({required this.sp, required this.days});
  final StepProvider sp;
  final int days;

  @override
  Widget build(BuildContext context) {
    final entries = sp.entriesForDays(days);
    final maxSteps = entries.map((e) => e.steps).fold(0, (a, b) => a > b ? a : b);

    if (maxSteps == 0) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border)),
        child: const Text('No data yet.',
            style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    final maxY = (maxSteps + 1000).toDouble();

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border)),
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
                  if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                  try {
                    final d = DateTime.parse(entries[idx].date);
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(DateFormat('d').format(d),
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textMuted)),
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
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: entries.asMap().entries.map((e) {
            final steps = e.value.steps;
            final reached = steps >= sp.dailyGoal;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: steps.toDouble(),
                  color: reached ? Colors.green : AppTheme.primary,
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
