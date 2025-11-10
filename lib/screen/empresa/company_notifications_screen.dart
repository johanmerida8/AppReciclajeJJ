import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/screen/distribuidor/detail_recycle_screen.dart';
import 'package:reciclaje_app/services/recycling_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ✅ Notifications screen for companies (admin-empresa)
/// Shows approved/rejected requests from distributors
class CompanyNotificationsScreen extends StatefulWidget {
  const CompanyNotificationsScreen({super.key});

  @override
  State<CompanyNotificationsScreen> createState() => _CompanyNotificationsScreenState();
}

class _CompanyNotificationsScreenState extends State<CompanyNotificationsScreen> {
  final _authService = AuthService();
  final _usersDatabase = UsersDatabase();
  final _mediaDatabase = MediaDatabase();
  final _dataService = RecyclingDataService();

  List<Map<String, dynamic>> _allNotifications = []; // ✅ Combined list
  bool _isLoading = true;
  int? _currentUserId;
  int? _companyId;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      // Get current user ID and company ID
      final email = _authService.getCurrentUserEmail();
      print('🔍 Current user email: $email');
      
      if (email != null) {
        final currentUser = await _usersDatabase.getUserByEmail(email);
        _currentUserId = currentUser?.id;
        print('🔍 Current user ID: $_currentUserId');

        if (_currentUserId != null) {
          // Try to get company ID from empresa table (if user is admin-empresa)
          var companyData = await Supabase.instance.client
              .from('company')
              .select('idCompany')
              .eq('adminUserID', _currentUserId!)
              .limit(1)
              .maybeSingle();

          print('🔍 Company data (from empresa): $companyData');

          // If not found in empresa table, try employees table (if user is employee)
          if (companyData == null) {
            companyData = await Supabase.instance.client
                .from('employees')
                .select('companyID')
                .eq('userID', _currentUserId!)
                .limit(1)
                .maybeSingle();
            
            print('🔍 Company data (from employees): $companyData');
            
            if (companyData != null) {
              _companyId = companyData['companyID'] as int?;
            }
          } else {
            _companyId = companyData['idCompany'] as int?;
          }

          print('🔍 Final Company ID: $_companyId');

          if (_companyId != null) {
            // Load all notifications (approved and rejected combined)
            await _loadAllNotifications();
          } else {
            print('❌ No company found for this user');
          }
        }
      }
    } catch (e) {
      print('❌ Error loading notifications: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// ✅ Load all notifications (approved and rejected) in one list
  Future<void> _loadAllNotifications() async {
    if (_companyId == null) {
      print('❌ Company ID is null, cannot load notifications');
      return;
    }

    try {
      print('🔍 Loading notifications for company ID: $_companyId');
      
      // Get both approved and rejected requests in one query
      final requests = await Supabase.instance.client
          .from('request')
          .select('''
            *,
            article:articleID (
              idArticle,
              name,
              userID
            )
          ''')
          .eq('companyID', _companyId!)
          .inFilter('status', ['aprobado', 'rechazado']) // ✅ Get both statuses
          .order('lastUpdate', ascending: false);

      print('🔍 Found ${requests.length} requests');
      print('🔍 Requests data: $requests');

      // Load distributor info and article photos for each request
      for (var request in requests) {
        final article = request['article'] as Map<String, dynamic>?;
        print('🔍 Processing request: ${request['idRequest']}, article: $article');
        
        if (article != null) {
          final userId = article['userID'];
          print('🔍 Loading distributor info for user ID: $userId');
          
          // Load distributor info
          final distributor = await _usersDatabase.getUserById(userId);
          request['distributorName'] = distributor?.names ?? 'Usuario';
          print('🔍 Distributor name: ${request['distributorName']}');
          
          // Load distributor avatar
          final userRole = distributor?.role?.toLowerCase() ?? 'user';
          final avatarPattern = 'users/$userRole/$userId/avatars/';
          print('🔍 Loading avatar with pattern: $avatarPattern');
          final avatar = await _mediaDatabase.getMainPhotoByPattern(avatarPattern);
          request['distributorAvatar'] = avatar;
          print('🔍 Avatar loaded: ${avatar?.url}');

          // Load article photo
          final articleId = article['idArticle'];
          final articlePhotoPattern = 'articles/$articleId';
          print('🔍 Loading article photo with pattern: $articlePhotoPattern');
          final articlePhoto = await _mediaDatabase.getMainPhotoByPattern(articlePhotoPattern);
          request['articlePhoto'] = articlePhoto;
          print('🔍 Article photo loaded: ${articlePhoto?.url}');
        }
      }

      print('🔍 Setting ${requests.length} notifications to state');
      setState(() {
        _allNotifications = requests;
      });
    } catch (e) {
      print('❌ Error loading notifications: $e');
      print('❌ Error stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _navigateToArticleDetails(Map<String, dynamic> requestData) async {
    try {
      final article = requestData['article'] as Map<String, dynamic>?;
      if (article == null) return;

      final articleId = article['idArticle'];
      
      // Load full article details
      final items = await _dataService.loadRecyclingItems();
      final fullArticle = items.firstWhere((item) => item.id == articleId);

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailRecycleScreen(item: fullArticle),
          ),
        );
        // Refresh after returning
        _loadNotifications();
      }
    } catch (e) {
      print('❌ Error navigating to article: $e');
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
          : _allNotifications.isEmpty
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
            'Tienes ${_allNotifications.length} ${_allNotifications.length == 1 ? 'notificación' : 'notificaciones'}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ..._allNotifications.map((request) => _buildNotificationCard(request)),
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
            'Las solicitudes aprobadas o rechazadas aparecerán aquí',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// ✅ Universal notification card (handles both approved and rejected)
  Widget _buildNotificationCard(Map<String, dynamic> request) {
    final status = request['status'] as String?;
    
    if (status == 'aprobado') {
      return _buildApprovedNotificationCard(request);
    } else if (status == 'rechazado') {
      return _buildRejectedNotificationCard(request);
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildApprovedNotificationCard(Map<String, dynamic> request) {
    final article = request['article'] as Map<String, dynamic>?;
    final articlePhoto = request['articlePhoto'] as Multimedia?;
    final lastUpdate = request['lastUpdate'] != null 
        ? DateTime.parse(request['lastUpdate']) 
        : DateTime.now();

    final distributorName = request['distributorName'] ?? 'Distribuidor';
    final articleName = article?['name'] ?? 'Artículo';
    final timeAgo = _getTimeAgo(lastUpdate);

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
            // Header: Status icon + Time
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '¡Solicitud Aprobada!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
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
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Article preview with photo
            Row(
              children: [
                // Article photo
                if (articlePhoto?.url != null)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(articlePhoto!.url!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.recycling,
                      color: Colors.grey[400],
                      size: 30,
                    ),
                  ),
                const SizedBox(width: 12),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text: distributorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D8A8A),
                              ),
                            ),
                            const TextSpan(text: ' aprobó tu solicitud para: '),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '"$articleName"',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToArticleDetails(request),
                icon: const Icon(Icons.assignment_ind, size: 18),
                label: const Text('Asignar Empleado'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D8A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedNotificationCard(Map<String, dynamic> request) {
    final article = request['article'] as Map<String, dynamic>?;
    final articlePhoto = request['articlePhoto'] as Multimedia?;
    final lastUpdate = request['lastUpdate'] != null 
        ? DateTime.parse(request['lastUpdate']) 
        : DateTime.now();

    final distributorName = request['distributorName'] ?? 'Distribuidor';
    final articleName = article?['name'] ?? 'Artículo';
    final timeAgo = _getTimeAgo(lastUpdate);

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Status icon + Time
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.cancel,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Solicitud Rechazada',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
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
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Article preview with photo
            Row(
              children: [
                // Article photo
                if (articlePhoto?.url != null)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(articlePhoto!.url!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.recycling,
                      color: Colors.grey[400],
                      size: 30,
                    ),
                  ),
                const SizedBox(width: 12),
                // Text content
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: distributorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D8A8A),
                          ),
                        ),
                        const TextSpan(text: ' rechazó tu solicitud para: '),
                        TextSpan(
                          text: '"$articleName"',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
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
