import 'package:reciclaje_app/screen/administrator/employeesList.dart';

import '/database/admin/companyList_db.dart';
import '/model/admin/company_model.dart';
import '/components/admin/company_card.dart';
import '/components/admin/custom_search_bar.dart';
import '/components/admin/filter_buttons.dart';
import '/theme/app_colors.dart';
import '/theme/app_spacing.dart';
import '/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

class CompanyList extends StatefulWidget {
  const CompanyList({super.key});

  @override
  State<CompanyList> createState() => _CompanyListState();
}

class _CompanyListState extends State<CompanyList> {
  final CompanyListDB _db = CompanyListDB();
  final TextEditingController _searchController = TextEditingController();

  bool _showArchived = false;
  bool _ascending = true;
  bool _isLoading = true;

  List<CompanyModel> _companies = [];

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    try {
      final data = await _db.fetchCompanies();
      if (mounted) {
        setState(() {
          _companies = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('❌ Error cargando usuarios: $e');
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
        title: const Text('Compañias', style: AppTextStyles.title),
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
                      hintText: 'Buscar compañia',
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
                      'Total: ${filteredUsers.length} compañia${filteredUsers.length == 1 ? '' : 's'}',
                      style: AppTextStyles.textSmall,
                    ),
                    const SizedBox(height: AppSpacing.spacingMedium),

                    Expanded(
                      child:
                          filteredUsers.isEmpty
                              ? const Center(
                                child: Text(
                                  'No se encontraron compañias.',
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
                                  return CompanyCard(
                                    name: user.nameCompany,
                                    adminName: user.adminName,
                                    state: user.state,
                                    isApproved: user.isApproved,
                                    totalEmployees: user.totalEmployees,
                                    totalArticlesApproved:
                                        user.totalArticlesApproved,
                                    date:
                                        user.createdAt
                                            .toLocal()
                                            .toString()
                                            .split(' ')[0],
                                    imageUrl:
                                        user.avatarUrl?.isNotEmpty == true
                                            ? user.avatarUrl!
                                            : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(user.nameCompany)}'
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

                                      final ok = await _db.setCompanyState(
                                        user.idCompany,
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
                                                  ? "Compañía archivada correctamente"
                                                  : "Compañía activada correctamente",
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    onEmployees: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => EmployeesList(
                                                companyId: user.idCompany,
                                              ),
                                        ),
                                      );
                                    },
                                    onApprove: () async {
                                      final ok = await _db
                                          .updateCompanyApproval(
                                            user.idCompany,
                                            "Approved",
                                          );

                                      if (ok && mounted) {
                                        setState(() {
                                          user.isApproved =
                                              "Approved"; // Solo si existe en el modelo
                                        });

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Empresa aprobada correctamente",
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
  List<CompanyModel> _applyFilters() {
    List<CompanyModel> filtered =
        _companies.where((company) {
          final query = _searchController.text.toLowerCase();
          final matchesSearch = company.nameCompany.toLowerCase().contains(
            query,
          );
          final matchesArchived =
              _showArchived ? company.state == 0 : company.state == 1;
          return matchesSearch && matchesArchived;
        }).toList();

    filtered.sort((a, b) {
      final cmp = a.createdAt.compareTo(b.createdAt);
      return _ascending ? cmp : -cmp;
    });

    return filtered;
  }
}
