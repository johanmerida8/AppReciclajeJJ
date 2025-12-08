import 'package:flutter/material.dart';
import '/theme/app_colors.dart';
import '/theme/app_spacing.dart';
import '/theme/app_text_styles.dart';

class UserCard extends StatelessWidget {
  final String name;
  final int articles;
  final int state;
  final String date;
  final String imageUrl;
  final VoidCallback? onPressed;
  final VoidCallback? onArchive;

  const UserCard({
    super.key,
    required this.name,
    required this.articles,
    required this.state,
    required this.date,
    required this.imageUrl,
    this.onPressed,
    this.onArchive,
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
          //border: Border.all(color: AppColors.fondoGrisClaro, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.fondoGrisMedio.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 🖼️ Imagen de usuario o avatar
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

            // 🧾 Información del usuario (usa Expanded para evitar overflow)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre
                  Text(
                    name,
                    style: AppTextStyles.textMedium.copyWith(
                      color: AppColors.grisOscuroLetra,
                      //fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),

                  const SizedBox(height: 2),

                  // Artículos + Estado
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '$articles artículos',
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

                  const SizedBox(height: 0),
                  Row(
                    children: [
                      // 🔹 Calificación con icono
                      /*
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '5',
                        style: AppTextStyles.textSmall.copyWith(
                          color: AppColors.grisLetra,
                        ),
                      ),
                      */
                      const SizedBox(
                        width: 12,
                      ), // espacio entre calificación y fecha
                      // Fecha de creación
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppColors.grisLetra,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: AppTextStyles.textSmall.copyWith(
                          color: AppColors.grisLetra,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ⋮ Botón de menú (ajustado para no romper layout)
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
                title: const Text('Ver perfil', style: AppTextStyles.textLarge),
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
                  state == 1 ? 'Archivar usuario' : 'Activar usuario',
                  style: AppTextStyles.textLarge,
                ),

                onTap: () {
                  Navigator.pop(context);
                  onArchive?.call();
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
