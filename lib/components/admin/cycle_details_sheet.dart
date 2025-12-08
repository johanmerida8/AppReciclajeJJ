import 'package:flutter/material.dart';
import 'package:reciclaje_app/components/admin/TopPointsWidget.dart';
import 'package:reciclaje_app/components/admin/star_points_widget.dart';
import '/database/admin/cycleList_db.dart';
import '/model/admin/cycle_star_model.dart';
import '/theme/app_text_styles.dart';
import '/theme/app_colors.dart';
import '/theme/app_spacing.dart';
import '/components/admin/points_calculator.dart'; // <-- generateCarryOverTiers y CarryOverTier

class CycleDetailsSheet extends StatefulWidget {
  final int cycleId;
  final String cycleName;
  final int topQuantity;

  const CycleDetailsSheet({
    super.key,
    required this.cycleId,
    required this.cycleName,
    required this.topQuantity,
  });

  @override
  State<CycleDetailsSheet> createState() => _CycleDetailsSheetState();
}

class _CycleDetailsSheetState extends State<CycleDetailsSheet> {
  final _db = CycleListDB();
  bool _loading = true;
  List<CycleStarModel> _starValues = [];
  List<CarryOverTier> _tiers = [];

  @override
  void initState() {
    super.initState();
    _loadStars();
  }

  Future<void> _loadStars() async {
    final data = await _db.fetchCycleStarValues(widget.cycleId);
    setState(() {
      _starValues = data;
      _tiers = generateCarryOverTiers(
        topCount: widget.topQuantity,
        starValues: _starValues,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.spacingMedium),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicador superior
          Center(
            child: Container(
              width: 45,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.fondoGrisMedio,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Título del ciclo
          Text("Detalles de ${widget.cycleName}", style: AppTextStyles.title),
          const SizedBox(height: 16),

          // ⭐ Puntos por Calificación
          StarPointsWidget(
            title: "⭐ Puntos por Calificación",
            starValues: _starValues,
            reverseOrder: true, // empieza con 5 estrellas
          ),

          const SizedBox(height: 16),
          
          // 🏆 Puntos Iniciales (Top N)
          TopPointsWidget(
            title: "Puntos Iniciales (Top ${widget.topQuantity})",
            tiers: _tiers,
          ),
        ],
      ),
    );
  }
}
