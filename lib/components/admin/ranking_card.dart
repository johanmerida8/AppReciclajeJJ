import 'package:flutter/material.dart';
import '/model/admin/ranking_model.dart';
import '/theme/app_colors.dart';
import '/theme/app_text_styles.dart';

class RankingCard extends StatelessWidget {
  final RankingModel user;
  final String avatarUrl;

  const RankingCard({
    super.key,
    required this.user,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: AppColors.fondoBlanco,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "#${user.position}",
              style: AppTextStyles.textMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.verdeOscuro,
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 25,
              backgroundImage: NetworkImage(avatarUrl),
            ),
          ],
        ),

        title: Text(
          user.names,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.textMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.verdeOscuro,
          ),
        ),

        trailing: Text(
          "${user.totalPoints} xp",
          style: AppTextStyles.textMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.fondoGrisMedio,
          ),
        ),
      ),
    );
  }
}
