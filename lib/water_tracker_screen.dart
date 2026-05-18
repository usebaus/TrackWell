import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'goal_provider.dart';

class WaterTrackerScreen extends StatefulWidget {
  const WaterTrackerScreen({super.key});

  @override
  State<WaterTrackerScreen> createState() => _WaterTrackerScreenState();
}

class _WaterTrackerScreenState extends State<WaterTrackerScreen> {
  late DateTime _selectedDate;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayFormat = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  
  String get _selectedDateKey => _dateFormat.format(_selectedDate);

  DocumentReference<Map<String, dynamic>> get _docRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('water_logs')
          .doc(_selectedDateKey);

  Future<void> _updateIntake(int delta) async {
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(_docRef);
        final current = snap.exists ? ((snap.data() as Map)['intake_ml'] as int? ?? 0) : 0;
        final updated = (current + delta).clamp(0, 99999);
        tx.set(
          _docRef,
          {
            'intake_ml': updated,
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(delta > 0 ? '+${delta}ml added' : '${delta.abs()}ml removed'),
            duration: const Duration(seconds: 1),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
  }

  void _goToYesterday() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<GoalsProvider>();
    final isToday = _isToday;

    if (goals.loading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Water Tracker'),
          backgroundColor: AppTheme.background,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (goals.errorMessage != null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Water Tracker'),
          backgroundColor: AppTheme.background,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  goals.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dailyGoal = goals.waterGoalMl <= 0 ? 2000 : goals.waterGoalMl;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Water Tracker'),
        backgroundColor: AppTheme.background,
        actions: [
          if (!isToday)
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: _goToToday,
              tooltip: 'Go to today',
            ),
        ],
      ),
      body: Column(
        children: [
          // Date selector bar - FIXED: No overflow
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _displayFormat.format(_selectedDate),
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!isToday)
                  IconButton(
                    onPressed: _goToToday,
                    icon: const Icon(Icons.today, size: 20),
                    tooltip: 'Today',
                  ),
                IconButton(
                  onPressed: _goToYesterday,
                  icon: const Icon(Icons.arrow_back, size: 20),
                  tooltip: 'Yesterday',
                ),
              ],
            ),
          ),
          
          // Main content
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _docRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading data.'));
                }

                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final intake = data?['intake_ml'] as int? ?? 0;
                final progress = (intake / dailyGoal).clamp(0.0, 1.0);
                final reached = progress >= 1.0;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Date badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isToday ? AppTheme.primaryLight : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isToday ? 'Today' : _displayFormat.format(_selectedDate),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isToday ? AppTheme.primary : AppTheme.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Progress ring
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 150,
                            height: 150,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 12,
                              backgroundColor: AppTheme.primaryLight,
                              color: reached ? Colors.green : AppTheme.primary,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                intake >= 1000
                                    ? '${(intake / 1000).toStringAsFixed(1)}L'
                                    : '${intake}ml',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'of ${dailyGoal}ml',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        reached ? 'Goal reached! 🎉' : 'Keep sipping water',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: reached ? Colors.green : AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Linear progress
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: AppTheme.primaryLight,
                          color: reached ? Colors.green : AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(progress * 100).toInt()}% of daily goal',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Empty state
                      if (intake == 0) ...[
                        const Icon(
                          Icons.water_drop_outlined,
                          size: 40,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isToday
                              ? 'No water logged yet.\nStart by adding your first glass below.'
                              : 'No water logged on this day.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Action buttons
                      if (isToday) ...[
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [150, 250, 350, 500].map((ml) {
                            return ElevatedButton(
                              onPressed: () => _updateIntake(ml),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(70, 44),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text('+${ml}ml', style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: intake >= 250 ? () => _updateIntake(-250) : null,
                          icon: const Icon(Icons.remove, size: 16),
                          label: const Text('Remove 250ml'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                            side: const BorderSide(color: AppTheme.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.history, size: 32, color: AppTheme.primary),
                              const SizedBox(height: 8),
                              Text(
                                'Total: $intake ml',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'of $dailyGoal ml goal',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}