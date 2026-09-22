import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'history_screen.dart';
import 'services/api_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  static const primary = Color(0xFF00695C);
  static const background = Color(0xFFF8F9FF);
  static const blue = Color(0xFFEFF4FF);
  static const dark = Color(0xFF172033);
  static const grey = Color(0xFF5F6368);

  static const cloudinaryCloudName = 'gawa5bgv';
  static const cloudinaryUploadPreset = 'roommate_proofs';

  final ImagePicker _picker = ImagePicker();

  String userName = 'Jason';
  String userTeam = 'A';

  String trashPerson = 'Loading...';
  String waterPerson = 'Loading...';

  String trashStatus = 'Loading...';
  String waterStatus = 'Loading...';

  Map<String, dynamic>? trashTask;
  Map<String, dynamic>? waterTask;
  Map<String, dynamic>? sundaySchedule;

  bool waterReported = false;
  bool loading = true;
  bool completing = false;
  bool reportingWater = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // ============================================================
  // IST HELPERS
  // ============================================================

  DateTime _istNow() {
    return DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  String _istDateKey(DateTime value) {
    final ist = value.toUtc().add(const Duration(hours: 5, minutes: 30));
    final month = ist.month.toString().padLeft(2, '0');
    final day = ist.day.toString().padLeft(2, '0');
    return '${ist.year}-$month-$day';
  }

  bool _isToday(dynamic value) {
    if (value == null) return false;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return false;
    return _istDateKey(parsed) == _istDateKey(_istNow());
  }

  String _getUpcomingSunday() {
    final now = _istNow();
    final daysUntilSunday = (DateTime.sunday - now.weekday + 7) % 7;
    final sunday = now.add(Duration(days: daysUntilSunday));

    final year = sunday.year.toString().padLeft(4, '0');
    final month = sunday.month.toString().padLeft(2, '0');
    final day = sunday.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> _loadTasks() async {
    if (!mounted) return;

    setState(() => loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('userName');
      final savedTeam = prefs.getString('userTeam');

      if (savedName != null && savedName.isNotEmpty) {
        userName = savedName;
      }
      if (savedTeam != null && savedTeam.isNotEmpty) {
        userTeam = savedTeam;
      }

      final results = await Future.wait([
        ApiService.getCurrentTrashPerson(),
        ApiService.getCurrentWaterPerson(),
        ApiService.getAllTasks(),
      ]);

      final trashData = results[0] as Map<String, dynamic>;
      final waterData = results[1] as Map<String, dynamic>;
      final allTasks = results[2] as List<dynamic>;

      final currentTrashPerson =
          _mapName(trashData['currentPerson']) ?? 'No assignment';
      final currentWaterPerson =
          _mapName(waterData['currentPerson']) ?? 'No assignment';

      final currentTrashTask = _asMap(trashData['currentTask']);
      final currentWaterTask = _asMap(waterData['currentTask']);

      final todayTrashTasks = allTasks
          .map(_asMap)
          .where(
            (task) =>
                task != null &&
                task['type']?.toString().toLowerCase() == 'trash' &&
                task['isSundayTeamTask'] != true &&
                _isToday(task['dueDate']),
          )
          .cast<Map<String, dynamic>>()
          .toList();

      final todayWaterTasks = allTasks
          .map(_asMap)
          .where(
            (task) =>
                task != null &&
                task['type']?.toString().toLowerCase() == 'water' &&
                _isToday(task['dueDate']),
          )
          .cast<Map<String, dynamic>>()
          .toList();

      final selectedTrash = _selectTodayTask(
        todayTrashTasks,
        currentTrashTask,
        preferUserCompleted: true,
      );

      final selectedWater = _selectTodayTask(
        todayWaterTasks,
        currentWaterTask,
        preferUserCompleted: true,
      );

      Map<String, dynamic>? sunday;
      try {
        final sundayDate = _getUpcomingSunday();
        try {
          final data = await ApiService.getSundayCleaning(sundayDate);
          sunday = _asMap(data['schedule']);
        } catch (_) {
          final created = await ApiService.createSundayCleaning(sundayDate);
          sunday = _asMap(created['schedule']);
        }
      } catch (_) {
        sunday = null;
      }

      if (!mounted) return;

      setState(() {
        trashPerson =
            _mapName(selectedTrash?['assignedTo']) ?? currentTrashPerson;
        trashTask = selectedTrash;
        trashStatus = selectedTrash == null
            ? 'No task'
            : _formatStatus(selectedTrash['status']?.toString() ?? 'pending');

        waterPerson =
            _mapName(selectedWater?['assignedTo']) ?? currentWaterPerson;
        waterTask = selectedWater;
        waterReported = currentWaterTask != null || selectedWater != null;
        waterStatus = selectedWater == null
            ? 'Water available'
            : _formatStatus(selectedWater['status']?.toString() ?? 'pending');

        sundaySchedule = sunday;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      _showMessage('Failed to load tasks: $error', isError: true);
    }
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String? _mapName(dynamic value) {
    final map = _asMap(value);
    final name = map?['name']?.toString();
    return name == null || name.isEmpty ? null : name;
  }

  String? _taskAssignedName(Map<String, dynamic>? task) {
    if (task == null) return null;
    return _mapName(task['assignedTo']);
  }

  Map<String, dynamic>? _selectTodayTask(
    List<Map<String, dynamic>> tasks,
    Map<String, dynamic>? currentTask, {
    bool preferUserCompleted = false,
  }) {
    if (tasks.isEmpty) {
      if (currentTask != null && _isToday(currentTask['dueDate'])) {
        return currentTask;
      }
      return null;
    }

    if (preferUserCompleted) {
      final myCompleted = tasks.where((task) {
        final assigned = _taskAssignedName(task);
        return assigned != null &&
            assigned.toLowerCase() == userName.toLowerCase() &&
            task['status']?.toString().toLowerCase() == 'completed';
      }).toList();

      if (myCompleted.isNotEmpty) {
        return _latestTask(myCompleted);
      }
    }

    if (currentTask != null && _isToday(currentTask['dueDate'])) {
      final currentId = currentTask['_id']?.toString();
      for (final task in tasks) {
        if (task['_id']?.toString() == currentId) return task;
      }
      return currentTask;
    }

    return _latestTask(tasks);
  }

  Map<String, dynamic> _latestTask(List<Map<String, dynamic>> tasks) {
    tasks.sort((a, b) {
      final aDate =
          DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return tasks.first;
  }

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
  // WATER REPORT
  // ============================================================

  Future<void> _reportWaterEmpty() async {
    if (reportingWater) return;

    setState(() => reportingWater = true);

    try {
      await ApiService.reportWaterEmpty();
      if (!mounted) return;
      _showMessage('Water marked as empty');
      await _loadTasks();
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => reportingWater = false);
    }
  }

  // ============================================================
  // COMPLETE TRASH / WATER
  // ============================================================

  Future<void> _completeTask({
    required String taskId,
    required String type,
  }) async {
    if (completing) return;

    final image = await _pickProofImage();
    if (image == null) return;

    setState(() => completing = true);

    try {
      final proofUrl = await _uploadToCloudinary(image);

      if (type == 'trash') {
        await ApiService.completeTask(taskId, proofUrl);
      } else {
        await ApiService.completeWaterTask(taskId, proofUrl);
      }

      if (!mounted) return;
      _showMessage('Task completed successfully');
      await _loadTasks();
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => completing = false);
    }
  }

  Future<void> _markTrashMissed() async {
    final id = trashTask?['_id']?.toString();
    if (id == null) return;

    try {
      await ApiService.markTrashMissed(id);
      if (!mounted) return;
      _showMessage('Trash task marked as missed');
      await _loadTasks();
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _markWaterMissed() async {
    final id = waterTask?['_id']?.toString();
    if (id == null) return;

    try {
      await ApiService.markWaterMissed(id);
      if (!mounted) return;
      _showMessage('Water task marked as missed');
      await _loadTasks();
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  // ============================================================
  // SUNDAY COMPLETION
  // ============================================================

  bool _isHouseMember() {
    final house = _asMap(sundaySchedule?['houseCleaning']);
    final members = house?['members'];
    if (members is! List) return false;

    return members.any((member) {
      final name = _mapName(member);
      return name != null && name.toLowerCase() == userName.toLowerCase();
    });
  }

  bool _isBathroomMember() {
    final bathroom = _asMap(sundaySchedule?['bathroomCleaning']);
    final name = _mapName(bathroom?['assignedTo']);
    return name != null && name.toLowerCase() == userName.toLowerCase();
  }

  Future<void> _completeSundayTask(String type) async {
    if (completing || sundaySchedule == null) return;

    final sundayDate = _getUpcomingSunday();
    final image = await _pickProofImage();
    if (image == null) return;

    setState(() => completing = true);

    try {
      final proofUrl = await _uploadToCloudinary(image);

      if (type == 'house') {
        await ApiService.completeHouseCleaning(sundayDate, proofUrl);
      } else if (type == 'bathroom') {
        await ApiService.completeBathroomCleaning(sundayDate, proofUrl);
      } else {
        await ApiService.completeSundayTrash(sundayDate, proofUrl);
      }

      if (!mounted) return;
      _showMessage('Sunday task completed successfully');
      await _loadTasks();
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => completing = false);
    }
  }

  // ============================================================
  // IMAGE PICKER + CLOUDINARY
  // ============================================================

  Future<XFile?> _pickProofImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return null;

    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
    } catch (error) {
      if (!mounted) return null;
      _showMessage('Could not select image: $error', isError: true);
      return null;
    }
  }

  Future<String> _uploadToCloudinary(XFile image) async {
    final bytes = await image.readAsBytes();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload',
      ),
    );

    request.fields['upload_preset'] = cloudinaryUploadPreset;
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: image.name),
    );

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Proof upload failed: ${response.statusCode}');
    }

    final data = jsonDecode(body);
    final url = data['secure_url']?.toString();

    if (url == null || url.isEmpty) {
      throw Exception('Cloudinary did not return an image URL');
    }

    return url;
  }

  // ============================================================
  // UI
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
                onRefresh: _loadTasks,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      _title(),
                      _myTask(),
                      _householdTasks(),
                      _statusGuide(),
                      _harmony(),
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

  Widget _header() {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFECEEF5))),
      ),
      child: Row(
        children: [
          _logo(),
          const SizedBox(width: 11),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RoomMate',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: dark,
                ),
              ),
              Text('Tasks', style: TextStyle(fontSize: 14, color: grey)),
            ],
          ),
          const Spacer(),
          _profile(),
        ],
      ),
    );
  }

  Widget _title() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tasks',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: dark,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Your household responsibilities & proof',
            style: TextStyle(fontSize: 17, color: grey),
          ),
        ],
      ),
    );
  }

  Widget _myTask() {
    final trashMine = _isMyActiveTask(trashTask, trashPerson);
    final waterMine = _isMyActiveTask(waterTask, waterPerson);

    Map<String, dynamic>? myTask;
    String type = '';

    if (trashMine) {
      myTask = trashTask;
      type = 'trash';
    } else if (waterMine) {
      myTask = waterTask;
      type = 'water';
    }

    final title = type == 'trash'
        ? 'Take Out Trash'
        : type == 'water'
        ? 'Water Refill'
        : 'No active task';

    final description = type == 'trash'
        ? (trashTask?['isPenalty'] == true
              ? 'Penalty trash task'
              : 'Take out the household trash')
        : type == 'water'
        ? 'Refill the household water'
        : 'You are not currently responsible for a task';

    final status = myTask == null
        ? 'Waiting'
        : _formatStatus(myTask['status']?.toString() ?? 'pending');

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('MY TASK', myTask == null ? null : '✦ Your Turn'),
          const SizedBox(height: 10),
          _card(
            Column(
              children: [
                Row(
                  children: [
                    _taskIcon(
                      type == 'water'
                          ? Icons.water_drop_outlined
                          : Icons.delete_outline_rounded,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: dark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: const TextStyle(color: grey),
                          ),
                        ],
                      ),
                    ),
                    _statusChip(status),
                  ],
                ),
                if (myTask != null &&
                    (myTask['status']?.toString().toLowerCase() == 'pending' ||
                        myTask['status']?.toString().toLowerCase() ==
                            'active')) ...[
                  const SizedBox(height: 18),
                  _button(
                    completing ? 'Uploading Proof...' : 'Complete Task',
                    onTap: completing
                        ? null
                        : () => _completeTask(
                            taskId: myTask!['_id'].toString(),
                            type: type,
                          ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: completing
                        ? null
                        : type == 'trash'
                        ? _markTrashMissed
                        : _markWaterMissed,
                    child: const Text(
                      'Mark as Missed',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isMyActiveTask(Map<String, dynamic>? task, String person) {
    if (task == null) return false;
    final status = task['status']?.toString().toLowerCase();
    return (status == 'pending' || status == 'active') &&
        person.toLowerCase() == userName.toLowerCase();
  }

  Widget _householdTasks() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 29, 24, 0),
      child: Column(
        children: [
          _sectionTitle('HOUSEHOLD TASKS', '4 duties listed'),
          const SizedBox(height: 11),
          _taskCard(
            Icons.delete_outline,
            'Trash & Recycling',
            trashPerson,
            _trashDetail(),
            trashStatus,
            task: trashTask,
          ),
          const SizedBox(height: 15),
          _taskCard(
            Icons.water_drop_outlined,
            'Water Refill',
            waterPerson,
            _waterDetail(),
            waterStatus,
            task: waterTask,
            action: waterTask == null ? _reportWaterEmpty : null,
          ),
          const SizedBox(height: 15),
          _taskCard(
            Icons.cleaning_services_outlined,
            'House Deep Cleaning',
            _houseTeam(),
            'Sunday',
            _houseStatus(),
            task: _asMap(sundaySchedule?['houseCleaning']),
            sundayType: 'house',
          ),
          const SizedBox(height: 15),
          _taskCard(
            Icons.shower_outlined,
            'Bathroom Cleaning',
            _bathroomPerson(),
            'Sunday',
            _bathroomStatus(),
            task: _asMap(sundaySchedule?['bathroomCleaning']),
            sundayType: 'bathroom',
          ),
        ],
      ),
    );
  }

  String _trashDetail() {
    if (trashTask == null) return 'No task today';
    if (trashTask?['isPenalty'] == true) return 'Penalty task • Today';
    return 'Today';
  }

  String _waterDetail() {
    if (waterTask == null) return 'Water available';
    final status = waterTask?['status']?.toString().toLowerCase();
    if (status == 'completed') return 'Filled today';
    if (status == 'missed') return 'Missed • responsibility continues';
    return 'Needs to be filled';
  }

  Widget _taskCard(
    IconData icon,
    String title,
    String person,
    String detail,
    String status, {
    Map<String, dynamic>? task,
    VoidCallback? action,
    String? sundayType,
  }) {
    final proof = task?['proofImage']?.toString() ?? '';
    final normalizedStatus = status.toLowerCase();
    final isSundayToday = _istNow().weekday == DateTime.sunday;
    final canCompleteSunday =
        isSundayToday &&
        sundayType != null &&
        normalizedStatus == 'pending' &&
        ((sundayType == 'house' && _isHouseMember()) ||
            (sundayType == 'bathroom' && _isBathroomMember()));

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 15, 14, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _taskIcon(icon),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: dark,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$person • $detail',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(status),
            ],
          ),
          if (proof.isNotEmpty && normalizedStatus == 'completed') ...[
            const SizedBox(height: 14),
            _proofPreview(proof, title),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _completedByText(task),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ),
          ],
          if (task?['isPenalty'] == true) ...[
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Penalty Task • normal rotation waits until penalty is finished',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (action != null && task == null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: reportingWater ? null : action,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  reportingWater ? 'Reporting...' : 'Report Water Empty',
                  style: const TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          if (canCompleteSunday) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: completing
                    ? null
                    : () => _completeSundayTask(sundayType),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  completing ? 'Uploading...' : 'Complete with Proof',
                  style: const TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _completedByText(Map<String, dynamic>? task) {
    final name = _taskAssignedName(task);
    if (name == null) return 'Completed';
    if (name.toLowerCase() == userName.toLowerCase()) {
      return '✓ Completed by You';
    }
    return '✓ Completed by $name';
  }

  Widget _proofPreview(String url, String title) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showProof(url, title),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Container(
              height: 150,
              width: double.infinity,
              color: const Color(0xFFEFF2F8),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image_outlined, size: 35),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_full, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'View proof',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProof(String url, String title) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 300,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Close',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // SUNDAY HELPERS
  // ============================================================

  String _houseTeam() {
    final house = _asMap(sundaySchedule?['houseCleaning']);
    final members = house?['members'];
    if (members is List && members.isNotEmpty) {
      final names = members.map(_mapName).whereType<String>().toList();
      if (names.isNotEmpty) return names.join(' • ');
    }
    return 'Team $userTeam';
  }

  String _bathroomPerson() {
    final bathroom = _asMap(sundaySchedule?['bathroomCleaning']);
    return _mapName(bathroom?['assignedTo']) ?? 'Assigned member';
  }

  String _houseStatus() {
    final house = _asMap(sundaySchedule?['houseCleaning']);
    return _formatStatus(house?['status']?.toString() ?? 'pending');
  }

  String _bathroomStatus() {
    final bathroom = _asMap(sundaySchedule?['bathroomCleaning']);
    return _formatStatus(bathroom?['status']?.toString() ?? 'pending');
  }

  // ============================================================
  // STATUS GUIDE
  // ============================================================

  Widget _statusGuide() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 30, 24, 0),
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: blue,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          _sectionTitle('STATUS GUIDE'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _guide(
                  'Completed',
                  const Color(0xFF65E5B2),
                  const Color(0xFF087A5C),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _guide(
                  'Pending',
                  const Color(0xFFFFDDAE),
                  const Color(0xFF553A15),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _guide(
                  'Missed',
                  const Color(0xFFFFD7D7),
                  const Color(0xFFAD3030),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _harmony() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 30, 24, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE4EDFF),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Row(
        children: [
          Icon(Icons.favorite_border, color: primary, size: 30),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Living in harmony',
                  style: TextStyle(fontWeight: FontWeight.w700, color: dark),
                ),
                SizedBox(height: 3),
                Text(
                  'Complete responsibilities and keep the rotation moving.',
                  style: TextStyle(color: grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMMON UI
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
            true,
            const TasksScreen(),
          ),
          _nav(
            context,
            Icons.history_rounded,
            'History',
            false,
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

  Widget _sectionTitle(String title, [String? right]) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: .4,
            color: grey,
          ),
        ),
        const Spacer(),
        if (right != null)
          Text(
            right,
            style: const TextStyle(color: primary, fontWeight: FontWeight.w700),
          ),
      ],
    );
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _taskIcon(IconData icon) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFE5EEFF),
        borderRadius: BorderRadius.circular(13),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 29, color: const Color(0xFF596274)),
    );
  }

  Widget _statusChip(String text) {
    Color background;
    Color textColor;

    switch (text.toLowerCase()) {
      case 'completed':
        background = const Color(0xFF65E5B2);
        textColor = const Color(0xFF087A5C);
        break;
      case 'missed':
        background = const Color(0xFFFFD7D7);
        textColor = const Color(0xFFAD3030);
        break;
      case 'active':
        background = const Color(0xFFDDE9FF);
        textColor = const Color(0xFF334E7C);
        break;
      case 'pending':
        background = const Color(0xFFFFDDAE);
        textColor = const Color(0xFF553A15);
        break;
      case 'water available':
        background = const Color(0xFF65E5B2);
        textColor = const Color(0xFF087A5C);
        break;
      default:
        background = const Color(0xFFE5EDFF);
        textColor = dark;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _guide(String text, Color background, Color textColor) {
    return Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _button(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 57,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? primary.withValues(alpha: 0.5) : primary,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Icon(Icons.home, color: Colors.white),
    );
  }

  Widget _profile() {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(color: primary, shape: BoxShape.circle),
      child: const Icon(Icons.person_outline, color: Colors.white),
    );
  }

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
