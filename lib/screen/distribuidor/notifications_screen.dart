import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/database/task_database.dart'; // ✅ Add task database
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/model/task.dart'; // ✅ Add task model
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _authService = AuthService();
  final _usersDatabase = UsersDatabase();
  final _mediaDatabase = MediaDatabase();
  final _taskDatabase = TaskDatabase(); // ✅ Add task database

  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
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
          final myRequests = requests.where((req) {
            final article = req['article'] as Map<String, dynamic>?;
            return article != null && article['userID'] == _currentUserId;
          }).toList();

          // Load company logos for each request
          for (var request in myRequests) {
            final company = request['company'] as Map<String, dynamic>?;
            if (company != null) {
              final companyId = company['idCompany'];
              // Use only companyId pattern to avoid issues with special characters
              final logoPattern = 'empresa/$companyId/avatar/';
              final logo = await _mediaDatabase.getMainPhotoByPattern(logoPattern);
              request['companyLogo'] = logo;
            }
          }

          setState(() {
            _pendingRequests = myRequests;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading notifications: $e');
    } finally {
      setState(() => _isLoading = false);
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

      // Update request status to "aprobado"
      await Supabase.instance.client
          .from('request')
          .update({
            'status': 'aprobado',
            'lastUpdate': DateTime.now().toIso8601String(),
          })
          .eq('idRequest', requestId);

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

      print('✅ Task created with "sin_asignar" status - Article: $articleId, Company: $companyId, Request: $requestId');

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
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
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
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2D8A8A),
              ),
            )
          : _pendingRequests.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
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
                              'Tienes ${_pendingRequests.length} ${_pendingRequests.length == 1 ? 'notificación' : 'notificaciones'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Notifications list
                      ..._pendingRequests.map((request) => _buildNotificationCard(request)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
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
    final requestDate = request['requestDate'] != null 
        ? DateTime.parse(request['requestDate']) 
        : DateTime.now();

    final companyName = company?['nameCompany'] ?? 'Empresa';
    final articleName = article?['name'] ?? 'Artículo';
    final timeAgo = _getTimeAgo(requestDate);
    final scheduledDay = request['scheduledDay'] as String?;
    final scheduledTime = request['scheduledTime'] as String?;

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
                // Company logo
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D8A8A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    image: companyLogo?.url != null
                        ? DecorationImage(
                            image: NetworkImage(companyLogo!.url!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: companyLogo?.url == null
                      ? const Icon(
                          Icons.business,
                          color: Color(0xFF2D8A8A),
                          size: 24,
                        )
                      : null,
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
                  if (scheduledDay != null && scheduledTime != null) ...[
                    const TextSpan(text: ' el '),
                    TextSpan(
                      text: scheduledDay,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D8A8A),
                      ),
                    ),
                    const TextSpan(text: ' a las '),
                    TextSpan(
                      text: _formatTime(scheduledTime),
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
}
