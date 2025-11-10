import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/screen/distribuidor/detail_recycle_screen.dart';
import 'package:reciclaje_app/model/recycling_items.dart';
import 'package:reciclaje_app/utils/category_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🔔 Employee Notifications Screen
/// Shows tasks with "asignado" status with article name and scheduled date/time
class EmployeeNotificationsScreen extends StatefulWidget {
  const EmployeeNotificationsScreen({super.key});

  @override
  State<EmployeeNotificationsScreen> createState() => _EmployeeNotificationsScreenState();
}

class _EmployeeNotificationsScreenState extends State<EmployeeNotificationsScreen> {
  final _authService = AuthService();
  final _usersDatabase = UsersDatabase();

  List<Map<String, dynamic>> _notifications = [];
  int? _employeeId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadEmployeeId();
    await _loadNotifications();
  }

  Future<void> _loadEmployeeId() async {
    try {
      final email = _authService.getCurrentUserEmail();
      if (email == null) throw Exception('No user email found');

      final user = await _usersDatabase.getUserByEmail(email);
      if (user == null) throw Exception('User not found');

      final employeeData = await Supabase.instance.client
          .from('employees')
          .select('idEmployee')
          .eq('userID', user.id!)
          .maybeSingle();

      if (employeeData == null) throw Exception('Employee not found');

      setState(() {
        _employeeId = employeeData['idEmployee'] as int;
      });
    } catch (e) {
      print('❌ Error loading employee ID: $e');
    }
  }

  Future<void> _loadNotifications() async {
    if (_employeeId == null) return;

    setState(() => _isLoading = true);

    try {
      // Get tasks with "asignado" status
      final tasks = await Supabase.instance.client
          .from('tasks')
          .select('''
            idTask,
            employeeID,
            articleID,
            assignedDate,
            workflowStatus,
            article:articleID(
              idArticle,
              name,
              description,
              address,
              lat,
              lng,
              categoryID,
              userID,
              condition,
              category:categoryID(name),
              user:userID(names, email)
            ),
            request:requestID(
              scheduledDay,
              scheduledTime
            )
          ''')
          .eq('employeeID', _employeeId!)
          .eq('workflowStatus', 'asignado')
          .order('assignedDate', ascending: false);

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(tasks);
          _isLoading = false;
        });

        print('✅ Loaded ${_notifications.length} notifications for employee $_employeeId');
      }
    } catch (e) {
      print('❌ Error loading notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadNotifications,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2D8A8A),
              ),
            )
          : _notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationsList(),
    );
  }

  Widget _buildNotificationsList() {
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: const Color(0xFF2D8A8A),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Tienes ${_notifications.length} ${_notifications.length == 1 ? 'notificación' : 'notificaciones'}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ..._notifications.map((notification) => _buildNotificationCard(notification)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay notificaciones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Las nuevas tareas asignadas aparecerán aquí',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final article = notification['article'] as Map<String, dynamic>?;
    final request = notification['request'] as Map<String, dynamic>?;
    final category = article?['category'] as Map<String, dynamic>?;
    final assignedDate = notification['assignedDate'] as String?;

    // Parse data
    final articleName = article?['name'] ?? 'Artículo sin nombre';
    final categoryName = category?['name'] ?? 'Sin categoría';

    // Scheduled date and time
    final scheduledDay = request?['scheduledDay'] as String?;
    final scheduledTime = request?['scheduledTime'] as String?;

    // Parse assigned date for time ago
    DateTime assignedDateTime = DateTime.now();
    try {
      if (assignedDate != null) {
        assignedDateTime = DateTime.parse(assignedDate);
      }
    } catch (e) {
      print('Error parsing assigned date: $e');
    }

    final timeAgo = _getTimeAgo(assignedDateTime);

    // Format scheduled info
    String scheduledInfo = 'No programado';
    if (scheduledDay != null && scheduledTime != null) {
      scheduledInfo = '$scheduledDay a las $scheduledTime';
    } else if (scheduledDay != null) {
      scheduledInfo = scheduledDay;
    } else if (scheduledTime != null) {
      scheduledInfo = 'a las $scheduledTime';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToDetails(notification),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar + Title + Time
            Row(
              children: [
                // Category icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D8A8A).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    CategoryUtils.getCategoryIcon(categoryName),
                    color: const Color(0xFF2D8A8A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Objeto asignado',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange,
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
                      const SizedBox(height: 4),
                      Text(
                        '"$articleName".',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Entrega: $scheduledInfo',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _navigateToDetails(Map<String, dynamic> notification) {
    final article = notification['article'] as Map<String, dynamic>?;
    if (article == null) return;

    final category = article['category'] as Map<String, dynamic>?;
    final user = article['user'] as Map<String, dynamic>?;

    // Convert to RecyclingItem
    final item = RecyclingItem(
      id: article['idArticle'] as int,
      title: article['name'] as String,
      description: article['description'] as String?,
      address: article['address'] as String,
      latitude: (article['lat'] as num).toDouble(),
      longitude: (article['lng'] as num).toDouble(),
      categoryID: article['categoryID'] as int?,
      categoryName: category?['name'] as String? ?? 'Sin categoría',
      ownerUserId: article['userID'] as int?,
      userName: user?['names'] as String? ?? 'Usuario',
      userEmail: user?['email'] as String? ?? '',
      availableDays: article['availableDays'] as String? ?? 'No especificado',
      availableTimeStart: article['availableTimeStart'] as String? ?? '00:00',
      availableTimeEnd: article['availableTimeEnd'] as String? ?? '23:59',
      condition: article['condition'] as String?,
      createdAt: DateTime.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailRecycleScreen(item: item),
      ),
    ).then((_) {
      // Refresh notifications when returning
      _loadNotifications();
    });
  }
}
