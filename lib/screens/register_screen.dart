import 'package:flutter/material.dart';
import '../database/database.dart';
import '../managers/api_client.dart';

class RegisterScreen extends StatefulWidget {
  final String epc;
  final int scanId;
  final AppDatabase appDb;
  final ApiClient apiClient;

  const RegisterScreen({
    super.key, 
    required this.epc, 
    required this.scanId,
    required this.appDb,
    required this.apiClient,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  String _selectedSpecies = 'Cattle';
  final _speciesOptions = ['Cattle', 'Goat', 'Sheep'];
  bool _isSubmitting = false;

  Future<void> _submitRegistration() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an animal name')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.apiClient.registerAnimal(widget.epc, name, _selectedSpecies);
      
      // Update local database to visually turn the Red Cross into a Green Tick
      await widget.appDb.updateScan(
        widget.scanId, 
        'completed', 
        found: true, 
        animalName: name
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful!')),
        );
        Navigator.pop(context); // Go back to Scan Screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Animal'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: TextEditingController(text: widget.epc),
              decoration: const InputDecoration(
                labelText: 'RFID EPC Tag',
                border: OutlineInputBorder(),
              ),
              enabled: false, // Locked pre-filled tag
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Animal Name / ID',
                border: OutlineInputBorder(),
              ),
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedSpecies,
              decoration: const InputDecoration(
                labelText: 'Species',
                border: OutlineInputBorder(),
              ),
              items: _speciesOptions.map((species) {
                return DropdownMenuItem(
                  value: species,
                  child: Text(species),
                );
              }).toList(),
              onChanged: _isSubmitting ? null : (val) {
                if (val != null) setState(() => _selectedSpecies = val);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitRegistration,
              icon: _isSubmitting 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_task),
              label: Text(_isSubmitting ? 'Registering...' : 'Register to Farm'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
