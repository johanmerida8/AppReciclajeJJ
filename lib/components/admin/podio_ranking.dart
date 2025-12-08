import 'package:flutter/material.dart';
import '/model/admin/ranking_model.dart';
import '/theme/app_colors.dart';
import '/theme/app_text_styles.dart';

class PodioRanking extends StatelessWidget {
  final List<RankingModel> ranking;

  const PodioRanking({super.key, required this.ranking});

  @override
  Widget build(BuildContext context) {
final first = ranking.length > 0 ? ranking[0] : null;
final second = ranking.length > 1 ? ranking[1] : null;
final third = ranking.length > 2 ? ranking[2] : null;

    String url(String name) =>
        "https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}"
        "&background=F1F5F9&color=314158&font-size=0.3&size=128&bold=true";

    return Row(
  mainAxisAlignment: MainAxisAlignment.spaceAround,
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    if (second != null)
      _podioItem(user: second, avatar: url(second.names), color: AppColors.verdeMedio, position: 2),
    if (first != null)
      _podioItem(user: first, avatar: url(first.names), color: AppColors.verdeEsmeralda, position: 1),
    if (third != null)
      _podioItem(user: third, avatar: url(third.names), color: AppColors.verdeOscuro, position: 3),
  ],
);

  }

  Widget _podioItem({
    required RankingModel user,
    required String avatar,
    required Color color,
    required int position,
  }) {
    // Altura del escalón según la posición
    double escalonHeight;
    switch (position) {
      case 1:
        escalonHeight = 70; // Primer lugar más alto
        break;
      case 2:
        escalonHeight = 50; // Segundo lugar
        break;
      case 3:
        escalonHeight = 40; // Tercer lugar
        break;
      default:
        escalonHeight = 20;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        /// Avatar
        CircleAvatar(radius: 35, backgroundImage: NetworkImage(avatar)),

        const SizedBox(height: 6),

        /// Nombre
        SizedBox(
          width: 90,
          child: Text(
            user.names,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.blancoLetra,
            ),
          ),
        ),

        /// Puntos
        Text(
          "${user.totalPoints} xp",
          style: const TextStyle(fontSize: 12, color: AppColors.blancoLetra),
        ),

        const SizedBox(height: 6),

        /// Escalón (posición)
        Container(
          height: escalonHeight,
          width: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: const Border(
              bottom: BorderSide(
                color: Colors.white,
                width: 4, // grosor de la línea
              ),
            ),
          ),
          child: Text(
            "$position°",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
