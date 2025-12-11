import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/components/admin/history_screen.dart';
import 'package:reciclaje_app/database/admin/ArticleHistory_db.dart';
import 'package:reciclaje_app/database/article_database.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/article.dart';
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/model/recycling_items.dart';
import 'package:reciclaje_app/model/users.dart';
import 'package:reciclaje_app/screen/distribuidor/detail_recycle_screen.dart';
import 'package:reciclaje_app/screen/distribuidor/edit_profile_screen.dart';
import 'package:reciclaje_app/screen/distribuidor/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reciclaje_app/database/admin/ArticleHistory_db.dart';
import 'package:reciclaje_app/model/admin/article_history_model.dart';

class ProfileAdmin extends StatefulWidget {
  const ProfileAdmin({super.key});

  @override
  State<ProfileAdmin> createState() => _ProfileAdminState();
}

class _ProfileAdminState extends State<ProfileAdmin> {
  final authService = AuthService();
  final usersDatabase = UsersDatabase();
  final articleDatabase = ArticleDatabase();
  final mediaDatabase = MediaDatabase();

  Users? currentUser;
  Multimedia? currentUserAvatar; // User's avatar from multimedia table
  List<Article> userArticles = [];
  Map<int, Multimedia?> articlePhotos = {}; // Cache for article photos
  Map<int, String> categoryNames = {}; // Cache for category names
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  final articleHistoryDB = ArticleHistoryDB();

 void _showHistoryBottomSheet(Article article) async {
  final history = await articleHistoryDB.getArticleHistory(article.id!);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (_) => Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 45,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            "Historial del artículo",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D8A8A)),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder(
              future: Future.wait(history.map(_buildHistoryText)),
              builder: (_, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final items = snap.data as List<String>;
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final text = items[i];
                    final date = history[i].formattedDate;
                    return ListTile(
                      leading: const Icon(Icons.history, color: Colors.teal),
                      title: Text(text),
                      subtitle: Text(date),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
Future<String> _getUserName(int userId) async {
  try {
    final res = await Supabase.instance.client
        .from('users')
        .select('names')
        .eq('idUser', userId)
        .single();
    return res['names'] ?? 'Usuario';
  } catch (_) {
    return 'Usuario';
  }
}

Future<String> _getCompanyName(int companyId) async {
  try {
    final res = await Supabase.instance.client
        .from('company')
        .select('nameCompany')
        .eq('idCompany', companyId)
        .single();
    return res['nameCompany'] ?? 'Empresa';
  } catch (_) {
    return 'Empresa';
  }
}


  Future<String> _buildHistoryText(ArticleHistoryModel h) async {
  final actorName = await _getUserName(h.actorId);
  String? targetName;
  if (h.targetID != null) {
    targetName = await _getCompanyName(h.targetID!);
  }

  switch (h.description) {
    case 'published':
      return "$actorName publicó el artículo";
    case 'request_sent':
      return targetName != null
          ? "$targetName envió una solicitud a $actorName"
          : "$actorName envió una solicitud";
    case 'request_accepted':
      return targetName != null
          ? "$actorName aceptó la solicitud de $targetName"
          : "$actorName aceptó una solicitud";
    case 'delivered':
      return targetName != null
          ? "$actorName entregó el artículo a $targetName"
          : "$actorName entregó el artículo";
    default:
      return "$actorName realizó una acción";
  }
}


  Future<void> _loadUserData() async {
    setState(() => isLoading = true);

    try {
      final email = authService.getCurrentUserEmail();
      if (email != null) {
        // Fetch user details
        currentUser = await usersDatabase.getUserByEmail(email);

        print('✅ Loaded user: ${currentUser?.names} (${currentUser?.email})');
        print('✅ User role from DB: ${currentUser?.role}');

        // Load user avatar from multimedia table
        if (currentUser?.id != null) {
          final avatarPattern = 'users/${currentUser!.id}/avatars/';
          currentUserAvatar = await mediaDatabase.getMainPhotoByPattern(
            avatarPattern,
          );
          print('📸 User avatar: ${currentUserAvatar?.url ?? "No avatar"}');
        }

        // Fetch user's articles
        if (currentUser?.id != null) {
          userArticles = await articleDatabase.getAllArticles();

          // Load photos and category names for each article
          for (var article in userArticles) {
            if (article.id != null) {
              print(
                '🔍 Buscando foto principal para artículo ID: ${article.id}',
              );
              final urlPattern = 'articles/${article.id}';
              final photo = await mediaDatabase.getMainPhotoByPattern(
                urlPattern,
              );
              articlePhotos[article.id!] = photo;

              // Fetch category name
              if (article.categoryID != null) {
                final category =
                    await Supabase.instance.client
                        .from('category')
                        .select('name')
                        .eq('idCategory', article.categoryID!)
                        .single();
                categoryNames[article.id!] = category['name'] as String;
              }
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _logout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cerrar Sesión'),
            content: const Text('¿Estás seguro que deseas cerrar sesión?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  // Navigate to edit profile screen
  void _navigateToEditProfile() async {
    if (currentUser == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(user: currentUser!),
      ),
    );

    // Refresh data if profile was updated
    if (result == true) {
      _loadUserData();
    }
  }

  // Convert Article to RecyclingItem for DetailRecycleScreen
  Future<RecyclingItem?> _convertArticleToRecyclingItem(Article article) async {
    try {
      // Fetch deliver info
      // final deliver = await Supabase.instance.client
      //     .from('deliver')
      //     .select('address, lat, lng')
      //     .eq('idDeliver', article.deliverID!)
      //     .single();

      return RecyclingItem(
        id: article.id!,
        title: article.name ?? '',
        // deliverID: article.deliverID,
        description: article.description,
        categoryID: article.categoryID,
        categoryName: categoryNames[article.id] ?? '',
        condition: article.condition,
        ownerUserId: article.userId,
        userName: currentUser?.names ?? '',
        userEmail: currentUser?.email ?? '',
        address: article.address!,
        latitude: article.lat!,
        longitude: article.lng!,
        // latitude: (deliver['lat'] as num).toDouble(),
        // longitude: (deliver['lng'] as num).toDouble(),
        // address: deliver['address'] as String,
        availableDays: article.availableDays ?? '',
        availableTimeStart: article.availableTimeStart ?? '',
        availableTimeEnd: article.availableTimeEnd ?? '',
        createdAt: article.lastUpdate ?? DateTime.now(),
      );
    } catch (e) {
      print('❌ Error converting article to recycling item: $e');
      return null;
    }
  }

  // Navigate to detail screen
  void _navigateToDetail(Article article) async {
    final recyclingItem = await _convertArticleToRecyclingItem(article);
    if (recyclingItem != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailRecycleScreen(item: recyclingItem),
        ),
      ).then((_) {
        // Refresh data when coming back
        _loadUserData();
      });
    }
  }

  // Show profile menu with edit profile and logout options (from edit icon)
  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit, color: Color(0xFF2D8A8A)),
                  title: const Text('Editar perfil'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToEditProfile();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Cerrar sesión',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFF2D8A8A),
        body:
            isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
                : Column(
                  children: [
                    // Profile header section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(25, 20, 25, 30),
                      child: Row(
                        children: [
                          // Avatar on the left
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            backgroundImage:
                                currentUserAvatar?.url != null
                                    ? NetworkImage(currentUserAvatar!.url!)
                                    : null,
                            child:
                                currentUserAvatar?.url == null
                                    ? const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Color(0xFF2D8A8A),
                                    )
                                    : null,
                          ),
                          const SizedBox(width: 20),
                          // Name and role on the right
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // User name with edit icon
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        currentUser?.names ?? 'Usuario',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _showProfileMenu,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.more_vert,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // User role (not "Usuario" badge)
                                Text(
                                  currentUser?.role?.toLowerCase() ==
                                          'distribuidor'
                                      ? 'Distribuidor'
                                      : currentUser?.role?.toUpperCase() ??
                                          'USUARIO',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Stats row
                    // Container(
                    //   margin: const EdgeInsets.symmetric(horizontal: 25),
                    //   padding: const EdgeInsets.all(20),
                    //   decoration: BoxDecoration(
                    //     color: Colors.white,
                    //     borderRadius: BorderRadius.circular(15),
                    //   ),
                    //   child: Row(
                    //     mainAxisAlignment: MainAxisAlignment.spaceAround,
                    //     children: [
                    //       _buildStatItem(
                    //         '${userArticles.length}',
                    //         'Publicados',
                    //         Colors.blue,
                    //       ),
                    //       Container(width: 1, height: 40, color: Colors.grey[300]),
                    //       _buildStatItem(
                    //         '${userArticles.where((a) => a.workflowStatus == 'en_proceso').length}',
                    //         'En Procesos',
                    //         Colors.orange,
                    //       ),
                    //       Container(width: 1, height: 40, color: Colors.grey[300]),
                    //       _buildStatItem(
                    //         '${userArticles.where((a) => a.workflowStatus == 'completado').length}',
                    //         'Recogidos',
                    //         Colors.green,
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    const SizedBox(height: 20),
                    // Publications section
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(25, 25, 25, 10),
                              child: Text(
                                'Publicaciones',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D8A8A),
                                ),
                              ),
                            ),
                            // Search bar
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                              ),
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Buscar',
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Colors.grey,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Filter options
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                              ),
                              // child: Row(
                              //   children: [
                              //     Text(
                              //       'por fecha',
                              //       style: TextStyle(
                              //         fontSize: 14,
                              //         color: Colors.grey[600],
                              //       ),
                              //     ),
                              //     const SizedBox(width: 8),
                              //     Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                              //     const Spacer(),
                              //     // 3-dot menu button
                              //     IconButton(
                              //       icon: Icon(Icons.more_vert, size: 24, color: Colors.grey[600]),
                              //       onPressed: _showSettingsMenu,
                              //       tooltip: 'Más opciones',
                              //       padding: EdgeInsets.zero,
                              //       constraints: const BoxConstraints(),
                              //     ),
                              //     const SizedBox(width: 16),
                              //     Icon(Icons.sort, size: 20, color: Colors.grey[600]),
                              //     const SizedBox(width: 16),
                              //     Icon(Icons.grid_view, size: 20, color: Colors.grey[600]),
                              //   ],
                              // ),
                            ),
                            const SizedBox(height: 10),
                            // Articles count
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                              ),
                              child: Text(
                                'Total ${userArticles.length} finalizadas',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            // Grid of articles
                            Expanded(
                              child:
                                  userArticles.isEmpty
                                      ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.inventory_2_outlined,
                                              size: 80,
                                              color: Colors.grey[300],
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No tienes publicaciones',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      : Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 15,
                                        ),
                                        child: GridView.builder(
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 2,
                                                mainAxisSpacing: 10,
                                                crossAxisSpacing: 10,
                                                childAspectRatio: 0.85,
                                              ),
                                          itemCount: userArticles.length,
                                          itemBuilder: (context, index) {
                                            final article = userArticles[index];
                                            return GestureDetector(
                                              onTap:
                                                  () => _navigateToDetail(
                                                    article,
                                                  ),
                                              onLongPress: () {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (_) => HistoryBottomSheet(
      articleId: article.id!,
      articleName: article.name ?? 'Artículo',
    ),
  );
},
// ✅ Aquí mostramos el historial
                                              child: _buildArticleCard(article),
                                            );
                                          },
                                        ),
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

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildArticleCard(Article article) {
    // Simple status based on article state
    Color statusColor;
    String statusText;

    if (article.state == 1) {
      statusColor = Colors.green;
      statusText = 'Activo';
    } else if (article.state == 0) {
      statusColor = Colors.grey;
      statusText = 'Inactivo';
    } else {
      statusColor = Colors.orange;
      statusText = 'Desconocido';
    }

    final photo = articlePhotos[article.id];
    final imageUrl = photo?.url;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image:
            imageUrl != null
                ? DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                )
                : null,
        color: imageUrl == null ? Colors.grey[300] : null,
      ),
      child: Stack(
        children: [
          // Gradient overlay for better text visibility
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                stops: const [0.5, 1.0],
              ),
            ),
          ),
          // Status badge at top right
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Article title at bottom
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.name ?? 'Sin título',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (article.condition != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    article.condition!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Show icon if no image
          if (imageUrl == null)
            Center(
              child: Icon(
                Icons.image_not_supported,
                size: 40,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }
}
