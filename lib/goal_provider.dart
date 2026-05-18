import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  bool _disposed = false;

  bool loading = true;
  String? errorMessage;

  int waterGoalMl = 2000;
  int exerciseGoalMin = 30;

  TimeOfDay? waterReminderTime;
  TimeOfDay? exerciseReminderTime;

  DocumentReference<Map<String, dynamic>>? _prefsRefFor(User user) =>
      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('profile')
          .doc('preferences');

  void _onUserChanged(User? user) {
    _prefsSub?.cancel();
    _prefsSub = null;

    if (user == null) {
      loading = false;
      errorMessage = null;
      if (!_disposed) notifyListeners();
      return;
    }

    loading = true;
    errorMessage = null;
    if (!_disposed) notifyListeners();

    _prefsSub = _prefsRefFor(user)!.snapshots().listen(
      (doc) {
        if (_disposed) return;
        final data = doc.data();
        waterGoalMl = (data?['daily_water_goal_ml'] as int?) ?? 2000;
        exerciseGoalMin = (data?['daily_exercise_goal_min'] as int?) ?? 30;
        waterReminderTime = _parseTimeOfDay(
            data?['water_reminder_time'] as String?);
        exerciseReminderTime = _parseTimeOfDay(
            data?['exercise_reminder_time'] as String?);
        loading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (e) {
        if (_disposed) return;
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
    await _prefsRefFor(user)!.set(
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
    await _prefsRefFor(user)!.set(
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
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}';
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
    _disposed = true;
    _prefsSub?.cancel();
    _authSub.cancel();
    super.dispose();
  }
}