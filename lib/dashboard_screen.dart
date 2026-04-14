import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'water_tracker_screen.dart';
import 'meal_tracker_screen.dart';
import 'exercise_tracker_screen.dart';
import 'medication_tracker_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(color: AppTheme.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(80, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.split(' ').first ?? 'there';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('TrackWell',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
                          color: AppTheme.primary, fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_greeting()}, $name',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16,
                                color: AppTheme.textPrimary)),
                        const Text("Let's check your progress today",
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _LiveStatChips(uid: _uid, today: _today),
            const SizedBox(height: 24),
            _sectionHeader('💧 Water', 'Today'),
            const SizedBox(height: 10),
            _trackerCard(context,
                icon: Icons.water_drop_outlined,
                title: 'Water Tracker',
                subtitle: 'Track your daily hydration',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WaterTrackerScreen()))),
            const SizedBox(height: 20),
            _sectionHeader('🍽 Meals', 'Today'),
            const SizedBox(height: 10),
            _trackerCard(context,
                icon: Icons.restaurant_outlined,
                title: 'Meal Tracker',
                subtitle: 'Log your food intake',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MealTrackerScreen()))),
            const SizedBox(height: 20),
            _sectionHeader('🏃 Exercise', 'Today'),
            const SizedBox(height: 10),
            _trackerCard(context,
                icon: Icons.fitness_center_outlined,
                title: 'Exercise Tracker',
                subtitle: 'Log your workouts',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ExerciseTrackerScreen()))),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ExerciseTrackerScreen())),
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
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MedicationTrackerScreen()))),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String sub) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 16,
                color: AppTheme.textPrimary)),
        Text(sub, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _trackerCard(BuildContext context,
      {required IconData icon, required String title,
       required String subtitle, required VoidCallback onTap}) {
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
                      style: const TextStyle(fontWeight: FontWeight.w600,
                          fontSize: 15, color: AppTheme.textPrimary)),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
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

    _subs.add(
      db.collection('users').doc(uid).collection('water_logs').doc(today)
          .snapshots()
          .listen((s) {
        if (mounted) setState(() => _waterMl = (s.data()?['intake_ml'] as int?) ?? 0);
      }),
    );

    _subs.add(
      db.collection('users').doc(uid).collection('meals')
          .where('date', isEqualTo: today)
          .snapshots()
          .listen((s) {
        if (mounted) setState(() => _mealCount = s.docs.length);
      }),
    );

    _subs.add(
      db.collection('users').doc(uid).collection('exercise_totals').doc(today)
          .snapshots()
          .listen((s) {
        if (mounted) setState(() => _exerciseMins = (s.data()?['total_minutes'] as int?) ?? 0);
      }),
    );

    _subs.add(
      db.collection('users').doc(uid).collection('medications')
          .snapshots()
          .listen((s) {
        if (mounted) setState(() => _medCount = s.docs.length);
      }),
    );
  }

  @override
  void dispose() {
    for (final s in _subs) { s.cancel(); }
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
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 15, color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}