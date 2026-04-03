import 'package:flutter/material.dart';

class MedicationTrackerScreen extends StatefulWidget {
  const MedicationTrackerScreen({Key? key}) : super(key: key);

  @override
  _MedicationTrackerScreenState createState() => _MedicationTrackerScreenState();
}

class _MedicationTrackerScreenState extends State<MedicationTrackerScreen> {
  List<String> _medications = [];
  final _medicationController = TextEditingController();

  void _addMedication() {
    setState(() {
      _medications.add(_medicationController.text);
      _medicationController.clear();
    });
  }

  void _removeMedication(int index) {
    setState(() {
      _medications.removeAt(index);
    });
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
              child: ListView.builder(
                itemCount: _medications.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      title: Text(_medications[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _removeMedication(index),
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
        onPressed: _addMedication,
        tooltip: 'Add Medication',
        child: const Icon(Icons.add),
      ),
    );
  }
}
