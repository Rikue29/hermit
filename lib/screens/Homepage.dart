import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:food_waste_reducer/screens/food_scanner_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_waste_reducer/services/recipe_service.dart';
import 'package:food_waste_reducer/services/waste_management_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum TaskType {
  recipe,
  disposal
}

class Task {
  final String title;
  final String timing;
  final String tag;
  final Color tagColor;
  final Color tagTextColor;
  final TaskType type;
  final Recipe? recipeDetails;
  final WasteDisposalSuggestion? wasteSuggestion;
  bool isCompleted;

  Task({
    required this.title,
    required this.timing,
    required this.tag,
    required this.tagColor,
    required this.tagTextColor,
    required this.type,
    this.recipeDetails,
    this.wasteSuggestion,
    this.isCompleted = false,
  });

  // Convert color to hex string
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0')}';
  }

  // Convert hex string to color
  static Color _hexToColor(String hex) {
    return Color(int.parse(hex.substring(1), radix: 16));
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'timing': timing,
    'tag': tag,
    'tagColor': _colorToHex(tagColor),
    'tagTextColor': _colorToHex(tagTextColor),
    'type': type.toString(),
    'isCompleted': isCompleted,
    'recipeDetails': recipeDetails?.toJson(),
    'wasteSuggestion': wasteSuggestion?.toJson(),
  };

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      title: json['title'],
      timing: json['timing'],
      tag: json['tag'],
      tagColor: _hexToColor(json['tagColor']),
      tagTextColor: _hexToColor(json['tagTextColor']),
      type: TaskType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => TaskType.disposal,
      ),
      isCompleted: json['isCompleted'] ?? false,
      recipeDetails: json['recipeDetails'] != null
          ? Recipe.fromJson(json['recipeDetails'])
          : null,
      wasteSuggestion: json['wasteSuggestion'] != null
          ? WasteDisposalSuggestion.fromJson(json['wasteSuggestion'])
          : null,
    );
  }
}

class Alert {
  final String title;
  final String description;
  bool isRead;

  Alert({
    required this.title,
    required this.description,
    this.isRead = false,
  });
}

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<Homepage> with TickerProviderStateMixin {
  int _currentIndex = 0;
  List<Task> _tasks = [];
  late SharedPreferences _prefs;
  final ImagePicker _picker = ImagePicker();
  
  final List<Alert> _alerts = [
    Alert(
      title: 'Overdue Tasks Alert',
      description: '2 tasks pending for more than 2 days',
    ),
    Alert(
      title: 'Food Expiring Soon',
      description: 'Check your inventory for items expiring this week',
    ),
  ];

  Map<int, bool> _completedTasks = {};
  Map<int, AnimationController> _fadeControllers = {};

  @override
  void initState() {
    super.initState();
    _initializePrefs();
  }

  Future<void> _initializePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasksJson = _prefs.getStringList('tasks') ?? [];
    setState(() {
      _tasks = tasksJson
          .map((json) => Task.fromJson(jsonDecode(json)))
          .toList();
    });
  }

  Future<void> _saveTasks() async {
    final tasksJson = _tasks
        .map((task) => jsonEncode(task.toJson()))
        .toList();
    await _prefs.setStringList('tasks', tasksJson);
  }

  @override
  void dispose() {
    // Dispose all animation controllers
    for (var controller in _fadeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Create a fade controller for a specific index
  AnimationController _getFadeController(int index) {
    if (!_fadeControllers.containsKey(index)) {
      _fadeControllers[index] = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );
    }
    return _fadeControllers[index]!;
  }

  void _addTask(String title, TaskType type) {
    setState(() {
      _tasks.add(
        Task(
          title: title,
          timing: 'Today',
          tag: type == TaskType.recipe ? 'Recipe' : 'Waste',
          tagColor: type == TaskType.recipe
              ? const Color(0xFFE3EAFF)
              : const Color(0xFFDCFCE7),
          tagTextColor: type == TaskType.recipe
              ? const Color(0xFF2563EB)
              : const Color(0xFF15803D),
          type: type,
        ),
      );
    });
    _saveTasks();
  }

  void _addTaskFromRecipe(Recipe recipe) {
    setState(() {
      _tasks.add(
        Task(
          title: recipe.name,
          timing: 'Today',
          tag: 'Recipe',
          tagColor: const Color(0xFFE3EAFF),
          tagTextColor: const Color(0xFF2563EB),
          type: TaskType.recipe,
          recipeDetails: recipe,
        ),
      );
    });
    _saveTasks();
  }

  void _addTaskFromWasteSuggestion(WasteDisposalSuggestion suggestion) {
    setState(() {
      _tasks.add(
        Task(
          title: suggestion.suggestion,
          timing: 'Today',
          tag: suggestion.category,
          tagColor: const Color(0xFFDCFCE7),
          tagTextColor: const Color(0xFF15803D),
          type: TaskType.disposal,
          wasteSuggestion: suggestion,
        ),
      );
    });
    _saveTasks();
  }

  Future<void> _getImageFromGallery(int index) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _completedTasks[index] = true;
      });
      
      await Future.delayed(const Duration(milliseconds: 800));
      
      final fadeController = _getFadeController(index);
      await fadeController.forward();
      
      setState(() {
        _tasks.removeAt(index);
        _completedTasks.remove(index);
      });
      
      fadeController.dispose();
      _fadeControllers.remove(index);
      
      _saveTasks();
    }
  }

  void _toggleTask(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Proof Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please provide proof of completion:'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _getImageFromGallery(index);
                },
                icon: const Icon(Icons.photo_library),
                label: const Text('Choose from Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _markAlertAsRead(int index) {
    setState(() {
      _alerts.removeAt(index);
    });
  }

  Widget _buildAlertItem(Alert alert, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: alert.isRead ? const Color(0xFFE8F5E9) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(
                alert.isRead ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                color: alert.isRead ? const Color(0xFF4CAF50) : const Color(0xFFD97706),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3142),
                    height: 1.5,
                  ),
                ),
                if (!alert.isRead) ...[
                  const SizedBox(height: 2),
                  Text(
                    alert.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!alert.isRead)
            TextButton(
              onPressed: () => _markAlertAsRead(index),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFECFDF5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: const Text(
                'Got it',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF059669),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskCheckbox(int index, bool isCompleted) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        border: Border.all(
          color: _completedTasks[index] == true
              ? const Color(0xFF4CAF50)
              : const Color(0xFFE5E7EB),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(6),
        color: _completedTasks[index] == true
            ? const Color(0xFF4CAF50)
            : Colors.white,
      ),
      child: _completedTasks[index] == true
          ? const Icon(
              Icons.check,
              size: 16,
              color: Colors.white,
            )
          : null,
    );
  }

  void _showTaskDetails(Task task) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
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
                    color: task.tagColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        task.type == TaskType.recipe
                            ? Icons.restaurant_menu
                            : Icons.eco,
                        color: task.tagTextColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: task.tagTextColor,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        color: task.tagTextColor,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: task.type == TaskType.recipe
                        ? _buildRecipeDetails(task.recipeDetails!)
                        : _buildWasteSuggestionDetails(task.wasteSuggestion!),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipeDetails(Recipe recipe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.description,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildInfoChip(Icons.timer, recipe.prepTime),
            _buildInfoChip(Icons.local_fire_department, recipe.cookTime),
            _buildInfoChip(Icons.people, recipe.servings),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Ingredients',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...recipe.ingredients.map(
          (ingredient) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.fiber_manual_record, size: 8),
                const SizedBox(width: 8),
                Expanded(child: Text(ingredient)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Instructions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...recipe.steps.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWasteSuggestionDetails(WasteDisposalSuggestion suggestion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    suggestion.emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    suggestion.category,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (suggestion.location != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
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
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        suggestion.location!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        const Text(
          'Steps to follow:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...suggestion.steps.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            // Home Page
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // App Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/hermit_logo1.png',
                              height: 40,
                              width: 40,
                            ),
                            const SizedBox(width: 8),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hermit',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3142),
                                  ),
                                ),
                                Text(
                                  'Reducing waste, one meal at a time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        CircleAvatar(
                          backgroundColor: const Color(0xFFE8F5E9),
                          child: Icon(
                            Icons.person_outline,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Impact Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF66BB6A), Color(0xFF4CAF50)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your Impact',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'This week',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 120,
                                height: 120,
                                margin: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: 0.75,
                                      backgroundColor:
                                          Colors.white.withOpacity(0.2),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              Colors.white),
                                      strokeWidth: 4,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '75%',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _ImpactMetric(
                                title: 'Saved',
                                value: '3.2 kg',
                              ),
                              _ImpactMetric(
                                title: 'Money Saved',
                                value: '\$24',
                              ),
                              _ImpactMetric(
                                title: 'Shared Items',
                                value: '5',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Alert Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Alerts',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3142),
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'View All',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF4CAF50),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _alerts.any((alert) => !alert.isRead)
                            ? ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _alerts.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) => _buildAlertItem(_alerts[index], index),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.check_circle_outline,
                                          color: Color(0xFF4CAF50),
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'No active alerts',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF6B7280),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Waste Reduction Tasks Section
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Waste Reduction Tasks',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3142),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _tasks.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 24),
                            itemBuilder: (context, index) {
                              final task = _tasks[index];
                              return FadeTransition(
                                opacity: Tween<double>(
                                  begin: 1.0,
                                  end: 0.0,
                                ).animate(CurvedAnimation(
                                  parent: _getFadeController(index),
                                  curve: Curves.easeOut,
                                )),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _toggleTask(index),
                                      child: _buildTaskCheckbox(index, task.isCompleted),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  task.title,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    height: 1.5,
                                                    color: task.isCompleted
                                                        ? Colors.grey.shade400
                                                        : const Color(0xFF2D3142),
                                                    fontWeight: FontWeight.w600,
                                                    decoration: task.isCompleted
                                                        ? TextDecoration.lineThrough
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: task.tagColor,
                                                  borderRadius: BorderRadius.circular(100),
                                                ),
                                                child: Text(
                                                  task.tag,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: task.isCompleted
                                                        ? Colors.grey.shade400
                                                        : task.tagTextColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                task.timing,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: task.isCompleted
                                                      ? Colors.grey.shade400
                                                      : Colors.grey.shade600,
                                                  decoration: task.isCompleted
                                                      ? TextDecoration.lineThrough
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (!task.isCompleted && (task.recipeDetails != null || task.wasteSuggestion != null))
                                                TextButton.icon(
                                                  onPressed: () => _showTaskDetails(task),
                                                  icon: Icon(
                                                    task.type == TaskType.recipe
                                                        ? Icons.restaurant_menu
                                                        : Icons.eco,
                                                    size: 16,
                                                    color: task.tagTextColor,
                                                  ),
                                                  label: Text(
                                                    'View Details',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: task.tagTextColor,
                                                    ),
                                                  ),
                                                  style: TextButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    backgroundColor: task.tagColor.withOpacity(0.5),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Scan Page
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'What would you like to do with this item?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      _addTask('New Recipe Item', TaskType.recipe);
                      setState(() => _currentIndex = 0);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE3EAFF),
                      foregroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restaurant_menu),
                        SizedBox(width: 8),
                        Text('Make into Recipe'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _addTask('New Waste Management Item', TaskType.disposal);
                      setState(() => _currentIndex = 0);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDCFCE7),
                      foregroundColor: const Color(0xFF15803D),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.recycling),
                        SizedBox(width: 8),
                        Text('Proper Disposal'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Profile Page
            const Center(
              child: Text('Profile Page'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            // Scan tab
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FoodScannerScreen(
                  onAddRecipeTask: _addTaskFromRecipe,
                  onAddWasteSuggestionTask: _addTaskFromWasteSuggestion,
                ),
              ),
            );
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups),
            label: 'Community',
          ),
        ],
      ),
    );
  }
}

class _ImpactMetric extends StatelessWidget {
  final String title;
  final String value;

  const _ImpactMetric({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
