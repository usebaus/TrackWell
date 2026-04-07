import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WaterTrackerScreen extends StatefulWidget {
  const WaterTrackerScreen({Key? key}) : super(key: key);

  @override
  _WaterTrackerScreenState createState() => _WaterTrackerScreenState();
}

class _WaterTrackerScreenState extends State<WaterTrackerScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // Key the document by today's date so each day starts at 0
  String get _today => DateTime.now().toIso8601String().substring(0, 10); // "2026-04-07"

  DocumentReference get _docRef => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('water_logs')
      .doc(_today);

  Future<void> _updateIntake(int delta) async {
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(_docRef);
        final current = snap.exists ? ((snap.data() as Map)['intake_ml'] as int? ?? 0) : 0;
        final updated = (current + delta).clamp(0, 99999);
        tx.set(
          _docRef,
          {'intake_ml': updated, 'updated_at': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save data. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Water Tracker')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _docRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading data.'));
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final intake = data?['intake_ml'] as int? ?? 0;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Water Intake (ml):',
                  style: TextStyle(fontSize: 20),
                ),
                Text(
                  '$intake',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: intake >= 250 ? () => _updateIntake(-250) : null,
                      child: const Text('Remove 250ml'),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton(
                      onPressed: () => _updateIntake(250),
                      child: const Text('Add 250ml'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}