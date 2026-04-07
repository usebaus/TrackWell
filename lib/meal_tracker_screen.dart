import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MealTrackerScreen extends StatefulWidget {
  const MealTrackerScreen({Key? key}) : super(key: key);

  @override
  _MealTrackerScreenState createState() => _MealTrackerScreenState();
}

class _MealTrackerScreenState extends State<MealTrackerScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  final _mealController = TextEditingController();

  CollectionReference get _mealsCol => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('meals');

  Future<void> _addMeal() async {
    final text = _mealController.text.trim();
    if (text.isEmpty) return;
    _mealController.clear();
    try {
      await _mealsCol.add({
        'name': text,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add meal. Please try again.')),
        );
      }
    }
  }

  Future<void> _removeMeal(String docId) async {
    try {
      await _mealsCol.doc(docId).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete meal.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _mealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meal Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _mealController,
              decoration: const InputDecoration(labelText: 'Add a meal'),
              onSubmitted: (_) => _addMeal(),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _mealsCol
                    .orderBy('created_at', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading meals.'));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No meals logged yet.'));
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
                            onPressed: () => _removeMeal(doc.id),
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
        onPressed: _addMeal,
        tooltip: 'Add Meal',
        child: const Icon(Icons.add),
      ),
    );
  }
}