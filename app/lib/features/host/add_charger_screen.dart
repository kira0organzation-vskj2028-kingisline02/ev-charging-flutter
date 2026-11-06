import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models/charger_model.dart';
import '../../data/repositories/chargers_repository.dart';
import '../../data/repositories/host_repository.dart';

class AddChargerScreen extends ConsumerStatefulWidget {
  const AddChargerScreen({super.key});

  @override
  ConsumerState<AddChargerScreen> createState() => _AddChargerScreenState();
}

class _AddChargerScreenState extends ConsumerState<AddChargerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _latCtrl = TextEditingController(text: '28.6139');
  final _lngCtrl = TextEditingController(text: '77.2090');
  final _powerCtrl = TextEditingController(text: '7.4');
  final _priceKwhCtrl = TextEditingController(text: '15.0');
  final _priceHrCtrl = TextEditingController(text: '120.0');

  String _connectorType = 'Type2';
  bool _isGeneratingAi = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  final List<String> _connectorTypes = ['CCS2', 'Type2', 'CHAdeMO', 'GB/T', '3-pin'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _powerCtrl.dispose();
    _priceKwhCtrl.dispose();
    _priceHrCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateAiDescription() async {
    final location = _addressCtrl.text.trim();
    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an address / location first')),
      );
      return;
    }

    setState(() => _isGeneratingAi = true);
    try {
      final suggestion = await ref.read(hostRepositoryProvider).generateAiListing(
            location: location,
            connectorType: _connectorType,
            powerKw: double.tryParse(_powerCtrl.text) ?? 7.4,
            amenities: ['Covered Parking', '24/7 Security', 'Restroom Access'],
          );

      setState(() {
        _descCtrl.text = suggestion.description;
        _priceKwhCtrl.text = suggestion.suggestedPriceMin.toStringAsFixed(1);
        final kw = double.tryParse(_powerCtrl.text) ?? 7.4;
        _priceHrCtrl.text = (suggestion.suggestedPriceMin * (kw > 7.4 ? 7.4 : kw)).toStringAsFixed(0);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI generated listing description and suggested price: ₹${suggestion.suggestedPriceMin} - ₹${suggestion.suggestedPriceMax}/kWh',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Assistant error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingAi = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Default daily schedule 08:00 to 22:00
      final availability = List.generate(
        7,
        (day) => AvailabilitySlot(
          dayOfWeek: day,
          startTime: '08:00',
          endTime: '22:00',
        ),
      );

      await ref.read(chargersRepositoryProvider).createCharger(
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            lat: double.parse(_latCtrl.text),
            lng: double.parse(_lngCtrl.text),
            address: _addressCtrl.text.trim(),
            connectorType: _connectorType,
            powerKw: double.parse(_powerCtrl.text),
            pricePerKwh: double.parse(_priceKwhCtrl.text),
            pricePerHour: double.tryParse(_priceHrCtrl.text),
            availability: availability,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Charger listing published successfully!')),
        );
        context.go('/host');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to publish listing: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add EV Charger')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.error),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.error)),
                ),

              const Text('General Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Listing Title',
                  hintText: 'e.g. Green Park Fast CCS2 Station',
                ),
                validator: (v) => (v == null || v.trim().length < 3) ? 'Title is too short' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Address / Landmark',
                  hintText: 'e.g. Flat 4B, Sector 15, Gurgaon',
                ),
                validator: (v) => (v == null || v.trim().length < 5) ? 'Enter a valid address' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text('Hardware Specifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _connectorType,
                decoration: const InputDecoration(labelText: 'Connector Type'),
                items: _connectorTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _connectorType = val);
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _powerCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Power (kW)'),
                      validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceKwhCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '₹ per kWh'),
                      validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceHrCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '₹ per Hour'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Listing Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: _isGeneratingAi
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 16),
                    label: const Text('Generate with AI', style: TextStyle(color: AppTheme.accent)),
                    onPressed: _isGeneratingAi ? null : _generateAiDescription,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Describe amenities, access directions, parking space, or click "Generate with AI" above...',
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Publish Charger Listing'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
