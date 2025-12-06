import 'package:flutter/material.dart';
import 'package:reciclaje_app/widgets/distribuidor_widget_controller.dart';
import '/model/admin/ranking_model.dart';
import '/database/admin/ranking_db.dart';
import '/theme/app_colors.dart';
import '/theme/app_text_styles.dart';

// Componentes separados
import '/components/admin/podio_ranking.dart';
import '/components/admin/ranking_card.dart';

class CycleRanking extends StatefulWidget {
  final int cycleId;
  final String cycleName;

  const CycleRanking({
    super.key,
    required this.cycleId,
    required this.cycleName,
  });

  @override
  State<CycleRanking> createState() => _CycleRankingState();
}

class _CycleRankingState extends State<CycleRanking> {
  final RankingDB _db = RankingDB();
  List<RankingModel> _ranking = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRanking();
  }

  Future<void> _loadRanking() async {
    setState(() => _isLoading = true);

    final data = await _db.fetchRankingByCycle(widget.cycleId);

    setState(() {
      _ranking = data;
      _isLoading = false;
    });
  }

  int daysRemaining(DateTime endDate) {
    final today = DateTime.now();
    final difference = endDate.difference(today).inDays;
    return difference >= 0 ? difference : 0;
  }

  @override
  Widget build(BuildContext context) {
    final int remainingDays =
        _ranking.isNotEmpty ? daysRemaining(_ranking.first.endDate) : 0;

    return Scaffold(
      backgroundColor: AppColors.fondoBlanco,
      appBar: AppBar(
        backgroundColor: AppColors.verdeOscuro,
        elevation: 0,
        title: Text(
          "Ranking - ${widget.cycleName}",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        centerTitle: false,
        actions: [
          if (_ranking.isNotEmpty)
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: AppColors.amarilloBrillante,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  "$remainingDays días",
                  style: AppTextStyles.textSmall.copyWith(
                    color: AppColors.amarilloBrillante,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
        ],
      ),

      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadRanking,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    /// 🟩 Sección del PODIO con fondo verde
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [AppColors.verdeMedio, AppColors.verdeOscuro],
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          if (_ranking.length >= 1)
                            PodioRanking(ranking: _ranking),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),

                    const SizedBox(height: 0),

                    /// ⚪ Sección de la LISTA con fondo blanco
                    /// ⚪ Sección de la LISTA con fondo blanco y borde redondeado arriba
                    Transform.translate(
                      offset: const Offset(0, -16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.fondoBlanco,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            ..._ranking.asMap().entries.map((entry) {
                              int index = entry.key;
                              var user = entry.value;

                              if (index < 3) return const SizedBox();

                              final avatarUrl =
                                  "https://ui-avatars.com/api/?name=${Uri.encodeComponent(user.names)}"
                                  "&background=F1F5F9&color=314158&font-size=0.3&size=128&bold=true";

                              return RankingCard(
                                user: user,
                                avatarUrl: avatarUrl,
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
