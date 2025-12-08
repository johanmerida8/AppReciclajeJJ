import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/widgets/distribuidor_widget_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final _authService = AuthService();
  final _usersDatabase = UsersDatabase();
  final _mediaDatabase = MediaDatabase();

  List<Map<String, dynamic>> _rankings = [];
  Map<String, dynamic>? _currentUserRanking;
  String? _currentUserEmail;
  int? _currentUserId;
  int? _daysRemaining;
  bool _isCycleExpired = false;
  bool _isRefreshing = false; // ✅ Track manual refresh state
  bool _isInitialLoad = true; // ✅ Track initial load

  // ✅ Realtime subscription
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscription();
    _loadRankings(isInitialLoad: true); // ✅ Initial load
  }

  @override
  void dispose() {
    // ✅ Clean up realtime subscription
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  /// ✅ Setup realtime subscription for userPointsLog changes
  void _setupRealtimeSubscription() async {
    try {
      // Get current user ID first
      _currentUserEmail = _authService.getCurrentUserEmail();
      if (_currentUserEmail == null) return;

      final currentUser = await _usersDatabase.getUserByEmail(
        _currentUserEmail!,
      );
      if (currentUser == null) return;

      _currentUserId = currentUser.id;

      print('🔄 Setting up realtime subscription for user $_currentUserId');

      // Subscribe to userPointsLog changes for current user
      _realtimeChannel =
          Supabase.instance.client
              .channel('userPointsLog_changes')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'userPointsLog',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'userID',
                  value: _currentUserId,
                ),
                callback: (payload) {
                  print('🔔 Realtime update received for userPointsLog');
                  print('   Event: ${payload.eventType}');
                  print('   Data: ${payload.newRecord}');

                  // Reload rankings when points change (silent reload, no refresh indicator)
                  _loadRankings(isInitialLoad: false);
                },
              )
              .subscribe();

      print('✅ Realtime subscription active');
    } catch (e) {
      print('❌ Error setting up realtime subscription: $e');
    }
  }

  /// Calculate user's average rating from reviews they've received
  Future<Map<String, dynamic>> _calculateUserRating(int userId) async {
    try {
      final reviewsData = await Supabase.instance.client
          .from('reviews')
          .select('starID')
          .eq('receiverID', userId)
          .eq('state', 1); // Only active reviews

      if (reviewsData.isEmpty) {
        return {'rating': 0.0, 'totalReviews': 0};
      }

      int totalStars = 0;
      for (var review in reviewsData) {
        totalStars += (review['starID'] as int? ?? 0);
      }

      final avgRating = totalStars / reviewsData.length;
      return {'rating': avgRating, 'totalReviews': reviewsData.length};
    } catch (e) {
      print('❌ Error calculating rating for user $userId: $e');
      return {'rating': 0.0, 'totalReviews': 0};
    }
  }

  Future<void> _loadRankings({bool isInitialLoad = false}) async {
    // Only set refresh state for manual refreshes (not initial load or realtime updates)
    if (!isInitialLoad && mounted) {
      setState(() => _isRefreshing = true);
    }

    try {
      _currentUserEmail = _authService.getCurrentUserEmail();

      // Fetch rankings from current_ranking view
      final rankingsData = await Supabase.instance.client
          .from('current_ranking2')
          .select()
          .order('position', ascending: true)
          .limit(100);

      print('📊 Loaded ${rankingsData.length} rankings');

      // ✅ STEP 1: Load current user data FIRST
      if (_currentUserEmail != null && rankingsData.isNotEmpty) {
        final currentUser = await _usersDatabase.getUserByEmail(
          _currentUserEmail!,
        );
        
        if (currentUser != null) {
          _currentUserId = currentUser.id;
          _currentUserRanking = rankingsData.firstWhere(
            (r) => r['idUser'] == currentUser.id,
            orElse: () => {},
          );

          // Load current user's avatar and rating
          if (_currentUserRanking != null && _currentUserRanking!.isNotEmpty) {
            final userData = await _usersDatabase.getUserById(_currentUserId!);
            final userRole = userData?.role?.toLowerCase() ?? 'user';

            // Try new path first (with role)
            String avatarPattern = 'users/$userRole/$_currentUserId/avatars/';
            Multimedia? avatar = await _mediaDatabase.getMainPhotoByPattern(
              avatarPattern,
            );

            // If not found, try old path (without role)
            if (avatar == null) {
              avatarPattern = 'users/$_currentUserId/avatar/';
              avatar = await _mediaDatabase.getMainPhotoByPattern(avatarPattern);
            }

            _currentUserRanking!['avatar'] = avatar;

            // Calculate rating
            final ratingData = await _calculateUserRating(_currentUserId!);
            _currentUserRanking!['userRating'] = ratingData['rating'];
            _currentUserRanking!['totalReviews'] = ratingData['totalReviews'];

            // Update widget with current user's position and points
            final userPosition = _currentUserRanking!['position'] ?? 0;
            final userPoints = _currentUserRanking!['totalpoints'] ?? 0;

            print('📊 Updating DistribuidorWidget for current user:');
            print('   Position: $userPosition');
            print('   Points: $userPoints');

            await DistribuidorWidgetController.actualizar(
              puntos: userPoints,
              ranking: userPosition,
            );

            // Update UI with current user info
            if (mounted) {
              setState(() {});
            }
          }
        }
      }

      // ✅ STEP 2: Load cycle information
      if (rankingsData.isNotEmpty) {
        final cycleId = rankingsData.first['idCycle'];

        if (cycleId != null) {
          try {
            final now = DateTime.now();

            final cycleData =
                await Supabase.instance.client
                    .from('cycle')
                    .select('endDate, startDate, state, name')
                    .eq('idCycle', cycleId)
                    .eq('state', 1)
                    .lte('startDate', now.toIso8601String())
                    .gte('endDate', now.toIso8601String())
                    .maybeSingle();

            final endDateStr = cycleData?['endDate'] as String?;
            final startDateStr = cycleData?['startDate'] as String?;
            final cycleName = cycleData?['name'];

            print('🔍 Debug - cycleId: $cycleId, cycleName: $cycleName');
            print('   📅 Period: $startDateStr to $endDateStr');
            print('   🕒 Current: ${now.toIso8601String()}');

            if (endDateStr != null && cycleData != null) {
              final endDate = DateTime.parse(endDateStr);

              final difference = endDate.difference(
                DateTime(now.year, now.month, now.day),
              );
              final daysLeft = difference.inDays + 1;

              if (daysLeft <= 0) {
                _isCycleExpired = true;
                _daysRemaining = null;
                print('⚠️ Cycle has expired. End date was: $endDate');
              } else {
                _isCycleExpired = false;
                _daysRemaining = daysLeft;
                print(
                  '✅ Cycle active. $daysLeft days remaining until $endDate',
                );
              }
            } else {
              _isCycleExpired = true;
              _daysRemaining = null;
              print('⚠️ No active cycle found for current date period');
            }

            // Update UI with cycle info
            if (mounted) {
              setState(() {});
            }
          } catch (e) {
            print('❌ Error loading cycle data: $e');
            _isCycleExpired = false;
            _daysRemaining = null;
          }
        } else {
          _isCycleExpired = false;
          _daysRemaining = null;
        }
      }

      // ✅ STEP 3: Update UI with basic ranking data
      if (mounted) {
        setState(() {
          _rankings = List<Map<String, dynamic>>.from(rankingsData);
        });
      }

      // ✅ STEP 4: Load other users' avatars and ratings progressively
      for (int i = 0; i < rankingsData.length; i++) {
        final ranking = rankingsData[i];
        final userId = ranking['idUser'];
        
        // Skip current user (already loaded)
        if (userId == _currentUserId) {
          if (mounted) {
            setState(() {
              _rankings[i] = _currentUserRanking!;
            });
          }
          continue;
        }
        
        if (userId != null) {
          // Get user data to fetch role for avatar path
          final userData = await _usersDatabase.getUserById(userId);
          final userRole = userData?.role?.toLowerCase() ?? 'user';

          // Try new path first (with role)
          String avatarPattern = 'users/$userRole/$userId/avatars/';
          Multimedia? avatar = await _mediaDatabase.getMainPhotoByPattern(
            avatarPattern,
          );

          // If not found, try old path (without role) for backward compatibility
          if (avatar == null) {
            avatarPattern = 'users/$userId/avatar/';
            avatar = await _mediaDatabase.getMainPhotoByPattern(avatarPattern);
          }

          ranking['avatar'] = avatar;

          // Calculate real rating
          final ratingData = await _calculateUserRating(userId);
          ranking['userRating'] = ratingData['rating'];
          ranking['totalReviews'] = ratingData['totalReviews'];

          // Update UI after each user is loaded
          if (mounted) {
            setState(() {
              _rankings[i] = ranking;
            });
          }
        }
      }
    } catch (e) {
      print('❌ Error loading rankings: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _isInitialLoad = false; // ✅ Initial load complete
        });
      }
    }
  }

  /// Get gradient colors for podium positions
  List<Color> _getPositionGradient(int position) {
    switch (position) {
      case 1:
        return [
          const Color(0xFFFFD700),
          const Color(0xFFFFB300),
        ]; // Gold gradient
      case 2:
        return [
          const Color(0xFFC0C0C0),
          const Color(0xFF9E9E9E),
        ]; // Silver gradient
      case 3:
        return [
          const Color(0xFFCD7F32),
          const Color(0xFF8B5A2B),
        ]; // Bronze gradient
      default:
        return [const Color(0xFF2D8A8A), const Color(0xFF1F6060)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2D8A8A),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                _buildHeader(),
                // Top 3 Podium
                if (_rankings.length >= 3) _buildPodium(),
                // Rest of rankings list
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child:
                        _rankings.isEmpty && _isInitialLoad
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF2D8A8A),
                                ),
                              )
                            : (_rankings.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(32.0),
                                      child: Text(
                                        'No hay participantes en el ranking',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )
                                : (_rankings.length > 3
                                    ? ListView.builder(
                                        padding: const EdgeInsets.only(
                                          top: 20,
                                          bottom: 100,
                                        ),
                                        itemCount: _rankings.length - 3,
                                        itemBuilder: (context, index) {
                                          final ranking = _rankings[index + 3];
                                          final isCurrentUser =
                                              _currentUserRanking != null &&
                                              ranking['idUser'] ==
                                                  _currentUserRanking!['idUser'];
                                          return _buildRankingCard(
                                            ranking,
                                            isCurrentUser,
                                          );
                                        },
                                      )
                                    : const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(32.0),
                                          child: Text(
                                            'No hay suficientes participantes en el ranking',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ))),
                  ),
                ),
              ],
            ),
            // ✅ Full screen loading overlay when refreshing
            if (_isRefreshing)
              Container(
                color: const Color(0xFF2D8A8A),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _isRefreshing
          ? null
          : FloatingActionButton(
              onPressed: () => _loadRankings(isInitialLoad: false),
              backgroundColor: const Color(0xFF2D8A8A),
              child: const Icon(Icons.refresh, color: Colors.white),
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // User profile
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                backgroundImage:
                    _currentUserRanking?['avatar'] != null
                        ? CachedNetworkImageProvider(
                          (_currentUserRanking!['avatar'] as Multimedia).url!,
                        )
                        : null,
                child:
                    _currentUserRanking?['avatar'] == null
                        ? const Icon(Icons.person, color: Color(0xFF2D8A8A))
                        : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentUserRanking?['names'] ?? 'Usuario',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${(_currentUserRanking?['totalpoints'] ?? 0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Days remaining or expired badge - Always show if we have cycle data
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  _isCycleExpired
                      ? Colors.red
                      : (_daysRemaining != null && _daysRemaining! <= 3
                          ? Colors.red
                          : Colors.amber),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  _isCycleExpired ? Icons.warning : Icons.access_time,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _isCycleExpired
                      ? 'VENCIDO'
                      : (_daysRemaining != null
                          ? '$_daysRemaining Días'
                          : 'Sin ciclo'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium() {
    if (_rankings.length < 3) return const SizedBox();

    final first = _rankings[0];
    final second = _rankings.length > 1 ? _rankings[1] : null;
    final third = _rankings.length > 2 ? _rankings[2] : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Second place
          if (second != null) Expanded(child: _buildPodiumCard(second, 2, 130)),
          const SizedBox(width: 10),
          // First place (taller)
          Expanded(child: _buildPodiumCard(first, 1, 170)),
          const SizedBox(width: 10),
          // Third place
          if (third != null) Expanded(child: _buildPodiumCard(third, 3, 110)),
        ],
      ),
    );
  }

  Widget _buildPodiumCard(
    Map<String, dynamic> ranking,
    int position,
    double height,
  ) {
    final avatar = ranking['avatar'] as Multimedia?;
    final name = ranking['names'] as String? ?? 'Nombre';
    final points = ranking['totalpoints'] ?? 0;
    final gradientColors = _getPositionGradient(position);
    final userRating = (ranking['userRating'] as num?)?.toDouble() ?? 0.0;
    final totalReviews = ranking['totalReviews'] ?? 0;
    final isCurrentUser =
        _currentUserRanking != null &&
        ranking['idUser'] == _currentUserRanking!['idUser'];

    return Column(
      children: [
        // Avatar
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isCurrentUser ? Colors.amber : Colors.white,
              width: isCurrentUser ? 3 : 2,
            ),
          ),
          child: CircleAvatar(
            radius: position == 1 ? 36 : 32,
            backgroundColor: Colors.white,
            backgroundImage:
                avatar?.url != null
                    ? CachedNetworkImageProvider(avatar!.url!)
                    : null,
            child:
                avatar?.url == null
                    ? Icon(
                      Icons.person,
                      color: const Color(0xFF2D8A8A),
                      size: position == 1 ? 36 : 32,
                    )
                    : null,
          ),
        ),
        const SizedBox(height: 8),
        // Name
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        // Rating
        if (totalReviews > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 14),
              const SizedBox(width: 2),
              Text(
                userRating.toStringAsFixed(1),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        const SizedBox(height: 8),
        // Podium with gradient
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradientColors[1].withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$position',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$points EXP',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankingCard(Map<String, dynamic> ranking, bool isCurrentUser) {
    final position = ranking['position'] ?? 0;
    final avatar = ranking['avatar'] as Multimedia?;
    final name = ranking['names'] as String? ?? 'Nombre';
    final points = ranking['totalpoints'] ?? 0;
    final userRating = (ranking['userRating'] as num?)?.toDouble() ?? 0.0;
    final totalReviews = ranking['totalReviews'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:
            isCurrentUser
                ? const Color(0xFF2D8A8A).withOpacity(0.1)
                : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser ? const Color(0xFF2D8A8A) : Colors.grey[300]!,
          width: isCurrentUser ? 2 : 1,
        ),
        boxShadow:
            isCurrentUser
                ? [
                  BoxShadow(
                    color: const Color(0xFF2D8A8A).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                : [],
      ),
      child: Row(
        children: [
          // Position number
          Container(
            width: 32,
            alignment: Alignment.center,
            child: Text(
              '$position',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color:
                    isCurrentUser ? const Color(0xFF2D8A8A) : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF2D8A8A).withOpacity(0.1),
            backgroundImage:
                avatar?.url != null
                    ? CachedNetworkImageProvider(avatar!.url!)
                    : null,
            child:
                avatar?.url == null
                    ? const Icon(Icons.person, color: Color(0xFF2D8A8A))
                    : null,
          ),
          const SizedBox(width: 12),
          // Name and rating
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color:
                        isCurrentUser
                            ? const Color(0xFF2D8A8A)
                            : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (totalReviews > 0)
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        userRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    'Sin reseñas',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          // Points
          Row(
            children: [
              const Icon(Icons.bolt, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                '$points EXP',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color:
                      isCurrentUser
                          ? const Color(0xFF2D8A8A)
                          : Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
