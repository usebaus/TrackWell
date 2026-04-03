import 'package:flutter/material.dart';

class MealTrackerScreen extends StatefulWidget {
  const MealTrackerScreen({Key? key}) : super(key: key);

  @override
  _MealTrackerScreenState createState() => _MealTrackerScreenState();
}

class _MealTrackerScreenState extends State<MealTrackerScreen> {
  List<String> _meals = [];
  final _mealController = TextEditingController();

  void _addMeal() {
    setState(() {
      _meals.add(_mealController.text);
      _mealController.clear();
    });
  }

  void _removeMeal(int index) {
    setState(() {
      _meals.removeAt(index);
    });
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
              child: ListView.builder(
                itemCount: _meals.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      title: Text(_meals[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _removeMeal(index),
                      ),
                    ),
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
