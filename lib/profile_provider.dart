import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider({
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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  bool _disposed = false;

  // ── State ──────────────────────────────────────────────
  bool loading = true;
  String? errorMessage;

  String? displayName;
  int? age;
  String? gender;
  int? heightCm;
  double? weightKg;
  double? targetWeightKg;

  // ── Derived ───────────────────────────────────────────
  double? get bmi {
    if (heightCm == null || weightKg == null) return null;
    final h = heightCm! / 100.0;
    return weightKg! / (h * h);
  }

  BmiCategory get bmiCategory {
    final b = bmi;
    if (b == null) return BmiCategory.unknown;
    if (b < 18.5) return BmiCategory.underweight;
    if (b < 25.0) return BmiCategory.normal;
    if (b < 30.0) return BmiCategory.overweight;
    return BmiCategory.obese;
  }

  bool get hasProfileData => heightCm != null && weightKg != null;

  // ── Firestore ref ──────────────────────────────────────
  DocumentReference<Map<String, dynamic>>? _docRefFor(User user) =>
      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('profile')
          .doc('health_info');

  // ── Auth listener ──────────────────────────────────────
  void _onUserChanged(User? user) {
    _profileSub?.cancel();
    _profileSub = null;

    if (user == null) {
      _reset();
      loading = false;
      if (!_disposed) notifyListeners();
      return;
    }

    loading = true;
    errorMessage = null;
    if (!_disposed) notifyListeners();

    _profileSub = _docRefFor(user)!.snapshots().listen(
      (doc) {
        if (_disposed) return;
        final d = doc.data();
        displayName = d?['displayName'] as String?;
        age = d?['age'] as int?;
        gender = d?['gender'] as String?;
        heightCm = d?['heightCm'] as int?;
        weightKg = (d?['weightKg'] as num?)?.toDouble();
        targetWeightKg = (d?['targetWeightKg'] as num?)?.toDouble();
        loading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (e) {
        if (_disposed) return;
        loading = false;
        errorMessage = 'Failed to load profile';
        notifyListeners();
      },
    );
  }

  void _reset() {
    displayName = null;
    age = null;
    gender = null;
    heightCm = null;
    weightKg = null;
    targetWeightKg = null;
  }

  // ── Save ───────────────────────────────────────────────
  Future<void> saveProfile({
    String? displayName,
    int? age,
    String? gender,
    int? heightCm,
    double? weightKg,
    double? targetWeightKg,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final Map<String, dynamic> data = {
      'updated_at': FieldValue.serverTimestamp(),
    };

    if (displayName != null) data['displayName'] = displayName;
    if (age != null) data['age'] = age;
    if (gender != null) data['gender'] = gender;
    if (heightCm != null) data['heightCm'] = heightCm;
    if (weightKg != null) data['weightKg'] = weightKg;
    data['targetWeightKg'] = targetWeightKg;

    await _docRefFor(user)!.set(data, SetOptions(merge: true));

    if (displayName != null && displayName.isNotEmpty) {
      await user.updateDisplayName(displayName);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _profileSub?.cancel();
    _authSub.cancel();
    super.dispose();
  }
}

enum BmiCategory { unknown, underweight, normal, overweight, obese }

extension BmiCategoryExtension on BmiCategory {
  String get label {
    switch (this) {
      case BmiCategory.underweight:
        return 'Underweight';
      case BmiCategory.normal:
        return 'Normal';
      case BmiCategory.overweight:
        return 'Overweight';
      case BmiCategory.obese:
        return 'Obese';
      case BmiCategory.unknown:
        return '—';
    }
  }

  String get message {
    switch (this) {
      case BmiCategory.underweight:
        return 'Consider consulting a nutritionist.';
      case BmiCategory.normal:
        return "You're in a healthy range! Keep it up.";
      case BmiCategory.overweight:
        return 'Small steps make a big difference.';
      case BmiCategory.obese:
        return 'Talk to your doctor for a personalised plan.';
      case BmiCategory.unknown:
        return 'Add your height & weight to see your BMI.';
    }
  }

  Color get color {
    switch (this) {
      case BmiCategory.underweight:
        return const Color(0xFF006494);
      case BmiCategory.normal:
        return const Color(0xFF437a22);
      case BmiCategory.overweight:
        return const Color(0xFFda7101);
      case BmiCategory.obese:
        return const Color(0xFFa12c7b);
      case BmiCategory.unknown:
        return const Color(0xFF7a7974);
    }
  }
}