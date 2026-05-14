import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'water_tracker_screen.dart';
import 'meal_tracker_screen.dart';
import 'exercise_tracker_screen.dart';
import 'medication_tracker_screen.dart';
import 'goal_provider.dart';
import 'profile_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(80, 38),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _showEditGoalsDialog(
    BuildContext context,
    GoalsProvider goals,
  ) async {
    final waterController =
        TextEditingController(text: goals.waterGoalMl.toString());
    final exerciseController =
        TextEditingController(text: goals.exerciseGoalMin.toString());

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Daily goals',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: waterController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Water goal (ml)',
                hintText: 'e.g. 2000',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: exerciseController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Exercise goal (min)',
                hintText: 'e.g. 30',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final water =
                  int.tryParse(waterController.text.trim()) ??
                      goals.waterGoalMl;
              final exercise =
                  int.tryParse(exerciseController.text.trim()) ??
                      goals.exerciseGoalMin;
              await goals.updateDailyGoals(
                waterGoalMlNew: water.clamp(500, 100000),
                exerciseGoalMinNew: exercise.clamp(5, 600),
              );
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Goals updated')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    waterController.dispose();
    exerciseController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<GoalsProvider>();
    final profile = context.watch<ProfileProvider>();     // ← NEW

    final name = profile.displayName?.trim().isNotEmpty == true
        ? profile.displayName!.split(' ').first
        : (FirebaseAuth.instance.currentUser?.displayName
                ?.split(' ')
                .first ??
            'there');

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text(
          'TrackWell',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Log Out',
            onPressed: () => _logout(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Greeting card ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryLight,
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_greeting()}, $name!',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Text(
                          "Let's check your progress today",
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Profile summary card (weight / target weight) ──────
            if (!profile.loading) _ProfileSummaryCard(profile: profile),

            const SizedBox(height: 12),

            // ── BMI card ───────────────────────────────────────────
            if (!profile.loading) _BmiCard(profile: profile),

            const SizedBox(height: 12),

            _LiveStatChips(uid: _uid, today: _today),
            const SizedBox(height: 24),

            // ── Daily goals section ────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's goals",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: goals.loading
                      ? null
                      : () => _showEditGoalsDialog(context, goals),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit goals'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (goals.loading)
              _loadingCard()
            else if (goals.errorMessage != null)
              _errorCard(goals.errorMessage!)
            else
              Column(
                children: [
                  _WaterGoalCard(uid: _uid, dailyGoalMl: goals.waterGoalMl),
                  const SizedBox(height: 12),
                  _ExerciseGoalCard(
                      uid: _uid, dailyGoalMin: goals.exerciseGoalMin),
                ],
              ),

            const SizedBox(height: 24),

            // ── Tracker navigation cards ───────────────────────────
            _sectionHeader('💧 Water', 'Today'),
            const SizedBox(height: 10),
            _trackerCard(context,
                icon: Icons.water_drop_outlined,
                title: 'Water Tracker',
                subtitle: 'Track your daily hydration',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const WaterTrackerScreen()))),
            const SizedBox(height: 20),
            _sectionHeader('🍽 Meals', 'Today'),
            const SizedBox(height: 10),
            _trackerCard(context,
                icon: Icons.restaurant_outlined,
                title: 'Meal Tracker',
                subtitle: 'Log your food intake',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MealTrackerScreen()))),
            const SizedBox(height: 20),
            _sectionHeader('🏃 Exercise', 'Today'),
            const SizedBox(height: 10),
            _trackerCard(context,
                icon: Icons.fitness_center_outlined,
                title: 'Exercise Tracker',
                subtitle: 'Log your workouts',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ExerciseTrackerScreen()))),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ExerciseTrackerScreen())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Activity'),
              ),
            ),
            const SizedBox(height: 20),
            _sectionHeader('💊 Medication', 'Today'),
            const SizedBox(height: 10),
            _trackerCard(context,
                icon: Icons.medication_outlined,
                title: 'Medication Tracker',
                subtitle: 'Track your medications',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MedicationTrackerScreen()))),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _loadingCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );

  Widget _errorCard(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    style:
                        const TextStyle(color: Colors.red, fontSize: 13))),
          ],
        ),
      );

  Widget _sectionHeader(String title, String sub) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: AppTheme.textPrimary)),
          Text(sub,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        ],
      );

  Widget _trackerCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppTheme.textPrimary)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Profile summary card ────────────────────────────────────────────────────

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.profile});

  final ProfileProvider profile;

  @override
  Widget build(BuildContext context) {
    // Don't show if no weight/target data
    if (profile.weightKg == null && profile.targetWeightKg == null) {
      return GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/settings'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
          ),
          child: Row(
            children: const [
              Icon(Icons.person_outline, color: AppTheme.primary, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Complete your profile to see personalised insights →',
                  style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final weight = profile.weightKg != null
        ? '${profile.weightKg!.toStringAsFixed(1)} kg'
        : '—';
    final target = profile.targetWeightKg != null
        ? '${profile.targetWeightKg!.toStringAsFixed(1)} kg'
        : 'Not set';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          _chip(Icons.monitor_weight_outlined, 'Weight', weight),
          const SizedBox(width: 10),
          _chip(Icons.flag_outlined, 'Target', target),
          if (profile.heightCm != null) ...[
            const SizedBox(width: 10),
            _chip(Icons.height, 'Height', '${profile.heightCm} cm'),
          ],
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textPrimary)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── BMI card ────────────────────────────────────────────────────────────────

class _BmiCard extends StatelessWidget {
  const _BmiCard({required this.profile});

  final ProfileProvider profile;

  @override
  Widget build(BuildContext context) {
    final bmi = profile.bmi;
    final category = profile.bmiCategory;

    if (bmi == null) {
      // Friendly prompt if profile incomplete
      return GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/settings'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calculate_outlined,
                    color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BMI',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppTheme.textPrimary)),
                    Text(
                      'Add height & weight in Settings to calculate your BMI',
                      style:
                          TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ],
          ),
        ),
      );
    }

    final color = category.color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  bmi.toStringAsFixed(1),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: color),
                ),
                Text('BMI',
                    style: TextStyle(fontSize: 11, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category.label,
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  category.message,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Unchanged widgets from previous version ─────────────────────────────────

class _WaterGoalCard extends StatelessWidget {
  const _WaterGoalCard({required this.uid, required this.dailyGoalMl});

  final String uid;
  final int dailyGoalMl;

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  DocumentReference<Map<String, dynamic>> get _docRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('water_logs')
          .doc(_today);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _docRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingCard();
        }
        if (snapshot.hasError) return _errorCard('Error loading water data');

        final data = snapshot.data?.data();
        final intake = data?['intake_ml'] as int? ?? 0;
        final goal = dailyGoalMl <= 0 ? 2000 : dailyGoalMl;
        final progress = (intake / goal).clamp(0.0, 1.0);
        final reached = progress >= 1.0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: reached ? Colors.green : AppTheme.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: AppTheme.primaryLight,
                      color: reached ? Colors.green : AppTheme.primary,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          intake >= 1000
                              ? '${(intake / 1000).toStringAsFixed(1)}L'
                              : '${intake}ml',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.textPrimary),
                        ),
                        Text('${(progress * 100).toInt()}%',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Water today',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text('$intake / $goal ml',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    Text(
                      reached ? 'Goal reached! 🎉' : 'Keep sipping water',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: reached ? Colors.green : AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _loadingCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );

  Widget _errorCard(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    style:
                        const TextStyle(color: Colors.red, fontSize: 13))),
          ],
        ),
      );
}

class _ExerciseGoalCard extends StatelessWidget {
  const _ExerciseGoalCard({required this.uid, required this.dailyGoalMin});

  final String uid;
  final int dailyGoalMin;

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  DocumentReference<Map<String, dynamic>> get _totalsDoc =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('exercise_totals')
          .doc(_today);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _totalsDoc.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingCard();
        }
        if (snapshot.hasError) {
          return _errorCard('Error loading exercise data');
        }

        final data = snapshot.data?.data();
        final totalMins = data?['total_minutes'] as int? ?? 0;
        final goal = dailyGoalMin <= 0 ? 30 : dailyGoalMin;
        final progress = (totalMins / goal).clamp(0.0, 1.0);
        final reached = progress >= 1.0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: reached ? Colors.green : AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Exercise today',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text('$totalMins / $goal min',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textMuted)),
              const SizedBox(height: 8),
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
                reached
                    ? 'Goal reached! 🎉'
                    : 'You can still move a bit',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: reached ? Colors.green : AppTheme.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _loadingCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );

  Widget _errorCard(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    style:
                        const TextStyle(color: Colors.red, fontSize: 13))),
          ],
        ),
      );
}

class _LiveStatChips extends StatefulWidget {
  const _LiveStatChips({required this.uid, required this.today});

  final String uid;
  final String today;

  @override
  State<_LiveStatChips> createState() => _LiveStatChipsState();
}

class _LiveStatChipsState extends State<_LiveStatChips> {
  int _waterMl = 0;
  int _mealCount = 0;
  int _exerciseMins = 0;
  int _medCount = 0;

  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _listenAll();
  }

  void _listenAll() {
    final uid = widget.uid;
    final today = widget.today;
    final db = FirebaseFirestore.instance;

    _subs.add(db
        .collection('users')
        .doc(uid)
        .collection('water_logs')
        .doc(today)
        .snapshots()
        .listen((s) {
      if (mounted) {
        setState(() => _waterMl = (s.data()?['intake_ml'] as int?) ?? 0);
      }
    }));

    _subs.add(db
        .collection('users')
        .doc(uid)
        .collection('meals')
        .where('date', isEqualTo: today)
        .snapshots()
        .listen((s) {
      if (mounted) setState(() => _mealCount = s.docs.length);
    }));

    _subs.add(db
        .collection('users')
        .doc(uid)
        .collection('exercise_totals')
        .doc(today)
        .snapshots()
        .listen((s) {
      if (mounted) {
        setState(() =>
            _exerciseMins = (s.data()?['total_minutes'] as int?) ?? 0);
      }
    }));

    _subs.add(db
        .collection('users')
        .doc(uid)
        .collection('medications')
        .snapshots()
        .listen((s) {
      if (mounted) setState(() => _medCount = s.docs.length);
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waterLabel = _waterMl >= 1000
        ? '${(_waterMl / 1000).toStringAsFixed(1)}L'
        : '${_waterMl}ml';

    return Row(
      children: [
        _chip(waterLabel, 'Water'),
        const SizedBox(width: 10),
        _chip('$_mealCount', 'Meals'),
        const SizedBox(width: 10),
        _chip('$_exerciseMins min', 'Exercise'),
        const SizedBox(width: 10),
        _chip('$_medCount', 'Meds'),
      ],
    );
  }

  Widget _chip(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}