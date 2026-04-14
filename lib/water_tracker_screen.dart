import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';

class WaterTrackerScreen extends StatelessWidget {
  const WaterTrackerScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  DocumentReference get _docRef => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('water_logs')
      .doc(_today);

  DocumentReference get _prefsRef => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('profile')
      .doc('preferences');

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
              content: Text('Failed to save data. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Water Tracker'),
        backgroundColor: AppTheme.background,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // FIX: Also stream preferences to display the daily goal
        stream: _docRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading data.'));
          }

          final data =
              snapshot.data?.data() as Map<String, dynamic>?;
          final intake = data?['intake_ml'] as int? ?? 0;

          return FutureBuilder<DocumentSnapshot>(
            future: _prefsRef.get(),
            builder: (context, prefsSnap) {
              final prefsData =
                  prefsSnap.data?.data() as Map<String, dynamic>?;
              final goal =
                  prefsData?['daily_water_goal_ml'] as int? ?? 2000;
              final progress = (intake / goal).clamp(0.0, 1.0);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),

                    // Progress circle
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
                            color: AppTheme.primary,
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
                                  color: AppTheme.textPrimary),
                            ),
                            Text(
                              'of ${goal}ml',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // FIX: Added linear progress bar for visual goal tracking
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: AppTheme.primaryLight,
                        color: AppTheme.primary,
                      ),
                    ),

                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toInt()}% of daily goal',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textMuted),
                    ),

                    const SizedBox(height: 32),

                    // Quick-add buttons
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [150, 250, 350, 500].map((ml) {
                        return ElevatedButton(
                          onPressed: () =>
                              _updateIntake(context, ml),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(80, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(14)),
                          ),
                          child: Text('+${ml}ml'),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    OutlinedButton.icon(
                      onPressed: intake >= 250
                          ? () => _updateIntake(context, -250)
                          : null,
                      icon: const Icon(Icons.remove, size: 16),
                      label: const Text('Remove 250ml'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: const BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}