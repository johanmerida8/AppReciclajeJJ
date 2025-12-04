import '/database/admin/userList_db.dart';
import '/model/admin/user_model.dart';
import '/components/admin/user_card.dart';
import '/components/admin/custom_search_bar.dart';
import '/components/admin/filter_buttons.dart';
import '/theme/app_colors.dart';
import '/theme/app_spacing.dart';
import '/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

class EmployeesList extends StatefulWidget {
  const EmployeesList({super.key});

  @override
  State<EmployeesList> createState() => _EmployeesListState();
}

class _EmployeesListState extends State<EmployeesList> {
  final UserListDB _db = UserListDB();
  final TextEditingController _searchController = TextEditingController();

  bool _showArchived = false;
  bool _ascending = true;
  bool _isLoading = true;

  List<UserModel> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final data = await _db.fetchUsers();
      if (mounted) {
        setState(() {
          _users = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('❌ Error cargando distribuidores: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _applyFilters();

    return Scaffold(
      backgroundColor: AppColors.fondoBlanco,
      appBar: AppBar(
        backgroundColor: AppColors.fondoBlanco,
        elevation: 0,
        toolbarHeight: 48,
        title: const Text('Distribuidores', style: AppTextStyles.title),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(AppSpacing.paddingbody),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomSearchBar(
                      controller: _searchController,
                      hintText: 'Buscar distribuidor',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.spacingMedium),

                    // 🔘 Componente de filtros (Archivados / Ascendente)
                    FilterButtons(
                      archivedOnly: _showArchived,
                      ascending: _ascending,
                      onArchivedToggle:
                          () => setState(() => _showArchived = !_showArchived),
                      onOrderToggle:
                          () => setState(() => _ascending = !_ascending),
                    ),

                    const SizedBox(height: AppSpacing.spacingMedium),

                    Text(
                      'Total: ${filteredUsers.length} distribuidor${filteredUsers.length == 1 ? '' : 'es'}',
                      style: AppTextStyles.textSmall,
                    ),
                    const SizedBox(height: AppSpacing.spacingMedium),

                    Expanded(
                      child:
                          filteredUsers.isEmpty
                              ? const Center(
                                child: Text(
                                  'No se encontraron distribuidores.',
                                  style: AppTextStyles.textMedium,
                                ),
                              )
                              : ListView.separated(
                                itemCount: filteredUsers.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(
                                      height: AppSpacing.spacingMedium,
                                    ),
                                itemBuilder: (context, index) {
                                  final user = filteredUsers[index];
                                  return UserCard(
                                    name: user.names,
                                    articles: user.articles,
                                    state: user.state,
                                    date:
                                        user.createdAt
                                            .toLocal()
                                            .toString()
                                            .split(' ')[0],
                                    imageUrl:
                                        user.avatarUrl?.isNotEmpty == true
                                            ? user.avatarUrl!
                                            : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(user.names)}'
                                                '&background=F1F5F9'
                                                '&color=314158'
                                                '&font-size=0.3'
                                                '&size=128'
                                                '&bold=true',

                                    onPressed: () {
                                      // Acción para abrir perfil o detalles
                                    },
                                    onArchive: () async {
                                      final newState = user.state == 1 ? 0 : 1;

                                      final ok = await _db.setUserState(
                                        user.idUser,
                                        newState,
                                      );

                                      if (ok && mounted) {
                                        setState(() {
                                          user.state = newState;
                                        });

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              newState == 0
                                                  ? "Usuario archivado correctamente"
                                                  : "Usuario activado nuevamente",
                                            ),
                                          ),
                                        );
                                      }
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

  /// 🔍 Aplica búsqueda, archivado y orden al listado
  List<UserModel> _applyFilters() {
    List<UserModel> filtered =
        _users.where((user) {
          final query = _searchController.text.toLowerCase();
          final matchesSearch = user.names.toLowerCase().contains(query);
          final matchesArchived =
              _showArchived ? user.state == 0 : user.state == 1;
          return matchesSearch && matchesArchived;
        }).toList();

    filtered.sort((a, b) {
      final cmp = a.createdAt.compareTo(b.createdAt);
      return _ascending ? cmp : -cmp;
    });

    return filtered;
  }
}
