import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/database/articleHistory_database.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/database/task_database.dart'; // ✅ Add task database
import 'package:reciclaje_app/model/articleHistory.dart';
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/model/recycling_items.dart';
import 'package:reciclaje_app/model/task.dart'; // ✅ Add task model
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsScreen extends StatefulWidget {
  final RecyclingItem? item;
  const NotificationsScreen({super.key, this.item});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _authService = AuthService();
  final _usersDatabase = UsersDatabase();
  final _mediaDatabase = MediaDatabase();
  final _taskDatabase = TaskDatabase(); // ✅ Add task database
  final _articleHistoryDb = ArticlehistoryDatabase();

  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _assignedTasks =
      []; // ✅ Tasks with assigned employees
  bool _isLoading = true;
  int? _currentUserId;

  RealtimeChannel? _requestChannel;
  RealtimeChannel? _taskChannel; // ✅ Add task channel

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupRealtimeListener();
    _markAllAsReadLocally();
  }

  @override
  void dispose() {
    // Unsubscribe from real-time channels
    _requestChannel?.unsubscribe();
    _taskChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeListener() {
    // Listen to request table changes
    _requestChannel =
        Supabase.instance.client
            .channel('distributor-notifications-requests')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'request',
              callback: (payload) {
                print(
                  '🔔 Real-time request notification: ${payload.eventType}',
                );
                _loadNotifications();
              },
            )
            .subscribe();

    // ✅ Listen to tasks table changes for employee assignments
    _taskChannel =
        Supabase.instance.client
            .channel('distributor-notifications-tasks')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'tasks',
              callback: (payload) {
                print('🔔 Real-time task notification: ${payload.eventType}');
                _loadNotifications();
              },
            )
            .subscribe();
  }

  /// ✅ Mark all current notifications as read locally
  Future<void> _markAllAsReadLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readNotifications =
          prefs.getStringList('read_distributor_notifications') ?? [];
      final readAssignedTasks =
          prefs.getStringList('read_distributor_assigned_tasks') ?? [];

      // Mark pending requests as read
      for (var request in _pendingRequests) {
        final requestId = request['idRequest'].toString();
        if (!readNotifications.contains(requestId)) {
          readNotifications.add(requestId);
        }
      }

      // ✅ Mark assigned tasks as read
      for (var task in _assignedTasks) {
        final taskId = task['idTask'].toString();
        if (!readAssignedTasks.contains(taskId)) {
          readAssignedTasks.add(taskId);
        }
      }

      await prefs.setStringList(
        'read_distributor_notifications',
        readNotifications,
      );
      await prefs.setStringList(
        'read_distributor_assigned_tasks',
        readAssignedTasks,
      );
      print(
        '✅ Marked ${_pendingRequests.length} requests and ${_assignedTasks.length} assigned tasks as read locally',
      );
    } catch (e) {
      print('❌ Error marking notifications as read: $e');
    }
  }

  /// ✅ Get count of unread notifications
  // static Future<int> getUnreadCount(int? userId) async {
  //   if (userId == null) return 0;

  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final readNotifications = prefs.getStringList('read_distributor_notifications') ?? [];

  //     // Get pending requests for this user
  //     final requests = await Supabase.instance.client
  //         .from('request')
  //         .select('''
  //           idRequest,
  //           article:articleID (
  //             userID
  //           )
  //         ''')
  //         .eq('status', 'pendiente');

  //     // Filter by user's articles and check if read
  //     final unreadCount = requests.where((req) {
  //       final article = req['article'] as Map<String, dynamic>?;
  //       if (article == null || article['userID'] != userId) return false;

  //       final requestId = req['idRequest'].toString();
  //       return !readNotifications.contains(requestId);
  //     }).length;

  //     return unreadCount;
  //   } catch (e) {
  //     print('❌ Error getting unread count: $e');
  //     return 0;
  //   }
  // }

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Get current user ID
      final email = _authService.getCurrentUserEmail();
      if (email != null) {
        final currentUser = await _usersDatabase.getUserByEmail(email);
        _currentUserId = currentUser?.id;

        if (_currentUserId != null) {
          // Get pending requests for articles owned by this user
          final requests = await Supabase.instance.client
              .from('request')
              .select('''
                *,
                article:articleID (
                  idArticle,
                  name,
                  userID
                ),
                company:companyID (
                  idCompany,
                  nameCompany
                )
              ''')
              .eq('status', 'pendiente')
              .order('requestDate', ascending: false);

          // Filter requests where article belongs to current user
          final myRequests =
              requests.where((req) {
                final article = req['article'] as Map<String, dynamic>?;
                return article != null && article['userID'] == _currentUserId;
              }).toList();

          print('🔔 Found ${myRequests.length} pending requests');

          // ✅ Get tasks with assigned employees for user's articles
          final tasks = await Supabase.instance.client
              .from('tasks')
              .select('''
                idTask,
                employeeID,
                articleID,
                assignedDate,
                workflowStatus,
                lastUpdate,
                article:articleID (
                  idArticle,
                  name,
                  userID
                ),
                employee:employeeID (
                  idEmployee,
                  user:userID (
                    names
                  )
                ),
                request:requestID (
                  scheduledDay,
                  scheduledStartTime,
                  scheduledEndTime
                )
              ''')
              .eq('workflowStatus', 'en_proceso')
              .order('lastUpdate', ascending: false);

          // Filter tasks where article belongs to current user
          final myTasks =
              tasks.where((task) {
                final article = task['article'] as Map<String, dynamic>?;
                return article != null && article['userID'] == _currentUserId;
              }).toList();

          print('🔔 Found ${myTasks.length} tasks with assigned employees');

          // Load company logos and ratings for each request
          for (var request in myRequests) {
            final company = request['company'] as Map<String, dynamic>?;
            if (company != null) {
              final companyId = company['idCompany'];
              // Use only companyId pattern to avoid issues with special characters
              final logoPattern = 'empresa/$companyId/avatar/';
              final logo = await _mediaDatabase.getMainPhotoByPattern(
                logoPattern,
              );
              request['companyLogo'] = logo;

              // ✅ Load company rating
              final rating = await _loadCompanyRating(companyId);
              request['companyRating'] = rating;
            }
          }

          if (mounted) {
            setState(() {
              _pendingRequests = myRequests;
              _assignedTasks = myTasks;
            });
            // Mark as read after loading
            await _markAllAsReadLocally();
          }
        }
      }
    } catch (e) {
      print('❌ Error loading notifications: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// ✅ Load company rating (average rating of all employees)
  Future<double> _loadCompanyRating(int companyId) async {
    try {
      // Get all employees for this company (no state column on employees table)
      final employees = await Supabase.instance.client
          .from('employees')
          .select('userID')
          .eq('companyID', companyId);

      if (employees.isEmpty) return 0.0;

      // Get all employee user IDs
      final employeeUserIds = employees.map((e) => e['userID'] as int).toList();

      // Get all reviews for these employees
      final reviews = await Supabase.instance.client
          .from('reviews')
          .select('starID')
          .inFilter('receiverID', employeeUserIds)
          .eq('state', 1);

      if (reviews.isEmpty) return 0.0;

      // Calculate average rating
      int totalStars = 0;
      for (var review in reviews) {
        totalStars += (review['starID'] as int? ?? 0);
      }

      return totalStars / reviews.length;
    } catch (e) {
      print('❌ Error loading company rating: $e');
      return 0.0;
    }
  }

  Future<void> _handleAccept(Map<String, dynamic> requestData) async {
    try {
      final requestId = requestData['idRequest'];
      final articleId = requestData['article']?['idArticle'] as int?;
      final companyId = requestData['company']?['idCompany'] as int?;

      if (articleId == null || companyId == null) {
        throw Exception('Missing article or company ID');
      }

      print('🔍 Creating task with:');
      print('   articleId: $articleId');
      print('   companyId: $companyId');
      print('   requestId: $requestId');

      // Update request status to "aprobado"
      await Supabase.instance.client
          .from('request')
          .update({
            'status': 'aprobado',
            'lastUpdate': DateTime.now().toIso8601String(),
          })
          .eq('idRequest', requestId);

      print('✅ Request updated to "aprobado"');

      // ✅ Create task with "sin_asignar" status (no employee assigned yet)
      final task = Task(
        articleId: articleId,
        companyId: companyId,
        requestId: requestId,
        assignedDate: DateTime.now(),
        workflowStatus: 'sin_asignar', // ✅ No employee assigned yet
        state: 1, // Active
        lastUpdate: DateTime.now(),
      );

      await _taskDatabase.createTask(task);

      print(
        '✅ Task created with "sin_asignar" status - Article: $articleId, Company: $companyId, Request: $requestId',
      );

      final newLog = articleHistory(
        articleId: articleId,
        actorId: widget.item?.ownerUserId,
        targetId: companyId,
        description: 'request_accepted',
      );

      await _articleHistoryDb.createArticleHistory(newLog);

      // ✅ Verify task was created
      final verifyTask =
          await Supabase.instance.client
              .from('tasks')
              .select()
              .eq('requestID', requestId)
              .maybeSingle();

      print(
        '🔍 Verification - Task in DB: ${verifyTask != null ? "FOUND (ID: ${verifyTask['idTask']})" : "NOT FOUND"}',
      );
      if (verifyTask != null) {
        print(
          '   Task details: workflowStatus=${verifyTask['workflowStatus']}, articleID=${verifyTask['articleID']}, companyID=${verifyTask['companyID']}',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Solicitud aprobada'),
            backgroundColor: Colors.green,
          ),
        );
        _loadNotifications(); // Refresh
      }
    } catch (e) {
      print('❌ Error accepting request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleReject(Map<String, dynamic> requestData) async {
    try {
      final requestId = requestData['idRequest'];

      // Update request status to "rechazado"
      await Supabase.instance.client
          .from('request')
          .update({
            'status': 'rechazado',
            'lastUpdate': DateTime.now().toIso8601String(),
          })
          .eq('idRequest', requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Solicitud rechazada'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadNotifications(); // Refresh
      }
    } catch (e) {
      print('❌ Error rejecting request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min';
    } else {
      return 'Ahora';
    }
  }

  String _formatTime(String timeStr) {
    try {
      // Parse time string "HH:MM:SS" or "HH:MM"
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1].padLeft(2, '0');
        return '$hour:$minute';
      }
      return timeStr;
    } catch (e) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D8A8A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notificaciones',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2D8A8A)),
              )
              : (_pendingRequests.isEmpty && _assignedTasks.isEmpty)
              ? _buildEmptyState()
              : RefreshIndicator(
                onRefresh: () async {
                  await _loadNotifications();
                },
                color: const Color(0xFF2D8A8A),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // "Hoy" header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hoy',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D8A8A),
                            ),
                          ),
                          Text(
                            'Tienes ${_pendingRequests.length + _assignedTasks.length} ${(_pendingRequests.length + _assignedTasks.length) == 1 ? 'notificación' : 'notificaciones'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ✅ Assigned tasks notifications (employee assigned)
                    ..._assignedTasks.map(
                      (task) => _buildAssignedTaskCard(task),
                    ),
                    // Pending requests notifications
                    ..._pendingRequests.map(
                      (request) => _buildNotificationCard(request),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadNotifications();
      },
      color: const Color(0xFF2D8A8A),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'No tienes notificaciones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Las solicitudes de empresas aparecerán aquí',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> request) {
    final company = request['company'] as Map<String, dynamic>?;
    final article = request['article'] as Map<String, dynamic>?;
    final companyLogo = request['companyLogo'] as Multimedia?;
    final requestDate =
        request['requestDate'] != null
            ? DateTime.parse(request['requestDate']).toLocal()
            : DateTime.now();

    final companyName = company?['nameCompany'] ?? 'Empresa';
    final articleName = article?['name'] ?? 'Artículo';
    final timeAgo = _getTimeAgo(requestDate);
    final scheduledDay = request['scheduledDay'] as String?;
    final scheduledStartTime = request['scheduledStartTime'] as String?;

    // Format the scheduled day to show day name and date
    String? formattedScheduledDay;
    if (scheduledDay != null) {
      try {
        final date = DateTime.parse(scheduledDay);
        final dayNames = [
          'lunes',
          'martes',
          'miércoles',
          'jueves',
          'viernes',
          'sábado',
          'domingo',
        ];
        final dayName = dayNames[date.weekday - 1];
        formattedScheduledDay = '$dayName ${date.day}';
      } catch (e) {
        // If it's not a date, use as is (fallback for old format)
        formattedScheduledDay = scheduledDay;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Company logo + Name + Time
            Row(
              children: [
                // Company logo with rating
                Column(
                  children: [
                    // ✅ Company rating above logo
                    if (request['companyRating'] != null &&
                        request['companyRating'] > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              (request['companyRating'] as double)
                                  .toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Company logo
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D8A8A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        image:
                            companyLogo?.url != null
                                ? DecorationImage(
                                  image: NetworkImage(companyLogo!.url!),
                                  fit: BoxFit.cover,
                                )
                                : null,
                      ),
                      child:
                          companyLogo?.url == null
                              ? const Icon(
                                Icons.business,
                                color: Color(0xFF2D8A8A),
                                size: 24,
                              )
                              : null,
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Company name and time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Nueva Solicitud',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D8A8A),
                              ),
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Request message with schedule
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: companyName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D8A8A),
                    ),
                  ),
                  const TextSpan(text: ' quiere recoger tu: '),
                  TextSpan(
                    text: '"$articleName"',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (formattedScheduledDay != null &&
                      scheduledStartTime != null) ...[
                    const TextSpan(text: ' el '),
                    TextSpan(
                      text: formattedScheduledDay,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D8A8A),
                      ),
                    ),
                    const TextSpan(text: ' a las '),
                    TextSpan(
                      text: _formatTime(scheduledStartTime),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D8A8A),
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                // Reject button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleReject(request),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[400]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Rechazar',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Accept button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAccept(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D8A8A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Aceptar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Build notification card for assigned tasks (employee assigned to collect)
  Widget _buildAssignedTaskCard(Map<String, dynamic> task) {
    final article = task['article'] as Map<String, dynamic>?;
    final employee = task['employee'] as Map<String, dynamic>?;
    final employeeUser = employee?['user'] as Map<String, dynamic>?;
    final request = task['request'] as Map<String, dynamic>?;

    final lastUpdate =
        task['lastUpdate'] != null
            ? DateTime.parse(task['lastUpdate']).toLocal()
            : DateTime.now();

    final articleName = article?['name'] ?? 'Artículo';
    final employeeName = employeeUser?['names'] ?? 'Empleado';
    final timeAgo = _getTimeAgo(lastUpdate);
    final scheduledDay = request?['scheduledDay'] as String?;
    final scheduledStartTime = request?['scheduledStartTime'] as String?;

    // Format the scheduled day to show day name and date
    String? formattedScheduledDay;
    if (scheduledDay != null) {
      try {
        final date = DateTime.parse(scheduledDay);
        final dayNames = [
          'lunes',
          'martes',
          'miércoles',
          'jueves',
          'viernes',
          'sábado',
          'domingo',
        ];
        final dayName = dayNames[date.weekday - 1];
        formattedScheduledDay = '$dayName ${date.day}';
      } catch (e) {
        formattedScheduledDay = scheduledDay;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_pin_circle,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Empleado Asignado',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Tu reciclaje será recogido',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    timeAgo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Message
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: employeeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const TextSpan(text: ' recogerá tu: '),
                  TextSpan(
                    text: '"$articleName"',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (formattedScheduledDay != null &&
                      scheduledStartTime != null) ...[
                    const TextSpan(text: ' el '),
                    TextSpan(
                      text: formattedScheduledDay,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const TextSpan(text: ' a las '),
                    TextSpan(
                      text: _formatTime(scheduledStartTime),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
