import 'package:reciclaje_app/components/admin/cycle_card.dart';
import 'package:reciclaje_app/components/admin/cycle_details_sheet.dart';
import 'package:reciclaje_app/screen/administrator/CycleRanking.dart';
import 'package:reciclaje_app/screen/administrator/create_cycle_form_fullscreen.dart';

import '/database/admin/cycleList_db.dart';
import '/model/admin/cycle_model.dart';
import '/components/admin/custom_search_bar.dart';
import '/components/admin/filter_buttons.dart';
import '/theme/app_colors.dart';
import '/theme/app_spacing.dart';
import '/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import '/database/admin/ranking_db.dart';

class CycleList extends StatefulWidget {
  const CycleList({super.key});

  @override
  State<CycleList> createState() => _CycleListState();
}

class _CycleListState extends State<CycleList> {
  final CycleListDB _db = CycleListDB();
  final TextEditingController _searchController = TextEditingController();

  bool _showArchived = false;
  bool _ascending = true;
  bool _isLoading = true;

  List<CycleModel> _cycles = [];

  @override
  void initState() {
    super.initState();
    _loadCycles();
  }

  Future<void> _loadCycles() async {
    try {
      final data = await _db.fetchCycles();
      if (mounted) {
        setState(() {
          _cycles = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('❌ Error cargando Ciclos: $e');
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
        title: const Text('Ciclos', style: AppTextStyles.title),
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
                      hintText: 'Buscar ciclos',
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
                      'Total: ${filteredUsers.length} ciclo${filteredUsers.length == 1 ? '' : 's'}',
                      style: AppTextStyles.textSmall,
                    ),
                    const SizedBox(height: AppSpacing.spacingMedium),

                    Expanded(
                      child:
                          filteredUsers.isEmpty
                              ? const Center(
                                child: Text(
                                  'No se encontraron ciclos.',
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
                                  final cycle = filteredUsers[index];
                                  return CycleCard(
                                    name: cycle.name,
                                    state: cycle.state,
                                    startDate:
                                        cycle.startDate
                                            .toLocal()
                                            .toString()
                                            .split(' ')[0],
                                    endDate:
                                        cycle.endDate
                                            .toLocal()
                                            .toString()
                                            .split(' ')[0],
                                    createdAt:
                                        cycle.createdAt
                                            .toLocal()
                                            .toString()
                                            .split(' ')[0],
                                    topQuantity: cycle.topQuantity,
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: AppColors.fondoBlanco,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(
                                              AppSpacing.radiusLarge,
                                            ),
                                          ),
                                        ),
                                        builder:
                                            (_) => CycleDetailsSheet(
                                              cycleId: cycle.idCycle,
                                              cycleName: cycle.name,
                                              topQuantity: cycle.topQuantity,
                                            ),
                                      );
                                    },

                                    onShowRanking: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => CycleRanking(
                                                cycleId: cycle.idCycle,
                                                cycleName: cycle.name,
                                              ),
                                        ),
                                      );
                                    },

                                    onArchive: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) {
                                          return AlertDialog(
                                            title: const Text("Archivar ciclo"),
                                            content: const Text(
                                              "¿Estás seguro de que quieres archivar este ciclo?\n"
                                              "Los usuarios ya no podrán participar, pero los datos se mantendrán.",
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      ctx,
                                                      false,
                                                    ),
                                                child: const Text("Cancelar"),
                                              ),
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      ctx,
                                                      true,
                                                    ),
                                                child: const Text("Archivar"),
                                              ),
                                            ],
                                          );
                                        },
                                      );

                                      if (confirm != true) return;

                                      final success = await _db.deactivateCycle(
                                        cycle.idCycle,
                                      );

                                      if (success) {
                                        _loadCycles(); // 🔄 recargar lista

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Ciclo archivado correctamente",
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Error al archivar ciclo",
                                            ),
                                            backgroundColor: Colors.red,
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

      floatingActionButton: FloatingActionButton(
        backgroundColor:
            AppColors.verdeOscuro, // ← cambia este color a lo que quieras
        foregroundColor: Colors.white,
        onPressed: () async {
          final result = await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => CreateCycleFormFullScreen(existingCycles: _cycles),
          );

          if (result == true) {
            _loadCycles(); // 🔄 vuelve a cargar los ciclos
          }
        },

        child: const Icon(Icons.add),
      ),
    );
  }

  /// 🔍 Aplica búsqueda, archivado y orden al listado
  List<CycleModel> _applyFilters() {
    List<CycleModel> filtered =
        _cycles.where((cycle) {
          final query = _searchController.text.toLowerCase();
          final matchesSearch = cycle.name.toLowerCase().contains(query);
          final matchesArchived =
              _showArchived ? cycle.state == 0 : cycle.state == 1;
          return matchesSearch && matchesArchived;
        }).toList();

    filtered.sort((a, b) {
      final cmp = a.createdAt.compareTo(b.createdAt);
      return _ascending ? cmp : -cmp;
    });

    return filtered;
  }
}
