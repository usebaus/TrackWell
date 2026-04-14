import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';

class MedicationTrackerScreen extends StatefulWidget {
  const MedicationTrackerScreen({super.key});

  @override
  State<MedicationTrackerScreen> createState() =>
      _MedicationTrackerScreenState();
}

class _MedicationTrackerScreenState
    extends State<MedicationTrackerScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  final _medicationController = TextEditingController();
  final _dosageController = TextEditingController();

  CollectionReference get _medsCol => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('medications');

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
        'taken': false, // FIX: track whether taken today
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Failed to add medication. Please try again.')),
        );
      }
    }
  }

  // FIX: Toggle taken status — was missing entirely
  Future<void> _toggleTaken(String docId, bool current) async {
    try {
      await _medsCol.doc(docId).update({'taken': !current});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to update medication.')),
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
          const SnackBar(
              content: Text('Failed to delete medication.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _medicationController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Medication Tracker'),
        backgroundColor: AppTheme.background,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _medicationController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Medication name'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _dosageController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                        labelText: 'Dosage (optional)'),
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
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _medsCol
                    .orderBy('created_at', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                        child:
                            Text('Error loading medications.'));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.medication_outlined,
                              size: 48, color: AppTheme.textMuted),
                          SizedBox(height: 12),
                          Text('No medications logged yet.',
                              style: TextStyle(
                                  color: AppTheme.textMuted)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final d =
                          doc.data() as Map<String, dynamic>;
                      final taken = d['taken'] as bool? ?? false;
                      final dosage = d['dosage'] as String? ?? '';
                      return Card(
                        child: ListTile(
                          // FIX: Checkmark to mark medication as taken
                          leading: GestureDetector(
                            onTap: () =>
                                _toggleTaken(doc.id, taken),
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
                                color: taken
                                    ? Colors.white
                                    : AppTheme.primary,
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
                                    : AppTheme.textPrimary),
                          ),
                          subtitle: dosage.isNotEmpty
                              ? Text(dosage,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMuted))
                              : null,
                          trailing: IconButton(
                            icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () =>
                                _removeMedication(doc.id),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}