import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';

class MealTrackerScreen extends StatefulWidget {
  const MealTrackerScreen({super.key});

  @override
  State<MealTrackerScreen> createState() => _MealTrackerScreenState();
}

class _MealTrackerScreenState extends State<MealTrackerScreen> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  // FIX: Added date field so dashboard can filter by today
  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  final _mealController = TextEditingController();
  final _caloriesController = TextEditingController();
  String _selectedMealType = 'Snack';
  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  CollectionReference get _mealsCol => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('meals');

  Future<void> _addMeal() async {
    final text = _mealController.text.trim();
    if (text.isEmpty) return;
    final cals = int.tryParse(_caloriesController.text.trim()) ?? 0;
    _mealController.clear();
    _caloriesController.clear();
    try {
      await _mealsCol.add({
        'name': text,
        'meal_type': _selectedMealType,
        'calories': cals,
        'date': _today, // FIX: needed for dashboard count query
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Failed to add meal. Please try again.')),
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
    _caloriesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Meal Tracker'),
        backgroundColor: AppTheme.background,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FIX: Meal type selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _mealTypes.map((type) {
                  final selected = _selectedMealType == type;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedMealType = type),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primary
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.border,
                        ),
                      ),
                      child: Text(type,
                          style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 13)),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _mealController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Meal name'),
                    onSubmitted: (_) => _addMeal(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _caloriesController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                        labelText: 'Calories (optional)',
                        suffixText: 'kcal'),
                    onSubmitted: (_) => _addMeal(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // FIX: Added explicit Add button (previously only FAB and keyboard submit)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addMeal,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Meal'),
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _mealsCol
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
                        child: Text('Error loading meals.'));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.restaurant_menu_outlined,
                              size: 48, color: AppTheme.textMuted),
                          SizedBox(height: 12),
                          Text('No meals logged yet.',
                              style: TextStyle(
                                  color: AppTheme.textMuted)),
                          Text('Add your first meal above.',
                              style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 13)),
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
                      final cals = d['calories'] as int? ?? 0;
                      final mealType =
                          d['meal_type'] as String? ?? '';
                      return Card(
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight,
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: const Icon(
                                Icons.restaurant_outlined,
                                color: AppTheme.primary,
                                size: 18),
                          ),
                          title: Text(d['name'] as String),
                          subtitle: Text(
                              '$mealType${cals > 0 ? ' • $cals kcal' : ''}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () =>
                                _removeMeal(doc.id),
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