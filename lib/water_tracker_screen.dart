import 'package:flutter/material.dart';

class WaterTrackerScreen extends StatefulWidget {
  const WaterTrackerScreen({Key? key}) : super(key: key);

  @override
  _WaterTrackerScreenState createState() => _WaterTrackerScreenState();
}

class _WaterTrackerScreenState extends State<WaterTrackerScreen> {
  int _waterIntake = 0; // in ml

  void _addWater() {
    setState(() {
      _waterIntake += 250; // Add 250ml
    });
  }

  void _removeWater() {
    setState(() {
      if (_waterIntake >= 250) {
        _waterIntake -= 250;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Water Tracker')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Water Intake (ml):',
              style: TextStyle(fontSize: 20),
            ),
            Text(
              '$_waterIntake',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _removeWater,
                  child: const Text('Remove 250ml'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _addWater,
                  child: const Text('Add 250ml'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
