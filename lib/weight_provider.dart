import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// A single weight entry persisted to Firestore.
class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.weightKg,
    required this.timestamp,
    this.note,
  });

  final String id;
  final double weightKg;
  final DateTime timestamp;
  final String? note;

  factory WeightEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return WeightEntry(
      id: doc.id,
      weightKg: (d['weightKg'] as num).toDouble(),
      timestamp: (d['timestamp'] as Timestamp).toDate(),
      note: d['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'weightKg': weightKg,
        'timestamp': Timestamp.fromDate(timestamp),
        'note': note,
      };

  WeightEntry copyWith({double? weightKg, DateTime? timestamp, String? note}) =>
      WeightEntry(
        id: id,
        weightKg: weightKg ?? this.weightKg,
        timestamp: timestamp ?? this.timestamp,
        note: note ?? this.note,
      );
}

/// Range filter for graph display.
enum WeightRange { sevenDays, thirtyDays, ninetyDays, allTime }

extension WeightRangeLabel on WeightRange {
  String get label {
    switch (this) {
      case WeightRange.sevenDays:
        return '7D';
      case WeightRange.thirtyDays:
        return '30D';
      case WeightRange.ninetyDays:
        return '90D';
      case WeightRange.allTime:
        return 'All';
    }
  }

  DateTime? get cutoff {
    final now = DateTime.now();
    switch (this) {
      case WeightRange.sevenDays:
        return now.subtract(const Duration(days: 7));
      case WeightRange.thirtyDays:
        return now.subtract(const Duration(days: 30));
      case WeightRange.ninetyDays:
        return now.subtract(const Duration(days: 90));
      case WeightRange.allTime:
        return null;
    }
  }
}

/// Manages historical weight entries via Firestore.
///
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

  // ── State ────────────────────────────────────────────
  bool loading = true;
  String? errorMessage;
  List<WeightEntry> _entries = [];
  WeightRange selectedRange = WeightRange.thirtyDays;

  // ── Getters ──────────────────────────────────────────
  List<WeightEntry> get allEntries => List.unmodifiable(_entries);

  List<WeightEntry> get filteredEntries {
    final cutoff = selectedRange.cutoff;
    if (cutoff == null) return allEntries;
    return _entries
        .where((e) => e.timestamp.isAfter(cutoff))
        .toList();
  }

  WeightEntry? get latestEntry =>
      _entries.isEmpty ? null : _entries.first;

  double? get latestWeightKg => latestEntry?.weightKg;

  /// Net change over selected range (positive = gained, negative = lost).
  double? get rangeChange {
    final filtered = filteredEntries;
    if (filtered.length < 2) return null;
    return filtered.first.weightKg - filtered.last.weightKg;
  }

  /// Average weekly change over selected range.
  double? get weeklyChange {
    final filtered = filteredEntries;
    if (filtered.length < 2) return null;
    final days = filtered.first.timestamp
        .difference(filtered.last.timestamp)
        .inDays;
    if (days == 0) return null;
    final totalChange = filtered.first.weightKg - filtered.last.weightKg;
    return totalChange / (days / 7.0);
  }

  /// Average monthly change over all-time entries.
  double? get monthlyChange {
    if (_entries.length < 2) return null;
    final days =
        _entries.first.timestamp.difference(_entries.last.timestamp).inDays;
    if (days < 14) return null;
    final totalChange = _entries.first.weightKg - _entries.last.weightKg;
    return totalChange / (days / 30.0);
  }

  /// Human-readable insight string.
  String get insightText {
    final rc = rangeChange;
    if (rc == null) return 'Log more entries to see trends.';
    final absKg = rc.abs().toStringAsFixed(1);
    final direction = rc < 0 ? 'lost' : 'gained';
    final period = selectedRange == WeightRange.sevenDays
        ? 'the last 7 days'
        : selectedRange == WeightRange.thirtyDays
            ? 'the last month'
            : selectedRange == WeightRange.ninetyDays
                ? 'the last 3 months'
                : 'all time';
    return 'You $direction ${absKg} kg in $period.';
  }

  String get weeklyInsightText {
    final wc = weeklyChange;
    if (wc == null) return '';
    final absKg = wc.abs().toStringAsFixed(2);
    final direction = wc < 0 ? 'losing' : 'gaining';
    return 'Average weekly change: $direction ${absKg} kg/week.';
  }

  // ── Firestore helpers ────────────────────────────────
  CollectionReference<Map<String, dynamic>>? _colRef(User user) =>
      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('weight_entries');

  // ── Auth listener ────────────────────────────────────
  void _onUserChanged(User? user) {
    _entriesSub?.cancel();
    _entriesSub = null;
    _entries = [];

    if (user == null) {
      loading = false;
      notifyListeners();
      return;
    }

    loading = true;
    notifyListeners();

    _entriesSub = _colRef(user)!
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
      (snap) {
        _entries = snap.docs
            .map((d) => WeightEntry.fromDoc(d))
            .toList();
        loading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (e) {
        loading = false;
        errorMessage = 'Failed to load weight history.';
        notifyListeners();
      },
    );
  }

  // ── CRUD ─────────────────────────────────────────────
  Future<void> addEntry(double weightKg, {String? note}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _colRef(user)!.add({
      'weightKg': weightKg,
      'timestamp': FieldValue.serverTimestamp(),
      'note': note,
    });
  }

  Future<void> updateEntry(
      String id, double weightKg, DateTime timestamp, {String? note}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _colRef(user)!.doc(id).update({
      'weightKg': weightKg,
      'timestamp': Timestamp.fromDate(timestamp),
      'note': note,
    });
  }

  Future<void> deleteEntry(String id) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _colRef(user)!.doc(id).delete();
  }

  void setRange(WeightRange range) {
    selectedRange = range;
    notifyListeners();
  }

  /// Seeds realistic demo data for the last 90 days so graphs look
  /// meaningful immediately after install. Only seeds if no entries exist.
  Future<void> seedDemoDataIfEmpty() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (_entries.isNotEmpty) return;

    final now = DateTime.now();
    double weight = 83.5;
    final batch = _firestore.batch();
    final col = _colRef(user)!;

    for (int i = 90; i >= 0; i -= 3) {
      // Slight downward trend with natural variance
      weight += (-0.15 + (i % 7 == 0 ? 0.3 : -0.05));
      weight = weight.clamp(70.0, 95.0);
      final ts = now.subtract(Duration(days: i));
      final doc = col.doc();
      batch.set(doc, {
        'weightKg': double.parse(weight.toStringAsFixed(1)),
        'timestamp': Timestamp.fromDate(
            DateTime(ts.year, ts.month, ts.day, 8, 0)),
        'note': null,
      });
    }
    await batch.commit();
  }

  @override
  void dispose() {
    _entriesSub?.cancel();
    _authSub.cancel();
    super.dispose();
  }
}
