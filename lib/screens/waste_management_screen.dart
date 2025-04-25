import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../services/waste_management_service.dart';
import '../services/env_service.dart';

class WasteManagementDialog extends StatefulWidget {
  final FoodItem foodItem;

  const WasteManagementDialog({
    super.key,
    required this.foodItem,
  });

  @override
  State<WasteManagementDialog> createState() => _WasteManagementDialogState();
}

class _WasteManagementDialogState extends State<WasteManagementDialog> {
  late final _wasteService;
  List<WasteDisposalSuggestion>? _suggestions;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _wasteService = WasteManagementService(apiKey: EnvService.geminiApiKey);
    _fetchSuggestions();
  }

  Future<void> _fetchSuggestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final suggestions = await _wasteService.getSustainableSuggestions(widget.foodItem.name);
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
        print('Received ${suggestions.length} suggestions'); // Debug print
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
      print('Error fetching suggestions: $e'); // Debug print
    }
  }

  Widget _buildSuggestionCard(WasteDisposalSuggestion suggestion) {
    Color color;
    String timeEstimate;
    IconData categoryIcon;

    switch (suggestion.category.toLowerCase()) {
      case 'reuse':
        color = Colors.green;
        timeEstimate = '5-15 mins';
        categoryIcon = Icons.home_repair_service;
        break;
      case 'compost':
        color = Colors.brown;
        timeEstimate = '10-20 mins';
        categoryIcon = Icons.yard;
        break;
      case 'dispose':
        color = Colors.red;
        timeEstimate = '5-10 mins';
        categoryIcon = Icons.delete_outline;
        break;
      default:
        color = Colors.grey;
        timeEstimate = 'varies';
        categoryIcon = Icons.info_outline;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        leading: Text(
          suggestion.emoji,
          style: const TextStyle(fontSize: 24),
        ),
        title: Text(
          suggestion.suggestion,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(categoryIcon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              suggestion.category,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.timer_outlined, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              timeEstimate,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (suggestion.location != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Where to go:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                suggestion.location!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'What you\'ll need:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.home, color: color),
                      const SizedBox(width: 8),
                      const Text('Common household items'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Steps to follow:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ...suggestion.steps.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.bookmark_border),
                      label: const Text('Save Tip'),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${suggestion.category} tip saved! (Coming soon)'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.eco),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sustainable Disposal Options',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Finding sustainable options...'),
                  ],
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchSuggestions,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              )
            else if (_suggestions?.isEmpty ?? true)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No suggestions available'),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'For: ${widget.foodItem.name}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 16),
                    ..._suggestions!.map(_buildSuggestionCard).toList(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
} 