import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';

class ExerciseTrackerScreen extends StatefulWidget {
  const ExerciseTrackerScreen({Key? key}) : super(key: key);

  @override
  _ExerciseTrackerScreenState createState() => _ExerciseTrackerScreenState();
}

class _ExerciseTrackerScreenState extends State<ExerciseTrackerScreen> {
  final _durationController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _distanceController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedActivity = 'Run';
  String _selectedIntensity = 'Medium';

  final List<String> _quickActivities = ['Run', 'Walk', 'Cycle', 'Swim', 'Strength'];
  final List<String> _intensities = ['Low', 'Medium', 'High'];

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference get _exercisesCol => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('exercises');

  String get _today => DateTime.now().toIso8601String().substring(0, 10);
  DocumentReference get _totalsDoc => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('exercise_totals')
      .doc(_today);

  Future<void> _logActivity() async {
    final mins = int.tryParse(_durationController.text) ?? 0;
    final cals = int.tryParse(_caloriesController.text) ?? 0;
    final dist = double.tryParse(_distanceController.text) ?? 0.0;

    if (mins == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter duration')),
      );
      return;
    }

    try {
      await _exercisesCol.add({
        'activity': _selectedActivity,
        'intensity': _selectedIntensity,
        'duration_mins': mins,
        'calories': cals,
        'distance_km': dist,
        'notes': _notesController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
      });

      await _totalsDoc.set({
        'total_minutes': FieldValue.increment(mins),
        'total_calories': FieldValue.increment(cals),
        'total_distance': FieldValue.increment(dist),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _durationController.clear();
      _caloriesController.clear();
      _distanceController.clear();
      _notesController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity logged!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to log activity. Please try again.')),
        );
      }
    }
  }

  Future<void> _deleteEntry(String docId) async {
    try {
      await _exercisesCol.doc(docId).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete entry.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    _caloriesController.dispose();
    _distanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Log Exercise'),
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            Navigator.pushNamed(context, '/settings');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            const Text(
              'Quick Add',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _quickActivities.map((a) {
                final selected = _selectedActivity == a;
                return GestureDetector(
                  onTap: () => setState(() => _selectedActivity = a),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppTheme.primary : AppTheme.border,
                      ),
                    ),
                    child: Text(
                      a,
                      style: TextStyle(
                        color: selected ? Colors.white : AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            const Text(
              'Details',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedActivity,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const Text(
                            'Type of exercise',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.monitor_heart_outlined,
                              color: AppTheme.primary,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Select',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Duration (min)',
                            hintStyle: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _caloriesController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Calories (kcal)',
                            hintStyle: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _distanceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Distance (km)',
                            hintStyle: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Heart Rate (avg)',
                            hintStyle: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Intensity',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'How hard was it?',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: _intensities.map((i) {
                          final sel = _selectedIntensity == i;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedIntensity = i),
                            child: Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel ? AppTheme.primary : AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                i,
                                style: TextStyle(
                                  color: sel ? Colors.white : AppTheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Notes',
                      hintStyle: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _logActivity,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Log Activity'),
            ),

            const SizedBox(height: 24),

            const Text(
              "Today's Progress",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<DocumentSnapshot>(
              stream: _totalsDoc.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final totalMins = data?['total_minutes'] as int? ?? 0;
                final totalCals = data?['total_calories'] as int? ?? 0;
                final totalDist = (data?['total_distance'] as num?)?.toDouble() ?? 0.0;
                return Row(
                  children: [
                    _progressChip(Icons.timer_outlined, '$totalMins min', 'Duration'),
                    const SizedBox(width: 10),
                    _progressChip(
                      Icons.local_fire_department_outlined,
                      '$totalCals kcal',
                      'Calories',
                    ),
                    const SizedBox(width: 10),
                    _progressChip(
                      Icons.map_outlined,
                      '${totalDist.toStringAsFixed(1)} km',
                      'Distance',
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            const Text(
              'History',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: _exercisesCol
                  .orderBy('created_at', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading history.'));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No activities logged yet.',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final activity = d['activity'] as String? ?? '';
                    final dist = (d['distance_km'] as num?)?.toDouble() ?? 0.0;
                    final mins = d['duration_mins'] as int? ?? 0;
                    final cals = d['calories'] as int? ?? 0;
                    return _historyItem(
                      docId: doc.id,
                      activity: activity,
                      detail: '${dist.toStringAsFixed(1)} km • $mins min • $cals kcal',
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _progressChip(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyItem({
    required String docId,
    required String activity,
    required String detail,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.fitness_center_outlined,
              color: AppTheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: AppTheme.textMuted,
              size: 20,
            ),
            onPressed: () => _deleteEntry(docId),
          ),
        ],
      ),
    );
  }
}