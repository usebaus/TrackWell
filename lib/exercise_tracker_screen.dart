import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';

class ExerciseTrackerScreen extends StatefulWidget {
  const ExerciseTrackerScreen({super.key});

  @override
  State<ExerciseTrackerScreen> createState() =>
      _ExerciseTrackerScreenState();
}

class _ExerciseTrackerScreenState
    extends State<ExerciseTrackerScreen> {
  final _durationController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _distanceController = TextEditingController();
  final _notesController = TextEditingController();
  // FIX: Heart rate field had no controller — data was silently discarded
  final _heartRateController = TextEditingController();

  String _selectedActivity = 'Run';
  String _selectedIntensity = 'Medium';

  final List<String> _quickActivities = [
    'Run', 'Walk', 'Cycle', 'Swim', 'Strength'
  ];
  // FIX: Extended activity list for the bottom sheet picker
  final List<Map<String, dynamic>> _allActivities = [
    {'name': 'Run', 'icon': Icons.directions_run},
    {'name': 'Walk', 'icon': Icons.directions_walk},
    {'name': 'Cycle', 'icon': Icons.directions_bike},
    {'name': 'Swim', 'icon': Icons.pool},
    {'name': 'Strength', 'icon': Icons.fitness_center},
    {'name': 'Yoga', 'icon': Icons.self_improvement},
    {'name': 'HIIT', 'icon': Icons.electric_bolt},
    {'name': 'Boxing', 'icon': Icons.sports_mma},
    {'name': 'Rowing', 'icon': Icons.rowing},
    {'name': 'Other', 'icon': Icons.sports},
  ];
  final List<String> _intensities = ['Low', 'Medium', 'High'];

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference get _exercisesCol =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('exercises');

  String get _today =>
      DateTime.now().toIso8601String().substring(0, 10);

  DocumentReference get _totalsDoc => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('exercise_totals')
      .doc(_today);

  Future<void> _logActivity() async {
    final mins = int.tryParse(_durationController.text) ?? 0;
    final cals = int.tryParse(_caloriesController.text) ?? 0;
    final dist =
        double.tryParse(_distanceController.text) ?? 0.0;
    // FIX: Now actually reads heart rate
    final hr = int.tryParse(_heartRateController.text) ?? 0;

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
        'heart_rate_avg': hr, // FIX: now saved
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
      _heartRateController.clear();
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
          const SnackBar(
              content: Text(
                  'Failed to log activity. Please try again.')),
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
          const SnackBar(
              content: Text('Failed to delete entry.')),
        );
      }
    }
  }

  // FIX: "Select" button now opens a bottom sheet to pick any activity type
  void _showActivityPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose Activity',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _allActivities.map((a) {
                final sel = _selectedActivity == a['name'];
                return GestureDetector(
                  onTap: () {
                    setState(
                        () => _selectedActivity = a['name']);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppTheme.primary
                          : Colors.white,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                          color: sel
                              ? AppTheme.primary
                              : AppTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(a['icon'] as IconData,
                            size: 16,
                            color: sel
                                ? Colors.white
                                : AppTheme.textPrimary),
                        const SizedBox(width: 6),
                        Text(a['name'] as String,
                            style: TextStyle(
                                color: sel
                                    ? Colors.white
                                    : AppTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // FIX: History button now shows a full history bottom sheet
  void _showFullHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Exercise History',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _exercisesCol
                      .orderBy('created_at', descending: true)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final docs =
                        snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                          child: Text('No history yet.'));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final d = doc.data()
                            as Map<String, dynamic>;
                        final activity =
                            d['activity'] as String? ?? '';
                        final dist = (d['distance_km']
                                as num?)
                            ?.toDouble() ??
                            0.0;
                        final mins =
                            d['duration_mins'] as int? ?? 0;
                        final cals =
                            d['calories'] as int? ?? 0;
                        return _historyItem(
                          docId: doc.id,
                          activity: activity,
                          detail:
                              '${dist.toStringAsFixed(1)} km • $mins min • $cals kcal',
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _durationController.dispose();
    _caloriesController.dispose();
    _distanceController.dispose();
    _notesController.dispose();
    _heartRateController.dispose(); // FIX: was missing
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Log Exercise'),
        // FIX: Was settings icon (wrong for a sub-screen) — now back arrow
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // FIX: History button now actually opens history
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Full History',
            onPressed: _showFullHistory,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            const Text('Quick Add',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _quickActivities.map((a) {
                final selected = _selectedActivity == a;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedActivity = a),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primary
                          : Colors.white,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.border,
                      ),
                    ),
                    child: Text(a,
                        style: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 14)),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            const Text('Details',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted)),
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
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(_selectedActivity,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color:
                                      AppTheme.textPrimary)),
                          const Text('Type of exercise',
                              style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12)),
                        ],
                      ),
                      // FIX: "Select" button now opens _showActivityPicker()
                      GestureDetector(
                        onTap: _showActivityPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                  Icons.edit_outlined,
                                  color: AppTheme.primary,
                                  size: 14),
                              SizedBox(width: 4),
                              Text('Select',
                                  style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight:
                                          FontWeight.w500,
                                      fontSize: 13)),
                            ],
                          ),
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
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                              hintText: 'Duration (min)',
                              hintStyle: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _caloriesController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                              hintText: 'Calories (kcal)',
                              hintStyle: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 13)),
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
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                              hintText: 'Distance (km)',
                              hintStyle: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // FIX: Heart rate now has a controller and is saved
                      Expanded(
                        child: TextFormField(
                          controller: _heartRateController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                              hintText: 'Heart Rate (avg)',
                              hintStyle: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('Intensity',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary)),
                          Text('How hard was it?',
                              style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12)),
                        ],
                      ),
                      Row(
                        children: _intensities.map((i) {
                          final sel = _selectedIntensity == i;
                          return GestureDetector(
                            onTap: () => setState(
                                () => _selectedIntensity = i),
                            child: Container(
                              margin: const EdgeInsets.only(
                                  left: 6),
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppTheme.primary
                                    : AppTheme.primaryLight,
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                              child: Text(i,
                                  style: TextStyle(
                                      color: sel
                                          ? Colors.white
                                          : AppTheme.primary,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w500)),
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
                        hintStyle: TextStyle(
                            color: AppTheme.textMuted)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _logActivity,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Log Activity'),
              ),
            ),

            const SizedBox(height: 24),

            const Text("Today's Progress",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted)),
            const SizedBox(height: 10),
            StreamBuilder<DocumentSnapshot>(
              stream: _totalsDoc.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                final data = snapshot.data?.data()
                    as Map<String, dynamic>?;
                final totalMins =
                    data?['total_minutes'] as int? ?? 0;
                final totalCals =
                    data?['total_calories'] as int? ?? 0;
                final totalDist =
                    (data?['total_distance'] as num?)
                        ?.toDouble() ??
                        0.0;
                return Row(
                  children: [
                    _progressChip(Icons.timer_outlined,
                        '$totalMins min', 'Duration'),
                    const SizedBox(width: 10),
                    _progressChip(
                        Icons.local_fire_department_outlined,
                        '$totalCals kcal',
                        'Calories'),
                    const SizedBox(width: 10),
                    _progressChip(Icons.map_outlined,
                        '${totalDist.toStringAsFixed(1)} km',
                        'Distance'),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            const Text('Recent History',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: _exercisesCol
                  .orderBy('created_at', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Error loading history.'));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 16),
                      child: Text('No activities logged yet.',
                          style: TextStyle(
                              color: AppTheme.textMuted)),
                    ),
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final d =
                        doc.data() as Map<String, dynamic>;
                    final activity =
                        d['activity'] as String? ?? '';
                    final dist =
                        (d['distance_km'] as num?)
                            ?.toDouble() ??
                            0.0;
                    final mins =
                        d['duration_mins'] as int? ?? 0;
                    final cals = d['calories'] as int? ?? 0;
                    return _historyItem(
                      docId: doc.id,
                      activity: activity,
                      detail:
                          '${dist.toStringAsFixed(1)} km • $mins min • $cals kcal',
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

  Widget _progressChip(
      IconData icon, String value, String label) {
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
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimary)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted)),
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
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: const Icon(Icons.fitness_center_outlined,
                color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimary)),
                Text(detail,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.red, size: 18),
            onPressed: () => _deleteEntry(docId),
          ),
        ],
      ),
    );
  }
}