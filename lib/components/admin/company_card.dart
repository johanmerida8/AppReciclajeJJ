import 'package:flutter/material.dart';
import '/theme/app_colors.dart';
import '/theme/app_spacing.dart';
import '/theme/app_text_styles.dart';

class CompanyCard extends StatelessWidget {
  final String name;
  final String adminName;
  final int state;
  final String date;
  final String imageUrl;
  final VoidCallback? onPressed;
  final VoidCallback? onArchive;
  final VoidCallback? onEmployees; // 👉 NUEVO CALLBACK
  final int totalEmployees;
  final int totalArticlesApproved;
  final VoidCallback? onApprove; // 👉 NUEVO
  final String isApproved;

  const CompanyCard({
    super.key,
    required this.name,
    required this.adminName,
    required this.state,
    required this.date,
    required this.imageUrl,
    required this.totalEmployees,
    required this.totalArticlesApproved,
    required this.isApproved,

    this.onPressed,
    this.onArchive,
    this.onEmployees, // 👉 NUEVO CALLBACK
    this.onApprove, // 👉 NUEVO
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
                // Foto
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  child: Image.network(
                    imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => Container(
                          width: 60,
                          height: 60,
                          color: AppColors.fondoGrisClaro,
                          child: const Icon(
                            Icons.person,
                            color: AppColors.fondoGrisOscuro,
                            size: 30,
                          ),
                        ),
                  ),
                ),

                const SizedBox(width: AppSpacing.spacingMedium),

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
                              adminName,
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
                      Row(
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 16,
                            color:
                                isApproved == "Approved"
                                    ? AppColors
                                        .verdeOscuro // Aprobado
                                    : isApproved == "Pending"
                                    ? Colors
                                        .orange // Pendiente
                                    : Colors.red, // Rechazado
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isApproved == "Approved"
                                ? "Aprobada"
                                : isApproved == "Pending"
                                ? "Pendiente"
                                : "Rechazada",
                            style: AppTextStyles.textSmall.copyWith(
                              color:
                                  isApproved == "Approved"
                                      ? AppColors.verdeOscuro
                                      : isApproved == "Pending"
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 2),
                      // Calificación/* estrellas */
                      /*
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '5',
                            style: AppTextStyles.textSmall.copyWith(
                              color: AppColors.grisLetra,
                            ),
                          ),
                        ],
                      ),
                      */
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

            // Fila inferior: Empleados | Recolecciones | Fecha
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Empleados
                Row(
                  children: [
                    const Icon(
                      Icons.people,
                      size: 16,
                      color: AppColors.grisLetra,
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$totalEmployees', // número de empleados
                          style: AppTextStyles.textSmall.copyWith(
                            color: AppColors.grisLetra,
                          ),
                        ),
                        Text(
                          'Empleados',
                          style: AppTextStyles.textSmall.copyWith(
                            color: AppColors.grisLetra,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(width: 24),

                // Recolecciones
                Row(
                  children: [
                    const Icon(
                      Icons.local_shipping,
                      size: 16,
                      color: AppColors.grisLetra,
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$totalArticlesApproved', // número de recolecciones
                          style: AppTextStyles.textSmall.copyWith(
                            color: AppColors.grisLetra,
                          ),
                        ),
                        Text(
                          'Recolecciones',
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
                          date, // variable date
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
                  Icons.person_outline,
                  color: AppColors.fondoGrisOscuro,
                ),
                title: const Text(
                  'Ver perfil Empresa',
                  style: AppTextStyles.textLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  onPressed?.call();
                },
              ),
              // Ver perfil
              ListTile(
                leading: const Icon(
                  Icons.person_outline,
                  color: AppColors.fondoGrisOscuro,
                ),
                title: const Text(
                  'Ver perfil Administrador',
                  style: AppTextStyles.textLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  onPressed?.call();
                },
              ),
              // Archivar usuario
              ListTile(
                leading: Icon(
                  state == 1
                      ? Icons.archive_outlined
                      : Icons.unarchive_outlined,
                  color: AppColors.fondoGrisOscuro,
                ),

                title: Text(
                  state == 1 ? 'Archivar empresa' : 'Activar empresa',
                  style: AppTextStyles.textLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  onArchive?.call();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.verified_outlined,
                  color: AppColors.verdeOscuro,
                ),
                title: const Text(
                  'Aprobar empresa',
                  style: AppTextStyles.textLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  onApprove?.call(); // 👉 LLAMADA AL CALLBACK
                },
              ),
              // Ver empleados de la empresa
              ListTile(
                leading: const Icon(
                  Icons.people_outline,
                  color: AppColors.fondoGrisOscuro,
                ),
                title: const Text(
                  'Ver empleados',
                  style: AppTextStyles.textLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  onEmployees?.call(); // 👉 NUEVO CALLBACK
                },
              ),
              const SizedBox(height: AppSpacing.spacingMedium),
            ],
          ),
        );
      },
    );
  }
}
