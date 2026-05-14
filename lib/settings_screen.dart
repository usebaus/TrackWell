import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'profile_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Notification / preference state (unchanged) ──────────────────────────
  final _waterGoalController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _remindersEnabled = false;
  String _distanceUnit = 'km';
  TimeOfDay? _waterReminderTime;
  TimeOfDay? _exerciseReminderTime;

  // ── Profile state (NEW) ───────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  String? _selectedGender;
  bool _profileSaving = false;

  static const List<String> _genders = ['male', 'female', 'other'];

  User? get _user => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>> get _prefsRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_user?.uid)
          .collection('profile')
          .doc('preferences');

  DocumentReference<Map<String, dynamic>> get _todayWaterRef {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_user?.uid)
        .collection('water_logs')
        .doc(today);
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _waterGoalController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  // ── Load existing prefs ───────────────────────────────────────────────────
  Future<void> _loadSettings() async {
    if (_user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final doc = await _prefsRef.get();
      final data = doc.data();
      _waterGoalController.text =
          (data?['daily_water_goal_ml'] ?? 2000).toString();
      _distanceUnit = data?['distance_unit'] ?? 'km';
      _remindersEnabled = data?['reminders_enabled'] ?? false;
      _waterReminderTime =
          _parseTimeOfDay(data?['water_reminder_time'] as String?);
      _exerciseReminderTime =
          _parseTimeOfDay(data?['exercise_reminder_time'] as String?);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load settings.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Pre-fill profile form from provider ──────────────────────────────────
  void _prefillProfileForm(ProfileProvider profile) {
    if (_nameController.text.isEmpty && profile.displayName != null) {
      _nameController.text = profile.displayName!;
    }
    if (_ageController.text.isEmpty && profile.age != null) {
      _ageController.text = profile.age.toString();
    }
    if (_heightController.text.isEmpty && profile.heightCm != null) {
      _heightController.text = profile.heightCm.toString();
    }
    if (_weightController.text.isEmpty && profile.weightKg != null) {
      _weightController.text = profile.weightKg!.toStringAsFixed(1);
    }
    if (_targetWeightController.text.isEmpty &&
        profile.targetWeightKg != null) {
      _targetWeightController.text =
          profile.targetWeightKg!.toStringAsFixed(1);
    }
    if (_selectedGender == null && profile.gender != null) {
      _selectedGender = profile.gender;
    }
  }

  // ── Save profile ──────────────────────────────────────────────────────────
  Future<void> _saveProfile(ProfileProvider profile) async {
    setState(() => _profileSaving = true);
    try {
      await profile.saveProfile(
        displayName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        gender: _selectedGender,
        heightCm: int.tryParse(_heightController.text.trim()),
        weightKg: double.tryParse(_weightController.text.trim()),
        targetWeightKg: _targetWeightController.text.trim().isEmpty
            ? null
            : double.tryParse(_targetWeightController.text.trim()),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save profile.')),
        );
      }
    } finally {
      if (mounted) setState(() => _profileSaving = false);
    }
  }

  // ── Existing helpers (unchanged) ─────────────────────────────────────────
  TimeOfDay? _parseTimeOfDay(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String? _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return null;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}';
  }

  Future<void> _pickReminderTime({required bool water}) async {
    final initial = water
        ? _waterReminderTime ?? const TimeOfDay(hour: 9, minute: 0)
        : _exerciseReminderTime ?? const TimeOfDay(hour: 18, minute: 0);

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (water) {
        _waterReminderTime = picked;
      } else {
        _exerciseReminderTime = picked;
      }
    });
  }

  Future<void> _saveSettings() async {
    if (_user == null) return;
    final waterGoal =
        int.tryParse(_waterGoalController.text.trim()) ?? 2000;

    setState(() => _saving = true);
    try {
      await _prefsRef.set(
        {
          'daily_water_goal_ml': waterGoal,
          'distance_unit': _distanceUnit,
          'reminders_enabled': _remindersEnabled,
          'water_reminder_time': _remindersEnabled
              ? _formatTimeOfDay(_waterReminderTime)
              : null,
          'exercise_reminder_time': _remindersEnabled
              ? _formatTimeOfDay(_exerciseReminderTime)
              : null,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (_remindersEnabled) {
        if (_waterReminderTime != null) {
          await NotificationService().scheduleDailyReminder(
            id: NotificationService.waterReminderId,
            timeOfDay: _waterReminderTime!,
            title: 'Time to drink water',
            body: 'Keep your hydration on track with TrackWell.',
          );
        } else {
          await NotificationService()
              .cancel(NotificationService.waterReminderId);
        }

        if (_exerciseReminderTime != null) {
          await NotificationService().scheduleDailyReminder(
            id: NotificationService.exerciseReminderId,
            timeOfDay: _exerciseReminderTime!,
            title: 'Time to move',
            body: 'Log a quick workout in TrackWell.',
          );
        } else {
          await NotificationService()
              .cancel(NotificationService.exerciseReminderId);
        }
      } else {
        await NotificationService()
            .cancel(NotificationService.waterReminderId);
        await NotificationService()
            .cancel(NotificationService.exerciseReminderId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save settings.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetTodayWater() async {
    if (_user == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reset water log?"),
        content: const Text("This will set today's water intake back to 0 ml."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Reset', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _todayWaterRef.set(
        {'intake_ml': 0, 'updated_at': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Water reset to 0 ml.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reset water.')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will be returned to login.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await AuthService.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/login', (route) => false);
    }
  }

  void _showTermsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Terms & Conditions'),
        content: const Text(
          'TrackWell is a student project. Do not use it as a substitute '
          'for professional medical advice or emergency services.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = _user;
    final profile = context.watch<ProfileProvider>();

    // Pre-fill form fields once profile is loaded
    if (!profile.loading) _prefillProfileForm(profile);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? const Center(child: Text('No user found.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Account chip ─────────────────────────────────
                      _card(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.primaryLight,
                              child: Text(
                                (user.displayName?.isNotEmpty == true
                                        ? user.displayName![0]
                                        : user.email![0])
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.displayName ?? 'No name set',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    user.email ?? '',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ══════════════════════════════════════════════════
                      //  NEW: Profile & Health Info section
                      // ══════════════════════════════════════════════════
                      _sectionTitle('Profile & Health Info'),
                      const SizedBox(height: 10),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name
                            const Text('Display Name',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: 'Your name',
                                prefixIcon: Icon(Icons.person_outline,
                                    size: 20, color: AppTheme.textMuted),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Age
                            const Text('Age',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: 'e.g. 25',
                                suffixText: 'years',
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Gender
                            const Text('Gender',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              hint: const Text('Select gender'),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.wc_outlined,
                                    size: 20, color: AppTheme.textMuted),
                              ),
                              items: _genders
                                  .map((g) => DropdownMenuItem(
                                        value: g,
                                        child: Text(
                                          g[0].toUpperCase() +
                                              g.substring(1),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedGender = val),
                            ),
                            const SizedBox(height: 16),

                            // Height / Weight side by side
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Height',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.textPrimary)),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _heightController,
                                        keyboardType: TextInputType.number,
                                        textInputAction:
                                            TextInputAction.next,
                                        decoration: const InputDecoration(
                                          hintText: 'e.g. 175',
                                          suffixText: 'cm',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Weight',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.textPrimary)),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _weightController,
                                        keyboardType:
                                            const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                        textInputAction:
                                            TextInputAction.next,
                                        decoration: const InputDecoration(
                                          hintText: 'e.g. 70.5',
                                          suffixText: 'kg',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Target weight
                            const Text('Target Weight (optional)',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _targetWeightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                hintText: 'e.g. 65.0 (leave blank to skip)',
                                suffixText: 'kg',
                              ),
                            ),

                            // BMI preview
                            if (profile.bmi != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: profile.bmiCategory.color
                                      .withOpacity(0.09),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calculate_outlined,
                                        color: profile.bmiCategory.color,
                                        size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Current BMI: ${profile.bmi!.toStringAsFixed(1)}  •  ${profile.bmiCategory.label}',
                                      style: TextStyle(
                                          color: profile.bmiCategory.color,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _profileSaving
                                    ? null
                                    : () => _saveProfile(profile),
                                child: _profileSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Save Profile'),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ══════════════════════════════════════════════════
                      //  Existing sections below — completely unchanged
                      // ══════════════════════════════════════════════════
                      const SizedBox(height: 20),
                      _sectionTitle('Preferences'),
                      const SizedBox(height: 10),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Daily water goal (ml)',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _waterGoalController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'e.g. 2500',
                                suffixText: 'ml',
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text('Distance unit',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary)),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                    value: 'km', label: Text('KM')),
                                ButtonSegment(
                                    value: 'miles',
                                    label: Text('Miles')),
                              ],
                              selected: {_distanceUnit},
                              onSelectionChanged: (val) => setState(
                                  () => _distanceUnit = val.first),
                            ),
                            const SizedBox(height: 20),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Enable reminders'),
                              subtitle: const Text(
                                'Get daily water and exercise reminders',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted),
                              ),
                              value: _remindersEnabled,
                              onChanged: (val) =>
                                  setState(() => _remindersEnabled = val),
                            ),
                            if (_remindersEnabled) ...[
                              const SizedBox(height: 8),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                    Icons.water_drop_outlined,
                                    color: AppTheme.primary),
                                title: const Text('Water reminder time',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textPrimary)),
                                subtitle: Text(
                                  _waterReminderTime == null
                                      ? 'Not set'
                                      : _formatTimeOfDay(
                                          _waterReminderTime!)!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMuted),
                                ),
                                onTap: () =>
                                    _pickReminderTime(water: true),
                              ),
                              const SizedBox(height: 4),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                    Icons.fitness_center_outlined,
                                    color: AppTheme.primary),
                                title: const Text(
                                    'Exercise reminder time',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textPrimary)),
                                subtitle: Text(
                                  _exerciseReminderTime == null
                                      ? 'Not set'
                                      : _formatTimeOfDay(
                                          _exerciseReminderTime!)!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMuted),
                                ),
                                onTap: () =>
                                    _pickReminderTime(water: false),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sectionTitle('Data'),
                      const SizedBox(height: 10),
                      _card(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                                Icons.water_drop_outlined,
                                color: AppTheme.primary,
                                size: 18),
                          ),
                          title: const Text("Reset today's water",
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary)),
                          subtitle: const Text("Set today's intake to 0 ml",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted)),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppTheme.textMuted),
                          onTap: _resetTodayWater,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sectionTitle('About & Terms'),
                      const SizedBox(height: 10),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                    Icons.description_outlined,
                                    color: AppTheme.primary,
                                    size: 18),
                              ),
                              title: const Text('Terms & Conditions',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textPrimary)),
                              subtitle: const Text(
                                'TrackWell is a student project and not medical advice.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted),
                              ),
                              trailing: const Icon(Icons.chevron_right,
                                  color: AppTheme.textMuted),
                              onTap: _showTermsDialog,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'By using TrackWell you agree that all data is for learning and demonstration only.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveSettings,
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save Settings'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout,
                              size: 18, color: Colors.red),
                          label: const Text('Sign Out',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500)),
                          style: OutlinedButton.styleFrom(
                            minimumSize:
                                const Size(double.infinity, 52),
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppTheme.textPrimary),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );
}