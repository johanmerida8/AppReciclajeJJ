import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/database/article_database.dart';
import 'package:reciclaje_app/database/company_database.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/article.dart';
import 'package:reciclaje_app/model/company.dart';
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/model/users.dart';
import 'package:reciclaje_app/screen/distribuidor/edit_profile_screen.dart';
import 'package:reciclaje_app/screen/distribuidor/login_screen.dart';
import 'package:reciclaje_app/screen/empresa/edit_company_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final authService = AuthService();
  final usersDatabase = UsersDatabase();
  final companyDatabase = CompanyDatabase();
  final articleDatabase = ArticleDatabase();
  final mediaDatabase = MediaDatabase();

  Users? currentUser;
  Multimedia? currentUserAvatar; // Admin user's avatar from multimedia table
  Multimedia? companyAvatar; // Company's avatar/logo from multimedia table
  Company? currentCompany;
  List<Article> companyArticles = [];
  Map<int, Multimedia?> articlePhotos = {};
  Map<int, String> categoryNames = {};
  bool isLoading = true;
  bool isViewingCompanyProfile = true; // Toggle between company and admin profile

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
        
        // Fetch company details first (needed for correct paths)
        if (currentUser?.id != null) {
          // Get company where this user is admin
          final companies = await Supabase.instance.client
              .from('company')
              .select()
              .eq('adminUserID', currentUser!.id!)
              .limit(1);
          
          if (companies.isNotEmpty) {
            currentCompany = Company.fromMap(companies.first);
            
            // Load admin user avatar from multimedia table (role-based path)
            if (currentUser?.id != null && currentUser?.role != null) {
              final userRole = currentUser!.role!.toLowerCase();
              final userId = currentUser!.id!;
              final avatarPattern = 'users/$userRole/$userId/avatars/';
              currentUserAvatar = await mediaDatabase.getMainPhotoByPattern(avatarPattern);
              print('📸 Admin user avatar pattern: $avatarPattern');
              print('📸 Admin user avatar: ${currentUserAvatar?.url ?? "No avatar"}');
            }
            
            // Load company logo from multimedia table (company-based path)
            if (currentCompany?.companyId != null && currentCompany?.nameCompany != null) {
              final companyName = currentCompany!.nameCompany!;
              final companyId = currentCompany!.companyId!;
              final companyAvatarPattern = 'empresa/$companyName/$companyId/avatar/';
              companyAvatar = await mediaDatabase.getMainPhotoByPattern(companyAvatarPattern);
              print('🏢 Company logo pattern: $companyAvatarPattern');
              print('🏢 Company logo: ${companyAvatar?.url ?? "No company logo"}');
            }
            
            // Fetch company's articles
            companyArticles = await articleDatabase.getArticlesByUserId(currentUser!.id!);
            
            // Load photos and category names for each article
            for (var article in companyArticles) {
              if (article.id != null) {
                final photo = await mediaDatabase.getMainPhotoByPattern('articles/${article.id}');
                articlePhotos[article.id!] = photo;
                
                // Fetch category name
                if (article.categoryID != null) {
                  final category = await Supabase.instance.client
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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

  void _navigateToEditProfile() async {
    if (currentUser == null) return;
    
    if (isViewingCompanyProfile) {
      // Edit company profile
      _navigateToEditCompanyProfile();
    } else {
      // Edit admin user profile
      _navigateToEditAdminProfile();
    }
  }

  void _navigateToEditAdminProfile() async {
    if (currentUser == null) return;
    
    // Navigate to edit profile screen (same as distribuidor)
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

  void _navigateToEditCompanyProfile() async {
    if (isViewingCompanyProfile) {
      // Editing company profile
      if (currentCompany == null) return;
      
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditCompanyProfileScreen(
            company: currentCompany,
            adminUser: null,
            isEditingCompany: true,
          ),
        ),
      );
      
      if (result == true) {
        await _loadUserData();
      }
    } else {
      // Editing admin personal profile
      if (currentUser == null) return;
      
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditCompanyProfileScreen(
            company: null,
            adminUser: currentUser,
            isEditingCompany: false,
          ),
        ),
      );
      
      if (result == true) {
        await _loadUserData();
      }
    }
  }

  void _toggleProfileView() {
    setState(() {
      isViewingCompanyProfile = !isViewingCompanyProfile;
    });
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
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
    // Determine what to display based on profile view
    final displayAvatar = isViewingCompanyProfile ? companyAvatar : currentUserAvatar;
    final displayName = isViewingCompanyProfile 
        ? (currentCompany?.nameCompany ?? 'Empresa') 
        : (currentUser?.names ?? 'Usuario');
    final displayRole = isViewingCompanyProfile ? 'Empresa' : 'Administrador de Empresa';
    
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFF2D8A8A),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  // Profile header section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(25, 20, 25, 30),
                    child: Row(
                      children: [
                        // Avatar on the left (company or admin based on toggle)
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          backgroundImage: displayAvatar?.url != null
                              ? NetworkImage(displayAvatar!.url!)
                              : null,
                          child: displayAvatar?.url == null
                              ? Icon(
                                  isViewingCompanyProfile ? Icons.business : Icons.person,
                                  size: 60,
                                  color: const Color(0xFF2D8A8A),
                                )
                              : null,
                        ),
                        const SizedBox(width: 20),
                        // Name and role on the right
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Profile name with switcher and menu
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayName,
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
                                  // Profile switcher button
                                  GestureDetector(
                                    onTap: _toggleProfileView,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.3),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isViewingCompanyProfile 
                                            ? Icons.person_outline 
                                            : Icons.business_outlined,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
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
                              // Role display
                              Text(
                                displayRole,
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
                  // Objetos stats - only show in Admin view
                  if (!isViewingCompanyProfile)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Objetos',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D8A8A),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildObjectStatItem('8', 'En espera', Colors.orange),
                              _buildObjectStatItem('8', 'Sin Asignar', Colors.purple),
                              _buildObjectStatItem('8', 'En Proceso', Colors.amber),
                              _buildObjectStatItem('8', 'Entregado', Colors.teal),
                              _buildObjectStatItem('8', 'Vencido', Colors.red),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 25),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Buscar',
                                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Articles count
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 25),
                            child: Text(
                              'Total ${companyArticles.length} publicaciones',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          // Grid of articles
                          Expanded(
                            child: companyArticles.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
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
                                    padding: const EdgeInsets.symmetric(horizontal: 15),
                                    child: GridView.builder(
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 10,
                                        crossAxisSpacing: 10,
                                        childAspectRatio: 0.85,
                                      ),
                                      itemCount: companyArticles.length,
                                      itemBuilder: (context, index) {
                                        final article = companyArticles[index];
                                        return GestureDetector(
                                          onTap: () {
                                            // TODO: Navigate to detail
                                          },
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

  Widget _buildObjectStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
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
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              )
            : null,
        color: imageUrl == null ? Colors.grey[300] : null,
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.5, 1.0],
              ),
            ),
          ),
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
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 2,
                      ),
                    ],
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
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
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


