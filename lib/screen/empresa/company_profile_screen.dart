import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/database/article_database.dart';
import 'package:reciclaje_app/database/company_database.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/article.dart';
import 'package:reciclaje_app/model/company.dart';
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/model/users.dart';
import 'package:reciclaje_app/model/recycling_items.dart';
import 'package:reciclaje_app/screen/distribuidor/edit_profile_screen.dart';
import 'package:reciclaje_app/screen/distribuidor/login_screen.dart';
import 'package:reciclaje_app/screen/distribuidor/detail_recycle_screen.dart';
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

  // ✅ New: Store article cards with their specific request/task info
  List<Map<String, dynamic>> articleCards =
      []; // Each card has: article, status, type (task/request), id
  List<Map<String, dynamic>> filteredArticleCards = []; // Filtered cards

  List<Map<String, dynamic>> completedTasks =
      []; // Completed tasks with reviews for empresa view
  Map<int, Multimedia?> articlePhotos = {};
  Map<int, String> categoryNames = {};
  bool isLoading = true;
  bool isLoadingArticles = true; // ✅ Track article loading state
  bool isViewingCompanyProfile =
      true; // Toggle between company and admin profile

  // Filter and search state
  String searchQuery = '';
  bool sortAscending =
      false; // ✅ Default: false = descending (latest/newest first), true = ascending (oldest first)
  Set<String> selectedStatusFilters = {}; // For admin view filtering

  // Pagination state
  final ScrollController _scrollController = ScrollController();
  int _currentArticlePage = 1;
  final int _articlesPerPage =
      4; // ✅ Load 4 articles at a time for faster loading
  bool _isLoadingMoreArticles = false;
  bool _hasMoreArticles = true;

  // Stats data
  Map<String, int> articleStats = {
    'enEspera': 0,
    'sinAsignar': 0,
    'enProceso': 0,
    'recibido': 0,
    'vencido': 0,
  };
  double companyRating = 0.0;
  int totalReviews = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onArticleScroll);
    _loadUserData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // ✅ Clear cached data to prevent memory leaks
    articlePhotos.clear();
    categoryNames.clear();
    articleCards.clear();
    filteredArticleCards.clear();
    completedTasks.clear();
    super.dispose();
  }

  void _onArticleScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMoreArticles && _hasMoreArticles && !isLoadingArticles) {
        _loadMoreArticles();
      }
    }
  }

  Future<void> _loadMoreArticles() async {
    if (_isLoadingMoreArticles || !_hasMoreArticles) return;

    setState(() {
      _isLoadingMoreArticles = true;
    });

    // Simulate loading delay
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _currentArticlePage++;
      _isLoadingMoreArticles = false;
    });
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
              currentUserAvatar = await mediaDatabase.getMainPhotoByPattern(
                avatarPattern,
              );
              print('📸 Admin user avatar pattern: $avatarPattern');
              print(
                '📸 Admin user avatar: ${currentUserAvatar?.url ?? "No avatar"}',
              );
            }

            // Fetch company logo from multimedia table (company-based path)
            if (currentCompany?.companyId != null) {
              final companyId = currentCompany!.companyId!;
              // Use only companyId pattern to avoid issues with special characters in company name
              final companyAvatarPattern = 'empresa/$companyId/avatar/';
              companyAvatar = await mediaDatabase.getMainPhotoByPattern(
                companyAvatarPattern,
              );
              print('🏢 Company logo pattern: $companyAvatarPattern');
              print(
                '🏢 Company logo: ${companyAvatar?.url ?? "No company logo"}',
              );
            }

            // Load company rating from all employee reviews (lightweight)
            await _loadCompanyRating();

            // ✅ Show profile UI immediately after loading avatars and rating
            if (mounted) {
              setState(() => isLoading = false);
            }

            // ✅ Load heavy data in background after UI is shown
            Future.delayed(const Duration(milliseconds: 100), () async {
              if (!mounted) return;

              // ✅ Set loading articles state
              if (mounted) {
                setState(() => isLoadingArticles = true);
              }

              await _loadArticleStats();
              await _loadArticlesFromTasks();
              _applyFilters();

              // ✅ Load article photos and categories progressively
              await _loadArticlePhotosProgressively();

              // ✅ Load completed tasks with reviews last
              await _loadCompletedTasks();

              // ✅ Mark article loading as complete
              if (mounted) {
                setState(() => isLoadingArticles = false);
              }
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

  /// Navigate to article detail screen
  // Future<void> _navigateToArticleDetail(Article article) async {
  //   // Need to load additional data for RecyclingItem
  //   final categoryName = article.categoryID != null
  //       ? await _getCategoryName(article.categoryID!)
  //       : 'Sin categoría';

  //   final ownerData = article.userId != null
  //       ? await _getUserData(article.userId!)
  //       : {'name': 'Desconocido', 'email': ''};

  //   // Convert Article to RecyclingItem for detail screen
  //   final recyclingItem = RecyclingItem(
  //     id: article.id!,
  //     title: article.name ?? '',
  //     description: article.description,
  //     condition: article.condition,
  //     categoryName: categoryName,
  //     categoryID: article.categoryID,
  //     ownerUserId: article.userId ?? 0,
  //     userName: ownerData['name']!,
  //     userEmail: ownerData['email']!,
  //     latitude: article.lat ?? 0.0,
  //     longitude: article.lng ?? 0.0,
  //     address: article.address ?? '',
  //     createdAt: article.lastUpdate ?? DateTime.now(),
  //     workflowStatus: articleStatuses[article.id!],
  //     availableDays: null,
  //     availableTimeStart: null,
  //     availableTimeEnd: null,
  //   );

  //   // Navigate to detail screen
  //   final result = await Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => DetailRecycleScreen(item: recyclingItem),
  //     ),
  //   );

  //   // Refresh data if changes were made
  //   if (result == true) {
  //     await _refreshData();
  //   }
  // }

  Future<RecyclingItem?> _getRecyclingItemFromCard(
    Map<String, dynamic> card,
  ) async {
    try {
      final article = card['article'] as Article?;
      if (article == null) return null;

      final cardStatus = card['status'] as String?;

      final categoryName =
          article.categoryID != null
              ? await _getCategoryName(article.categoryID!)
              : 'Sin categoría';

      final ownerData =
          article.userId != null
              ? await _getUserData(article.userId!)
              : {'names': 'Desconocido', 'email': ''};

      return RecyclingItem(
        id: article.id!,
        title: article.name ?? '',
        description: article.description,
        condition: article.condition,
        categoryName: categoryName,
        categoryID: article.categoryID,
        ownerUserId: article.userId ?? 0,
        userName: ownerData['names']!,
        userEmail: ownerData['email']!,
        latitude: article.lat ?? 0.0,
        longitude: article.lng ?? 0.0,
        address: article.address ?? '',
        createdAt: article.lastUpdate ?? DateTime.now(),
        workflowStatus: cardStatus,
        availableDays: null,
        availableTimeStart: null,
        availableTimeEnd: null,
      );
    } catch (e) {
      print('❌ Error converting card to RecyclingItem: $e');
      return null;
    }
  }

  void _navigateToDetail(Map<String, dynamic> card) async {
    final recyclingItem = await _getRecyclingItemFromCard(card);
    if (recyclingItem == null) return;

    final article = card['article'] as Article?;
    if (article == null) return;

    // Check if this is a completed task for empresa view
    Map<String, dynamic>? taskData;
    if (isViewingCompanyProfile) {
      // Find matching completed task
      try {
        final matchingTask = completedTasks.firstWhere(
          (task) => task['article']?['idArticle'] == article.id,
        );
        taskData = matchingTask;
      } catch (e) {
        // No matching task found
      }
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => DetailRecycleScreen(
              item: recyclingItem,
              isEmpresaView: isViewingCompanyProfile, // Pass empresa view flag
              taskData: taskData, // Pass task data with reviews
              cardType:
                  card['type'] as String?, // ✅ Pass card type (task/request)
              cardStatus:
                  card['status']
                      as String?, // ✅ Pass card status (vencido, en_espera, etc.)
            ),
      ),
    );

    // Refresh data if changes were made
    if (result == true) {
      await _refreshData();
    }
  }

  Future<String> _getCategoryName(int categoryID) async {
    try {
      final response =
          await Supabase.instance.client
              .from('category')
              .select('name')
              .eq('idCategory', categoryID)
              .single();
      return response['name'] as String? ?? 'Sin categoría';
    } catch (e) {
      return 'Sin categoría';
    }
  }

  Future<Map<String, String>> _getUserData(int userId) async {
    try {
      final response =
          await Supabase.instance.client
              .from('users')
              .select('names, email')
              .eq('idUser', userId)
              .single();
      return {
        'names': response['names'] as String? ?? 'Desconocido',
        'email': response['email'] as String? ?? '',
      };
    } catch (e) {
      return {'names': 'Desconocido', 'email': ''};
    }
  }

  Future<void> _loadArticleStats() async {
    if (currentUser?.id == null) return;

    try {
      // Get company ID first
      final companies = await Supabase.instance.client
          .from('company')
          .select('idCompany')
          .eq('adminUserID', currentUser!.id!)
          .limit(1);

      if (companies.isEmpty) return;

      final companyId = companies.first['idCompany'] as int;
      print('📊 Loading stats for companyID: $companyId');

      // Load all requests for this company
      final requests = await Supabase.instance.client
          .from('request')
          .select('*')
          .eq('companyID', companyId)
          .eq('state', 1);

      print('📨 Found ${requests.length} requests');

      // Load all tasks for this company
      final tasks = await Supabase.instance.client
          .from('tasks')
          .select('*')
          .eq('companyID', companyId)
          .eq('state', 1);

      print('✅ Found ${tasks.length} tasks');

      // Reset stats
      articleStats = {
        'enEspera': 0,
        'sinAsignar': 0,
        'enProceso': 0,
        'recibido': 0,
        'vencido': 0,
      };

      // Create a set of article IDs that have tasks
      final articleIdsWithTasks = <int>{};

      // Count tasks by their workflow status
      for (var task in tasks) {
        final articleId = task['articleID'] as int?;
        if (articleId == null) continue;

        articleIdsWithTasks.add(articleId);
        final workflowStatus = task['workflowStatus'] as String?;
        final employeeId = task['employeeID'] as int?;

        print(
          '   📋 Task for article $articleId: workflowStatus=$workflowStatus, employeeID=$employeeId',
        );

        if (workflowStatus == 'completado') {
          articleStats['recibido'] = articleStats['recibido']! + 1;
        } else if (workflowStatus == 'vencido') {
          // ✅ Task is overdue/expired
          articleStats['vencido'] = articleStats['vencido']! + 1;
        } else if (workflowStatus == 'en_proceso' ||
            workflowStatus == 'asignado') {
          articleStats['enProceso'] = articleStats['enProceso']! + 1;
        } else if (employeeId == null) {
          // Task exists but no employee assigned
          articleStats['sinAsignar'] = articleStats['sinAsignar']! + 1;
        } else {
          // Has employee but unknown status - treat as en_proceso
          articleStats['enProceso'] = articleStats['enProceso']! + 1;
        }
      }

      // Count requests (can exist alongside tasks, e.g., new pendiente request after vencido task)
      for (var request in requests) {
        final articleId = request['articleID'] as int?;
        if (articleId == null) continue;

        final requestStatus = request['status'] as String?;
        print('   📨 Request for article $articleId: status=$requestStatus');

        // ✅ Check if this article has ANY task (completed, vencido, or active)
        bool hasAnyTask = articleIdsWithTasks.contains(articleId);
        String? taskStatus;

        if (hasAnyTask) {
          // Find the task for this article
          final articleTask = tasks.firstWhere(
            (t) => t['articleID'] == articleId,
            orElse: () => {},
          );
          taskStatus = articleTask['workflowStatus'] as String?;
        }

        if (requestStatus == 'aprobado') {
          // ✅ Only count as "Sin Asignar" if:
          // 1. No task exists at all (never assigned), OR
          // 2. Task exists but is "sin_asignar" status (distributor accepted but hasn't assigned employee yet)
          if (!hasAnyTask || taskStatus == 'sin_asignar') {
            articleStats['sinAsignar'] = articleStats['sinAsignar']! + 1;
          }
          // ✅ If task is vencido/completado/en_proceso, the request is ALREADY processed - don't count it
        } else if (requestStatus == 'pendiente') {
          // ✅ Always count pendiente requests (waiting for distributor approval)
          // Can exist even if there's a vencido task (distributor needs to approve new request)
          articleStats['enEspera'] = articleStats['enEspera']! + 1;
        }
        // Note: 'rechazado' requests are not counted
      }

      print('📊 Final stats: $articleStats');
    } catch (e) {
      print('❌ Error loading article stats: $e');
    }
  }

  Future<void> _loadArticlesFromTasks() async {
    if (currentUser?.id == null) return;

    try {
      // Get company ID
      final companies = await Supabase.instance.client
          .from('company')
          .select('idCompany')
          .eq('adminUserID', currentUser!.id!)
          .limit(1);

      if (companies.isEmpty) return;
      final companyId = companies.first['idCompany'] as int;

      // Load all tasks with full data
      final tasks = await Supabase.instance.client
          .from('tasks')
          .select('idTask, articleID, workflowStatus, employeeID, lastUpdate')
          .eq('companyID', companyId)
          .eq('state', 1);

      // Load all requests with full data
      final requests = await Supabase.instance.client
          .from('request')
          .select('idRequest, articleID, status, requestDate')
          .eq('companyID', companyId)
          .eq('state', 1);

      // ✅ Create card objects for each task
      articleCards = [];
      Set<int> uniqueArticleIds = {};

      // Add task cards
      for (var task in tasks) {
        final articleId = task['articleID'] as int?;
        final workflowStatus = task['workflowStatus'] as String?;

        if (articleId != null && workflowStatus != null) {
          uniqueArticleIds.add(articleId);

          // Determine display status from workflowStatus
          String displayStatus;
          if (workflowStatus == 'completado') {
            displayStatus = 'recibido';
          } else if (workflowStatus == 'vencido') {
            displayStatus = 'vencido';
          } else if (workflowStatus == 'en_proceso' ||
              workflowStatus == 'asignado') {
            displayStatus = 'en_proceso';
          } else if (task['employeeID'] == null ||
              workflowStatus == 'sin_asignar') {
            displayStatus = 'sin_asignar';
          } else {
            displayStatus = 'en_proceso';
          }

          articleCards.add({
            'articleId': articleId,
            'type': 'task',
            'id': task['idTask'],
            'status': displayStatus,
            'rawStatus': workflowStatus,
            'date': task['lastUpdate'],
          });
        }
      }

      // Add request cards (only pendiente, or aprobado without task)
      for (var request in requests) {
        final articleId = request['articleID'] as int?;
        final requestStatus = request['status'] as String?;

        if (articleId != null && requestStatus != null) {
          uniqueArticleIds.add(articleId);

          // Check if this article already has a task
          final hasTask = tasks.any((t) => t['articleID'] == articleId);

          if (requestStatus == 'pendiente') {
            // Always show pendiente requests (even with vencido task)
            articleCards.add({
              'articleId': articleId,
              'type': 'request',
              'id': request['idRequest'],
              'status': 'en_espera',
              'rawStatus': requestStatus,
              'date': request['requestDate'],
            });
          } else if (requestStatus == 'aprobado' && !hasTask) {
            // Only show aprobado if no task exists yet
            articleCards.add({
              'articleId': articleId,
              'type': 'request',
              'id': request['idRequest'],
              'status': 'sin_asignar',
              'rawStatus': requestStatus,
              'date': request['requestDate'],
            });
          }
        }
      }

      if (uniqueArticleIds.isEmpty) {
        return;
      }

      print(
        '📦 Created ${articleCards.length} article cards from ${uniqueArticleIds.length} unique articles',
      );

      // Load article data for all unique IDs
      final articlesData = await Supabase.instance.client
          .from('article')
          .select()
          .inFilter('idArticle', uniqueArticleIds.toList())
          .eq('state', 1);

      // Map articles by ID for quick lookup
      final articlesMap = {
        for (var data in articlesData)
          data['idArticle'] as int: Article.fromMap(data),
      };

      // Attach article data to each card
      for (var card in articleCards) {
        final articleId = card['articleId'] as int;
        card['article'] = articlesMap[articleId];
      }

      print('✅ Loaded article data for ${articlesMap.length} articles');
    } catch (e) {
      print('❌ Error loading articles from tasks: $e');
    }
  }

  /// ✅ Load article photos and categories progressively in batches
  Future<void> _loadArticlePhotosProgressively() async {
    if (articleCards.isEmpty) return;

    print('📸 Loading article photos progressively...');

    // Get unique article IDs to avoid loading same photo multiple times
    final Set<int> loadedArticleIds = {};

    // ✅ Load in batches of 4 to match pagination (faster initial display)
    const batchSize = 4;
    for (var i = 0; i < articleCards.length; i += batchSize) {
      if (!mounted) break;

      final batch = articleCards.skip(i).take(batchSize);

      for (var card in batch) {
        final article = card['article'] as Article?;
        if (article?.id != null && !loadedArticleIds.contains(article!.id)) {
          loadedArticleIds.add(article.id!);

          // Load photo
          final photo = await mediaDatabase.getMainPhotoByPattern(
            'articles/${article.id}',
          );

          // Fetch category name
          String? categoryName;
          if (article.categoryID != null) {
            try {
              final category =
                  await Supabase.instance.client
                      .from('category')
                      .select('name')
                      .eq('idCategory', article.categoryID!)
                      .single();
              categoryName = category['name'] as String;
            } catch (e) {
              print('⚠️ Error loading category for article ${article.id}: $e');
            }
          }

          // Update UI with loaded data
          if (mounted) {
            setState(() {
              articlePhotos[article.id!] = photo;
              if (categoryName != null) {
                categoryNames[article.id!] = categoryName;
              }
            });
          }
        }
      }

      // Small delay between batches for smooth rendering
      if (i + batchSize < articleCards.length) {
        await Future.delayed(
          const Duration(milliseconds: 30),
        ); // ✅ Reduced delay for faster loading
      }
    }

    print('✅ Finished loading ${articlePhotos.length} article photos');
  }

  // ✅ Status is now determined when creating cards in _loadArticlesFromTasks()
  // No need for separate _loadArticleStatuses() method

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(articleCards);

    // Filter by view type
    if (isViewingCompanyProfile) {
      // Company view: only show completed/recibido articles
      filtered =
          filtered.where((card) {
            final status = card['status'] as String?;
            return status == 'recibido';
          }).toList();
    } else {
      // Admin view: filter by selected statuses (if any)
      if (selectedStatusFilters.isNotEmpty) {
        filtered =
            filtered.where((card) {
              final status = card['status'] as String?;
              return status != null && selectedStatusFilters.contains(status);
            }).toList();
      }
    }

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered =
          filtered.where((card) {
            final article = card['article'] as Article?;
            if (article == null) return false;
            final name = article.name?.toLowerCase() ?? '';
            final condition = article.condition?.toLowerCase() ?? '';
            final query = searchQuery.toLowerCase();
            return name.contains(query) || condition.contains(query);
          }).toList();
    }

    // Sort by date
    filtered.sort((a, b) {
      final dateA =
          DateTime.tryParse(a['date'] as String? ?? '') ?? DateTime(2000);
      final dateB =
          DateTime.tryParse(b['date'] as String? ?? '') ?? DateTime(2000);

      if (sortAscending) {
        return dateA.compareTo(dateB);
      } else {
        return dateB.compareTo(dateA);
      }
    });

    setState(() {
      filteredArticleCards = filtered;
    });
  }

  Future<void> _loadCompanyRating() async {
    if (currentCompany?.companyId == null) return;

    try {
      // Get all employees for this company
      final employees = await Supabase.instance.client
          .from('employees')
          .select('userID')
          .eq('companyID', currentCompany!.companyId!);

      if (employees.isEmpty) {
        companyRating = 0.0;
        totalReviews = 0;
        return;
      }

      // Get all employee user IDs
      final employeeUserIds = employees.map((e) => e['userID'] as int).toList();

      // Get all reviews for these employees
      final reviews = await Supabase.instance.client
          .from('reviews')
          .select('starID')
          .inFilter('receiverID', employeeUserIds)
          .eq('state', 1);

      if (reviews.isEmpty) {
        companyRating = 0.0;
        totalReviews = 0;
        return;
      }

      // Calculate average rating
      int totalStars = 0;
      for (var review in reviews) {
        totalStars += (review['starID'] as int? ?? 0);
      }

      totalReviews = reviews.length;
      companyRating = totalStars / totalReviews;

      print('⭐ Company rating: $companyRating from $totalReviews reviews');
    } catch (e) {
      print('❌ Error loading company rating: $e');
      companyRating = 0.0;
      totalReviews = 0;
    }
  }

  /// Load completed tasks with reviews for empresa view
  Future<void> _loadCompletedTasks() async {
    if (currentCompany?.companyId == null) return;

    try {
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
              condition,
              address,
              lat,
              lng,
              userID,
              categoryID,
              category:categoryID(name)
            ),
            request:requestID(
              scheduledDay,
              scheduledStartTime,
              scheduledEndTime
            )
          ''')
          .eq('companyID', currentCompany!.companyId!)
          .eq('workflowStatus', 'completado')
          .order('lastUpdate', ascending: false);

      // Get reviews for these tasks
      final tasksWithReviews = <Map<String, dynamic>>[];
      for (var task in tasks) {
        final articleId = task['article']?['idArticle'];
        if (articleId != null) {
          // Get reviews for this article
          final reviews = await Supabase.instance.client
              .from('reviews')
              .select('''
                idReview,
                starID,
                comment,
                senderID,
                receiverID,
                created_at,
                sender:senderID(idUser, names, role),
                receiver:receiverID(idUser, names, role)
              ''')
              .eq('articleID', articleId)
              .order('created_at', ascending: false);

          // Load article photo
          final urlPattern = 'articles/$articleId';
          final photo = await mediaDatabase.getMainPhotoByPattern(urlPattern);

          tasksWithReviews.add({...task, 'reviews': reviews, 'photo': photo});
        }
      }

      if (mounted) {
        setState(() {
          completedTasks = tasksWithReviews;
        });
      }

      print('✅ Loaded ${completedTasks.length} completed tasks with reviews');
    } catch (e) {
      print('❌ Error loading completed tasks: $e');
    }
  }

  void _logout() async {
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
          builder:
              (context) => EditCompanyProfileScreen(
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
          builder:
              (context) => EditCompanyProfileScreen(
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
      selectedStatusFilters.clear();
      searchQuery = '';
      sortAscending =
          false; // ✅ Reset to descending (latest first) when toggling views
      // Articles are already loaded, just apply filters
      isLoadingArticles = false;
      // Reset pagination
      _currentArticlePage = 1;
      _hasMoreArticles = true;
    });
    _applyFilters();
  }

  /// Refresh all data (stats, articles, ratings)
  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
      isLoadingArticles = true;
      // Reset pagination
      _currentArticlePage = 1;
      _hasMoreArticles = true;
    });
    try {
      await _loadArticleStats();
      await _loadCompanyRating();
      await _loadArticlesFromTasks();
      await _loadArticlePhotosProgressively();
      await _loadCompletedTasks();
      _applyFilters();
    } catch (e) {
      print('❌ Error refreshing data: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isLoadingArticles = false;
        });
      }
    }
  }

  void _showStatusFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
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
                          _buildFilterChip(
                            'En espera',
                            'en_espera',
                            Colors.orange,
                            setModalState,
                          ),
                          _buildFilterChip(
                            'Sin Asignar',
                            'sin_asignar',
                            Colors.purple,
                            setModalState,
                          ),
                          _buildFilterChip(
                            'En Proceso',
                            'en_proceso',
                            Colors.amber,
                            setModalState,
                          ),
                          _buildFilterChip(
                            'Recibido',
                            'recibido',
                            Colors.teal,
                            setModalState,
                          ),
                          _buildFilterChip(
                            'Vencido',
                            'vencido',
                            Colors.red,
                            setModalState,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                selectedStatusFilters.clear();
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

  Widget _buildFilterChip(
    String label,
    String value,
    Color color,
    StateSetter setModalState,
  ) {
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
    // Determine what to display based on profile view
    final displayAvatar =
        isViewingCompanyProfile ? companyAvatar : currentUserAvatar;
    final displayName =
        isViewingCompanyProfile
            ? (currentCompany?.nameCompany ?? 'Empresa')
            : (currentUser?.names ?? 'Usuario');
    final displayRole =
        isViewingCompanyProfile ? 'Empresa' : 'Administrador de Empresa';

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFF2D8A8A),
        body:
            isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
                : RefreshIndicator(
                  color: const Color(0xFF2D8A8A),
                  onRefresh: _refreshData,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Profile header as collapsible app bar
                      SliverAppBar(
                        expandedHeight: !isViewingCompanyProfile ? 150 : 250,
                        floating: false,
                        pinned: false,
                        backgroundColor: const Color(0xFF2D8A8A),
                        flexibleSpace: FlexibleSpaceBar(
                          background: Column(
                            children: [
                              // Profile header section
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  25,
                                  20,
                                  25,
                                  10,
                                ),
                                child: Row(
                                  children: [
                                    // Avatar on the left (company or admin based on toggle)
                                    CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.white,
                                      backgroundImage:
                                          displayAvatar?.url != null
                                              ? CachedNetworkImageProvider(
                                                displayAvatar!.url!,
                                              )
                                              : null,
                                      child:
                                          displayAvatar?.url == null
                                              ? Icon(
                                                isViewingCompanyProfile
                                                    ? Icons.business
                                                    : Icons.person,
                                                size: 60,
                                                color: const Color(0xFF2D8A8A),
                                              )
                                              : null,
                                    ),
                                    const SizedBox(width: 20),
                                    // Name and role on the right
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Profile switcher button
                                              GestureDetector(
                                                onTap: _toggleProfileView,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.3),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    isViewingCompanyProfile
                                                        ? Icons.person_outline
                                                        : Icons
                                                            .business_outlined,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              GestureDetector(
                                                onTap: _showProfileMenu,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.2),
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
                                          // Role display with rating for company
                                          Row(
                                            children: [
                                              Text(
                                                displayRole,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                              if (isViewingCompanyProfile &&
                                                  totalReviews > 0) ...[
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons.star,
                                                  color: Colors.amber,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  companyRating.toStringAsFixed(
                                                    1,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // ✅ Spacing before Objetos card
                              if (!isViewingCompanyProfile)
                                const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      // ✅ Objetos card (only in Admin view) - inline between header and publications
                      if (!isViewingCompanyProfile)
                        SliverToBoxAdapter(
                          child: Transform.translate(
                            offset: const Offset(0, 55),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 15,
                                ),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildObjectStatItem(
                                          '${articleStats['enEspera']}',
                                          'En espera',
                                          Colors.orange,
                                        ),
                                        _buildObjectStatItem(
                                          '${articleStats['sinAsignar']}',
                                          'Sin Asignar',
                                          Colors.purple,
                                        ),
                                        _buildObjectStatItem(
                                          '${articleStats['enProceso']}',
                                          'En Proceso',
                                          Colors.amber,
                                        ),
                                        _buildObjectStatItem(
                                          '${articleStats['recibido']}',
                                          'Recibido',
                                          Colors.teal,
                                        ),
                                        _buildObjectStatItem(
                                          '${articleStats['vencido']}',
                                          'Vencido',
                                          Colors.red,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      // White publications section with rounded top
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
                              SizedBox(
                                height: !isViewingCompanyProfile ? 80 : 25,
                              ),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(25, 0, 25, 10),
                                child: Center(
                                  child: Text(
                                    'Publicaciones',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D8A8A),
                                    ),
                                  ),
                                ),
                              ),
                              // Search bar
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 25,
                                ),
                                child: TextField(
                                  onChanged: (value) {
                                    setState(() {
                                      searchQuery = value;
                                    });
                                    _applyFilters();
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Buscar',
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      color: Colors.grey,
                                    ),
                                    suffixIcon:
                                        searchQuery.isNotEmpty
                                            ? IconButton(
                                              icon: const Icon(
                                                Icons.clear,
                                                color: Colors.grey,
                                              ),
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
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Articles count and controls
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 25,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total ${filteredArticleCards.length} publicaciones',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        // Sort button
                                        IconButton(
                                          icon: Icon(
                                            sortAscending
                                                ? Icons.arrow_upward
                                                : Icons.arrow_downward,
                                            color: const Color(0xFF2D8A8A),
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              sortAscending = !sortAscending;
                                            });
                                            _applyFilters();
                                          },
                                          tooltip:
                                              sortAscending
                                                  ? 'Más antiguos primero'
                                                  : 'Más recientes primero',
                                        ),
                                        // Filter button (only for admin view)
                                        if (!isViewingCompanyProfile)
                                          IconButton(
                                            icon: Icon(
                                              Icons.filter_list,
                                              color:
                                                  selectedStatusFilters.isEmpty
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
                      // Grid of articles as sliver
                      if (isLoadingArticles)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: Color(0xFF2D8A8A),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Cargando artículos...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (filteredArticleCards.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 60,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  searchQuery.isNotEmpty
                                      ? 'No se encontraron publicaciones'
                                      : (isViewingCompanyProfile
                                          ? 'No hay objetos recibidos'
                                          : 'No tienes publicaciones'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 0.85,
                                ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                // ✅ Apply pagination
                                final totalToShow =
                                    _currentArticlePage * _articlesPerPage;
                                final paginatedArticles =
                                    filteredArticleCards
                                        .take(totalToShow)
                                        .toList();
                                final hasMore =
                                    filteredArticleCards.length >
                                    paginatedArticles.length;

                                // Update hasMoreArticles flag
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted && _hasMoreArticles != hasMore) {
                                    setState(() {
                                      _hasMoreArticles = hasMore;
                                    });
                                  }
                                });

                                if (index == paginatedArticles.length) {
                                  // Loading indicator at bottom
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    alignment: Alignment.center,
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          color: Color(0xFF2D8A8A),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Cargando artículos...',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                final card = paginatedArticles[index];
                                return GestureDetector(
                                  onTap: () async {
                                    // Navigate to detail screen
                                    _navigateToDetail(card);
                                  },
                                  child: _buildArticleCard(card),
                                );
                              },
                              childCount: () {
                                final totalToShow =
                                    _currentArticlePage * _articlesPerPage;
                                final paginatedArticles =
                                    filteredArticleCards
                                        .take(totalToShow)
                                        .toList();
                                final hasMore =
                                    filteredArticleCards.length >
                                    paginatedArticles.length;
                                return paginatedArticles.length +
                                    (hasMore ? 1 : 0);
                              }(),
                            ),
                          ),
                        ),
                    ],
                  ),
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
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildArticleCard(Map<String, dynamic> card) {
    final article = card['article'] as Article?;
    if (article == null) return const SizedBox();

    // Get status from card
    final status = card['status'] as String? ?? 'publicado';
    Color statusColor;
    String statusText;

    switch (status) {
      case 'en_espera':
        statusColor = Colors.orange;
        statusText = 'En Espera';
        break;
      case 'sin_asignar':
        statusColor = Colors.purple;
        statusText = 'Sin Asignar';
        break;
      case 'en_proceso':
        statusColor = Colors.amber;
        statusText = 'En Proceso';
        break;
      case 'recibido':
        statusColor = Colors.teal;
        statusText = 'Recibido';
        break;
      case 'vencido':
        statusColor = Colors.red;
        statusText = 'Vencido';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Publicado';
    }

    final photo = articlePhotos[article.id];
    final imageUrl = photo?.url;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image:
            imageUrl != null
                ? DecorationImage(
                  image: CachedNetworkImageProvider(imageUrl),
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
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
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
