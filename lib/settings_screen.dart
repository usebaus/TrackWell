import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _waterGoalController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _remindersEnabled = false;
  String _distanceUnit = 'km';

  User? get _user => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>> get _prefsRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_user?.uid)
          .collection('profile')
          .doc('preferences');

  DocumentReference<Map<String, dynamic>> get _todayWaterRef {
    final today =
        DateTime.now().toIso8601String().substring(0, 10);
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

  // FIX: Added dispose() — was missing, causing TextEditingController leak
  @override
  void dispose() {
    _waterGoalController.dispose();
    super.dispose();
  }

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to load settings.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_user == null) return;
    final waterGoal =
        int.tryParse(_waterGoalController.text.trim()) ?? 2000;
    setState(() => _saving = true);
    try {
      await _prefsRef.set({
        'daily_water_goal_ml': waterGoal,
        'distance_unit': _distanceUnit,
        'reminders_enabled': _remindersEnabled,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Settings saved successfully.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to save settings.')),
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
        title: const Text('Reset water log?'),
        content: const Text(
            'This will set today\'s water intake back to 0 ml.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _todayWaterRef.set({
        'intake_ml': 0,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Water reset to 0 ml.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to reset water.')),
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out',
                style: TextStyle(color: Colors.red)),
          ),
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

  @override
  Widget build(BuildContext context) {
    final user = _user;
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
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // Account info card
                      _card(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor:
                                  AppTheme.primaryLight,
                              child: Text(
                                (user.displayName?.isNotEmpty ==
                                        true
                                    ? user.displayName![0]
                                    : user.email![0])
                                    .toUpperCase(),
                                style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.displayName ??
                                        'No name set',
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w600,
                                        fontSize: 15,
                                        color:
                                            AppTheme.textPrimary),
                                  ),
                                  Text(
                                    user.email ?? '',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color:
                                            AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      _sectionTitle('Preferences'),
                      const SizedBox(height: 10),

                      _card(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text('Daily water goal (ml)',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _waterGoalController,
                              keyboardType:
                                  TextInputType.number,
                              decoration:
                                  const InputDecoration(
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
                                    value: 'km',
                                    label: Text('KM')),
                                ButtonSegment(
                                    value: 'miles',
                                    label: Text('Miles')),
                              ],
                              selected: {_distanceUnit},
                              onSelectionChanged: (val) {
                                setState(() =>
                                    _distanceUnit = val.first);
                              },
                            ),
                            const SizedBox(height: 20),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                  'Enable reminders'),
                              value: _remindersEnabled,
                              onChanged: (val) {
                                setState(
                                    () => _remindersEnabled =
                                        val);
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      _sectionTitle('Data'),
                      const SizedBox(height: 10),

                      // FIX: Reset water button now visible in UI
                      _card(
                        child: Column(
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
                                    Icons.water_drop_outlined,
                                    color: AppTheme.primary,
                                    size: 18),
                              ),
                              title: const Text(
                                  'Reset today\'s water',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textPrimary)),
                              subtitle: const Text(
                                  'Set today\'s intake to 0 ml',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMuted)),
                              trailing: const Icon(
                                  Icons.chevron_right,
                                  color: AppTheme.textMuted),
                              onTap: _resetTodayWater,
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
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
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
                            side: const BorderSide(
                                color: Colors.red),
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

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: AppTheme.textPrimary));

  Widget _card({required Widget child}) {
    return Container(
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
}