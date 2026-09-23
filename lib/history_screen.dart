import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'tasks_screen.dart';
import 'services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const primary = Color(0xFF00695C);
  static const background = Color(0xFFF8F9FF);
  static const blue = Color(0xFFEFF4FF);
  static const dark = Color(0xFF172033);
  static const grey = Color(0xFF5F6368);

  List<dynamic> tasks = [];
  bool loading = true;
  String selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // ============================================================
  // IST DATE HELPERS
  // ============================================================

  DateTime _istNow() {
    return DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  DateTime? _parseIST(dynamic value) {
    if (value == null) return null;

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) return null;

    return parsed.toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  String _istDateKey(dynamic value) {
    final date = _parseIST(value);

    if (date == null) return '';

    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  // ============================================================
  // LOAD HISTORY
  // ============================================================

  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    try {
      final data = await ApiService.getAllTasks();

      if (!mounted) return;

      setState(() {
        tasks = data;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  // ============================================================
  // ONLY TODAY + PAST TASKS
  // ============================================================

  List<dynamic> get historyTasks {
    return tasks.where((task) {
      final status = (task['status'] ?? '').toString().toLowerCase();

      return status == 'completed' || status == 'missed';
    }).toList();
  }

  // ============================================================
  // FILTERS
  // ============================================================

  List<dynamic> get filteredTasks {
    final pastAndTodayTasks = historyTasks;

    if (selectedFilter == 'All') {
      return pastAndTodayTasks;
    }

    if (selectedFilter == 'Trash') {
      return pastAndTodayTasks
          .where((task) => task['type']?.toString().toLowerCase() == 'trash')
          .toList();
    }

    if (selectedFilter == 'Water') {
      return pastAndTodayTasks
          .where((task) => task['type']?.toString().toLowerCase() == 'water')
          .toList();
    }

    if (selectedFilter == 'Cleaning') {
      return pastAndTodayTasks.where((task) {
        final type = task['type']?.toString().toLowerCase();

        return type == 'house' || type == 'bathroom';
      }).toList();
    }

    return pastAndTodayTasks;
  }

  // ============================================================
  // COUNTS
  // ============================================================

  int get trashCount {
    return historyTasks
        .where((task) => task['type']?.toString().toLowerCase() == 'trash')
        .length;
  }

  int get waterCount {
    return historyTasks
        .where((task) => task['type']?.toString().toLowerCase() == 'water')
        .length;
  }

  int get cleaningCount {
    return historyTasks.where((task) {
      final type = task['type']?.toString().toLowerCase();

      return type == 'house' || type == 'bathroom';
    }).length;
  }

  int get completedCount {
    return historyTasks
        .where(
          (task) => task['status']?.toString().toLowerCase() == 'completed',
        )
        .length;
  }

  int get harmonyPercentage {
    if (historyTasks.isEmpty) return 100;

    return ((completedCount / historyTasks.length) * 100).round();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadHistory,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      _title(),
                      _harmonyCard(),
                      _filters(),
                      _history(),
                    ],
                  ),
                ),
              ),
            ),
            _navigation(context),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header() {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFECEEF5))),
      ),
      child: Row(
        children: [
          _logo(),
          const SizedBox(width: 13),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RoomMate',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: dark,
                ),
              ),
              Text('History', style: TextStyle(fontSize: 15, color: grey)),
            ],
          ),
          const Spacer(),
          _profile(),
        ],
      ),
    );
  }

  // ============================================================
  // TITLE
  // ============================================================

  Widget _title() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 10, 30, 24),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'History',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: dark,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Past household activity and log',
                  style: TextStyle(fontSize: 17, color: grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFDDE9FF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_outlined, size: 19, color: primary),
                SizedBox(width: 5),
                Text(
                  'Verified Log',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: dark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HARMONY CARD
  // ============================================================

  Widget _harmonyCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFF5BE8B1),
            child: Icon(Icons.eco_outlined, color: Color(0xFF087A5C), size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$harmonyPercentage% Harmony Score',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$completedCount of ${historyTasks.length} tasks completed',
                  style: const TextStyle(
                    color: dark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const CircleAvatar(
            radius: 25,
            backgroundColor: blue,
            child: Icon(Icons.celebration_outlined, color: primary),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 32),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filter(
              'All',
              selectedFilter == 'All',
              historyTasks.length.toString(),
            ),
            const SizedBox(width: 10),
            _filter('Trash', selectedFilter == 'Trash', trashCount.toString()),
            const SizedBox(width: 10),
            _filter('Water', selectedFilter == 'Water', waterCount.toString()),
            const SizedBox(width: 10),
            _filter(
              'Cleaning',
              selectedFilter == 'Cleaning',
              cleaningCount.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filter(String text, bool selected, String count) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = text;
        });
      },
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected ? primary : const Color(0xFFE5EDFF),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Text(
              text,
              style: TextStyle(
                color: selected ? Colors.white : dark,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 12,
              backgroundColor: selected
                  ? const Color(0xFF318F83)
                  : Colors.white,
              child: Text(
                count,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : dark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HISTORY
  // ============================================================

  Widget _history() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    if (filteredTasks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Text(
            'No history found',
            style: TextStyle(
              fontSize: 16,
              color: grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final sortedTasks = [...filteredTasks];

    sortedTasks.sort((a, b) {
      final aDate =
          DateTime.tryParse(a['dueDate']?.toString() ?? '') ?? DateTime(2000);

      final bDate =
          DateTime.tryParse(b['dueDate']?.toString() ?? '') ?? DateTime(2000);

      return bDate.compareTo(aDate);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < sortedTasks.length; i++) ...[
          if (i == 0 ||
              !_sameDay(
                sortedTasks[i - 1]['dueDate'],
                sortedTasks[i]['dueDate'],
              ))
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 30, bottom: 10),
              child: _date(
                _formatDate(sortedTasks[i]['dueDate']),
                _dateLabel(sortedTasks[i]['dueDate']),
                i == 0 ? primary : const Color(0xFF707B7D),
              ),
            ),
          _historyCardFromTask(sortedTasks[i]),
          if (i < sortedTasks.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  // ============================================================
  // HISTORY CARD DATA
  // ============================================================

  Widget _historyCardFromTask(Map<String, dynamic> task) {
    final type = task['type']?.toString().toLowerCase() ?? '';

    final status = task['status']?.toString() ?? 'pending';

    final assignedTo = task['assignedTo'];

    String person = 'Household';

    if (assignedTo is Map<String, dynamic>) {
      person = assignedTo['name']?.toString() ?? 'Household';
    }

    final title = task['title']?.toString() ?? _defaultTitle(type);

    final dateString = task['dueDate']?.toString();

    final time = _formatTime(dateString);

    return _historyCard(
      _taskIconForType(type),
      title,
      person,
      time,
      _formatStatus(status),
      status.toLowerCase() == 'completed',
    );
  }

  // ============================================================
  // DEFAULT TITLES
  // ============================================================

  String _defaultTitle(String type) {
    switch (type) {
      case 'trash':
        return 'Trash';

      case 'water':
        return 'Water Refill';

      case 'house':
        return 'House Cleaning';

      case 'bathroom':
        return 'Bathroom Cleaning';

      default:
        return 'Household Task';
    }
  }

  // ============================================================
  // ICONS
  // ============================================================

  IconData _taskIconForType(String type) {
    switch (type) {
      case 'trash':
        return Icons.delete_outline;

      case 'water':
        return Icons.water_drop_outlined;

      case 'house':
        return Icons.cleaning_services_outlined;

      case 'bathroom':
        return Icons.shower_outlined;

      default:
        return Icons.task_alt_outlined;
    }
  }

  // ============================================================
  // STATUS
  // ============================================================

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';

      case 'missed':
        return 'Missed';

      case 'active':
        return 'Active';

      case 'pending':
        return 'Pending';

      default:
        return status;
    }
  }

  // ============================================================
  // SAME DAY - IST
  // ============================================================

  bool _sameDay(dynamic first, dynamic second) {
    final firstDate = _istDateKey(first);
    final secondDate = _istDateKey(second);

    if (firstDate.isEmpty || secondDate.isEmpty) {
      return false;
    }

    return firstDate == secondDate;
  }

  // ============================================================
  // FORMAT DATE - IST
  // ============================================================

  String _formatDate(dynamic value) {
    final date = _parseIST(value);

    if (date == null) {
      return 'Unknown date';
    }

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.day}';
  }

  // ============================================================
  // DATE LABEL
  // ============================================================

  String _dateLabel(dynamic value) {
    final taskDate = _parseIST(value);

    if (taskDate == null) {
      return '';
    }

    final now = _istNow();

    final today = DateTime(now.year, now.month, now.day);

    final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);

    final difference = today.difference(taskDay).inDays;

    if (difference == 0) {
      return 'Today';
    }

    if (difference == 1) {
      return 'Yesterday';
    }

    if (difference > 1 && difference < 7) {
      return '${difference}d ago';
    }

    return '';
  }

  // ============================================================
  // FORMAT TIME - IST
  // ============================================================

  String _formatTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) {
      return '';
    }

    final local = date.toUtc().add(const Duration(hours: 5, minutes: 30));

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;

    final minute = local.minute.toString().padLeft(2, '0');

    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  // ============================================================
  // DATE HEADER
  // ============================================================

  Widget _date(String date, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Row(
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 11),
          Text(
            date,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: dark,
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text('• $label', style: const TextStyle(color: grey)),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // HISTORY CARD
  // ============================================================

  Widget _historyCard(
    IconData icon,
    String title,
    String person,
    String time,
    String status,
    bool completed,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE5EEFF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: const Color(0xFF596274)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$person • $time',
                  style: const TextStyle(fontSize: 14, color: grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: completed
                  ? const Color(0xFF5BE8B1)
                  : const Color(0xFFFFD8D7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: completed
                    ? const Color(0xFF087A5C)
                    : const Color(0xFFB42C31),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _navigation(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE8EAF0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _nav(context, Icons.home_outlined, 'Home', false, const HomeScreen()),
          _nav(
            context,
            Icons.checklist_rounded,
            'Tasks',
            false,
            const TasksScreen(),
          ),
          _nav(
            context,
            Icons.history_rounded,
            'History',
            true,
            const HistoryScreen(),
          ),
        ],
      ),
    );
  }

  Widget _nav(
    BuildContext context,
    IconData icon,
    String label,
    bool selected,
    Widget page,
  ) {
    return GestureDetector(
      onTap: selected
          ? null
          : () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => page),
              );
            },
      child: SizedBox(
        width: 90,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 27, color: selected ? primary : grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? primary : grey,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOGO
  // ============================================================

  Widget _logo() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.home, color: Colors.white),
    );
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Widget _profile() {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(color: primary, shape: BoxShape.circle),
      child: const Icon(Icons.person_outline, color: Colors.white),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : primary,
      ),
    );
  }
}
