import 'package:flutter/material.dart';
import '/theme/app_colors.dart';
import '/theme/app_spacing.dart';
import '/theme/app_text_styles.dart';

class CycleCard extends StatelessWidget {
  final String name;
  final int state;
  final String startDate;
  final String endDate;
  final String createdAt;
  final int topQuantity;
  final VoidCallback? onPressed;
  final VoidCallback? onArchive;
  final VoidCallback? onShowRanking;

  const CycleCard({
    super.key,
    required this.name,
    required this.state,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.topQuantity,
    this.onPressed,
    this.onArchive,
    this.onShowRanking,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.spacingVerySmall),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: AppColors.fondoBlanco,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppColors.fondoGrisMedio.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila superior: foto + info + menú
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info principal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre
                      Text(
                        name,
                        style: AppTextStyles.textMedium.copyWith(
                          color: AppColors.grisOscuroLetra,
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      // Admin + estado
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Ganador del ciclo',
                              style: AppTextStyles.textSmall.copyWith(
                                color: AppColors.grisLetra,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Text(
                            '  |  ',
                            style: TextStyle(color: AppColors.grisLetra),
                          ),
                          Flexible(
                            child: Text(
                              state == 1 ? 'Activo' : 'Inactivo',
                              style: AppTextStyles.textSmall.copyWith(
                                color:
                                    state == 1
                                        ? AppColors.verdeOscuro
                                        : AppColors.rojo,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Calificación
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            topQuantity.toString(),
                            style: AppTextStyles.textSmall.copyWith(
                              color: AppColors.grisLetra,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Menú
                IconButton(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.fondoGrisOscuro,
                    size: 22,
                  ),
                  onPressed: () => _showOptions(context),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  splashRadius: 20,
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Fila inferior: Inicio | fin | Creación
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Fecha Inicio
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppColors.grisLetra,
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          startDate, // fecha inicio
                          style: AppTextStyles.textSmall.copyWith(
                            color: AppColors.grisLetra,
                          ),
                        ),
                        Text(
                          'Inicio',
                          style: AppTextStyles.textSmall.copyWith(
                            color: AppColors.grisLetra,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(width: 24),

                // Fecha fin
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppColors.grisLetra,
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          endDate, // fecha fin
                          style: AppTextStyles.textSmall.copyWith(
                            color: AppColors.grisLetra,
                          ),
                        ),
                        Text(
                          'fin',
                          style: AppTextStyles.textSmall.copyWith(
                            color: AppColors.grisLetra,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(width: 24),

                // Fecha de creación
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppColors.grisLetra,
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          createdAt, // variable createdAt
                          style: AppTextStyles.textSmall.copyWith(
                            color: AppColors.grisLetra,
                          ),
                        ),
                        Text(
                          'Creación',
                          style: AppTextStyles.textSmall.copyWith(
                            color: AppColors.grisLetra,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 🔽 Menú inferior (Bottom Sheet)
  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.fondoBlanco,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.spacingMedium),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicador superior
              Container(
                width: 45,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.spacingMedium),
                decoration: BoxDecoration(
                  color: AppColors.fondoGrisMedio,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Ver perfil
              ListTile(
                leading: const Icon(
                  Icons.list_rounded,
                  color: AppColors.fondoGrisOscuro,
                ),
                title: const Text(
                  'Mas Detalles',
                  style: AppTextStyles.textLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  onPressed?.call();
                },
              ),
              const SizedBox(height: AppSpacing.spacingMedium),
              // Ver ranking del ciclo
              ListTile(
                leading: const Icon(
                  Icons.leaderboard,
                  color: AppColors.fondoGrisOscuro,
                ),
                title: const Text(
                  'Mostrar Ranking',
                  style: AppTextStyles.textLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  onShowRanking?.call(); // 👈 ejecuta el callback
                },
              ),
              const SizedBox(height: AppSpacing.spacingMedium),
              // Archivar ciclo
              ListTile(
                leading: const Icon(Icons.archive, color: AppColors.rojo),
                title: const Text(
                  'Archivar ciclo',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.rojo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onArchive?.call(); // 👈 ejecuta el callback
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
