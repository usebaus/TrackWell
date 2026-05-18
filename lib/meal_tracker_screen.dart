import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';

class MealTrackerScreen extends StatefulWidget {
  const MealTrackerScreen({super.key});

  @override
  State<MealTrackerScreen> createState() => _MealTrackerScreenState();
}

class _MealTrackerScreenState extends State<MealTrackerScreen> {
  late DateTime _selectedDate;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayFormat = DateFormat('d MMM yyyy');

  final _mealController = TextEditingController();
  final _caloriesController = TextEditingController();
  String _selectedMealType = 'Snack';
  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  String get _selectedDateKey => _dateFormat.format(_selectedDate);

  CollectionReference get _mealsCol => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('meals');

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

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
        'date': _selectedDateKey,
        'created_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meal added for ${_displayFormat.format(_selectedDate)}'),
            duration: const Duration(seconds: 1),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _goToToday() => setState(() => _selectedDate = DateTime.now());

  void _goToYesterday() =>
      setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));

  @override
  void dispose() {
    _mealController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Meal Tracker'),
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
                      _displayFormat.format(_selectedDate),
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

          // ── Add meal form (ALL dates) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                          const Icon(Icons.edit_calendar, color: AppTheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Adding meal for ${_displayFormat.format(_selectedDate)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Meal type selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _mealTypes.map((type) {
                      final selected = _selectedMealType == type;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedMealType = type),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.primary : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? AppTheme.primary : AppTheme.border,
                            ),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              color: selected ? Colors.white : AppTheme.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _mealController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Meal name',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 14),
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
                          labelText: 'Calories',
                          suffixText: 'kcal',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 14),
                        onSubmitted: (_) => _addMeal(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addMeal,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Meal'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // ── Meal list ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _mealsCol
                  .where('date', isEqualTo: _selectedDateKey)
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
                final totalCalories = docs.fold(0, (sum, doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return sum + (d['calories'] as int? ?? 0);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isToday ? Icons.restaurant_menu_outlined : Icons.history_outlined,
                          size: 48,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isToday
                              ? 'No meals logged yet today.'
                              : 'No meals logged on this day.',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                        ),
                        const Text(
                          'Add a meal using the form above.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: docs.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2DC88A), Color(0xFF1A9E6A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department,
                                color: Colors.white, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Calories',
                                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  Text(
                                    '$totalCalories kcal',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${docs.length} meals',
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final doc = docs[index - 1];
                    final d = doc.data() as Map<String, dynamic>;
                    final cals = d['calories'] as int? ?? 0;
                    final mealType = d['meal_type'] as String? ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.restaurant_outlined,
                              color: AppTheme.primary, size: 16),
                        ),
                        title: Text(
                          d['name'] as String,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          mealType,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (cals > 0)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$cals kcal',
                                  style: const TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red, size: 18),
                              onPressed: () => _removeMeal(doc.id),
                            ),
                          ],
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
    );
  }
}
