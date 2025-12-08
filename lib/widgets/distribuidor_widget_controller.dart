import 'package:home_widget/home_widget.dart';

class DistribuidorWidgetController {
  static Future<void> actualizar({
    required int puntos,
    required int ranking,
  }) async {
    await HomeWidget.saveWidgetData<int>('puntos', puntos);
    await HomeWidget.saveWidgetData<int>('ranking', ranking);

    await HomeWidget.updateWidget(
      name: 'DistribuidorWidget',
      androidName: 'DistribuidorWidget',
    );
    
    // Force widget to refresh with new layout
    print('🔄 Widget updated - Points: $puntos, Ranking: $ranking');
  }
  
  /// Force widget refresh (useful after layout changes)
  static Future<void> forceRefresh() async {
    await HomeWidget.updateWidget(
      name: 'DistribuidorWidget',
      androidName: 'DistribuidorWidget',
    );
    print('🔄 Widget force refreshed');
  }
}
