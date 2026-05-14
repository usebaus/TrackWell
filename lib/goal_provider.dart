import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Central place for user goals (water + exercise) and reminder times.
///
/// Data source:
/// users/{uid}/profile/preferences
///   - daily_water_goal_ml (int, default 2000)
///   - daily_exercise_goal_min (int, default 30)
///   - water_reminder_time (String 'HH:mm' or null)
///   - exercise_reminder_time (String 'HH:mm' or null)
class GoalsProvider extends ChangeNotifier {
  GoalsProvider({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    _authSub = _auth.authStateChanges().listen(_onUserChanged);
    _onUserChanged(_auth.currentUser);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  late final StreamSubscription<User?> _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _prefsSub;

  bool loading = true;
  String? errorMessage;

  int waterGoalMl = 2000;
  int exerciseGoalMin = 30;

  TimeOfDay? waterReminderTime;
  TimeOfDay? exerciseReminderTime;

  DocumentReference<Map<String, dynamic>>? _prefsRefFor(User user) {
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('profile')
        .doc('preferences');
  }

  void _onUserChanged(User? user) {
    _prefsSub?.cancel();
    _prefsSub = null;

    if (user == null) {
      loading = false;
      errorMessage = null;
      notifyListeners();
      return;
    }

    loading = true;
    errorMessage = null;
    notifyListeners();

    final prefsRef = _prefsRefFor(user)!;
    _prefsSub = prefsRef.snapshots().listen(
      (doc) {
        final data = doc.data();
        waterGoalMl = (data?['daily_water_goal_ml'] as int?) ?? 2000;
        exerciseGoalMin =
            (data?['daily_exercise_goal_min'] as int?) ?? 30;

        final waterTimeStr =
            data?['water_reminder_time'] as String?;
        final exerciseTimeStr =
            data?['exercise_reminder_time'] as String?;

        waterReminderTime = _parseTimeOfDay(waterTimeStr);
        exerciseReminderTime = _parseTimeOfDay(exerciseTimeStr);

        loading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (e) {
        loading = false;
        errorMessage = 'Failed to load goals';
        notifyListeners();
      },
    );
  }

  Future<void> updateDailyGoals({
    required int waterGoalMlNew,
    required int exerciseGoalMinNew,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final prefsRef = _prefsRefFor(user)!;

    await prefsRef.set(
      {
        'daily_water_goal_ml': waterGoalMlNew,
        'daily_exercise_goal_min': exerciseGoalMinNew,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateReminderTimes({
    TimeOfDay? waterTime,
    TimeOfDay? exerciseTime,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final prefsRef = _prefsRefFor(user)!;

    await prefsRef.set(
      {
        'water_reminder_time':
            waterTime != null ? _formatTimeOfDay(waterTime) : null,
        'exercise_reminder_time':
            exerciseTime != null ? _formatTimeOfDay(exerciseTime) : null,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    String twoDigits(int v) => v.toString().padLeft(2, '0');
    return '${twoDigits(time.hour)}:${twoDigits(time.minute)}';
  }

  TimeOfDay? _parseTimeOfDay(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  void dispose() {
    _prefsSub?.cancel();
    _authSub.cancel();
    super.dispose();
  }
}