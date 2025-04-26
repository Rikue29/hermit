import 'package:flutter/material.dart';

class ShareFormDialog extends StatefulWidget {
  const ShareFormDialog({super.key});

  @override
  State<ShareFormDialog> createState() => _ShareFormDialogState();
}

class _ShareFormDialogState extends State<ShareFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _quantityController = TextEditingController();
  DateTime? _expiryDate;
  Set<String> _selectedDietaryInfo = {};

  final List<String> _dietaryTags = [
    'Vegetarian',
    'Vegan',
    'Gluten-free',
    'Dairy-free',
    'Halal',
    'Homemade',
    'Organic',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Share Your Food',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32), // Dark green
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // What are you sharing field
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9), // Light green background
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextFormField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF1A1A1A),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'What are you sharing?',
                      hintStyle: TextStyle(
                        color: Color(0xFF689F38), // Green text
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Quantity field
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextFormField(
                    controller: _quantityController,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF1A1A1A),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Quantity',
                      hintStyle: TextStyle(
                        color: Color(0xFF689F38),
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Best Before Date field
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _expiryDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setState(() => _expiryDate = picked);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _expiryDate == null
                                    ? 'Best Before Date'
                                    : 'Best before ${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _expiryDate == null
                                      ? const Color(0xFF689F38)
                                      : const Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 20,
                              color: _expiryDate == null
                                  ? const Color(0xFF689F38)
                                  : const Color(0xFF1A1A1A),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Dietary Information section
                const Text(
                  'Dietary Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 8),

                // Dietary tags
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _dietaryTags.map((String tag) {
                    return FilterChip(
                      label: Text(tag),
                      labelStyle: TextStyle(
                        color: _selectedDietaryInfo.contains(tag)
                            ? Colors.white
                            : const Color(0xFF2E7D32),
                        fontSize: 14,
                      ),
                      selected: _selectedDietaryInfo.contains(tag),
                      selectedColor: const Color(0xFF4CAF50),
                      checkmarkColor: Colors.white,
                      backgroundColor: const Color(0xFFE8F5E9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedDietaryInfo.add(tag);
                          } else {
                            _selectedDietaryInfo.remove(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Share button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final formData = {
                          'title': _titleController.text,
                          'category': 'Other',
                          'quantity': _quantityController.text,
                          'description': _titleController.text,
                          'expiryDate': _expiryDate ??
                              DateTime.now().add(const Duration(days: 1)),
                          'dietaryInfo': _selectedDietaryInfo.toList(),
                          'address': 'Default Address',
                          'notes': '',
                        };
                        Navigator.of(context).pop(formData);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Share with Community',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
