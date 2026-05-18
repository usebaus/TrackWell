import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'exercise_tracker_screen.dart';
import 'meal_tracker_screen.dart';
import 'water_tracker_screen.dart';
import 'medication_tracker_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    ExerciseTrackerScreen(),
    MealTrackerScreen(),
    WaterTrackerScreen(),
    MedicationTrackerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Exercise'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: 'Meals'),
          BottomNavigationBarItem(icon: Icon(Icons.water_drop), label: 'Water'),
          BottomNavigationBarItem(icon: Icon(Icons.medication), label: 'Meds'),
        ],
      ),
    );
  }
}