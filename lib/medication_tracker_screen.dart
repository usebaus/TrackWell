import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';

class MedicationTrackerScreen extends StatefulWidget {
  const MedicationTrackerScreen({super.key});

  @override
  State<MedicationTrackerScreen> createState() => _MedicationTrackerScreenState();
}

class _MedicationTrackerScreenState extends State<MedicationTrackerScreen> {
  late DateTime _selectedDate;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayFormat = DateFormat('d MMM yyyy');

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  final _medicationController = TextEditingController();
  final _dosageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  String get _selectedDateKey => _dateFormat.format(_selectedDate);

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  /// Medications are date-scoped: stored in medications/{dateKey}/items
  CollectionReference get _medsCol => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('medication_logs')
      .doc(_selectedDateKey)
      .collection('items');

  Future<void> _addMedication() async {
    final text = _medicationController.text.trim();
    if (text.isEmpty) return;
    final dosage = _dosageController.text.trim();
    _medicationController.clear();
    _dosageController.clear();
    try {
      await _medsCol.add({
        'name': text,
        'dosage': dosage,
        'taken': false,
        'date': _selectedDateKey,
        'created_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Medication added for ${_displayFormat.format(_selectedDate)}'),
          duration: const Duration(seconds: 1),
          backgroundColor: AppTheme.primary,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add medication. Please try again.')),
        );
      }
    }
  }

  Future<void> _toggleTaken(String docId, bool current) async {
    try {
      await _medsCol.doc(docId).update({'taken': !current});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update medication.')),
        );
      }
    }
  }

  Future<void> _removeMedication(String docId) async {
    try {
      await _medsCol.doc(docId).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete medication.')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _goToToday() => setState(() => _selectedDate = DateTime.now());

  void _goToYesterday() =>
      setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));

  @override
  void dispose() {
    _medicationController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Medication Tracker'),
        backgroundColor: AppTheme.background,
        actions: [
          if (!isToday)
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: _goToToday,
              tooltip: 'Go to today',
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Date selector bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      isToday ? 'Today' : _displayFormat.format(_selectedDate),
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!isToday)
                  IconButton(
                    onPressed: _goToToday,
                    icon: const Icon(Icons.today, size: 20),
                    tooltip: 'Today',
                  ),
                IconButton(
                  onPressed: _goToYesterday,
                  icon: const Icon(Icons.arrow_back, size: 20),
                  tooltip: 'Previous day',
                ),
              ],
            ),
          ),

          // ── Add medication form (all dates) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                if (!isToday)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_calendar,
                              color: AppTheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Adding for ${_displayFormat.format(_selectedDate)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _medicationController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Medication name'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _dosageController,
                        textInputAction: TextInputAction.done,
                        decoration:
                            const InputDecoration(labelText: 'Dosage (optional)'),
                        onSubmitted: (_) => _addMedication(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addMedication,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Medication'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // ── Medication list ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _medsCol.orderBy('created_at', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading medications.'));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.medication_outlined,
                            size: 48, color: AppTheme.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          isToday
                              ? 'No medications logged today.'
                              : 'No medications on ${_displayFormat.format(_selectedDate)}.',
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                        const Text(
                          'Add a medication using the form above.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                final takenCount =
                    docs.where((d) => (d.data() as Map)['taken'] == true).length;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5B67F8), Color(0xFF3D52D5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.medication, color: Colors.white, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$takenCount / ${docs.length} taken',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (takenCount == docs.length && docs.isNotEmpty)
                              const Text('All done! 🎉',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final d = doc.data() as Map<String, dynamic>;
                          final taken = d['taken'] as bool? ?? false;
                          final dosage = d['dosage'] as String? ?? '';
                          return Card(
                            child: ListTile(
                              leading: GestureDetector(
                                onTap: () => _toggleTaken(doc.id, taken),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: taken
                                        ? AppTheme.primary
                                        : AppTheme.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    taken
                                        ? Icons.check
                                        : Icons.medication_outlined,
                                    color:
                                        taken ? Colors.white : AppTheme.primary,
                                    size: 18,
                                  ),
                                ),
                              ),
                              title: Text(
                                d['name'] as String,
                                style: TextStyle(
                                  decoration: taken
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: taken
                                      ? AppTheme.textMuted
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              subtitle: dosage.isNotEmpty
                                  ? Text(dosage,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textMuted))
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () => _removeMedication(doc.id),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
