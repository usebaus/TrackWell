import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StepEntry {
  const StepEntry({
    required this.date,
    required this.steps,
  });

  final String date;
  final int steps;

  factory StepEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return StepEntry(
      date: doc.id,
      steps: (d['steps'] as num?)?.toInt() ?? 0,
    );
  }
}

class StepProvider extends ChangeNotifier {
  StepProvider({
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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _stepsSub;

  bool _disposed = false;
  bool loading = true;
  String? errorMessage;
  final Map<String, int> _stepMap = {};

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int get todaySteps => _stepMap[_fmt(DateTime.now())] ?? 0;
  int get dailyGoal => 10000;

  /// All entries that have steps > 0, sorted newest first
  List<StepEntry> get allEntries {
    final entries = _stepMap.entries
        .where((e) => e.value > 0)
        .map((e) => StepEntry(date: e.key, steps: e.value))
        .toList();
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  List<StepEntry> entriesForDays(int days) {
    final now = DateTime.now();
    final result = <StepEntry>[];
    for (int i = days - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = _fmt(d);
      result.add(StepEntry(date: key, steps: _stepMap[key] ?? 0));
    }
    return result;
  }

  List<StepEntry> get last7Days => entriesForDays(7);
  List<StepEntry> get last30Days => entriesForDays(30);

  double get weeklyAverage {
    final entries = last7Days;
    if (entries.isEmpty) return 0;
    final total = entries.fold(0, (s, e) => s + e.steps);
    return total / entries.length;
  }

  double get monthlyAverage {
    final entries = last30Days;
    if (entries.isEmpty) return 0;
    final total = entries.fold(0, (s, e) => s + e.steps);
    return total / entries.length;
  }

  int get highestStepDay {
    if (_stepMap.isEmpty) return 0;
    return _stepMap.values.reduce(max);
  }

  String get highestStepDate {
    if (_stepMap.isEmpty) return '';
    final entry = _stepMap.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return entry.key;
  }

  int get currentStreak {
    int streak = 0;
    final now = DateTime.now();
    for (int i = 0;; i++) {
      final key = _fmt(now.subtract(Duration(days: i)));
      final steps = _stepMap[key] ?? 0;
      if (steps >= 5000) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  String get insightText {
    final avg = weeklyAverage;
    if (avg == 0) return 'Start tracking your steps today!';
    if (avg >= dailyGoal) {
      return 'Great! Averaging ${avg.toInt()} steps/day this week.';
    }
    final deficit = dailyGoal - avg.toInt();
    return 'Average ${avg.toInt()} steps/day. Add $deficit more to hit your goal!';
  }

  int stepsForDate(String dateKey) => _stepMap[dateKey] ?? 0;

  CollectionReference<Map<String, dynamic>>? _colRef(User user) =>
      _firestore.collection('users').doc(user.uid).collection('step_logs');

  void _onUserChanged(User? user) {
    _stepsSub?.cancel();
    _stepsSub = null;
    _stepMap.clear();

    if (user == null) {
      loading = false;
      errorMessage = null;
      if (!_disposed) notifyListeners();
      return;
    }

    loading = true;
    errorMessage = null;
    if (!_disposed) notifyListeners();

    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    _stepsSub = _colRef(user)!
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: _fmt(cutoff))
        .snapshots()
        .listen(
      (snap) {
        if (_disposed) return;
        _stepMap.clear();
        for (final doc in snap.docs) {
          final steps = (doc.data()['steps'] as num?)?.toInt() ?? 0;
          _stepMap[doc.id] = steps;
        }
        loading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (e) {
        if (_disposed) return;
        loading = false;
        errorMessage = 'Failed to load step data.';
        notifyListeners();
      },
    );
  }

  /// Set (overwrite) steps for a given date
  Future<void> logSteps(int steps, {DateTime? date}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final key = _fmt(date ?? DateTime.now());
    await _colRef(user)!.doc(key).set(
      {'steps': steps, 'updated_at': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// Add delta to today's steps
  Future<void> addSteps(int delta) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final key = _fmt(DateTime.now());
    final current = _stepMap[key] ?? 0;
    await _colRef(user)!.doc(key).set(
      {'steps': current + delta, 'updated_at': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// Delete (reset to 0) steps for a specific date
  Future<void> deleteStepsForDate(String dateKey) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _colRef(user)!.doc(dateKey).delete();
  }

  /// Edit steps for a specific date key
  Future<void> editStepsForDate(String dateKey, int newSteps) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (newSteps <= 0) {
      await deleteStepsForDate(dateKey);
    } else {
      await _colRef(user)!.doc(dateKey).set(
        {'steps': newSteps, 'updated_at': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
  }

  Future<void> seedDemoDataIfEmpty() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (_stepMap.isNotEmpty) return;

    final now = DateTime.now();
    final rng = Random(42);
    final batch = _firestore.batch();
    final col = _colRef(user)!;

    for (int i = 89; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = _fmt(d);
      final steps = rng.nextInt(3) == 0
          ? 1500 + rng.nextInt(3000)
          : 7000 + rng.nextInt(5000);
      batch.set(col.doc(key), {
        'steps': steps,
        'updated_at': Timestamp.fromDate(DateTime(d.year, d.month, d.day, 20, 0)),
      });
    }
    await batch.commit();
  }

  @override
  void dispose() {
    _disposed = true;
    _stepsSub?.cancel();
    _authSub.cancel();
    super.dispose();
  }
}
