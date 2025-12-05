import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/model/users.dart';
import 'package:reciclaje_app/model/recycling_items.dart';
import 'package:reciclaje_app/screen/distribuidor/login_screen.dart';
import 'package:reciclaje_app/screen/distribuidor/detail_recycle_screen.dart';
import 'package:reciclaje_app/screen/employee/edit_employee_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  final AuthService authService = AuthService();
  final UsersDatabase usersDatabase = UsersDatabase();
  final MediaDatabase mediaDatabase = MediaDatabase();

  Users? currentUser;
  Multimedia? currentUserAvatar; // User's avatar from multimedia table
  List<Map<String, dynamic>> allTasks = []; // All tasks (completed, en_proceso, asignado)
  List<Map<String, dynamic>> filteredTasks = []; // Filtered and sorted tasks
  bool isLoading = true;
  double employeeRating = 0.0; // ✅ Average rating for employee
  int totalReviews = 0; // ✅ Total number of reviews received
  
  // Stats data for Objetos card
  Map<String, int> taskStats = {
    'asignado': 0,
    'enProceso': 0,
    'recogidos': 0,
  };
  
  // Filter and search state
  String searchQuery = '';
  bool sortAscending = false; // false = newest first, true = oldest first
  Set<String> selectedStatusFilters = {'completado'}; // Default: show completed only

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    // ✅ Clear cached data to prevent memory leaks
    allTasks.clear();
    filteredTasks.clear();
    super.dispose();
  }

  /// Refresh all data
  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      await _loadUserData();
    } catch (e) {
      print('❌ Error refreshing data: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);

    try {
      final email = authService.getCurrentUserEmail();
      if (email != null) {
        // Fetch user details
        currentUser = await usersDatabase.getUserByEmail(email);
        
        print('✅ Loaded employee: ${currentUser?.names} (${currentUser?.email})');
        
        // Load user avatar from multimedia table
        if (currentUser?.id != null) {
          final userRole = currentUser!.role?.toLowerCase() ?? 'user';
          
          // ✅ Try new path first (with role)
          String avatarPattern = 'users/$userRole/${currentUser!.id}/avatars/';
          currentUserAvatar = await mediaDatabase.getMainPhotoByPattern(avatarPattern);
          
          // ✅ If not found, try old path (without role) for backward compatibility
          if (currentUserAvatar == null) {
            avatarPattern = 'users/${currentUser!.id}/avatars/';
            currentUserAvatar = await mediaDatabase.getMainPhotoByPattern(avatarPattern);
            print('⚠️ Avatar found using old path structure: $avatarPattern');
          }
          
          print('📸 User avatar: ${currentUserAvatar?.url ?? "No avatar"}');
        }
        
        // ✅ Show UI first
        if (mounted) {
          setState(() => isLoading = false);
        }
        
        // ✅ Defer heavy data loading to background
        if (currentUser?.id != null) {
          // First, get employee ID from employees table
          final employeeData = await Supabase.instance.client
              .from('employees')
              .select('idEmployee')
              .eq('userID', currentUser!.id!)
              .maybeSingle();

          if (employeeData != null) {
            final employeeId = employeeData['idEmployee'] as int;
            
            // ✅ Load tasks and rating in background
            Future.delayed(const Duration(milliseconds: 200), () async {
              if (!mounted) return;
              
              // Get all tasks (completed, en_proceso, asignado)
              await _loadAllTasks(employeeId);
              
              // ✅ Load employee rating
              await _loadEmployeeRating();
            });
          }
        }
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// Load all tasks (completed, en_proceso, asignado) with review information
  Future<void> _loadAllTasks(int employeeId) async {
    try {
      // Get all tasks for this employee (not just completed)
      final tasks = await Supabase.instance.client
          .from('tasks')
          .select('''
            idTask,
            workflowStatus,
            lastUpdate,
            article:articleID(
              idArticle,
              name,
              description,
              address,
              lat,
              lng,
              condition,
              userID,
              lastUpdate,
              categoryID,
              category:categoryID(name),
              user:userID(names, email)
            ),
            request:requestID(
              scheduledDay,
              scheduledStartTime
            )
          ''')
          .eq('employeeID', employeeId)
          .inFilter('workflowStatus', ['completado', 'en_proceso'])
          .order('lastUpdate', ascending: false);

      if (!mounted) return;
      
      // ✅ Calculate task statistics
      // Note: 'asignado' and 'enProceso' both count 'en_proceso' tasks
      // since tasks go directly to 'en_proceso' when assigned
      int enProcesoCount = tasks.where((task) => task['workflowStatus'] == 'en_proceso').length;
      int recogidos = tasks.where((task) => task['workflowStatus'] == 'completado').length;
      
      setState(() {
        taskStats = {
          'asignado': enProcesoCount, // Same as en_proceso
          'enProceso': enProcesoCount, // Tasks currently being worked on
          'recogidos': recogidos,
        };
      });
      
      print('📦 Found ${tasks.length} tasks to load progressively');

      // ✅ First pass: Show tasks with basic info (no photos/reviews yet)
      final tasksWithBasicInfo = tasks.map((task) => {
        ...task,
        'reviews': <dynamic>[], // Empty initially
        'photo': null, // No photo initially
      }).toList();
      
      if (mounted) {
        setState(() {
          allTasks = tasksWithBasicInfo;
        });
        _applyFilters();
        print('✅ Showing ${tasks.length} tasks with basic info');
      }

      // ✅ Second pass: Load photos and reviews in batches of 3 (max 4 articles)
      const batchSize = 3;
      final maxArticles = 4;
      final articlesToLoad = tasks.take(maxArticles).toList();
      
      for (var i = 0; i < articlesToLoad.length; i += batchSize) {
        if (!mounted) break;
        
        final batch = articlesToLoad.skip(i).take(batchSize);
        
        for (var task in batch) {
          if (!mounted) break;
          
          final articleId = task['article']?['idArticle'];
          if (articleId != null) {
            // Load reviews
            final reviews = await Supabase.instance.client
                .from('reviews')
                .select('''
                  idReview,
                  starID,
                  comment,
                  senderID,
                  receiverID,
                  created_at,
                  sender:senderID(names),
                  receiver:receiverID(names)
                ''')
                .eq('articleID', articleId)
                .order('created_at', ascending: false);
            
            // Load article photo
            final urlPattern = 'articles/$articleId';
            final photo = await mediaDatabase.getMainPhotoByPattern(urlPattern);
            
            // Update this specific task with photo and reviews
            if (mounted) {
              final taskIndex = allTasks.indexWhere((t) => t['idTask'] == task['idTask']);
              if (taskIndex != -1) {
                setState(() {
                  allTasks[taskIndex] = {
                    ...allTasks[taskIndex],
                    'reviews': reviews,
                    'photo': photo,
                  };
                });
              }
            }
          }
        }
        
        // Apply filters after each batch
        if (mounted) {
          _applyFilters();
          print('✅ Loaded photos/reviews for ${(i + batchSize).clamp(0, tasks.length)}/${tasks.length} tasks');
        }
        
        // Small delay between batches
        if (i + batchSize < tasks.length) {
          await Future.delayed(const Duration(milliseconds: 150));
        }
      }

      print('✅ Finished loading all task details');
    } catch (e) {
      print('❌ Error loading tasks: $e');
    }
  }

  /// Load employee rating from reviews
  Future<void> _loadEmployeeRating() async {
    if (currentUser?.id == null) return;
    
    try {
      // Get all reviews where current user is the receiver (employee)
      final reviews = await Supabase.instance.client
          .from('reviews')
          .select('starID')
          .eq('receiverID', currentUser!.id!)
          .eq('state', 1); // Only active reviews
      
      if (reviews.isEmpty) {
        if (mounted) {
          setState(() {
            employeeRating = 0.0;
            totalReviews = 0;
          });
        }
        return;
      }
      
      // Calculate average rating
      int totalStars = 0;
      for (var review in reviews) {
        totalStars += (review['starID'] as int? ?? 0);
      }
      
      final avgRating = totalStars / reviews.length;
      
      if (mounted) {
        setState(() {
          employeeRating = avgRating;
          totalReviews = reviews.length;
        });
      }
      
      print('⭐ Employee rating: ${avgRating.toStringAsFixed(1)} stars (${reviews.length} reviews)');
    } catch (e) {
      print('❌ Error loading employee rating: $e');
    }
  }

  /// Generate dynamic label based on selected filters
  String _getFilteredTasksLabel() {
    final count = filteredTasks.length;
    
    // If multiple filters selected, show generic label
    if (selectedStatusFilters.length > 1) {
      return 'Total $count publicaciones';
    }
    
    // Single filter - show specific label
    if (selectedStatusFilters.isEmpty) {
      return 'Total $count publicaciones';
    }
    
    final filter = selectedStatusFilters.first;
    switch (filter) {
      case 'completado':
        return 'Total $count recogidos';
      case 'en_proceso':
        return 'Total $count en procesos';
      case 'asignado':
        return 'Total $count asignados';
      default:
        return 'Total $count publicaciones';
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(allTasks);
    
    // Filter by selected statuses
    if (selectedStatusFilters.isNotEmpty) {
      filtered = filtered.where((task) {
        final status = task['workflowStatus'] as String?;
        // Map 'asignado' filter to 'en_proceso' status
        if (selectedStatusFilters.contains('asignado') && status == 'en_proceso') {
          return true;
        }
        // Map 'en_proceso' filter to 'en_proceso' status
        if (selectedStatusFilters.contains('en_proceso') && status == 'en_proceso') {
          return true;
        }
        return selectedStatusFilters.contains(status);
      }).toList();
    }
    
    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((task) {
        final article = task['article'] as Map<String, dynamic>?;
        final name = article?['name']?.toString().toLowerCase() ?? '';
        final description = article?['description']?.toString().toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();
        return name.contains(query) || description.contains(query);
      }).toList();
    }
    
    // Sort by date
    filtered.sort((a, b) {
      final aDate = DateTime.tryParse(a['lastUpdate'] ?? '') ?? DateTime.now();
      final bDate = DateTime.tryParse(b['lastUpdate'] ?? '') ?? DateTime.now();
      
      if (sortAscending) {
        return aDate.compareTo(bDate); // Oldest first
      } else {
        return bDate.compareTo(aDate); // Newest first
      }
    });
    
    setState(() {
      filteredTasks = filtered;
    });
  }

  /// Navigate to task detail screen
  Future<void> _navigateToTaskDetail(Map<String, dynamic> task) async {
    final article = task['article'] as Map<String, dynamic>?;
    if (article == null) return;

    // Get category name
    final categoryName = article['category']?['name'] as String? ?? 'Sin categoría';

    // Get owner data from article (already loaded in the query)
    final user = article['user'] as Map<String, dynamic>?;
    final userName = user?['names'] as String? ?? 'Desconocido';
    final userEmail = user?['email'] as String? ?? '';
    final ownerId = article['userID'] as int? ?? 0;

    // Convert task article to RecyclingItem for detail screen
    final recyclingItem = RecyclingItem(
      id: article['idArticle'] as int,
      title: article['name'] ?? '',
      description: article['description'] ?? '',
      condition: article['condition'] ?? '',
      categoryName: categoryName,
      categoryID: article['categoryID'] as int?,
      ownerUserId: ownerId,
      userName: userName,
      userEmail: userEmail,
      latitude: (article['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (article['lng'] as num?)?.toDouble() ?? 0.0,
      address: article['address'] ?? '',
      createdAt: article['lastUpdate'] != null
          ? DateTime.parse(article['lastUpdate'])
          : DateTime.now(),
      workflowStatus: task['workflowStatus'] as String? ?? 'en_proceso',
      availableDays: null,
      availableTimeStart: null,
      availableTimeEnd: null,
    );

    // Navigate to detail screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailRecycleScreen(item: recyclingItem),
      ),
    );

    // Refresh data if changes were made
    if (result == true) {
      await _loadUserData();
    }
  }

  Future<Map<String, String>> _getUserData(int userId) async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('names, email')
          .eq('idUsers', userId)
          .single();
      return {
        'names': response['names'] as String? ?? 'Desconocido',
        'email': response['email'] as String? ?? '',
      };
    } catch (e) {
      return {'names': 'Desconocido', 'email': ''};
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
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditEmployeeProfileScreen(user: currentUser!),
      ),
    );
    
    if (result == true) {
      await _loadUserData();
    }
  }

  void _showStatusFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtrar por estado',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D8A8A),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip('Completado', 'completado', Colors.green, setModalState),
                  _buildFilterChip('En Proceso', 'en_proceso', Colors.orange, setModalState),
                  _buildFilterChip('Asignado', 'asignado', Colors.blue, setModalState),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedStatusFilters = {'completado'}; // Reset to default
                      });
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('Limpiar filtros'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D8A8A),
                    ),
                    child: const Text(
                      'Aplicar',
                      style: TextStyle(color: Colors.white),
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

  Widget _buildFilterChip(String label, String value, Color color, StateSetter setModalState) {
    final isSelected = selectedStatusFilters.contains(value);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() {
          if (selected) {
            selectedStatusFilters.add(value);
          } else {
            selectedStatusFilters.remove(value);
          }
        });
        setState(() {});
        _applyFilters();
      },
      selectedColor: color.withOpacity(0.3),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
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
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFF2D8A8A),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : RefreshIndicator(
                color: const Color(0xFF2D8A8A),
                onRefresh: _refreshData,
                child: CustomScrollView(
                  slivers: [
                    // Profile header as collapsible app bar
                    SliverAppBar(
                      expandedHeight: 180,
                      floating: false,
                      pinned: false,
                      backgroundColor: const Color(0xFF2D8A8A),
                      flexibleSpace: FlexibleSpaceBar(
                        background: Column(
                          children: [
                            // Profile header section
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
                              child: Row(
                                children: [
                                  // Avatar on the left
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.white,
                                    child: currentUserAvatar?.url != null
                                        ? ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl: currentUserAvatar!.url!,
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => const Center(
                                                child: CircularProgressIndicator(
                                                  color: Color(0xFF2D8A8A),
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                              errorWidget: (context, url, error) => const Icon(
                                                Icons.person,
                                                size: 60,
                                                color: Color(0xFF2D8A8A),
                                              ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person,
                                            size: 60,
                                            color: Color(0xFF2D8A8A),
                                          ),
                                  ),
                                  const SizedBox(width: 20),
                                  // Name and role on the right
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // User name with menu icon
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                currentUser?.names ?? 'Empleado',
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
                                        // User role
                                        const Text(
                                          'Empleado',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        // ✅ Rating display
                                        if (totalReviews > 0) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                color: Colors.amber,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                employeeRating.toStringAsFixed(1),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '($totalReviews ${totalReviews == 1 ? 'reseña' : 'reseñas'})',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    // Objetos card - inline between header and tasks section
                    SliverToBoxAdapter(
                      child: Transform.translate(
                        offset: const Offset(0, 55),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 25),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
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
                                    _buildObjectStatItem(
                                      '${taskStats['asignado']}',
                                      'Asignado',
                                      Colors.blue,
                                    ),
                                    _buildObjectStatItem(
                                      '${taskStats['enProceso']}',
                                      'En Procesos',
                                      Colors.orange,
                                    ),
                                    _buildObjectStatItem(
                                      '${taskStats['recogidos']}',
                                      'Recogidos',
                                      Colors.green,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // White tasks section with rounded top
                    SliverToBoxAdapter(
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
                            const SizedBox(height: 80),
                            const Padding(
                              padding: EdgeInsets.fromLTRB(25, 0, 25, 10),
                              child: Text(
                                'Mis Tareas',
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
                                onChanged: (value) {
                                  setState(() {
                                    searchQuery = value;
                                  });
                                  _applyFilters();
                                },
                                decoration: InputDecoration(
                                  hintText: 'Buscar',
                                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                  suffixIcon: searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, color: Colors.grey),
                                          onPressed: () {
                                            setState(() {
                                              searchQuery = '';
                                            });
                                            _applyFilters();
                                          },
                                        )
                                      : null,
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
                            // Tasks count and controls
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 25),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _getFilteredTasksLabel(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      // Sort button
                                      IconButton(
                                        icon: Icon(
                                          sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                          color: const Color(0xFF2D8A8A),
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            sortAscending = !sortAscending;
                                          });
                                          _applyFilters();
                                        },
                                        tooltip: sortAscending ? 'Más antiguos primero' : 'Más recientes primero',
                                      ),
                                      // Filter button
                                      IconButton(
                                        icon: Icon(
                                          Icons.filter_list,
                                          color: selectedStatusFilters.length == 1 && selectedStatusFilters.contains('completado')
                                              ? Colors.grey[600]
                                              : const Color(0xFF2D8A8A),
                                          size: 20,
                                        ),
                                        onPressed: _showStatusFilterDialog,
                                        tooltip: 'Filtrar por estado',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 15),
                          ],
                        ),
                      ),
                    ),
                    // Grid of tasks as sliver
                    _buildTasksSliverGrid(),
                  ],
                ),
              ),
      ),
    );
  }

  // Build tasks grid as sliver
  Widget _buildTasksSliverGrid() {
    if (filteredTasks.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 60,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 12),
              Text(
                searchQuery.isNotEmpty
                    ? 'No se encontraron tareas'
                    : 'No hay tareas disponibles',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final task = filteredTasks[index];
            return GestureDetector(
              onTap: () async {
                // Navigate to detail screen instead of showing dialog
                await _navigateToTaskDetail(task);
              },
              child: _buildTaskCard(task),
            );
          },
          childCount: filteredTasks.length,
        ),
      ),
    );
  }

  // Show task detail dialog
  void _showTaskDetail(Map<String, dynamic> task) {
    final article = task['article'] as Map<String, dynamic>?;
    final reviews = task['reviews'] as List<dynamic>?;
    final request = task['request'] as Map<String, dynamic>?;
    final photo = task['photo'] as Multimedia?;
    final workflowStatus = task['workflowStatus'] as String?;
    
    final articleName = article?['name'] ?? 'Sin título';
    final scheduledDay = request?['scheduledDay'] ?? 'No especificado';
    final scheduledTime = request?['scheduledStartTime'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          articleName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Article photo
              if (photo?.url != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: photo!.url!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 40,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Scheduled date
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '$scheduledDay a las ${_formatTime(scheduledTime)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Reviews section (only for completed tasks)
              if (workflowStatus == 'completado') ...[
                const Text(
                  'Calificaciones:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D8A8A),
                  ),
                ),
                const SizedBox(height: 12),
                if (reviews != null && reviews.isNotEmpty)
                ...reviews.map((review) {
                  final sender = review['sender'] as Map<String, dynamic>?;
                  final senderName = sender?['names'] ?? 'Usuario';
                  final rating = review['starID'] as int? ?? 0;
                  final comment = review['comment'] as String?;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              senderName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < rating ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 16,
                                );
                              }),
                            ),
                          ],
                        ),
                        if (comment != null && comment.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            comment,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList()
              else
                Text(
                  'No hay calificaciones disponibles',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // Format time from database
  String _formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        final minute = parts[1].padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        return '$hour:$minute $period';
      }
    } catch (e) {
      // Return as is if parsing fails
    }
    return timeStr;
  }

  // Build task card
  Widget _buildTaskCard(Map<String, dynamic> task) {
    final article = task['article'] as Map<String, dynamic>?;
    final photo = task['photo'] as Multimedia?;
    final category = article?['category'] as Map<String, dynamic>?;
    final reviews = task['reviews'] as List<dynamic>?;
    final workflowStatus = task['workflowStatus'] as String?;
    
    final articleName = article?['name'] ?? 'Sin título';
    final categoryName = category?['name'] ?? '';
    final imageUrl = photo?.url;
    
    // Determine badge color and text based on status
    Color badgeColor;
    String badgeText;
    switch (workflowStatus) {
      case 'completado':
        badgeColor = Colors.green;
        badgeText = 'Completado';
        break;
      case 'en_proceso':
        badgeColor = Colors.orange;
        badgeText = 'En Proceso';
        break;
      case 'asignado':
        badgeColor = Colors.blue;
        badgeText = 'Asignado';
        break;
      default:
        badgeColor = Colors.grey;
        badgeText = 'Pendiente';
    }
    
    // Calculate average rating (only for completed tasks)
    double avgRating = 0;
    if (workflowStatus == 'completado' && reviews != null && reviews.isNotEmpty) {
      final totalStars = reviews.fold<int>(0, (sum, review) => sum + (review['starID'] as int? ?? 0));
      avgRating = totalStars / reviews.length;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: imageUrl == null ? Colors.grey[300] : null,
      ),
      child: Stack(
        children: [
          // Image
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 40,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          // Gradient overlay
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
          // Status badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Article info at bottom
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  articleName,
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
                const SizedBox(height: 4),
                if (categoryName.isNotEmpty)
                  Text(
                    categoryName,
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
                if (avgRating > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Show icon if no image
          if (imageUrl == null)
            Center(
              child: Icon(
                Icons.check_circle,
                size: 40,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildObjectStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

