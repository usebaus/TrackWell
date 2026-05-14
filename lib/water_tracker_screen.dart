import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'goal_provider.dart';

class WaterTrackerScreen extends StatelessWidget {
  const WaterTrackerScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  DocumentReference<Map<String, dynamic>> get _docRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('water_logs')
          .doc(_today);

  Future<void> _updateIntake(BuildContext context, int delta) async {
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(_docRef);
        final current =
            snap.exists ? ((snap.data() as Map)['intake_ml'] as int? ?? 0) : 0;
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save data. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<GoalsProvider>();

    if (goals.loading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Water Tracker'),
          backgroundColor: AppTheme.background,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
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
                const Icon(Icons.error_outline,
                    size: 40, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  goals.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
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
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _docRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Error loading data.'),
            );
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final intake = data?['intake_ml'] as int? ?? 0;
          final progress = (intake / dailyGoal).clamp(0.0, 1.0);
          final reached = progress >= 1.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
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
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'of ${dailyGoal}ml',
                          style: const TextStyle(
                            fontSize: 13,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: reached ? Colors.green : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: AppTheme.primaryLight,
                    color: reached ? Colors.green : AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).toInt()}% of daily goal',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 24),
                if (intake == 0) ...[
                  const Icon(
                    Icons.water_drop_outlined,
                    size: 40,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No water logged yet.\nStart by adding your first glass below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [150, 250, 350, 500].map((ml) {
                    return ElevatedButton(
                      onPressed: () => _updateIntake(context, ml),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(80, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text('+${ml}ml'),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed:
                      intake >= 250 ? () => _updateIntake(context, -250) : null,
                  icon: const Icon(Icons.remove, size: 16),
                  label: const Text('Remove 250ml'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}