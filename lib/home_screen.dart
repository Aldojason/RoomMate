import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'services/api_service.dart';
import 'tasks_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
  // =========================
  // USER
  // =========================

  String userName = 'Jason';
  String userTeam = 'A';
  List<String> teamMembers = ['Jason', 'Chandru', 'Deepan'];

  // =========================
  // ROTATIONS
  // =========================

  String trashPerson = 'Loading...';
  String waterPerson = 'Loading...';
  bool waterReported = false;

  Map<String, dynamic>? todayTrashTask;
  String todayTrashStatus = 'pending';
  bool todayTrashIsPenalty = false;

  Map<String, dynamic>? sundaySchedule;

  // =========================
  // CURRENT TASK
  // =========================

  String taskType = '';
  String taskPerson = '';
  String? currentTaskId;

  // =========================
  // PROOF
  // =========================

  XFile? proofImage;
  bool uploadingProof = false;
  bool completingTask = false;

  // =========================
  // CLOUDINARY
  // =========================
  //
  // These are safe to use with your unsigned upload preset.
  //

  static const String cloudinaryCloudName = 'gawa5bgv';
  static const String cloudinaryUploadPreset = 'roommate_proofs';

  // =========================
  // COLORS
  // =========================

  static const teal = Color(0xFF087A70);
  static const dark = Color(0xFF101820);
  static const grey = Color(0xFF384047);
  static const bg = Color(0xFFF8F9FF);
  static const blue = Color(0xFFEFF3FF);

  // =========================
  // INIT
  // =========================

  @override
  void initState() {
    super.initState();
    initializeHome();
  }

  Future<void> initializeHome() async {
    await loadUserName();
    await loadCurrentTask();
  }

  // =========================
  // LOAD USER
  // =========================

  Future<void> loadUserName() async {
    final prefs = await SharedPreferences.getInstance();

    final savedName = prefs.getString('userName');
    final savedTeam = prefs.getString('userTeam');

    if (!mounted) return;

    setState(() {
      if (savedName != null && savedName.isNotEmpty) {
        userName = savedName;
      }

      if (savedTeam != null && savedTeam.isNotEmpty) {
        userTeam = savedTeam;
      }

      teamMembers = userTeam == 'B'
          ? ['Harish', 'Mohan', 'Tamil']
          : ['Jason', 'Chandru', 'Deepan'];
    });
  }

  // =========================
  // LOAD CURRENT TASK
  // =========================

  DateTime _istNow() {
    return DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  String _istDateKey(DateTime dateTime) {
    final ist = dateTime.toUtc().add(const Duration(hours: 5, minutes: 30));
    final month = ist.month.toString().padLeft(2, '0');
    final day = ist.day.toString().padLeft(2, '0');
    return '${ist.year}-$month-$day';
  }

  bool _isTodayInIst(dynamic value) {
    if (value == null) return false;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return false;
    return _istDateKey(parsed) == _istDateKey(_istNow());
  }

  String _upcomingSundayLabel() {
    final today = _istNow();
    final daysUntilSunday = (DateTime.sunday - today.weekday + 7) % 7;
    if (daysUntilSunday == 0) return 'Today';
    if (daysUntilSunday == 1) return 'In 1 Day';
    return 'In $daysUntilSunday Days';
  }

  String _getUpcomingSunday() {
    final today = _istNow();
    final daysUntilSunday = (DateTime.sunday - today.weekday + 7) % 7;
    final sunday = today.add(Duration(days: daysUntilSunday));
    return _istDateKey(sunday);
  }

  Future<void> loadCurrentTask() async {
    try {
      final trash = await ApiService.getCurrentTrashPerson();
      final water = await ApiService.getCurrentWaterPerson();
      final allTasks = await ApiService.getAllTasks();

      Map<String, dynamic>? sunday;
      try {
        final sundayDate = _getUpcomingSunday();
        try {
          final data = await ApiService.getSundayCleaning(sundayDate);
          if (data['schedule'] is Map<String, dynamic>) {
            sunday = Map<String, dynamic>.from(data['schedule']);
          }
        } catch (_) {
          final created = await ApiService.createSundayCleaning(sundayDate);
          if (created['schedule'] is Map<String, dynamic>) {
            sunday = Map<String, dynamic>.from(created['schedule']);
          }
        }
      } catch (e) {
        debugPrint('Sunday schedule load error: $e');
      }

      final newTrashPerson =
          trash['currentPerson']?['name']?.toString() ?? 'Unknown';

      final newWaterPerson =
          water['currentPerson']?['name']?.toString() ?? 'Unknown';

      final currentTrashTask = trash['currentTask'];
      final currentWaterTask = water['currentTask'];

      final todayTrashTasks = allTasks
          .where(
            (task) =>
                task is Map<String, dynamic> &&
                task['type'] == 'trash' &&
                task['isSundayTeamTask'] != true &&
                _isTodayInIst(task['dueDate']),
          )
          .cast<Map<String, dynamic>>()
          .toList();

      todayTrashTasks.sort((a, b) {
        final aDate =
            DateTime.tryParse(a['dueDate']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            DateTime.tryParse(b['dueDate']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      final todayTask = todayTrashTasks.isEmpty ? null : todayTrashTasks.first;

      final bool newWaterReported =
          currentWaterTask != null &&
          (currentWaterTask['status'] == 'pending' ||
              currentWaterTask['status'] == 'active');

      String newTaskType = '';
      String newTaskPerson = '';
      String? newTaskId;

      if (userName == newTrashPerson && currentTrashTask != null) {
        newTaskType = 'trash';
        newTaskPerson = newTrashPerson;
        newTaskId = currentTrashTask['_id']?.toString();
      } else if (userName == newWaterPerson && currentWaterTask != null) {
        newTaskType = 'water';
        newTaskPerson = newWaterPerson;
        newTaskId = currentWaterTask['_id']?.toString();
      }

      if (!mounted) return;

      setState(() {
        trashPerson = newTrashPerson;
        waterPerson = newWaterPerson;
        waterReported = newWaterReported;
        todayTrashTask = todayTask;
        todayTrashStatus = todayTask?['status']?.toString() ?? 'pending';
        todayTrashIsPenalty = todayTask?['isPenalty'] == true;
        taskType = newTaskType;
        taskPerson = newTaskPerson;
        currentTaskId = newTaskId;
        sundaySchedule = sunday;
      });

      debugPrint('CURRENT USER: $userName');
      debugPrint('TRASH PERSON: $newTrashPerson');
      debugPrint('TODAY TRASH TASK: $todayTask');
      debugPrint('CURRENT TASK ID: $newTaskId');
    } catch (e) {
      debugPrint('Load current task error: $e');

      if (!mounted) return;

      setState(() {
        trashPerson = 'Unavailable';
        waterPerson = 'Unavailable';
        taskType = '';
        taskPerson = '';
        currentTaskId = null;
      });
    }
  }

  // =========================
  // PICK PROOF IMAGE
  // =========================

  Future<void> pickProofImage() async {
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final image = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() {
        proofImage = image;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not select image: $e')));
    }
  }

  // =========================
  // UPLOAD PROOF TO CLOUDINARY
  // =========================

  Future<String> uploadProofToCloudinary(XFile image) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/'
      '$cloudinaryCloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', url);

    request.fields['upload_preset'] = cloudinaryUploadPreset;

    final bytes = await image.readAsBytes();

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: image.name),
    );

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Photo upload failed: ${response.body}');
    }

    final data = jsonDecode(response.body);

    final secureUrl = data['secure_url']?.toString();

    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception('Cloudinary did not return an image URL');
    }

    return secureUrl;
  }

  // =========================
  // COMPLETE CURRENT TASK
  // =========================

  Future<void> completeCurrentTask() async {
    // Refresh the current task if the ID is missing.
    if (currentTaskId == null) {
      await loadCurrentTask();
    }

    if (currentTaskId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No active task found')));
      return;
    }

    // PROOF IS REQUIRED

    if (proofImage == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo proof is required before completing the task'),
        ),
      );
      return;
    }

    if (uploadingProof || completingTask) return;

    try {
      setState(() {
        uploadingProof = true;
      });

      // -------------------------
      // UPLOAD PHOTO
      // -------------------------

      final proofUrl = await uploadProofToCloudinary(proofImage!);

      if (!mounted) return;

      setState(() {
        uploadingProof = false;
        completingTask = true;
      });

      // -------------------------
      // COMPLETE BACKEND TASK
      // -------------------------

      if (taskType == 'water') {
        await ApiService.completeWaterTask(currentTaskId!, proofUrl);
      } else {
        await ApiService.completeTask(currentTaskId!, proofUrl);
      }

      if (!mounted) return;

      setState(() {
        completingTask = false;
        proofImage = null;
        currentTaskId = null;
        taskType = '';
        taskPerson = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task completed successfully ✅')),
      );

      // Refresh everything after completion.
      await loadCurrentTask();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        uploadingProof = false;
        completingTask = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> markCurrentTaskMissed() async {
    if (currentTaskId == null) {
      _showMessage('No active task found');
      return;
    }

    try {
      setState(() {
        completingTask = true;
      });

      await ApiService.markTrashMissed(currentTaskId!);

      if (!mounted) return;

      setState(() {
        proofImage = null;
        currentTaskId = null;
        completingTask = false;
      });

      _showMessage('Trash task marked as missed');

      await loadCurrentTask();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        completingTask = false;
      });

      _showMessage(e.toString());
    }
  }

  Future<void> markCurrentWaterMissed() async {
    if (currentTaskId == null) {
      _showMessage('No active water task found');
      return;
    }

    try {
      setState(() {
        completingTask = true;
      });

      await ApiService.markWaterMissed(currentTaskId!);

      if (!mounted) return;

      setState(() {
        currentTaskId = null;
        proofImage = null;
        completingTask = false;
      });

      _showMessage('Water task marked as missed');

      await loadCurrentTask();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        completingTask = false;
      });

      _showMessage(e.toString());
    }
  }

  // =========================
  // REPORT WATER EMPTY
  // =========================

  Future<void> reportWaterEmpty() async {
    try {
      await ApiService.reportWaterEmpty();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Water empty report submitted 💧')),
      );

      await loadCurrentTask();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    final bool isMyTask =
        taskPerson.isNotEmpty &&
        userName == taskPerson &&
        currentTaskId != null;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 18, 28, 25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _greeting(),

                    const SizedBox(height: 28),

                    _title(
                      isMyTask ? 'YOUR TASK' : 'TODAY\'S TASK',
                      '⚡ 3-Sec Glance',
                    ),

                    const SizedBox(height: 10),

                    _yourTask(),

                    const SizedBox(height: 30),

                    _title("WHO'S RESPONSIBLE?"),

                    const SizedBox(height: 10),

                    _responsibility(),

                    const SizedBox(height: 30),

                    _title('WATER'),

                    const SizedBox(height: 10),

                    _water(),

                    const SizedBox(height: 30),

                    _title('SUNDAY CLEANING', _upcomingSundayLabel()),

                    const SizedBox(height: 10),

                    _houseCleaning(),

                    const SizedBox(height: 12),

                    _bathroomCleaning(),

                    const SizedBox(height: 35),

                    _vibe(),
                  ],
                ),
              ),
            ),

            _bottomNavigation(context),
          ],
        ),
      ),
    );
  }

  // =========================
  // HEADER
  // =========================

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEDEEF5))),
      ),
      child: Row(
        children: [
          _logo(44),

          const SizedBox(width: 12),

          const Column(
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
              Text('Home', style: TextStyle(fontSize: 15, color: grey)),
            ],
          ),

          const Spacer(),

          _profile(),
        ],
      ),
    );
  }

  // =========================
  // GREETING
  // =========================

  Widget _greeting() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $userName 👋',
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w600,
                  color: dark,
                ),
              ),

              const SizedBox(height: 3),

              const Text(
                'Chavadi atti boys',
                style: TextStyle(fontSize: 17, color: grey),
              ),
            ],
          ),
        ),

        ...teamMembers.asMap().entries.map((entry) {
          final index = entry.key;
          final name = entry.value;
          final initials = name
              .split(' ')
              .where((part) => part.isNotEmpty)
              .map((part) => part[0])
              .join()
              .toUpperCase();
          final colors = [
            teal,
            const Color(0xFFE4EAF7),
            const Color(0xFFAD6508),
          ];
          return Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
            child: _avatar(
              initials,
              colors[index % colors.length],
              highlighted: name.toLowerCase() == userName.toLowerCase(),
            ),
          );
        }),
      ],
    );
  }

  // =========================
  // TITLE
  // =========================

  Widget _title(String text, [String? right]) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: .4,
            color: grey,
          ),
        ),

        const Spacer(),

        if (right != null)
          Text(
            right,
            style: const TextStyle(color: teal, fontWeight: FontWeight.w500),
          ),
      ],
    );
  }

  // =========================
  // YOUR TASK
  // =========================

  Widget _yourTask() {
    final bool isMyTask = taskPerson.isNotEmpty && userName == taskPerson;

    final bool isWater = taskType == 'water';

    final String taskTitle = isWater ? 'Refill Water' : 'Take Out Trash';

    final String taskDescription = isWater
        ? 'Check water / refill'
        : 'Kitchen bin + Recycling totes';

    final IconData taskIcon = isWater
        ? Icons.water_drop_outlined
        : Icons.delete_outline;

    return _card(
      Column(
        children: [
          Row(
            children: [
              _taskIcon(
                taskIcon,
                iconColor: isWater ? const Color(0xFF39B6E9) : teal,
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      taskType.isEmpty ? 'No Active Task' : taskTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: dark,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      taskType.isEmpty
                          ? 'You have no task right now'
                          : 'Due Today by 8:00 PM',
                      style: const TextStyle(fontSize: 15, color: grey),
                    ),
                  ],
                ),
              ),

              if (taskType.isNotEmpty) _chip('● Pending'),
            ],
          ),

          if (taskType.isNotEmpty) ...[
            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    isWater ? '💧' : '♻',
                    style: const TextStyle(fontSize: 20),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      taskDescription,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: grey,
                      ),
                    ),
                  ),

                  Text(
                    isMyTask ? 'Your turn' : 'Not your turn',
                    style: const TextStyle(
                      color: teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            if (isMyTask)
              GestureDetector(
                onTap: uploadingProof || completingTask ? null : pickProofImage,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: blue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        proofImage == null
                            ? Icons.camera_alt_outlined
                            : Icons.check_circle_outline,
                        color: teal,
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          proofImage == null
                              ? 'Add Photo Proof'
                              : 'Photo Selected ✓',
                          style: const TextStyle(
                            color: teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      if (proofImage != null)
                        const Text('Change', style: TextStyle(color: grey)),
                    ],
                  ),
                ),
              ),

            if (proofImage != null && isMyTask)
              FutureBuilder(
                future: proofImage!.readAsBytes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 180,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: blue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const CircularProgressIndicator(color: teal),
                    );
                  }

                  if (!snapshot.hasData) {
                    return Container(
                      height: 180,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: blue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Preview unavailable',
                        style: TextStyle(color: grey),
                      ),
                    );
                  }

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      snapshot.data!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            if (proofImage != null && isMyTask) const SizedBox(height: 12),

            if (isMyTask)
              _button(
                uploadingProof
                    ? 'Uploading Photo...'
                    : completingTask
                    ? 'Completing Task...'
                    : 'Complete Task',
                onTap: uploadingProof || completingTask
                    ? null
                    : completeCurrentTask,
              ),
            if (isMyTask && taskType == 'trash')
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: GestureDetector(
                  onTap: completingTask ? null : markCurrentTaskMissed,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Mark as Missed',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (isMyTask && taskType == 'water')
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: GestureDetector(
                  onTap: completingTask ? null : markCurrentWaterMissed,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Mark as Missed',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // =========================
  // TRASH RESPONSIBILITY
  // =========================

  Widget _responsibility() {
    final task = todayTrashTask;
    final status = task?['status']?.toString() ?? 'pending';
    final assignedName =
        task?['assignedTo']?['name']?.toString() ?? trashPerson;

    final bool isSunday = _istNow().weekday == DateTime.sunday;
    final bool completed = status == 'completed';
    final bool missed = status == 'missed';
    final bool pending = status == 'pending' || status == 'active';

    String statusLabel;
    Color statusColor;
    if (isSunday && task == null) {
      statusLabel = 'No individual trash duty today';
      statusColor = grey;
    } else if (completed) {
      statusLabel = 'Completed today';
      statusColor = const Color(0xFF087A70);
    } else if (missed) {
      statusLabel = 'Missed today';
      statusColor = const Color(0xFFAE1515);
    } else if (pending) {
      statusLabel = 'Pending today';
      statusColor = const Color(0xFF9A5A00);
    } else {
      statusLabel = 'No task';
      statusColor = grey;
    }

    return _card(
      Column(
        children: [
          Row(
            children: [
              _taskIcon(Icons.delete_outline),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trash Duty',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        color: dark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      todayTrashIsPenalty
                          ? 'Penalty Task • $assignedName'
                          : "Today's duty • $assignedName",
                      style: TextStyle(fontSize: 15, color: statusColor),
                    ),
                  ],
                ),
              ),
              _personChip('● $assignedName'),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      completed
                          ? Icons.check_circle_outline
                          : missed
                          ? Icons.cancel_outlined
                          : Icons.schedule_outlined,
                      size: 20,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                if (completed) ...[
                  const SizedBox(height: 5),
                  Text(
                    "$assignedName completed today's trash duty.",
                    style: const TextStyle(color: grey),
                  ),
                ],
                if (todayTrashIsPenalty) ...[
                  const SizedBox(height: 5),
                  const Text(
                    'This is a penalty task. The normal rotation does not advance until the penalty is finished.',
                    style: TextStyle(color: grey),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Text(
                  'Turn\nCycle:',
                  style: TextStyle(fontWeight: FontWeight.w600, color: grey),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Text(
                    'Jason → Harish → Chandru → Mohan → Deepan → Tamil',
                    style: TextStyle(
                      color: teal,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // WATER
  // =========================

  Widget _water() {
    final bool isMyWaterTask =
        userName == waterPerson &&
        waterPerson != 'Loading...' &&
        waterPerson != 'Unavailable';

    return _card(
      Column(
        children: [
          Row(
            children: [
              _taskIcon(
                Icons.water_drop_outlined,
                iconColor: const Color(0xFF39B6E9),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Water Refill',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        color: dark,
                      ),
                    ),

                    Text(
                      '● Responsible: $waterPerson',
                      style: const TextStyle(color: Color(0xFF007A55)),
                    ),
                  ],
                ),
              ),

              if (waterReported)
                const Text(
                  'Reported',
                  style: TextStyle(
                    color: Color(0xFFAE1515),
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (isMyWaterTask)
                const Text(
                  'Your turn',
                  style: TextStyle(color: teal, fontWeight: FontWeight.w600),
                ),
            ],
          ),

          const SizedBox(height: 18),

          if (waterReported)
            Container(
              height: 60,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8E6),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                '✓ Water Empty Reported • Waiting for $waterPerson',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFAE1515),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            GestureDetector(
              onTap: reportWaterEmpty,
              child: Container(
                height: 60,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD8D5),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text(
                  '⚠ Water is Empty',
                  style: TextStyle(
                    color: Color(0xFFAE1515),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Turn\nCycle:',
                  style: TextStyle(fontWeight: FontWeight.w600, color: grey),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Text(
                    'Mohan → Chandru → Tamil → Jason → Harish → Deepan',
                    style: TextStyle(
                      color: teal,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // =========================
  // HOUSE CLEANING
  // =========================

  String _houseCleaningMembers() {
    final house = sundaySchedule?['houseCleaning'];
    if (house is! Map) return 'Loading...';

    final members = house['members'];
    if (members is! List || members.isEmpty) return 'Not assigned';

    final names = members
        .map((member) {
          if (member is Map) return member['name']?.toString() ?? '';
          return '';
        })
        .where((name) => name.isNotEmpty)
        .toList();

    return names.isEmpty ? 'Not assigned' : names.join(' • ');
  }

  String _bathroomCleaningPerson() {
    final bathroom = sundaySchedule?['bathroomCleaning'];
    if (bathroom is! Map) return 'Loading...';

    final assignedTo = bathroom['assignedTo'];
    if (assignedTo is Map) {
      final name = assignedTo['name']?.toString();
      if (name != null && name.isNotEmpty) return name;
    }

    return 'Not assigned';
  }

  Widget _houseCleaning() {
    final members = _houseCleaningMembers();

    return _card(
      Row(
        children: [
          _taskIcon(Icons.cleaning_services_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'House Cleaning',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: dark,
                  ),
                ),
                Text(members, style: const TextStyle(color: grey)),
              ],
            ),
          ),
          _teamChip(
            text: sundaySchedule?['houseTeam']?.toString() ?? 'Upcoming',
          ),
        ],
      ),
    );
  }

  // =========================
  // BATHROOM CLEANING
  // =========================

  Widget _bathroomCleaning() {
    final person = _bathroomCleaningPerson();

    return _card(
      Column(
        children: [
          Row(
            children: [
              _taskIcon(Icons.shower_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bathroom Cleaning',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: dark,
                      ),
                    ),
                    Text(
                      'Responsible: $person',
                      style: const TextStyle(color: grey),
                    ),
                  ],
                ),
              ),
              _teamChip(text: person),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: blue,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Text(
              'ⓘ 1 person on rotation • Changes weekly',
              style: TextStyle(color: grey),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // VIBE
  // =========================

  Widget _vibe() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: blue,
        borderRadius: BorderRadius.circular(17),
      ),
      child: const Row(
        children: [
          Text('☺', style: TextStyle(fontSize: 27, color: teal)),

          SizedBox(width: 12),

          Expanded(
            child: Text(
              'Roommate vibe score: 100%\nPeaceful',
              style: TextStyle(fontWeight: FontWeight.w600, color: dark),
            ),
          ),

          Text('No chore\nfriction', style: TextStyle(color: grey)),
        ],
      ),
    );
  }

  // =========================
  // BOTTOM NAVIGATION
  // =========================

  Widget _bottomNavigation(BuildContext context) {
    return _navigation(context, 0);
  }

  Widget _navigation(BuildContext context, int selected) {
    return Container(
      height: 78,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE8EAF0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(
            context,
            Icons.home_outlined,
            'Home',
            selected == 0,
            const HomeScreen(),
          ),

          _navItem(
            context,
            Icons.checklist_rounded,
            'Tasks',
            selected == 1,
            const TasksScreen(),
          ),

          _navItem(
            context,
            Icons.history_rounded,
            'History',
            selected == 2,
            const HistoryScreen(),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
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
            Icon(icon, size: 27, color: selected ? teal : grey),

            const SizedBox(height: 4),

            Text(
              label,
              style: TextStyle(
                color: selected ? teal : grey,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // CARD
  // =========================

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  // =========================
  // BUTTON
  // =========================

  Widget _button(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade400 : teal,
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // =========================
  // TASK ICON
  // =========================

  Widget _taskIcon(IconData icon, {Color iconColor = teal}) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFE4ECFF),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 29, color: iconColor),
    );
  }

  // =========================
  // STATUS CHIP
  // =========================

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDDBB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4A2C05),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // =========================
  // PERSON CHIP
  // =========================

  Widget _personChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF8DEDE0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: teal, fontWeight: FontWeight.w600),
      ),
    );
  }

  // =========================
  // TEAM CHIP
  // =========================

  Widget _teamChip({String text = 'Team A'}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF8DEDE0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF075D55),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // =========================
  // AVATAR
  // =========================

  Widget _avatar(String text, Color color, {bool highlighted = false}) {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: highlighted ? Border.all(color: teal, width: 3) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: color == const Color(0xFFE4EAF7) ? grey : Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // =========================
  // PROFILE
  // =========================

  Widget _profile() {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(color: teal, shape: BoxShape.circle),
      child: const Icon(Icons.person_outline, color: Colors.white),
    );
  }

  // =========================
  // LOGO
  // =========================

  Widget _logo(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: teal,
        borderRadius: BorderRadius.circular(size * .25),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.home, color: Colors.white, size: size * .55),
    );
  }
}
