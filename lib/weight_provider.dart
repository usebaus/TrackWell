import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// A single weight entry stored in Firestore.
class WeightEntry {
  final String id;
  final double weightKg;
  final DateTime recordedAt;
  final String? note;

  const WeightEntry({
    required this.id,
    required this.weightKg,
    required this.recordedAt,
    this.note,
  });

  factory WeightEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return WeightEntry(
      id: doc.id,
      weightKg: (d['weight_kg'] as num).toDouble(),
      recordedAt: (d['recorded_at'] as Timestamp).toDate(),
      note: d['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'weight_kg': weightKg,
        'recorded_at': Timestamp.fromDate(recordedAt),
        if (note != null) 'note': note,
      };
}

enum WeightRange { days7, days30, days90, allTime }

extension WeightRangeLabel on WeightRange {
  String get label {
    switch (this) {
      case WeightRange.days7:
        return '7D';
      case WeightRange.days30:
        return '30D';
      case WeightRange.days90:
        return '90D';
      case WeightRange.allTime:
        return 'All';
    }
  }

  int? get days {
    switch (this) {
      case WeightRange.days7:
        return 7;
      case WeightRange.days30:
        return 30;
      case WeightRange.days90:
        return 90;
      case WeightRange.allTime:
        return null;
    }
  }
}

/// Manages weight history, trends and insights.
/// Firestore path: users/{uid}/weight_entries/{docId}
class WeightProvider extends ChangeNotifier {
  WeightProvider({
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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _entriesSub;

  List<WeightEntry> _allEntries = [];
  bool loading = true;
  String? errorMessage;

  // -- Public getters --
  List<WeightEntry> get allEntries => List.unmodifiable(_allEntries);

  List<WeightEntry> entriesForRange(WeightRange range) {
    final days = range.days;
    if (days == null) return allEntries;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _allEntries.where((e) => e.recordedAt.isAfter(cutoff)).toList();
  }

  double? get latestWeight =>
      _allEntries.isEmpty ? null : _allEntries.first.weightKg;

  double? get weeklyChange => _changeOver(7);
  double? get monthlyChange => _changeOver(30);

  String? get insight {
    final mc = monthlyChange;
    if (mc == null) return null;
    if (mc.abs() < 0.1) return 'Your weight is stable this month.';
    if (mc < 0) {
      return 'You lost ${mc.abs().toStringAsFixed(1)} kg in the last month.';
    }
    return 'You gained ${mc.toStringAsFixed(1)} kg in the last month.';
  }

  int trendDirection(WeightRange range) {
    final entries = entriesForRange(range);
    if (entries.length < 2) return 0;
    final diff = entries.first.weightKg - entries.last.weightKg;
    if (diff.abs() < 0.1) return 0;
    return diff < 0 ? 1 : -1;
  }

  // -- Firestore --
  CollectionReference<Map<String, dynamic>>? _colFor(User user) =>
      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('weight_entries');

  void _onUserChanged(User? user) {
    _entriesSub?.cancel();
    _entriesSub = null;
    if (user == null) {
      _allEntries = [];
      loading = false;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();

    _entriesSub = _colFor(user)!
        .orderBy('recorded_at', descending: true)
        .snapshots()
        .listen(
      (snap) {
        _allEntries = snap.docs.map(WeightEntry.fromDoc).toList();
        loading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (e) {
        loading = false;
        errorMessage = 'Failed to load weight history';
        notifyListeners();
      },
    );
  }

  Future<void> addEntry(double weightKg, {String? note}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _colFor(user)!.add({
      'weight_kg': weightKg,
      'recorded_at': FieldValue.serverTimestamp(),
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<void> deleteEntry(String id) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _colFor(user)!.doc(id).delete();
  }

  double? _changeOver(int days) {
    if (_allEntries.isEmpty) return null;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final old = _allEntries.lastWhere(
      (e) => e.recordedAt.isBefore(cutoff),
      orElse: () => _allEntries.last,
    );
    final latest = _allEntries.first;
    if (old.id == latest.id && _allEntries.length == 1) return null;
    return latest.weightKg - old.weightKg;
  }

  @override
  void dispose() {
    _entriesSub?.cancel();
    _authSub.cancel();
    super.dispose();
  }
}
