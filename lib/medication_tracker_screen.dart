import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MedicationTrackerScreen extends StatefulWidget {
  const MedicationTrackerScreen({Key? key}) : super(key: key);

  @override
  _MedicationTrackerScreenState createState() => _MedicationTrackerScreenState();
}

class _MedicationTrackerScreenState extends State<MedicationTrackerScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  final _medicationController = TextEditingController();

  CollectionReference get _medsCol => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('medications');

  Future<void> _addMedication() async {
    final text = _medicationController.text.trim();
    if (text.isEmpty) return;
    _medicationController.clear();
    try {
      await _medsCol.add({
        'name': text,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add medication. Please try again.')),
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

  @override
  void dispose() {
    _medicationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medication Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _medicationController,
              decoration: const InputDecoration(labelText: 'Add a medication'),
              onSubmitted: (_) => _addMedication(),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _medsCol
                    .orderBy('created_at', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading medications.'));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No medications logged yet.'));
                  }
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      return Card(
                        child: ListTile(
                          title: Text(doc['name'] as String),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _removeMedication(doc.id),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addMedication,
        tooltip: 'Add Medication',
        child: const Icon(Icons.add),
      ),
    );
  }
}