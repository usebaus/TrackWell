import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'water_tracker_screen.dart';
import 'meal_tracker_screen.dart';
import 'exercise_tracker_screen.dart';
import 'medication_tracker_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

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
          onPressed: () {},
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryLight,
              child: Text(name[0].toUpperCase(),
                  style: const TextStyle(color: AppTheme.primary,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Greeting card
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
                    child: Text(name[0].toUpperCase(),
                        style: const TextStyle(color: AppTheme.primary,
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Good morning, $name',
                          style: const TextStyle(fontWeight: FontWeight.w600,
                              fontSize: 16, color: AppTheme.textPrimary)),
                      const Text("You're 65% towards today's goals",
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Stats row
            Row(
              children: [
                _statChip('1.2L', 'Water'),
                const SizedBox(width: 10),
                _statChip('0', 'Meals'),
                const SizedBox(width: 10),
                _statChip('0 min', 'Exercise'),
                const SizedBox(width: 10),
                _statChip('0', 'Meds'),
              ],
            ),
            const SizedBox(height: 24),
            // Tracker sections
            _sectionHeader('💧 Water', 'Today'),
            const SizedBox(height: 10),
            _trackerCard(
              context,
              icon: Icons.water_drop_outlined,
              title: 'Water Intake',
              subtitle: 'Track your daily hydration',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WaterTrackerScreen())),
            ),
            const SizedBox(height: 20),
            _sectionHeader('🍽 Meals', 'Today'),
            const SizedBox(height: 10),
            _trackerCard(
              context,
              icon: Icons.restaurant_outlined,
              title: 'Meal Tracker',
              subtitle: 'Log your food intake',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MealTrackerScreen())),
            ),
            const SizedBox(height: 20),
            _sectionHeader('🏃 Exercise', 'Today'),
            const SizedBox(height: 10),
            _trackerCard(
              context,
              icon: Icons.fitness_center_outlined,
              title: 'Exercise Tracker',
              subtitle: 'Log your workouts',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ExerciseTrackerScreen())),
            ),
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
            _trackerCard(
              context,
              icon: Icons.medication_outlined,
              title: 'Medication Tracker',
              subtitle: 'Track your medications',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MedicationTrackerScreen())),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String value, String label) {
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

  Widget _sectionHeader(String title, String sub) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600,
                fontSize: 16, color: AppTheme.textPrimary)),
        Text(sub,
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _trackerCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
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
